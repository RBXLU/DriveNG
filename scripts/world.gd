class_name World
extends Node3D

## Игровая сессия: карта, игрок, камера, трафик, эффекты, реакция на аварии.

signal pause_requested
signal spawn_menu_requested
signal derby_state(alive: int, total: int)
signal derby_finished(win: bool)

var map: MapBase
var player: Car
var camera: CameraRig
var fx: Effects
var audio: AudioManager
var traffic: TrafficManager
var debris_root: Node3D
var spawned: Array[Car] = []
var derby_bots: Array[Car] = []
var derby_over := false
var _impact_cd := {}
var _fx_t := 0.0
var last_crash_kmh := 0.0
var max_speed := 0.0
var distance := 0.0


func start(map_id: String, car_id: String, color: Color, tod: int, density: int) -> void:
	Game.world = self
	match map_id:
		"city": map = MapCity.new()
		"highway": map = MapHighway.new()
		"mountain": map = MapMountain.new()
		"derby": map = MapDerby.new()
		_: map = MapTestGrounds.new()
	Game.map = map
	fx = Effects.new()
	fx.name = "Effects"
	add_child(fx)
	Game.fx = fx
	audio = AudioManager.new()
	audio.name = "Audio"
	add_child(audio)
	Game.audio = audio
	debris_root = Node3D.new()
	debris_root.name = "Debris"
	add_child(debris_root)
	Game.debris_root = debris_root
	add_child(map)
	map.build(tod)

	player = _make_car(car_id, color, true)
	player.controller = PlayerController.new()
	player.global_transform = map.spawn_transform(0)
	Game.player = player
	player.message.connect(Game.message)
	if map.is_night():
		player.set_lights(true)

	camera = CameraRig.new()
	add_child(camera)
	camera.set_target(player)

	if map.net != null and density > 0 and Game.map_info(map_id)["traffic"]:
		traffic = TrafficManager.new()
		traffic.name = "Traffic"
		add_child(traffic)
		traffic.setup(map.net, self, density)
		traffic.allow_heavy = map_id != "mountain"
		traffic.prefill()
	if map_id == "derby":
		_start_derby()


func _make_car(id: String, color: Color, is_player: bool) -> Car:
	var spec := CarDatabase.get_car(id)
	var car := Car.new()
	car.setup(spec, color, is_player)
	add_child(car)
	Game.register_car(car)
	car.impact.connect(on_car_impact)
	return car


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	if Game.world == self:
		Game.clear_world_refs()


# ---------------------------------------------------------------- ввод

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		pause_requested.emit()
	elif event.is_action_pressed("reset_car"):
		reset_player()
	elif event.is_action_pressed("repair_car"):
		repair_player()
	elif event.is_action_pressed("camera"):
		camera.next_mode()
	elif event.is_action_pressed("lights"):
		player.set_lights(not player.lights_on)
	elif event.is_action_pressed("beacons"):
		player.beacons_on = not player.beacons_on
	elif event.is_action_pressed("slowmo"):
		Game.cycle_slowmo()
		Game.message("Время: ×%s" % str(Game.slowmo_levels[Game.slowmo_index]))
	elif event.is_action_pressed("engine"):
		if player.engine_running:
			player.engine_running = false
		else:
			player.restart_engine()
	elif event.is_action_pressed("spawn_menu"):
		spawn_menu_requested.emit()


func reset_player() -> void:
	var p := player.global_position
	var h := map.height_at(p)
	if map.net != null:
		var near := map.net.nearest(p, -player.global_transform.basis.z)
		if not near.is_empty():
			var lane: RoadNetwork.Lane = near[0]
			var lp := lane.point_at(near[1])
			if lp.distance_to(p) < 40.0:
				var dir := lane.dir_at(near[1])
				player.reset_upright(lp, atan2(-dir.x, -dir.z))
				camera.set_target(player)
				return
	player.reset_upright(Vector3(p.x, h, p.z))
	camera.set_target(player)


func repair_player() -> void:
	player.repair()
	player.restart_engine()
	Game.message("Машина отремонтирована")


func respawn_player() -> void:
	player.repair()
	var xf := map.spawn_transform(0)
	player.reset_upright(xf.origin, xf.basis.get_euler().y)
	camera.set_target(player)


## Краш-тест: машина ставится перед стеной и получает заданную скорость
func crash_test(kmh: float, target: String = "wall") -> void:
	player.repair()
	var start := Vector3(0, 0.15, -400.0 + 1.5 + 45.0)
	match target:
		"pole": start = Vector3(-60, 0.15, -330.0 + 45.0)
		"angle": start = Vector3(90, 0.15, -330.0 + 45.0)
		"bus": start = Vector3(0, 0.15, -150.0 + 45.0)
	player.reset_upright(start, 0.0)
	var v := Vector3(0, 0, -kmh / 3.6)
	player.linear_velocity = v
	PhysicsServer3D.body_set_state(player.get_rid(), PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, v)
	for w in player.wheels:
		w.spin = kmh / 3.6 / w.radius
	player.gear = 3
	camera.set_target(player)
	Game.message("Краш-тест: %d км/ч" % int(kmh))


func change_player_car(id: String, color: Color) -> void:
	var xf := player.global_transform
	Game.unregister_car(player)
	player.queue_free()
	player = _make_car(id, color, true)
	player.controller = PlayerController.new()
	player.message.connect(Game.message)
	var yaw := atan2(-(-xf.basis.z).x, -(-xf.basis.z).z)
	player.global_transform = Transform3D(Basis(Vector3.UP, yaw), xf.origin + Vector3.UP * 0.5)
	Game.player = player
	if map.is_night():
		player.set_lights(true)
	camera.set_target(player)


## Спавн машины: parked — стоит перед игроком; ram — едет навстречу; traffic — в поток
func spawn_car(id: String, mode: String) -> void:
	var spec := CarDatabase.get_car(id)
	var cols: Array = spec["colors"]
	var col: Color = cols[randi() % cols.size()]
	var fwd := -player.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var car := _make_car(id, col, false)
	match mode:
		"ram":
			var p := player.global_position + fwd * 60.0
			p.y = map.height_at(p) + 0.1
			car.global_transform = Transform3D(Basis.looking_at(-fwd, Vector3.UP), p)
			car.controller = AIDriver.new(AIDriver.Mode.RAM)
			car.can_sleep = false
		"traffic":
			if map.net != null:
				var near := map.net.nearest(player.global_position + fwd * 30.0)
				if not near.is_empty():
					var lane: RoadNetwork.Lane = near[0]
					var ai := AIDriver.new(AIDriver.Mode.TRAFFIC)
					ai.place(map.net, lane, near[1])
					car.controller = ai
					car.can_sleep = false
					car.global_transform = Transform3D(Basis.looking_at(lane.dir_at(near[1]), Vector3.UP), lane.point_at(near[1]) + Vector3.UP * 0.1)
			if car.controller == null:
				car.global_transform = Transform3D(Basis.looking_at(fwd, Vector3.UP), player.global_position + fwd * 20.0 + Vector3.UP * 0.2)
		_:
			var p2 := player.global_position + fwd * (12.0 + float(spec["L"]))
			p2.y = map.height_at(p2) + 0.1
			var side := fwd.cross(Vector3.UP)
			car.global_transform = Transform3D(Basis.looking_at(side, Vector3.UP), p2)
	if map.is_night():
		car.lights_on = true
	spawned.append(car)


func clear_spawned() -> void:
	for c in spawned:
		if is_instance_valid(c):
			Game.unregister_car(c)
			c.queue_free()
	spawned.clear()
	for d in Game.debris:
		if is_instance_valid(d):
			d.queue_free()
	Game.debris.clear()


# ---------------------------------------------------------------- дерби

func _start_derby() -> void:
	var ids := ["vostok_2107", "volna_24", "nordhaus_240", "liberty_interceptor", "hayato_landmaster", "gazel", "liberty_fseries", "vostok_niva"]
	ids.shuffle()
	var n := 7 if int(Settings.get_v("quality_level")) >= 2 else 5
	for i in n:
		var spec := CarDatabase.get_car(ids[i % ids.size()])
		var cols: Array = spec["colors"]
		var car := _make_car(spec["id"], cols[randi() % cols.size()], false)
		car.global_transform = map.spawn_transform(i + 1)
		car.controller = AIDriver.new(AIDriver.Mode.DERBY)
		car.can_sleep = false
		derby_bots.append(car)
	derby_state.emit(derby_bots.size(), derby_bots.size())


func _check_derby() -> void:
	if derby_bots.is_empty() or derby_over:
		return
	var alive := 0
	for c in derby_bots:
		if is_instance_valid(c) and not c.wrecked and c.global_position.y > -20.0:
			alive += 1
	derby_state.emit(alive, derby_bots.size())
	if player.wrecked:
		derby_over = true
		derby_finished.emit(false)
	elif alive == 0:
		derby_over = true
		derby_finished.emit(true)


func restart_derby() -> void:
	for c in derby_bots:
		if is_instance_valid(c):
			Game.unregister_car(c)
			c.queue_free()
	derby_bots.clear()
	derby_over = false
	respawn_player()
	_start_derby()


# ---------------------------------------------------------------- аварии и эффекты

func on_car_impact(car: Car, point: Vector3, strength: float, other: Object) -> void:
	var key := car.get_instance_id()
	var now := Time.get_ticks_msec()
	if _impact_cd.has(key) and now - int(_impact_cd[key]) < 120:
		return
	_impact_cd[key] = now
	audio.play_crash(point, strength)
	if strength > 3.0:
		fx.impact_burst(point, car.linear_velocity * 0.5, strength)
	var involves_player := car == player or other == player
	if involves_player:
		camera.add_shake(clamp(strength / 18.0, 0.05, 1.0))
		if strength > 6.0 and car == player:
			last_crash_kmh = strength * 3.6
			Game.message("Удар! Δv %d км/ч" % int(strength * 3.6))


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var sp: float = abs(player.speed)
	max_speed = max(max_speed, sp)
	distance += sp * delta
	map.update_map(delta)
	_fx_t -= delta
	if _fx_t <= 0.0:
		_fx_t = 0.05
		_wheel_effects()
		_check_derby()


## Следы шин и дым для машин рядом с камерой
func _wheel_effects() -> void:
	var cp := camera.global_position
	for c in Game.cars:
		if not is_instance_valid(c) or c.global_position.distance_squared_to(cp) > 90.0 * 90.0:
			continue
		for i in c.wheels.size():
			var w: Car.Wheel = c.wheels[i]
			var key := c.get_instance_id() * 16 + i
			if w.detached or not w.grounded:
				fx.skid_break(key)
				continue
			var slip: float = max(w.slip_speed, w.lat_slip - 1.2)
			var dirt := w.surface_type != "asphalt"
			if slip > 2.0 or (dirt and abs(c.speed) > 6.0 and slip > 0.8):
				var k: float = clamp(slip / 10.0, 0.1, 1.0)
				fx.skid(key, w.contact, w.normal, w.width * 0.9, k, dirt)
				if slip > 4.0 or dirt:
					fx.tire_smoke(w.contact, c.linear_velocity, k, dirt)
			else:
				fx.skid_break(key)
			# колесо без покрышки/оторванная подвеска — искры
			if w.burst and abs(c.speed) > 8.0 and randf() < 0.3:
				fx.sparks(w.contact, c.linear_velocity * 0.5, 0.4)
