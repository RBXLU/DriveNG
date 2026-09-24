class_name CarDamage
extends RefCounted

## Модель повреждений.
## Сила удара оценивается через delta-V (импульс / масса) — ровно так, как её
## оценивают в реальной реконструкции ДТП. Глубина вмятины ~ delta-V, форма —
## по точкам контакта. Деформируются вершины всех панелей вокруг точки удара,
## пересобираются выпуклые формы коллизии (машина реально «укорачивается»),
## ломаются фары и стёкла, отрываются бамперы/двери/капот/колёса,
## страдают двигатель, радиатор, подвеска и развал колёс.

var car: Car
var _impacts: Array = []
var _scrapes: Array = []
var _shape_dirty := false
var _shape_t := 0.0
var _scratch_t := 0.0
var _smoke_t := 0.0
var glass_broken := false
var strength := 1.0
var size_k := 1.0
var _rng := RandomNumberGenerator.new()
var _events := {}


func _init(p_car: Car) -> void:
	car = p_car
	strength = float(car.spec.get("strength", 1.0))
	size_k = clamp(float(car.spec["L"]) / 4.5, 0.85, 1.7)
	_rng.randomize()


func queue_impact(p: Vector3, dir: Vector3, j: float, spread: float, other: Object, approach: float) -> void:
	if _impacts.size() < 8 and approach > 0.6:
		_impacts.append([p, dir, j, spread, other])


func queue_scrape(p: Vector3, spd: float) -> void:
	if _scrapes.size() < 3:
		_scrapes.append([p, spd])


func process_queue() -> void:
	for im in _impacts:
		_apply_impact(im[0], im[1], im[2], im[3], im[4])
	_impacts.clear()
	_scratch_t -= car.get_physics_process_delta_time()
	for sc in _scrapes:
		var p: Vector3 = sc[0]
		if Game.fx != null:
			Game.fx.sparks(p, car.linear_velocity * 0.6, clamp(float(sc[1]) / 15.0, 0.2, 1.0))
		if _scratch_t <= 0.0:
			_scratch_t = 0.08
			var lp := car.global_transform.affine_inverse() * p
			scratch(lp, 0.35, 0.08)
	_scrapes.clear()


func _apply_impact(p_g: Vector3, dir_g: Vector3, j: float, spread: float, other: Object) -> void:
	# Jolt может растянуть удар на несколько шагов — копим delta-V за событие.
	# Опорные контакты (машина лежит, упирается) отсечены по скорости сближения.
	var dv_step: float = j / car.mass
	var key: int = other.get_instance_id() if other != null else 0
	var now := Time.get_ticks_msec() / 1000.0
	var ev: Dictionary = _events.get(key, {})
	if ev.is_empty() or now - float(ev["t"]) > 0.3:
		ev = {"acc": 0.0, "t": now, "emitted": 0.0, "depth": 0.0}
		_events[key] = ev
	var old: float = ev["acc"]
	ev["acc"] = old + dv_step
	ev["t"] = now
	var acc: float = ev["acc"]
	var broke := false
	if other != null and other.has_method("on_hit"):
		broke = other.on_hit(j, p_g, dir_g)
	if broke:
		# срезанная опора: машина теряет лишь часть скорости
		car.linear_velocity += -dir_g * (j / car.mass) * 0.55
		ev["acc"] = old + dv_step * 0.45
		acc = ev["acc"]
	if acc - float(ev["emitted"]) > 1.8:
		ev["emitted"] = acc
		car.impact.emit(car, p_g, acc, other)
	var eff: float = max(0.0, acc - 1.3) - max(0.0, old - 1.3)
	if eff <= 0.0:
		return
	var mult: float = float(Settings.get_v("damage_mult")) / strength
	var inv := car.global_transform.affine_inverse()
	var p := inv * p_g
	var d := (car.global_transform.basis.inverse() * dir_g).normalized()
	var side_k: float = 1.0 + 0.4 * absf(d.x)
	var depth: float = clamp(eff * 0.042 * mult * side_k, 0.0, 0.65)
	if depth <= 0.002:
		return
	ev["depth"] = float(ev["depth"]) + depth
	var radius: float = clamp((0.32 + float(ev["depth"]) * 0.9 + spread * 0.7) * size_k, 0.3, 1.6)
	dent(p, d, depth, radius)
	car.total_damage += depth
	# двигатель и радиатор
	var ez := car.engine_zone
	var de := p.distance_to(ez)
	var reach := radius + 0.9
	if de < reach:
		var hit := depth * (1.0 - de / reach) * 1.7 / strength
		car.engine_health = max(0.0, car.engine_health - hit)
		if ez.z < 0.0 and p.z < ez.z + 0.3 and float(ev["depth"]) > 0.12:
			car.radiator_leak = max(car.radiator_leak, float(ev["depth"]) * 3.0)
		if car.engine_health <= 0.0:
			car._stall()
		elif car.engine_health < 0.35 and car.is_player and old < 8.0 and acc >= 8.0:
			car.message.emit("Двигатель серьёзно повреждён")
		if car.engine_health < 0.15 and acc > 11.0 and not car.engine_running and _rng.randf() < 0.02:
			car.on_fire = 25.0
	if car.total_damage > 1.6 or car.engine_health <= 0.0:
		car.wrecked = true
		car.hazard = true


## Вмятина: p, dir — в координатах модели; dir — куда вдавливается металл
func dent(p: Vector3, dir: Vector3, depth: float, radius: float) -> void:
	var r2 := radius * radius
	for part in car.parts:
		if not part.attached or not is_instance_valid(part.node):
			continue
		var nxf := part.node.transform
		if part.deformable:
			var lp := nxf.affine_inverse() * p
			if not part.aabb.grow(radius).has_point(lp):
				continue
			var ld := (nxf.basis.inverse() * dir).normalized()
			var v := part.verts
			var o := part.orig
			var dm := part.dmg
			var nz := part.noise
			var maxw := 0.0
			var md := part.max_deform
			for i in v.size():
				var dd := v[i].distance_squared_to(lp)
				if dd < r2:
					var w := 1.0 - dd / r2
					w *= w
					var amt := depth * w * (0.55 + 0.9 * nz[i])
					var nv := v[i] + ld * amt
					var off := nv - o[i]
					var ol := off.length()
					if ol > md:
						nv = o[i] + off * (md / ol)
					v[i] = nv
					dm[i] = Vector2(min(1.0, dm[i].x + w * depth * 5.0), 0.0)
					if w > maxw:
						maxw = w
			if maxw > 0.0:
				part.verts = v
				part.dmg = dm
				part.dirty = true
				part.damage += depth * maxw
				if part.shape != null:
					_shape_dirty = true
				_check_part(part, dir, depth * maxw)
		else:
			var c := part.aabb.get_center()
			var dist := c.distance_to(p)
			var reach := radius + 0.18
			if dist >= reach:
				continue
			var w2 := 1.0 - dist / reach
			var local := depth * w2
			part.damage += local
			match part.kind:
				"wheel":
					_damage_wheel(part, dir, local)
				"light":
					_move_small(part, dir * local * 0.8)
					if local > 0.012 and not part.broken:
						break_light(part)
					if local > 0.14:
						detach(part, dir, 1.5)
				"mirror":
					if local > 0.02:
						detach(part, -dir + Vector3.UP * 0.3, 3.0)
				"beacon", "spoiler":
					_move_small(part, dir * local * 0.6)
					if local > 0.12:
						detach(part, Vector3.UP, 2.0)
				_:
					_move_small(part, dir * local * 0.85)
					if local > 0.18:
						detach(part, -dir, 1.0)


## Царапины (без смещения геометрии) — при скольжении по поверхности
func scratch(p: Vector3, radius: float, amount: float) -> void:
	var r2 := radius * radius
	for part in car.parts:
		if not part.attached or not part.deformable or not is_instance_valid(part.node):
			continue
		var lp := part.node.transform.affine_inverse() * p
		if not part.aabb.grow(radius).has_point(lp):
			continue
		var v := part.verts
		var dm := part.dmg
		var changed := false
		for i in v.size():
			var dd := v[i].distance_squared_to(lp)
			if dd < r2:
				var w := 1.0 - dd / r2
				dm[i] = Vector2(min(1.0, dm[i].x + w * amount), 0.0)
				changed = true
		if changed:
			part.dmg = dm
			part.dirty = true


func _move_small(part: CarPart, off: Vector3) -> void:
	if off.length() > 0.3:
		off = off.normalized() * 0.3
	part.node.position += off
	part.base_transform.origin += off
	part.aabb.position += off


func _check_part(part: CarPart, dir: Vector3, local: float) -> void:
	match part.kind:
		"cabin":
			if not glass_broken and (part.damage > 0.07 or local > 0.09):
				break_glass()
		"hood", "trunk", "door":
			if part.damage > part.detach_at:
				detach(part, -dir + Vector3.UP * 0.4, 2.5)
			elif part.damage > part.loosen_at and not part.loose:
				part.loose = true
				part.hinge_vel = 1.5
				if car.is_player:
					match part.kind:
						"hood": car.message.emit("Капот открылся")
						"trunk": car.message.emit("Багажник открылся")
						"door": car.message.emit("Дверь сорвало с замка")
		"bumper":
			if part.damage > part.detach_at:
				detach(part, -dir + Vector3.UP * 0.3, 2.0)
			elif part.damage > part.detach_at * 0.4 and not part.loose:
				part.loose = true
				_droop_bumper(part, dir)


func _droop_bumper(part: CarPart, dir: Vector3) -> void:
	# бампер повисает на одном креплении: поворот вокруг дальнего от удара конца
	var ab := part.aabb
	var end_x := ab.position.x if dir.x > 0.0 else ab.end.x
	var pivot := Vector3(end_x, ab.get_center().y, ab.get_center().z)
	var ang := 0.18 * (1.0 if dir.x > 0.0 else -1.0)
	var rot := Transform3D(Basis(Vector3.BACK, ang), Vector3.ZERO)
	var xf := Transform3D(Basis.IDENTITY, pivot) * rot * Transform3D(Basis.IDENTITY, -pivot)
	part.base_transform = part.base_transform * xf
	part.node.transform = part.base_transform


func _damage_wheel(part: CarPart, dir: Vector3, local: float) -> void:
	var w: Car.Wheel = car.wheels[part.wheel_index]
	if w.detached:
		return
	w.damage += local
	w.toe = clamp(w.toe + _rng.randf_range(-1.0, 1.0) * local * 0.6, -0.35, 0.35)
	w.susp_health = max(0.0, w.susp_health - local * 2.2)
	var shift := dir * local * 0.4
	var new_mount := w.mount + shift
	var base_mount := w.pos + Vector3.UP * (w.rest - w.sag)
	if new_mount.distance_to(base_mount) < 0.22:
		w.mount = new_mount
		w.ray.position = w.mount
	if local > 0.05 and not w.burst and _rng.randf() < 0.35:
		w.burst = true
		w.grip_mult = 0.55
		if car.is_player:
			car.message.emit("Пробито колесо!")
	if w.damage > 0.3 / strength or w.susp_health <= 0.0:
		detach(part, -dir + Vector3.UP * 0.2, 2.0)


func break_light(part: CarPart) -> void:
	part.broken = true
	if part.node is MeshInstance3D:
		(part.node as MeshInstance3D).material_override = CarMaterials.light_off()
	if Game.fx != null:
		Game.fx.glass(part.node.global_position, car.linear_velocity, 10, part.light_type == "tail")


func break_glass() -> void:
	glass_broken = true
	for part in car.parts:
		if part.kind == "cabin" and part.mesh != null:
			for si in part.surfaces.size():
				if part.surfaces[si].get("glass", false):
					part.surfaces[si]["mat"] = CarMaterials.glass_broken()
					part.mesh.surface_set_material(si, CarMaterials.glass_broken())
			if Game.fx != null:
				var c := car.global_transform * (part.aabb.get_center() + Vector3(0, 0.1, 0))
				Game.fx.glass(c, car.linear_velocity, 40, false)
	if Game.audio != null:
		Game.audio.play_glass(car.global_position)


func detach(part: CarPart, dir_model: Vector3, push: float) -> void:
	if not part.attached or not is_instance_valid(part.node):
		return
	part.attached = false
	var node := part.node
	var gxf := node.global_transform.orthonormalized()
	node.get_parent().remove_child(node)
	var body := RigidBody3D.new()
	body.name = "debris_" + part.name
	body.mass = max(part.mass, 0.5)
	body.collision_layer = Car.LAYER_DEBRIS
	body.collision_mask = Car.LAYER_WORLD | Car.LAYER_CARS | Car.LAYER_DEBRIS | Car.LAYER_PROPS
	body.continuous_cd = part.kind == "wheel"
	var pm := PhysicsMaterial.new()
	pm.friction = 0.6
	pm.bounce = 0.15
	body.physics_material_override = pm
	var cs := CollisionShape3D.new()
	if part.kind == "wheel":
		var w: Car.Wheel = car.wheels[part.wheel_index]
		w.detached = true
		w.grounded = false
		w.ray.enabled = false
		var cyl := CylinderShape3D.new()
		cyl.radius = w.radius
		cyl.height = w.width
		cs.shape = cyl
		cs.transform = Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3.ZERO)
		body.angular_velocity = car.global_transform.basis * Vector3(-w.spin, 0, 0)
		if car.is_player:
			car.message.emit("Оторвало колесо!")
	else:
		var box := BoxShape3D.new()
		var ab := part.aabb
		if not part.deformable and node is MeshInstance3D:
			ab = (node as MeshInstance3D).mesh.get_aabb()
		box.size = Vector3(max(ab.size.x, 0.05), max(ab.size.y, 0.05), max(ab.size.z, 0.05))
		cs.shape = box
		cs.position = ab.get_center()
		body.angular_velocity = Vector3(_rng.randf_range(-3, 3), _rng.randf_range(-3, 3), _rng.randf_range(-3, 3))
	body.add_child(cs)
	body.add_child(node)
	node.transform = Transform3D.IDENTITY
	var root: Node = Game.debris_root if Game.debris_root != null else car.get_parent()
	root.add_child(body)
	body.global_transform = gxf
	var dir_w := car.global_transform.basis * dir_model.normalized()
	body.linear_velocity = car.linear_velocity + car.angular_velocity.cross(gxf.origin - car.global_position) + dir_w * push
	Game.register_debris(body)
	if part.kind == "light" and not part.broken:
		break_light(part)
	car.part_detached.emit(car, part)


## Анимация болтающихся деталей, пересборка мешей и форм, дым/огонь
func update_visual(delta: float) -> void:
	var rebuilt := 0
	for part in car.parts:
		if part.dirty and part.attached and rebuilt < 4:
			part.rebuild()
			rebuilt += 1
		if part.attached and part.loose and part.hinged:
			_simulate_hinge(part, delta)
	_shape_t -= delta
	if _shape_dirty and _shape_t <= 0.0:
		_shape_dirty = false
		_shape_t = 0.2
		for part in car.parts:
			if part.shape != null and part.attached:
				part.shape.points = part.shape_points()
	# дым из-под капота, огонь
	_smoke_t -= delta
	if _smoke_t <= 0.0 and Game.fx != null:
		_smoke_t = 0.12
		var ep := car.global_transform * (car.engine_zone + Vector3(0, 0.4, 0))
		if car.on_fire > 0.0:
			car.on_fire -= 0.12
			Game.fx.fire(ep, car.linear_velocity)
			Game.fx.smoke(ep + Vector3(0, 0.5, 0), car.linear_velocity, Color(0.08, 0.08, 0.08), 1.6)
		elif car.engine_health < 0.3:
			Game.fx.smoke(ep, car.linear_velocity, Color(0.12, 0.12, 0.12), 1.1)
		elif car.engine_health < 0.65 or car.radiator_leak > 0.0:
			Game.fx.smoke(ep, car.linear_velocity, Color(0.85, 0.85, 0.88), 0.8)


func _simulate_hinge(part: CarPart, dt: float) -> void:
	var a := car.local_accel
	var spd := car.speed
	var acc := 0.0
	match part.kind:
		"door":
			# боковое ускорение открывает/закрывает, встречный поток прижимает
			acc = -a.x * float(part.side) * 0.9 - a.z * 0.4 * (1.0 if part.front else 0.6)
			acc -= spd * abs(spd) * 0.0035 * (1.0 if spd > 0.0 else -1.0)
		"hood":
			acc = spd * abs(spd) * 0.004 + a.z * 0.25 - 2.0
		"trunk":
			acc = -a.y * 0.3 - a.z * 0.3 - 1.5
	acc -= part.hinge_vel * 2.5
	part.hinge_vel += acc * dt
	part.hinge_angle += part.hinge_vel * dt
	var lo := 0.02
	if part.hinge_angle < lo:
		part.hinge_angle = lo
		part.hinge_vel = abs(part.hinge_vel) * 0.25
	if part.hinge_angle > part.hinge_max:
		part.hinge_angle = part.hinge_max
		part.hinge_vel = -abs(part.hinge_vel) * 0.3
		if abs(spd) > 22.0 and _rng.randf() < dt * 0.35:
			detach(part, Vector3.UP + Vector3.BACK, 4.0)
			return
	var rot := Basis(part.hinge_axis, part.hinge_angle * part.hinge_sign)
	part.node.transform = part.base_transform * Transform3D(rot, Vector3.ZERO)
