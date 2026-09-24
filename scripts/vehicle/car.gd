class_name Car
extends RigidBody3D

## Физика автомобиля: подвеска на лучах, модель шины (статическое/кинетическое
## трение, пробуксовка, блокировка), двигатель с кривой момента, сцепление,
## коробка (автомат/механика), ABS/TCS/ESC, аэродинамика.
## Столкновения собираются в _integrate_forces и превращаются в деформацию (CarDamage).

signal impact(car: Car, point: Vector3, strength: float, other: Object)
signal part_detached(car: Car, part: CarPart)
signal message(text: String)

const LAYER_WORLD := 1
const LAYER_CARS := 2
const LAYER_DEBRIS := 4
const LAYER_PROPS := 8
const G := 9.81


class Wheel:
	var pos := Vector3.ZERO       # центр колеса в покое (модель)
	var mount := Vector3.ZERO     # начало луча подвески
	var radius := 0.3
	var width := 0.2
	var rest := 0.2
	var sag := 0.1
	var k := 30000.0
	var c := 3000.0
	var steer := false
	var front := true
	var side := 1
	var drive := 0.0              # доля момента
	var inertia := 1.0
	var ray: RayCast3D
	var part: CarPart
	var comp := 0.0
	var prev_comp := 0.0
	var grounded := false
	var spin := 0.0
	var angle := 0.0
	var slipping := false
	var slip_speed := 0.0
	var lat_slip := 0.0
	var load := 0.0
	var contact := Vector3.ZERO
	var normal := Vector3.UP
	var toe := 0.0
	var grip_mult := 1.0
	var detached := false
	var susp_health := 1.0
	var damage := 0.0
	var surface := 1.0
	var surface_type := "asphalt"
	var burst := false


var spec: Dictionary
var car_color: Color
var is_player := false
var controller: Object = null
var parts: Array[CarPart] = []
var wheels: Array[Wheel] = []
var damage: CarDamage
var model: Node3D
var paint_mat: ShaderMaterial
var head_mat: StandardMaterial3D
var tail_mat: StandardMaterial3D
var shape_nodes := {}   # part.name -> CollisionShape3D
var com := Vector3.ZERO

# управление (0..1, руль -1..1: + вправо)
var throttle := 0.0
var brake := 0.0
var steer := 0.0
var handbrake := 0.0
var want_shift := 0            # ручная КПП: +1/-1

# состояние
var gear := 1
var rpm := 800.0
var shift_timer := 0.0
var rev_timer := 0.0
var speed := 0.0
var steer_angle := 0.0
var engine_health := 1.0
var engine_running := true
var radiator_leak := 0.0
var on_fire := 0.0
var tcs_factor := 1.0
var lights_on := false
var beacons_on := false
var hazard := false
var wrecked := false
var total_damage := 0.0
var throttle_eff := 0.0
var brake_eff := 0.0
var drive_wheel_count := 0
var slip_sound := 0.0
var scrape := 0.0
var local_accel := Vector3.ZERO
var _prev_vel := Vector3.ZERO
var _pre_lin := Vector3.ZERO
var _pre_ang := Vector3.ZERO
var _flash_t := 0.0
var _abs_active := false
var _headlights: Array[SpotLight3D] = []
var air_time := 0.0

var gears: Array = []
var final_drive := 3.5
var max_torque := 200.0
var max_power := 100000.0
var redline := 6000.0
var idle := 800.0
var torque_rpm := 3500.0
var is_ev := false
var brake_torque := 2000.0
var steer_max := 0.6
var grip := 1.0
var roll_factor := 0.5
var engine_zone := Vector3.ZERO


func setup(p_spec: Dictionary, color: Color, player: bool = false) -> void:
	spec = p_spec
	car_color = color
	is_player = player
	name = str(spec["id"])
	mass = float(spec["mass"])
	collision_layer = LAYER_CARS
	collision_mask = LAYER_WORLD | LAYER_CARS | LAYER_DEBRIS | LAYER_PROPS
	contact_monitor = true
	max_contacts_reported = 12
	continuous_cd = true
	can_sleep = not player
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp = 0.08
	var pm := PhysicsMaterial.new()
	pm.friction = 0.45
	pm.bounce = 0.02
	physics_material_override = pm

	gears = spec["gears"]
	final_drive = spec["final"]
	max_torque = spec["torque"]
	max_power = float(spec["hp"]) * 735.5
	redline = spec["redline"]
	idle = spec["idle"]
	torque_rpm = spec["torque_rpm"]
	is_ev = spec.get("ev", false)
	brake_torque = spec["brake"]
	steer_max = deg_to_rad(spec["steer_max"])
	grip = spec["grip"]
	roll_factor = spec.get("roll_factor", 0.5)
	rpm = idle
	_build()


func _build() -> void:
	var b := CarBuilder.new()
	var res := b.build(spec, car_color)
	model = res["model"]
	add_child(model)
	parts = res["parts"]
	paint_mat = res["paint"]
	head_mat = res["head_mat"]
	tail_mat = res["tail_mat"]
	com = res["com"]
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = com
	var L: float = spec["L"]
	var W: float = spec["W"]
	var hh: float = spec["H"] - spec["clearance"]
	inertia = Vector3(mass * (hh * hh + L * L) / 12.0, mass * (W * W + L * L) / 12.0 * 0.9, mass * (W * W + hh * hh) / 12.0)
	match spec.get("engine", "front"):
		"front": engine_zone = Vector3(0, spec["clearance"] + 0.35, -L * 0.5 + 0.75)
		"mid": engine_zone = Vector3(0, spec["clearance"] + 0.35, L * 0.5 - 1.35)
		_: engine_zone = Vector3(0, spec["clearance"] + 0.35, L * 0.5 - 0.7)

	# формы коллизии — выпуклые оболочки деформируемых частей
	shape_nodes.clear()
	for p in parts:
		if p.shape_samples.size() > 0:
			var cs := CollisionShape3D.new()
			var sh := ConvexPolygonShape3D.new()
			sh.points = p.shape_points()
			cs.shape = sh
			cs.name = "shape_" + p.name
			p.shape = sh
			add_child(cs)
			shape_nodes[p.name] = cs

	# колёса
	wheels.clear()
	var wdefs: Array = res["wheels"]
	var n := wdefs.size()
	var corner_m := mass / n
	var hz: float = spec.get("spring_hz", 1.5)
	var zeta: float = spec.get("damping", 0.35)
	var drive: String = spec["drive"]
	drive_wheel_count = 0
	for wd in wdefs:
		var w := Wheel.new()
		w.pos = wd["pos"]
		w.radius = wd["radius"]
		w.width = wd["width"]
		w.side = wd["side"]
		w.steer = wd["steer"]
		w.front = wd["front"]
		w.part = wd["part"]
		var omega := TAU * hz
		w.k = corner_m * omega * omega
		w.c = 2.0 * zeta * sqrt(w.k * corner_m)
		w.sag = corner_m * G / w.k
		w.rest = w.sag + 0.11 + w.radius * 0.1
		w.mount = w.pos + Vector3.UP * (w.rest - w.sag)
		match drive:
			"FWD": w.drive = 1.0 if w.front else 0.0
			"RWD": w.drive = 0.0 if w.front else 1.0
			_: w.drive = 0.4 if w.front else 0.6
		if w.drive > 0.0:
			drive_wheel_count += 1
		w.inertia = 0.6 * (w.radius / 0.3) * (w.radius / 0.3) * (mass / 1400.0)
		var ray := RayCast3D.new()
		ray.position = w.mount
		ray.target_position = Vector3(0, -(w.rest + w.radius + 0.05), 0)
		ray.collision_mask = LAYER_WORLD | LAYER_CARS
		ray.hit_from_inside = false
		ray.name = "ray_%d" % wheels.size()
		add_child(ray)
		w.ray = ray
		w.comp = w.sag
		w.prev_comp = w.sag
		wheels.append(w)
	# нормируем доли момента по оси
	var fsum := 0.0
	var rsum := 0.0
	for w in wheels:
		if w.front:
			fsum += 1.0
		else:
			rsum += 1.0
	for w in wheels:
		if w.drive > 0.0:
			w.drive /= (fsum if w.front else rsum)

	damage = CarDamage.new(self)
	_apply_lights()


## Полный ремонт: пересобираем модель, формы и колёса
func repair() -> void:
	for p in parts:
		if p.attached and is_instance_valid(p.node):
			p.node.queue_free()
	if is_instance_valid(model):
		model.queue_free()
	for k in shape_nodes:
		var cs: Node = shape_nodes[k]
		if is_instance_valid(cs):
			cs.queue_free()
	for w in wheels:
		if is_instance_valid(w.ray):
			w.ray.queue_free()
	for l in _headlights:
		if is_instance_valid(l):
			l.queue_free()
	_headlights.clear()
	engine_health = 1.0
	engine_running = true
	radiator_leak = 0.0
	on_fire = 0.0
	wrecked = false
	total_damage = 0.0
	hazard = false
	_build()
	if lights_on:
		set_lights(true)


func reset_upright(pos: Vector3 = Vector3.INF, yaw: float = INF) -> void:
	var p := global_position if pos == Vector3.INF else pos
	var fwd := -global_transform.basis.z
	var y := atan2(-fwd.x, -fwd.z) if yaw == INF else yaw
	var xf := Transform3D(Basis(Vector3.UP, y), p + Vector3.UP * 0.6)
	PhysicsServer3D.body_set_state(get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, xf)
	PhysicsServer3D.body_set_state(get_rid(), PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, Vector3.ZERO)
	PhysicsServer3D.body_set_state(get_rid(), PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3.ZERO)
	global_transform = xf
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	for w in wheels:
		w.spin = 0.0
		w.slipping = false
	gear = 1


# ---------------------------------------------------------------- цикл

func _physics_process(delta: float) -> void:
	if controller != null:
		controller.update(self, delta)
	damage.process_queue()
	# ускорение в локальных координатах (для петель дверей и камеры)
	var a: Vector3 = (linear_velocity - _prev_vel) / maxf(delta, 1e-4)
	_prev_vel = linear_velocity
	local_accel = local_accel.lerp(global_transform.basis.inverse() * a, 0.3)
	if radiator_leak > 0.0 and engine_running:
		engine_health = max(0.0, engine_health - radiator_leak * delta * 0.004 * (0.3 + rpm / redline))
		if engine_health <= 0.0:
			_stall()


func _process(delta: float) -> void:
	_update_visuals(delta)
	damage.update_visual(delta)


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var dt := state.step
	var xf := state.transform
	var b := xf.basis
	var up := b.y
	var fwd := -b.z
	var lin := state.linear_velocity
	var ang := state.angular_velocity
	var com_g := xf * com
	speed = lin.dot(fwd)

	_collect_contacts(state, com_g)
	_pre_lin = lin
	_pre_ang = ang
	_drivetrain(dt)

	# рулевое
	var sp: float = abs(speed)
	var lim: float = steer_max * lerpf(1.0, 0.32, clampf(sp / 42.0, 0.0, 1.0)) if is_player else steer_max
	var target := steer * lim
	steer_angle = move_toward(steer_angle, target, dt * (3.0 if abs(target) > abs(steer_angle) else 4.5))

	# первый проход: сжатия подвески
	var grounded := 0
	for w in wheels:
		w.grounded = false
		if w.detached:
			continue
		if w.ray.is_colliding():
			var hit := w.ray.get_collision_point()
			var mount_g := xf * w.mount
			var dist := (mount_g - hit).dot(up)
			w.comp = clamp(w.rest + w.radius - dist, 0.0, w.rest + 0.08)
			if w.comp > 0.0:
				w.grounded = true
				w.contact = hit
				w.normal = w.ray.get_collision_normal()
				grounded += 1
				var col := w.ray.get_collider()
				w.surface = 1.0
				w.surface_type = "asphalt"
				if col != null and col.has_meta("grip"):
					w.surface = col.get_meta("grip")
					w.surface_type = col.get_meta("surface", "asphalt")
				if Game.map != null:
					var sg: Vector2 = Game.map.surface_at(hit, col)
					if sg.x > 0.0:
						w.surface = sg.x
						w.surface_type = "dirt" if sg.y > 0.5 else "asphalt"
		if not w.grounded:
			w.comp = move_toward(w.comp, 0.0, dt * 2.0)

	if grounded == 0:
		air_time += dt
	else:
		air_time = 0.0

	var m_eff: float = mass / maxi(1, grounded)
	var static_load := mass * G / wheels.size()
	slip_sound = 0.0
	var i := 0
	while i < wheels.size():
		var w := wheels[i]
		# стабилизатор: пары колёс одной оси
		var arb := 0.0
		if i + 1 < wheels.size() and wheels[i + 1].pos.z == w.pos.z:
			var w2 := wheels[i + 1]
			var d := w.comp - w2.comp
			arb = d * w.k * (0.6 if w.front else 0.35)
			_wheel_forces(state, w, dt, arb, m_eff, static_load, com_g, lin, ang, up, fwd)
			_wheel_forces(state, w2, dt, -arb, m_eff, static_load, com_g, lin, ang, up, fwd)
			i += 2
		else:
			_wheel_forces(state, w, dt, 0.0, m_eff, static_load, com_g, lin, ang, up, fwd)
			i += 1

	# аэродинамика
	var v2 := lin.length_squared()
	if v2 > 1.0:
		var drag: Vector3 = -lin * lin.length() * 0.6125 * float(spec["cd"]) * float(spec["area"])
		state.apply_force(drag, com_g - xf.origin)
		var df: float = spec.get("downforce", 0.0)
		if df > 0.0:
			state.apply_force(-up * 1.225 * df * float(spec["area"]) * v2, com_g - xf.origin)

	# ESC: гасим избыточную скорость рыскания
	if Settings.get_v("esc") and is_player and grounded >= 3 and sp > 6.0 and handbrake < 0.1:
		var wb: float = spec["wheelbase"]
		var yaw_expected := speed * tan(steer_angle) / wb * -1.0
		var yaw_rate := ang.dot(up)
		var err := yaw_rate - yaw_expected
		if abs(err) > 0.25:
			var corr: float = clamp((abs(err) - 0.25) * 0.6, 0.0, 1.0) * sign(err)
			state.apply_torque(-up * corr * inertia.y * 4.0)
			throttle_eff *= 0.7


func _pac(a: float) -> float:
	# упрощённая «магическая формула»: пик ~7°, скольжение ~78% от пика
	return sin(1.5 * atan(a * 14.0))


func _wheel_forces(state: PhysicsDirectBodyState3D, w: Wheel, dt: float, arb: float, m_eff: float, static_load: float, com_g: Vector3, lin: Vector3, ang: Vector3, up: Vector3, fwd: Vector3) -> void:
	var drive_t := _wheel_drive_torque(w)
	var brake_t := _wheel_brake_torque(w)
	var r := w.radius * (0.88 if w.burst else 1.0)
	if not w.grounded:
		# колесо в воздухе: свободно раскручивается двигателем, тормоза его останавливают
		w.spin += drive_t / (w.inertia * 3.0) * dt
		var bd := brake_t / w.inertia * dt
		w.spin = 0.0 if abs(w.spin) <= bd else w.spin - sign(w.spin) * bd
		w.spin *= 0.998
		w.slipping = false
		w.load = 0.0
		w.slip_speed = 0.0
		return
	var comp_vel := (w.comp - w.prev_comp) / dt
	w.prev_comp = w.comp
	var fs: float = w.k * w.comp * lerpf(0.35, 1.0, w.susp_health) + w.c * comp_vel + arb
	if w.comp > w.rest:
		fs += (w.comp - w.rest) * w.k * 10.0
		if comp_vel > 3.0 and damage != null:
			w.susp_health = max(0.0, w.susp_health - (comp_vel - 3.0) * 0.04)
	fs = clamp(fs, 0.0, static_load * 6.0)
	var hit := w.contact
	state.apply_force(up * fs, hit - state.transform.origin)
	w.load = fs

	# шина
	var n := w.normal
	var v := lin + ang.cross(hit - com_g)
	var sa := w.toe + (steer_angle if w.steer else 0.0)
	var heading := fwd.rotated(up, -sa)
	var tf := (heading - n * heading.dot(n)).normalized()
	var ts := tf.cross(n)
	var vl := v.dot(tf)
	var vs := v.dot(ts)
	var load_k: float = clamp(1.0 - 0.08 * (fs / max(static_load, 1.0) - 1.0), 0.75, 1.1)
	var mu := grip * w.surface * w.grip_mult * load_k
	var max_f := mu * fs

	# боковая сила
	var slip_a: float = atan2(vs, maxf(absf(vl), 0.9))
	w.lat_slip = abs(vs)
	var fy: float = -signf(vs) * max_f * _pac(absf(slip_a))
	var fy_cap: float = abs(vs) * m_eff / dt * 0.8
	fy = clamp(fy, -fy_cap, fy_cap)

	# продольная сила
	var fx := 0.0
	var roll_w := vl / r
	var abs_on: bool = Settings.get_v("abs") if is_player else true
	var hb := handbrake > 0.1 and not w.front
	if not w.slipping:
		var f_drive := drive_t / r
		var fb_max := brake_t / r
		if abs_on and not hb:
			fb_max = min(fb_max, max_f * 0.97)
		var f_hold := -vl * m_eff / dt
		var f_br: float = clamp(f_hold, -fb_max, fb_max)
		fx = f_drive + f_br
		fx += clamp(f_hold, -0.012 * fs, 0.012 * fs)
		if abs(fx) > max_f:
			if abs(f_drive) > 1.0 and sign(f_drive) == sign(fx) and abs(f_drive) > fb_max:
				w.slipping = true
				w.spin = roll_w + sign(f_drive) * 0.8 / r
			elif fb_max > max_f and (not abs_on or hb):
				w.slipping = true
				w.spin = roll_w * 0.8
			fx = clamp(fx, -max_f, max_f)
		if not w.slipping:
			w.spin = roll_w
		w.slip_speed = 0.0
	else:
		var slip_v := w.spin * r - vl
		fx = sign(slip_v) * max_f * 0.9 if abs(slip_v) > 0.05 else 0.0
		var torque := drive_t - fx * r
		var ns := w.spin + torque / w.inertia * dt
		var bdv := brake_t / w.inertia * dt
		ns = 0.0 if abs(ns) <= bdv else ns - sign(ns) * bdv
		if (ns * r - vl) * slip_v <= 0.0:
			w.slipping = false
			ns = roll_w
		w.spin = ns
		w.slip_speed = abs(slip_v)
		fy *= 0.6

	var tot := sqrt(fx * fx + fy * fy)
	if tot > max_f and tot > 0.0:
		var s := max_f / tot
		fx *= s
		fy *= s
	var app := hit + up * (up.dot(com_g - hit) * roll_factor)
	state.apply_force(tf * fx + ts * fy, app - state.transform.origin)
	slip_sound = max(slip_sound, max(w.slip_speed, abs(vs) - 1.5) * (1.0 if w.surface_type == "asphalt" else 0.3))


# ---------------------------------------------------------------- трансмиссия

func gear_ratio(g: int) -> float:
	if g == 0:
		return 0.0
	if g < 0:
		return -float(spec["reverse"])
	return float(gears[clampi(g - 1, 0, gears.size() - 1)])


func engine_torque_at(r: float) -> float:
	if is_ev:
		var om: float = max(r * TAU / 60.0, 1.0)
		return min(max_torque, max_power / om)
	var s := 0.0
	if r < torque_rpm:
		s = lerp(0.62, 1.0, smoothstep(idle * 0.8, torque_rpm, r))
	else:
		var q: float = (r - torque_rpm) / maxf(1.0, redline - torque_rpm)
		s = lerp(1.0, 0.7, q * q)
	var t := max_torque * s
	var om2: float = max(r * TAU / 60.0, 1.0)
	return min(t, max_power * 1.04 / om2)


var _drive_total := 0.0
var _engine_brake := 0.0


func _drivetrain(dt: float) -> void:
	var thr := throttle
	var brk := brake
	var auto: bool = int(Settings.get_v("gearbox")) == 0 or not is_player
	if auto:
		if gear >= 0 and speed < 0.9 and brk > 0.3 and thr < 0.05:
			rev_timer += dt
			if rev_timer > 0.25:
				gear = -1
				rev_timer = 0.0
		elif gear < 0 and speed > -0.9 and thr > 0.3 and brk < 0.05:
			rev_timer += dt
			if rev_timer > 0.25:
				gear = 1
				rev_timer = 0.0
		else:
			rev_timer = 0.0
		if gear < 0:
			var tmp := thr
			thr = brk
			brk = tmp
		if gear == 0:
			gear = 1
	else:
		if want_shift != 0:
			var ng := clampi(gear + want_shift, -1, gears.size())
			if ng != gear:
				gear = ng
				shift_timer = 0.2
			want_shift = 0

	# TCS
	var spinning := false
	for w in wheels:
		if w.drive > 0.0 and w.slipping and w.grounded and w.spin * gear_ratio(gear) > 0.0:
			spinning = true
	var tcs_on: bool = Settings.get_v("tcs") if is_player else true
	if tcs_on and spinning:
		tcs_factor = move_toward(tcs_factor, 0.25, dt * 5.0)
	else:
		tcs_factor = move_toward(tcs_factor, 1.0, dt * 2.0)
	thr *= tcs_factor if tcs_on else 1.0
	throttle_eff = thr
	brake_eff = brk

	# обороты
	var avg := 0.0
	var nd := 0
	for w in wheels:
		if w.drive > 0.0 and not w.detached:
			avg += w.spin
			nd += 1
	avg = avg / nd if nd > 0 else 0.0
	var ratio := gear_ratio(gear) * final_drive
	var wheel_rpm := avg * ratio * 60.0 / TAU
	var clutch := 1.0
	if shift_timer > 0.0:
		shift_timer -= dt
		clutch = 0.0
		rpm = move_toward(rpm, max(idle, wheel_rpm), 9000.0 * dt)
	elif is_ev:
		rpm = abs(wheel_rpm)
	else:
		var launch: float = lerp(idle, min(redline * 0.55, torque_rpm + 1200.0), thr)
		if wheel_rpm < launch and wheel_rpm < idle * 1.8:
			rpm = move_toward(rpm, max(launch, wheel_rpm), 6000.0 * dt)
			clutch = clamp(0.35 + wheel_rpm / max(1.0, launch), 0.35, 1.0)
		else:
			rpm = wheel_rpm
	if not engine_running:
		rpm = move_toward(rpm, 0.0, 3000.0 * dt)
	rpm = clamp(rpm, 0.0 if (is_ev or not engine_running) else idle * 0.9, redline * 1.03)

	var health_k: float = lerp(0.25, 1.0, engine_health)
	var te := engine_torque_at(rpm) * thr * health_k
	if rpm >= redline and not is_ev:
		te = 0.0
	if not engine_running:
		te = 0.0
	# торможение двигателем
	_engine_brake = 0.0
	if thr < 0.05 and clutch > 0.5 and engine_running:
		_engine_brake = max_torque * (0.12 if not is_ev else 0.25) * clamp(rpm / redline, 0.2, 1.0)
	_drive_total = te * ratio * 0.88 * clutch

	# автомат: переключения
	if auto and shift_timer <= 0.0 and gear >= 1 and not is_ev:
		var up_rpm: float = lerp(max(torque_rpm + 600.0, idle * 2.5), redline * 0.93, clamp(thr * 1.2, 0.0, 1.0))
		if rpm > up_rpm and gear < gears.size() and not spinning and speed > 2.0:
			gear += 1
			shift_timer = 0.22
		elif gear > 1:
			var down_rpm := rpm * gear_ratio(gear - 1) / gear_ratio(gear)
			var trigger: float = lerp(idle * 1.5, redline * 0.55, thr)
			if rpm < trigger and down_rpm < redline * 0.85:
				gear -= 1
				shift_timer = 0.18


func _wheel_drive_torque(w: Wheel) -> float:
	if w.drive <= 0.0 or w.detached:
		return 0.0
	var t := _drive_total * w.drive
	if _engine_brake > 0.0 and gear != 0:
		var ratio: float = abs(gear_ratio(gear) * final_drive)
		t -= sign(w.spin) * _engine_brake * ratio * w.drive * 0.9
	return t


func _wheel_brake_torque(w: Wheel) -> float:
	var t := brake_eff * brake_torque * (1.15 if w.front else 0.85)
	if handbrake > 0.1 and not w.front:
		t += handbrake * brake_torque * 2.5
	# автоматическое удержание на месте
	if controller != null and throttle_eff < 0.05 and abs(speed) < 0.4:
		t = max(t, brake_torque * 0.3)
	if controller == null:
		t = max(t, brake_torque * 0.5)
	return t * (w.radius / 0.32)


func _stall() -> void:
	if engine_running:
		engine_running = false
		if is_player:
			message.emit("Двигатель заглох!")


func restart_engine() -> void:
	if engine_health > 0.05:
		engine_running = true


# ---------------------------------------------------------------- столкновения

func _collect_contacts(state: PhysicsDirectBodyState3D, com_g: Vector3) -> void:
	var n := state.get_contact_count()
	if n == 0:
		scrape = move_toward(scrape, 0.0, 0.1)
		return
	var groups := {}
	var sc := 0.0
	for i in n:
		var imp: Vector3 = state.get_contact_impulse(i)
		var j := imp.length()
		var p := state.get_contact_local_position(i)
		var other := state.get_contact_collider_object(i)
		var rel := state.get_contact_local_velocity_at_position(i) - state.get_contact_collider_velocity_at_position(i)
		var nrm := state.get_contact_local_normal(i)
		var tang := rel - nrm * rel.dot(nrm)
		var ts := tang.length()
		if ts > 2.5 and j > 1.0:
			sc = max(sc, ts)
			damage.queue_scrape(p, ts)
		if j < mass * 0.9:
			continue
		var key: int = other.get_instance_id() if other != null else 0
		if not groups.has(key):
			groups[key] = {"j": 0.0, "p": Vector3.ZERO, "d": Vector3.ZERO, "pts": [], "other": other, "app": 0.0}
		var g: Dictionary = groups[key]
		var dir := imp / j
		if dir.dot(com_g - p) < 0.0:
			dir = -dir
		# скорость сближения до шага (отличает удар от опоры/упора)
		var v_pre := _pre_lin + _pre_ang.cross(p - com_g)
		var app: float = -(v_pre - state.get_contact_collider_velocity_at_position(i)).dot(dir)
		g["app"] = max(float(g["app"]), app)
		g["j"] += j
		g["p"] += p * j
		g["d"] += dir * j
		(g["pts"] as Array).append(p)
	scrape = sc
	for key in groups:
		var g: Dictionary = groups[key]
		var jt: float = g["j"]
		var center: Vector3 = g["p"] / jt
		var dirv: Vector3 = (g["d"] as Vector3).normalized()
		var spread := 0.0
		for pp in g["pts"]:
			spread = max(spread, (pp as Vector3).distance_to(center))
		damage.queue_impact(center, dirv, jt, spread, g["other"], g["app"])


# ---------------------------------------------------------------- визуал

func _update_visuals(delta: float) -> void:
	var up_local := Vector3.UP
	for w in wheels:
		if w.detached or not is_instance_valid(w.part.node):
			continue
		var node := w.part.node
		var drop := w.rest - w.comp
		var sa := w.toe + (steer_angle if w.steer else 0.0)
		w.angle = fmod(w.angle - w.spin * delta, TAU)
		node.transform = Transform3D(Basis(Vector3.UP, -sa), w.mount - up_local * drop)
		var spin_node: Node3D = node.get_child(0)
		spin_node.transform = Transform3D(Basis(Vector3.RIGHT, w.angle), Vector3.ZERO)
		if w.burst:
			spin_node.scale = Vector3(1, 0.9, 0.9)
	# огни
	_flash_t += delta
	var braking := brake_eff > 0.1 and speed > 0.5 or (gear < 0 and throttle > 0.1)
	if tail_mat:
		var e := 0.35
		if lights_on:
			e = 1.2
		if braking:
			e = 4.0
		if hazard:
			var on := fmod(_flash_t, 0.8) < 0.4
			tail_mat.emission = Color(1.0, 0.45, 0.02) if on else Color(1.0, 0.05, 0.02)
			e = 3.0 if on else 0.2
		else:
			tail_mat.emission = Color(1.0, 0.05, 0.02)
		tail_mat.emission_energy_multiplier = e
	if head_mat:
		head_mat.emission_energy_multiplier = 3.0 if lights_on and engine_health > 0.0 else 0.35
	if beacons_on:
		for p in parts:
			if p.kind == "beacon" and p.attached and p.node is MeshInstance3D:
				var mat: StandardMaterial3D = (p.node as MeshInstance3D).material_override
				var ph := fmod(_flash_t * 2.5 + (0.5 if p.side > 0 else 0.0), 1.0)
				mat.emission_energy_multiplier = 6.0 if ph < 0.25 or (ph > 0.5 and ph < 0.62) else 0.1


func set_lights(on: bool) -> void:
	lights_on = on
	_apply_lights()


func _apply_lights() -> void:
	for l in _headlights:
		if is_instance_valid(l):
			l.queue_free()
	_headlights.clear()
	if not lights_on or not is_player:
		return
	if int(Settings.get_v("quality_level")) < 1:
		return
	var L: float = spec["L"]
	var sl := SpotLight3D.new()
	sl.position = Vector3(0, spec["clearance"] + 0.55, -L * 0.5 - 0.1)
	sl.rotation = Vector3(-0.08, 0, 0)
	sl.spot_range = 55.0
	sl.spot_angle = 38.0
	sl.spot_attenuation = 0.8
	sl.light_energy = 6.0
	sl.light_color = Color(1.0, 0.95, 0.85)
	sl.shadow_enabled = false
	add_child(sl)
	_headlights.append(sl)


func headlights_intact() -> bool:
	for p in parts:
		if p.kind == "light" and p.light_type == "head" and p.attached and not p.broken:
			return true
	return false


func get_speed_kmh() -> float:
	return abs(speed) * 3.6


func gear_label() -> String:
	if gear < 0:
		return "R"
	if gear == 0:
		return "N"
	if is_ev:
		return "D"
	return str(gear)
