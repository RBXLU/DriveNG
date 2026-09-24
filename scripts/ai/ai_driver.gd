class_name AIDriver
extends RefCounted

## ИИ-водитель.
## traffic — едет по полосам: руление «pure pursuit», скорость по кривизне,
##           дистанция до лидера по модели IDM, светофоры, выход из застревания.
## derby   — выбирает жертву и таранит её.
## ram     — едет прямо на игрока (для спавна «лоб в лоб»).

enum Mode { TRAFFIC, DERBY, RAM, PARKED }

var mode := Mode.TRAFFIC
var net: RoadNetwork
var lane: RoadNetwork.Lane
var s := 0.0
var cruise := 13.0
var aggression := 1.0
var target: Car
var _retarget_t := 0.0
var _stuck_t := 0.0
var _reverse_t := 0.0
var _rng := RandomNumberGenerator.new()
var _panic_t := 0.0
var _next_lane: RoadNetwork.Lane


func _init(p_mode: Mode = Mode.TRAFFIC) -> void:
	mode = p_mode
	_rng.randomize()
	aggression = _rng.randf_range(0.85, 1.15)


func place(p_net: RoadNetwork, p_lane: RoadNetwork.Lane, p_s: float) -> void:
	net = p_net
	lane = p_lane
	s = p_s
	cruise = lane.speed * _rng.randf_range(0.82, 1.08)
	_pick_next()


func _pick_next() -> void:
	_next_lane = null
	if lane != null and not lane.next.is_empty():
		_next_lane = net.lanes[lane.next[_rng.randi() % lane.next.size()]]


func update(car: Car, dt: float) -> void:
	if car.wrecked or not car.engine_running:
		_stop(car)
		car.hazard = true
		return
	match mode:
		Mode.TRAFFIC:
			_traffic(car, dt)
		Mode.DERBY, Mode.RAM:
			_derby(car, dt)
		Mode.PARKED:
			_stop(car)


func _stop(car: Car) -> void:
	car.throttle = 0.0
	car.brake = 1.0
	car.steer = 0.0
	car.handbrake = 1.0


func _steer_to(car: Car, target_p: Vector3, lookahead: float) -> float:
	var local := car.global_transform.affine_inverse() * target_p
	var alpha := atan2(local.x, -local.z)
	var wb: float = car.spec["wheelbase"]
	var delta := atan(2.0 * wb * sin(alpha) / max(lookahead, 1.0))
	return clamp(delta / car.steer_max, -1.0, 1.0)


func _point_ahead(dist: float) -> Vector3:
	var rem := lane.length - s
	if dist <= rem or _next_lane == null:
		return lane.point_at(s + dist)
	return _next_lane.point_at(dist - rem)


func _dir_ahead(dist: float) -> Vector3:
	var rem := lane.length - s
	if dist <= rem or _next_lane == null:
		return lane.dir_at(s + dist)
	return _next_lane.dir_at(dist - rem)


func _traffic(car: Car, dt: float) -> void:
	if lane == null:
		_stop(car)
		return
	var pos := car.global_position
	var v := car.speed
	s = lane.project(pos, s)
	if s >= lane.length - 0.3 and _next_lane != null:
		s = _next_lane.project(pos, 0.0, 10.0)
		lane = _next_lane
		cruise = lane.speed * _rng.randf_range(0.82, 1.08) * aggression
		_pick_next()
	var lane_p := lane.point_at(s)
	var off: float = Vector2(pos.x - lane_p.x, pos.z - lane_p.z).length()
	if off > 14.0:
		# сбились с полосы (после аварии) — ищем ближайшую
		var near := net.nearest(pos, -car.global_transform.basis.z)
		if not near.is_empty():
			lane = near[0]
			s = near[1]
			_pick_next()

	# руление
	var la: float = clamp(5.0 + abs(v) * 0.6, 6.0, 26.0)
	var tp := _point_ahead(la)
	var steer := _steer_to(car, tp, la)

	# желаемая скорость: полоса + кривизна впереди
	var v_des := cruise
	var d0 := _dir_ahead(2.0)
	var look: float = clamp(abs(v) * 2.2, 15.0, 45.0)
	var d1 := _dir_ahead(look)
	var ang := acos(clamp(d0.dot(d1), -1.0, 1.0))
	if ang > 0.05:
		var kappa := ang / look
		v_des = min(v_des, sqrt(3.2 / kappa))

	# лидер и препятствия
	var gap := 999.0
	var lead_v := v_des
	var fwd := -car.global_transform.basis.z
	var my_half := float(car.spec["L"]) * 0.5
	var my_w := float(car.spec["W"]) * 0.5
	for other in Game.cars:
		if other == car or not is_instance_valid(other):
			continue
		var rel: Vector3 = other.global_position - pos
		if rel.length_squared() > 3600.0:
			continue
		var d := rel.dot(fwd)
		if d <= 0.0:
			continue
		var lat := (rel - fwd * d).length()
		var ow := float(other.spec["W"]) * 0.5
		if lat > my_w + ow + 0.5 + d * 0.03:
			continue
		var g := d - my_half - float(other.spec["L"]) * 0.5
		if g < gap:
			gap = g
			lead_v = other.linear_velocity.dot(fwd)
	# светофор
	if lane.inter != null:
		var st := lane.inter.state_for(lane.axis)
		var to_end := lane.length - s - 2.5
		if to_end > -1.0:
			var stop_needed := st == 2
			if st == 1:
				var brake_d: float = v * v / (2.0 * 4.0)
				stop_needed = to_end > brake_d * 0.8
			if stop_needed and to_end < gap:
				gap = max(to_end, 0.0)
				lead_v = 0.0

	# IDM
	var a_max := 2.2 * aggression
	var b := 3.5
	var s0 := 3.0
	var tt := 1.3 / aggression
	var dv := v - lead_v
	var s_star: float = s0 + max(0.0, v * tt + v * dv / (2.0 * sqrt(a_max * b)))
	var acc := a_max * (1.0 - pow(max(v, 0.0) / max(v_des, 0.5), 4.0) - pow(s_star / max(gap, 0.1), 2.0))

	var thr := 0.0
	var brk := 0.0
	if acc > 0.0:
		thr = clamp(acc / a_max, 0.0, 1.0)
	else:
		brk = clamp(-acc / 6.0, 0.0, 1.0)
	if v_des < 0.5 and abs(v) < 0.6:
		brk = 1.0
		thr = 0.0

	# застревание
	if _reverse_t > 0.0:
		_reverse_t -= dt
		car.throttle = 0.0
		car.brake = 0.8
		car.steer = -steer
		car.handbrake = 0.0
		if car.speed > -0.5 and car.gear >= 0:
			car.brake = 1.0
		return
	if thr > 0.3 and abs(v) < 0.6 and gap > 8.0:
		_stuck_t += dt
		if _stuck_t > 3.5:
			_stuck_t = 0.0
			_reverse_t = 1.8
	else:
		_stuck_t = max(0.0, _stuck_t - dt)

	car.throttle = thr
	car.brake = brk
	car.steer = steer
	car.handbrake = 0.0
	car.lights_on = Game.map != null and Game.map.is_night()


func _derby(car: Car, dt: float) -> void:
	_retarget_t -= dt
	if target == null or not is_instance_valid(target) or target.wrecked or _retarget_t <= 0.0:
		_retarget_t = _rng.randf_range(5.0, 10.0)
		target = _choose_target(car)
	if target == null:
		_stop(car)
		return
	var pos := car.global_position
	var aim := target.global_position + target.linear_velocity * 0.35
	var local := car.global_transform.affine_inverse() * aim
	var dist := local.length()
	var alpha := atan2(local.x, -local.z)
	var steer: float = clamp(alpha * 1.6, -1.0, 1.0)

	if _reverse_t > 0.0:
		_reverse_t -= dt
		car.throttle = 0.0
		car.brake = 1.0
		car.steer = -steer
		car.handbrake = 0.0
		return
	var thr := 1.0 if abs(alpha) < 1.0 else 0.55
	if dist < 6.0 and abs(alpha) > 1.4:
		# цель сбоку/сзади вплотную — сдаём назад для разгона
		_reverse_t = 1.0
	if abs(car.speed) < 0.8 and thr > 0.5:
		_stuck_t += dt
		if _stuck_t > 2.0:
			_stuck_t = 0.0
			_reverse_t = 1.4
	else:
		_stuck_t = 0.0
	car.throttle = thr * (0.85 if mode == Mode.DERBY else 1.0)
	car.brake = 0.0
	car.steer = steer
	car.handbrake = 1.0 if abs(alpha) > 1.3 and car.speed > 8.0 else 0.0


func _choose_target(car: Car) -> Car:
	if mode == Mode.RAM and Game.player != null:
		return Game.player
	var best: Car = null
	var bd := 1e18
	for other in Game.cars:
		if other == car or not is_instance_valid(other) or other.wrecked:
			continue
		var d: float = other.global_position.distance_squared_to(car.global_position)
		if other.is_player:
			d *= 0.6
		d *= _rng.randf_range(0.7, 1.3)
		if d < bd:
			bd = d
			best = other
	return best
