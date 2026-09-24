class_name TrafficManager
extends Node

## Поддерживает поток ИИ-машин вокруг игрока: спавн за пределами видимости
## по полосам, удаление далёких, ограничение по настройке плотности.

var net: RoadNetwork
var parent: Node3D
var max_cars := 8
var spawn_min := 90.0
var spawn_max := 260.0
var despawn := 330.0
var allow_heavy := true
var cars: Array[Car] = []
var _t := 0.0
var _rng := RandomNumberGenerator.new()


func setup(p_net: RoadNetwork, p_parent: Node3D, density: int) -> void:
	net = p_net
	parent = p_parent
	_rng.randomize()
	var cap: int = int(Settings.get_v("traffic"))
	var k: float = [0.0, 0.45, 0.75, 1.0][clampi(density, 0, 3)]
	max_cars = int(round(cap * k))


## Сразу заполнить дорогу машинами (при старте карты)
func prefill() -> void:
	for i in max_cars:
		_spawn_one(35.0, spawn_max)


func _physics_process(delta: float) -> void:
	if net == null:
		return
	net.update(delta)
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.5
	var pp := _focus()
	for c in cars.duplicate():
		if not is_instance_valid(c):
			cars.erase(c)
			continue
		var d: float = c.global_position.distance_to(pp)
		if d > despawn or (c.wrecked and d > 120.0) or c.global_position.y < -50.0:
			_remove(c)
	if cars.size() < max_cars:
		_spawn_one(spawn_min, spawn_max)


func _focus() -> Vector3:
	if Game.player != null and is_instance_valid(Game.player):
		return Game.player.global_position
	var cam := get_viewport().get_camera_3d()
	return cam.global_position if cam != null else Vector3.ZERO


func _remove(c: Car) -> void:
	cars.erase(c)
	Game.unregister_car(c)
	c.queue_free()


func clear() -> void:
	for c in cars:
		if is_instance_valid(c):
			Game.unregister_car(c)
			c.queue_free()
	cars.clear()


func _spawn_one(min_d: float, max_d: float) -> void:
	var sp := net.random_spawn(_focus(), min_d, max_d, _rng)
	if sp.is_empty():
		return
	var lane: RoadNetwork.Lane = sp[0]
	var s: float = sp[1]
	var p := lane.point_at(s)
	for c in Game.cars:
		if is_instance_valid(c) and c.global_position.distance_to(p) < 18.0:
			return
	var id := CarDatabase.random_traffic_id(_rng, allow_heavy)
	var spec := CarDatabase.get_car(id)
	var cols: Array = spec["colors"]
	var car := Car.new()
	car.setup(spec, cols[_rng.randi() % cols.size()], false)
	var ai := AIDriver.new(AIDriver.Mode.TRAFFIC)
	ai.place(net, lane, s)
	car.controller = ai
	car.can_sleep = false
	var dir := lane.dir_at(s)
	var xf := Transform3D(Basis.looking_at(dir, Vector3.UP), p + Vector3.UP * 0.05)
	parent.add_child(car)
	car.global_transform = xf
	car.linear_velocity = dir * ai.cruise * 0.7
	if Game.map != null and Game.map.is_night():
		car.lights_on = true
	if spec.get("extra", "") == "police" and _rng.randf() < 0.3:
		car.beacons_on = true
	Game.register_car(car)
	cars.append(car)
	car.impact.connect(Game.world.on_car_impact)
