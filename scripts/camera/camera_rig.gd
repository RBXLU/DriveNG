class_name CameraRig
extends Camera3D

## Камера: погоня (с инерцией и подстройкой под размер машины), вид с капота,
## свободный облёт (мышь/тач), «кино» с придорожных точек. Тряска при ударах.

enum Mode { CHASE, CHASE_FAR, HOOD, ORBIT, CINEMATIC }
const MODE_NAMES := ["Погоня", "Погоня (дальняя)", "С капота", "Облёт", "Кино"]

var target: Car
var mode := Mode.CHASE
var _yaw := 0.0
var _pitch := 0.28
var _orbit_dist := 8.0
var _shake := 0.0
var _vel_dir := Vector3.FORWARD
var _cine_pos := Vector3.ZERO
var _cine_t := 0.0
var _smoothed_pos := Vector3.ZERO
var _look_offset := Vector3.ZERO
var _dragging := false
var _last_touch := Vector2.ZERO
var _ray_q: PhysicsRayQueryParameters3D


func _ready() -> void:
	fov = Settings.get_v("fov")
	near = 0.08
	far = float(Settings.get_v("draw_distance")) + 200.0
	current = true
	_ray_q = PhysicsRayQueryParameters3D.new()
	_ray_q.collision_mask = 1


func set_target(c: Car, snap := true) -> void:
	target = c
	if c == null:
		return
	var fwd := -c.global_transform.basis.z
	_vel_dir = fwd
	_yaw = atan2(-fwd.x, -fwd.z)
	if snap:
		_smoothed_pos = _desired_chase_pos(1.0)
		global_position = _smoothed_pos
		look_at(c.global_position + Vector3.UP * 1.0)


func next_mode() -> void:
	mode = ((mode + 1) % Mode.size()) as Mode
	_cine_t = 0.0
	if Game.world != null:
		Game.message("Камера: " + MODE_NAMES[mode])


func add_shake(amount: float) -> void:
	if Settings.get_v("camera_shake"):
		_shake = min(1.0, _shake + amount)


func _unhandled_input(event: InputEvent) -> void:
	if mode != Mode.ORBIT:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_orbit_dist = max(3.0, _orbit_dist * 0.9)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_orbit_dist = min(40.0, _orbit_dist * 1.1)
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		_yaw -= mm.relative.x * 0.006
		_pitch = clamp(_pitch + mm.relative.y * 0.005, -0.2, 1.3)
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if sd.position.y < get_viewport().get_visible_rect().size.y * 0.6:
			_yaw -= sd.relative.x * 0.008
			_pitch = clamp(_pitch + sd.relative.y * 0.006, -0.2, 1.3)


func _desired_chase_pos(dist_mul: float) -> Vector3:
	var L: float = target.spec["L"]
	var H: float = target.spec["H"]
	var dist := (L * 0.9 + 3.4) * dist_mul
	var height := H * 0.9 + 0.9 * dist_mul
	var back := -_vel_dir
	back.y = 0.0
	if back.length_squared() < 0.001:
		back = target.global_transform.basis.z
	back = back.normalized()
	return target.global_position + back * dist + Vector3.UP * height


func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	# реальное (не замедленное) время — чтобы камера в slow-mo оставалась плавной
	var rdt: float = delta / max(Engine.time_scale, 0.01)
	rdt = min(rdt, 0.1)
	var tpos := target.global_position
	var fwd := -target.global_transform.basis.z
	var vel := target.linear_velocity
	var spd := vel.length()
	# направление «за машиной»: по скорости на ходу, по кузову при малой скорости
	var want_dir := fwd
	if spd > 3.0 and vel.normalized().dot(fwd) > -0.2:
		want_dir = fwd.lerp(vel.normalized(), 0.5).normalized()
	elif spd > 3.0 and target.gear < 0:
		want_dir = fwd
	_vel_dir = _vel_dir.slerp(want_dir, clamp(rdt * 3.5, 0.0, 1.0)) if _vel_dir.dot(want_dir) > -0.99 else want_dir

	match mode:
		Mode.CHASE, Mode.CHASE_FAR:
			var mul := 1.0 if mode == Mode.CHASE else 1.7
			var desired := _desired_chase_pos(mul)
			_smoothed_pos = _smoothed_pos.lerp(desired, clamp(rdt * 7.0, 0.0, 1.0))
			if _smoothed_pos.distance_to(desired) > 30.0:
				_smoothed_pos = desired
			var cam_pos := _avoid_ground(tpos + Vector3.UP * 1.0, _smoothed_pos)
			global_position = cam_pos
			var look := tpos + Vector3.UP * (float(target.spec["H"]) * 0.55) + _vel_dir * 2.0
			_safe_look(look)
			fov = lerp(fov, float(Settings.get_v("fov")) + clamp(spd * 0.25, 0.0, 14.0), clamp(rdt * 2.0, 0.0, 1.0))
		Mode.HOOD:
			var xf := target.global_transform
			var L: float = target.spec["L"]
			var p := xf * Vector3(0, float(target.spec["H"]) * 0.78, -L * 0.18)
			global_position = p
			global_basis = xf.basis
			fov = float(Settings.get_v("fov")) + 6.0
		Mode.ORBIT:
			var dir := Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch))
			var desired2 := tpos + Vector3.UP * 0.8 + dir * _orbit_dist
			global_position = _avoid_ground(tpos + Vector3.UP * 1.0, desired2)
			_safe_look(tpos + Vector3.UP * 0.8)
			fov = Settings.get_v("fov")
		Mode.CINEMATIC:
			_cine_t -= rdt
			if _cine_t <= 0.0 or _cine_pos.distance_to(tpos) > 70.0:
				_cine_t = 6.0
				var side := target.global_transform.basis.x * (1.0 if randf() < 0.5 else -1.0)
				_cine_pos = tpos + fwd * clamp(spd * 2.5, 10.0, 45.0) + side * randf_range(5.0, 12.0)
				if Game.map != null:
					_cine_pos.y = Game.map.height_at(_cine_pos) + randf_range(0.8, 3.5)
				else:
					_cine_pos.y = tpos.y + 1.5
			global_position = _cine_pos
			_safe_look(tpos + Vector3.UP * 0.6)
			fov = clamp(40.0 - _cine_pos.distance_to(tpos) * 0.3, 20.0, 50.0)

	# тряска
	if _shake > 0.001:
		var s := _shake * _shake * 0.35
		h_offset = randf_range(-s, s)
		v_offset = randf_range(-s, s)
		_shake = max(0.0, _shake - rdt * 1.8)
	else:
		h_offset = 0.0
		v_offset = 0.0


func _safe_look(p: Vector3) -> void:
	if global_position.distance_squared_to(p) > 0.0001:
		var up := Vector3.UP
		if abs((p - global_position).normalized().dot(up)) > 0.99:
			up = Vector3.FORWARD
		look_at(p, up)


## Не даём камере уйти под землю или за стену
func _avoid_ground(from: Vector3, to: Vector3) -> Vector3:
	var res := to
	var space := get_world_3d().direct_space_state
	if space != null:
		_ray_q.from = from
		_ray_q.to = to
		var hit := space.intersect_ray(_ray_q)
		if not hit.is_empty():
			res = (hit["position"] as Vector3) + (from - to).normalized() * 0.4
	if Game.map != null:
		var gh: float = Game.map.height_at(res)
		res.y = max(res.y, gh + 0.5)
	return res
