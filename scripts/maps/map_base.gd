class_name MapBase
extends Node3D

## Базовая карта: атмосфера, земля, строители статических объектов.
## Статическая геометрия объединяется в крупные меши (мало draw calls),
## растительность — MultiMesh, дальние мелкие объекты отсекаются по дистанции.

const GROUND_SHADER := preload("res://shaders/ground.gdshader")
const ROAD_SHADER := preload("res://shaders/road.gdshader")
const BUILDING_SHADER := preload("res://shaders/building.gdshader")

var map_id := ""
var atmosphere: Atmosphere
var net: RoadNetwork = null
var spawns: Array[Transform3D] = []
var terrain: Terrain = null
var rng := RandomNumberGenerator.new()
var night := false
var static_root: Node3D
var props_root: Node3D
var ground_grip := 1.0
var ground_surface := "asphalt"

static var _concrete: StandardMaterial3D
static var _metal: StandardMaterial3D


## Переопределяется картами
func build_map() -> void:
	pass


func build(tod: int) -> void:
	rng.seed = hash(map_id)
	night = tod == 2
	atmosphere = Atmosphere.new()
	add_child(atmosphere)
	atmosphere.setup(tod, fog_scale())
	static_root = Node3D.new()
	static_root.name = "Static"
	add_child(static_root)
	props_root = Node3D.new()
	props_root.name = "Props"
	add_child(props_root)
	build_map()


func fog_scale() -> float:
	return 1.0


func is_night() -> bool:
	return night


func height_at(p: Vector3) -> float:
	if terrain != null:
		return terrain.height_at(p.x, p.z)
	return 0.0


## (сцепление, 1 — грунт/трава) или x < 0, если определять по коллайдеру
func surface_at(_p: Vector3, _collider: Object) -> Vector2:
	return Vector2(-1.0, 0.0)


func spawn_transform(i: int = 0) -> Transform3D:
	if spawns.is_empty():
		return Transform3D(Basis.IDENTITY, Vector3(0, 1, 0))
	return spawns[i % spawns.size()]


func update_map(_dt: float) -> void:
	pass


# ---------------------------------------------------------------- материалы

static func concrete_mat() -> StandardMaterial3D:
	if _concrete == null:
		_concrete = StandardMaterial3D.new()
		_concrete.albedo_color = Color(0.62, 0.61, 0.58)
		_concrete.roughness = 0.9
		var nt := NoiseTexture2D.new()
		nt.width = 128
		nt.height = 128
		nt.seamless = true
		var fn := FastNoiseLite.new()
		fn.frequency = 0.05
		nt.noise = fn
		nt.color_ramp = Gradient.new()
		nt.color_ramp.set_color(0, Color(0.8, 0.8, 0.78))
		nt.color_ramp.set_color(1, Color(1, 1, 1))
		_concrete.albedo_texture = nt
		_concrete.uv1_triplanar = true
		_concrete.uv1_world_triplanar = true
		_concrete.uv1_scale = Vector3(0.25, 0.25, 0.25)
		_concrete.vertex_color_use_as_albedo = true
	return _concrete


static func metal_mat() -> StandardMaterial3D:
	if _metal == null:
		_metal = StandardMaterial3D.new()
		_metal.albedo_color = Color(0.7, 0.72, 0.74)
		_metal.metallic = 0.8
		_metal.roughness = 0.35
		_metal.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _metal


func ground_mat(a: Color, b: Color, c: Color, tiles: float = 0.0, rough: float = 0.92) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = GROUND_SHADER
	m.set_shader_parameter("color_a", a)
	m.set_shader_parameter("color_b", b)
	m.set_shader_parameter("color_c", c)
	m.set_shader_parameter("tiles", tiles)
	m.set_shader_parameter("rough", rough)
	return m


func road_mat(width: float, lanes: int, median: float, center_solid: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = ROAD_SHADER
	m.set_shader_parameter("road_width", width)
	m.set_shader_parameter("lanes_per_dir", float(lanes))
	m.set_shader_parameter("median", median)
	m.set_shader_parameter("center_solid", 1.0 if center_solid else 0.0)
	return m


# ---------------------------------------------------------------- земля

## Бесконечная плоскость коллизии + видимый квадрат с материалом
func flat_ground(size: float, mat: Material, grip: float, surface: String) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.collision_layer = Car.LAYER_WORLD
	sb.collision_mask = 0
	sb.set_meta("grip", grip)
	sb.set_meta("surface", surface)
	var cs := CollisionShape3D.new()
	cs.shape = WorldBoundaryShape3D.new()
	sb.add_child(cs)
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(size, size)
	pm.subdivide_width = 16
	pm.subdivide_depth = 16
	mi.mesh = pm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sb.add_child(mi)
	static_root.add_child(sb)
	return sb


# ---------------------------------------------------------------- пакет коробок

class BoxBatch:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var uv2 := PackedVector2Array()
	var idx := PackedInt32Array()

	func add(xf: Transform3D, size: Vector3, color: Color = Color.WHITE, seed: float = 0.0, skip_bottom: bool = true) -> void:
		var h := size * 0.5
		var faces := [
			[Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)],
			[Vector3(-1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)],
			[Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)],
			[Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, 1, 0)],
			[Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, 1, 0)],
			[Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)],
		]
		for fi in faces.size():
			if skip_bottom and fi == 5:
				continue
			var f: Array = faces[fi]
			var nn: Vector3 = f[0]
			var u: Vector3 = f[1]
			var w: Vector3 = f[2]
			var base := v.size()
			var wn := (xf.basis * nn).normalized()
			for q in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var lp: Vector3 = (nn + u * q.x + w * q.y) * h
				v.append(xf * lp)
				n.append(wn)
				c.append(color)
				uv2.append(Vector2(seed, 0))
			# здесь u×w = -нормаль: обход (0,1,2) по часовой снаружи — как нужно Godot
			idx.append_array([base, base + 1, base + 2, base, base + 2, base + 3])

	func build(mat: Material, shadows: bool = true) -> MeshInstance3D:
		var mi := MeshInstance3D.new()
		if v.is_empty():
			return mi
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = n
		arr[Mesh.ARRAY_COLOR] = c
		arr[Mesh.ARRAY_TEX_UV2] = uv2
		arr[Mesh.ARRAY_INDEX] = idx
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		m.surface_set_material(0, mat)
		mi.mesh = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		return mi


## Статическое тело с набором коробок-коллайдеров
func static_body(grip: float = 1.0, surface: String = "asphalt") -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.collision_layer = Car.LAYER_WORLD
	sb.collision_mask = 0
	sb.set_meta("grip", grip)
	sb.set_meta("surface", surface)
	static_root.add_child(sb)
	return sb


func add_box_shape(sb: StaticBody3D, xf: Transform3D, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.transform = xf
	sb.add_child(cs)


## Бетонный блок/стена/трамплин: визуал в batch + коллизия в sb
func solid_box(batch: BoxBatch, sb: StaticBody3D, xf: Transform3D, size: Vector3, color: Color = Color.WHITE) -> void:
	batch.add(xf, size, color, 0.0, false)
	add_box_shape(sb, xf, size)


## Трамплин: наклонная плита. Начало на земле в точке at, направление dir
func ramp(batch: BoxBatch, sb: StaticBody3D, at: Vector3, yaw: float, length: float, height: float, width: float) -> void:
	var ang := atan2(height, length)
	var slope_len := sqrt(length * length + height * height)
	var thick := 0.6
	var b := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, ang)
	var fwd := Basis(Vector3.UP, yaw) * Vector3.FORWARD
	var center := at + fwd * (length * 0.5) + Vector3.UP * (height * 0.5)
	# сдвигаем вниз на половину толщины по нормали плиты
	center -= (b * Vector3.UP) * (thick * 0.5)
	solid_box(batch, sb, Transform3D(b, center), Vector3(width, thick, slope_len), Color(0.85, 0.83, 0.8))
	# опора под верхним краем
	var top := at + fwd * length
	solid_box(batch, sb, Transform3D(Basis(Vector3.UP, yaw), top + Vector3.UP * (height * 0.5 - 0.3) - fwd * 0.4), Vector3(width, max(height - 0.3, 0.2), 0.8), Color(0.7, 0.7, 0.68))


# ---------------------------------------------------------------- растительность

static var _tree_mesh: ArrayMesh
static var _tree_mat: StandardMaterial3D


static func tree_mesh() -> ArrayMesh:
	if _tree_mesh == null:
		var d := {"v": PackedVector3Array(), "i": PackedInt32Array(), "c": PackedColorArray()}
		var trunk := MeshUtil.transform(MeshUtil.cylinder_x(6, 0.0), Transform3D(Basis(Vector3.BACK, PI * 0.5).scaled(Vector3(0.25, 3.0, 0.25)), Vector3(0, 1.5, 0)))
		trunk["c"] = PackedColorArray()
		for k in (trunk["v"] as PackedVector3Array).size():
			(trunk["c"] as PackedColorArray).append(Color(0.3, 0.2, 0.12))
		MeshUtil.append(d, trunk)
		# крона — три конуса
		for lvl in 3:
			var r := 2.2 - lvl * 0.55
			var y0 := 2.0 + lvl * 1.6
			var h := 3.2 - lvl * 0.4
			var rings: Array = []
			var zs := PackedFloat32Array()
			for k in 2:
				var ring := PackedVector2Array()
				var rr := r if k == 0 else 0.02
				for s in 8:
					var a := TAU * s / 8.0
					ring.append(Vector2(cos(a), sin(a)) * rr)
				rings.append(ring)
				zs.append(y0 + h * k)
			var cone := MeshUtil.loft(rings, zs, true, true, false)
			cone = MeshUtil.transform(cone, Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)), Vector3.ZERO))
			cone["c"] = PackedColorArray()
			var gc := Color(0.13, 0.3 + lvl * 0.03, 0.12)
			for k in (cone["v"] as PackedVector3Array).size():
				(cone["c"] as PackedColorArray).append(gc)
			MeshUtil.append(d, cone)
		_tree_mat = StandardMaterial3D.new()
		_tree_mat.vertex_color_use_as_albedo = true
		_tree_mat.roughness = 0.9
		_tree_mesh = MeshUtil.simple_mesh(d, _tree_mat)
	return _tree_mesh


## Деревья MultiMesh; коллизия стволов — только у тех, что ближе collide_fn
func add_trees(points: Array, collide: Callable) -> void:
	if points.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = tree_mesh()
	mm.instance_count = points.size()
	var sb := static_body(1.0, "grass")
	for i in points.size():
		var p: Vector3 = points[i]
		var s := rng.randf_range(0.8, 1.5)
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.9, 1.3), s)), p)
		mm.set_instance_transform(i, xf)
		if collide.call(p):
			var cs := CollisionShape3D.new()
			var cyl := CylinderShape3D.new()
			cyl.radius = 0.3 * s
			cyl.height = 4.0
			cs.shape = cyl
			cs.position = p + Vector3.UP * 2.0
			sb.add_child(cs)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.visibility_range_end = float(Settings.get_v("draw_distance"))
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if int(Settings.get_v("shadows")) >= 2 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	static_root.add_child(mmi)


func add_prop(kind: String, xf: Transform3D) -> Prop:
	var p := Prop.create(kind, xf, night)
	props_root.add_child(p)
	return p


## Припаркованная машина (без водителя, спит до удара)
func add_parked_car(id: String, xf: Transform3D) -> Car:
	var spec := CarDatabase.get_car(id)
	var cols: Array = spec["colors"]
	var car := Car.new()
	car.setup(spec, cols[rng.randi() % cols.size()], false)
	car.controller = null
	add_child(car)
	car.global_transform = xf
	Game.register_car(car)
	if Game.world != null:
		car.impact.connect(Game.world.on_car_impact)
	return car
