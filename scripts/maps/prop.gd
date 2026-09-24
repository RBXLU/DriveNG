class_name Prop
extends RigidBody3D

## Разрушаемый объект окружения: фонарный столб, конус, бочка, знак, отбойник.
## Тяжёлые объекты «заморожены», пока их не ударят достаточно сильно
## (ломающиеся опоры, как в реальности), лёгкие — сразу динамические.

var kind := ""
var break_impulse := 0.0
var broken := false
var lamp: OmniLight3D
var anchored := false

static var _meshes := {}
static var _mats := {}


static func _mat(key: String, color: Color, rough: float = 0.6, metallic: float = 0.0, emission: float = 0.0) -> StandardMaterial3D:
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = rough
		m.metallic = metallic
		if emission > 0.0:
			m.emission_enabled = true
			m.emission = color
			m.emission_energy_multiplier = emission
		_mats[key] = m
	return _mats[key]


static func create(p_kind: String, xf: Transform3D, night: bool = false) -> Prop:
	var p := Prop.new()
	p.kind = p_kind
	p.collision_layer = Car.LAYER_PROPS
	p.collision_mask = Car.LAYER_WORLD | Car.LAYER_CARS | Car.LAYER_DEBRIS | Car.LAYER_PROPS
	p.can_sleep = true
	var pm := PhysicsMaterial.new()
	pm.friction = 0.6
	pm.bounce = 0.1
	p.physics_material_override = pm
	var vis_end := 260.0
	match p_kind:
		"lamp":
			p.mass = 180.0
			p.break_impulse = 4500.0
			p.anchored = true
			p._add_box(Vector3(0.18, 7.0, 0.18), Vector3(0, 3.5, 0), _mat("pole", Color(0.35, 0.36, 0.38), 0.5, 0.6))
			p._add_box(Vector3(0.12, 0.12, 1.6), Vector3(0, 6.95, -0.75), _mat("pole", Color(0.35, 0.36, 0.38), 0.5, 0.6), false)
			p._add_box(Vector3(0.35, 0.1, 0.5), Vector3(0, 6.88, -1.45), _mat("lamp_on" if night else "lamp_off", Color(1.0, 0.85, 0.6) if night else Color(0.8, 0.8, 0.75), 0.3, 0.0, 6.0 if night else 0.0), false)
			p.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
			p.center_of_mass = Vector3(0, 2.5, 0)
			vis_end = 320.0
		"cone":
			p.mass = 4.0
			var cm := CylinderMesh.new()
			cm.top_radius = 0.03
			cm.bottom_radius = 0.17
			cm.height = 0.7
			cm.radial_segments = 8
			cm.rings = 1
			p._add_mesh(cm, Vector3(0, 0.35, 0), _mat("cone", Color(1.0, 0.35, 0.05), 0.7))
			var cs := CylinderShape3D.new()
			cs.radius = 0.15
			cs.height = 0.7
			p._add_shape(cs, Vector3(0, 0.35, 0))
			vis_end = 150.0
		"barrel":
			p.mass = 60.0
			var bm := CylinderMesh.new()
			bm.top_radius = 0.3
			bm.bottom_radius = 0.3
			bm.height = 0.9
			bm.radial_segments = 10
			bm.rings = 1
			p._add_mesh(bm, Vector3(0, 0.45, 0), _mat("barrel", Color(0.85, 0.3, 0.05), 0.5, 0.3))
			var bs := CylinderShape3D.new()
			bs.radius = 0.3
			bs.height = 0.9
			p._add_shape(bs, Vector3(0, 0.45, 0))
			vis_end = 200.0
		"water_barrier":
			p.mass = 90.0
			p._add_box(Vector3(1.8, 0.8, 0.45), Vector3(0, 0.4, 0), _mat("wbar", Color(0.9, 0.9, 0.88), 0.6))
			p._add_box(Vector3(1.82, 0.22, 0.47), Vector3(0, 0.55, 0), _mat("wbar_red", Color(0.8, 0.08, 0.05), 0.6), false)
		"sign":
			p.mass = 25.0
			p.break_impulse = 800.0
			p.anchored = true
			p._add_box(Vector3(0.08, 2.4, 0.08), Vector3(0, 1.2, 0), _mat("pole", Color(0.35, 0.36, 0.38), 0.5, 0.6))
			p._add_box(Vector3(0.7, 0.7, 0.04), Vector3(0, 2.35, 0), _mat("sign", Color(0.1, 0.3, 0.75), 0.4), false)
			p.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
			p.center_of_mass = Vector3(0, 1.3, 0)
		"tires":
			p.mass = 45.0
			var tm := CylinderMesh.new()
			tm.top_radius = 0.34
			tm.bottom_radius = 0.34
			tm.height = 0.8
			tm.radial_segments = 10
			tm.rings = 1
			p._add_mesh(tm, Vector3(0, 0.4, 0), _mat("tires", Color(0.05, 0.05, 0.05), 0.9))
			var ts := CylinderShape3D.new()
			ts.radius = 0.34
			ts.height = 0.8
			p._add_shape(ts, Vector3(0, 0.4, 0))
		"crate":
			p.mass = 30.0
			p._add_box(Vector3(0.9, 0.9, 0.9), Vector3(0, 0.45, 0), _mat("crate", Color(0.55, 0.4, 0.22), 0.8))
	for c in p.get_children():
		if c is GeometryInstance3D:
			(c as GeometryInstance3D).visibility_range_end = vis_end
			(c as GeometryInstance3D).visibility_range_end_margin = 20.0
	p.transform = xf
	if p.anchored:
		p.freeze = true
		p.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	else:
		p.sleeping = true
	return p


func _add_box(size: Vector3, pos: Vector3, mat: Material, collide: bool = true) -> void:
	var key := "box_%s" % str(size)
	if not _meshes.has(key):
		var bm := BoxMesh.new()
		bm.size = size
		_meshes[key] = bm
	_add_mesh(_meshes[key], pos, mat)
	if collide:
		var bs := BoxShape3D.new()
		bs.size = size
		_add_shape(bs, pos)


func _add_mesh(mesh: Mesh, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	add_child(mi)


func _add_shape(shape: Shape3D, pos: Vector3) -> void:
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = pos
	add_child(cs)


## Вызывается машиной при ударе. Возвращает true, если объект сломан (опора
## срезана) — тогда машина теряет лишь часть скорости.
func on_hit(j: float, p: Vector3, dir: Vector3) -> bool:
	if not anchored or broken:
		return false
	if j < break_impulse:
		return false
	broken = true
	call_deferred("_release", -dir * min(j * 0.25, mass * 8.0), p)
	return true


func _release(impulse: Vector3, at: Vector3) -> void:
	freeze = false
	sleeping = false
	apply_impulse(impulse + Vector3.UP * mass * 1.5, at - global_position)
	if Game.fx != null:
		Game.fx.sparks(at, Vector3.ZERO, 1.0)
	if kind == "lamp":
		for c in get_children():
			if c is MeshInstance3D and (c as MeshInstance3D).material_override == _mats.get("lamp_on"):
				(c as MeshInstance3D).material_override = _mat("lamp_off", Color(0.8, 0.8, 0.75), 0.3)
