class_name CarPart
extends RefCounted

## Деталь машины: меш (деформируемый или жёсткий), здоровье, петля (для дверей/капота).

var name := ""
var kind := ""               # body, cabin, chassis, hood, trunk, door, bumper, light, mirror, wheel, spoiler, cargo, trim
var node: Node3D             # MeshInstance3D или Node3D (колесо)
var mesh: ArrayMesh
var surfaces: Array = []     # [{i: PackedInt32Array, mat: Material, glass: bool}]
var verts := PackedVector3Array()
var orig := PackedVector3Array()
var norms := PackedVector3Array()
var colors := PackedColorArray()
var dmg := PackedVector2Array()   # UV2: x — повреждение
var noise := PackedFloat32Array()
var aabb := AABB()
var deformable := false
var detachable := false
var attached := true
var damage := 0.0            # накопленная глубина вмятин (м)
var detach_at := 0.3         # порог отрыва
var loosen_at := 0.12        # порог «замок сломан» (капот/двери)
var mass := 10.0
var dirty := false
var max_deform := 0.9
var shape_samples := PackedInt32Array()  # индексы вершин для выпуклой формы коллизии
var shape: ConvexPolygonShape3D
var side := 0                # -1 лево, 1 право
var front := true

# Петля: ось в локальных координатах детали, угол, скорость, пределы, состояние
var hinged := false
var hinge_axis := Vector3.UP
var hinge_sign := 1.0
var hinge_max := 1.2
var hinge_angle := 0.0
var hinge_vel := 0.0
var loose := false
var base_transform := Transform3D.IDENTITY

# Для колёс
var wheel_index := -1
# Для фар
var broken := false
var light_type := ""         # head, tail


func setup_mesh(v: PackedVector3Array, idx_surfaces: Array, cols: PackedColorArray = PackedColorArray()) -> void:
	verts = v
	orig = v.duplicate()
	surfaces = idx_surfaces
	var all_idx := PackedInt32Array()
	for s in surfaces:
		all_idx.append_array(s["i"])
	norms = MeshUtil.normals(verts, all_idx)
	colors = cols if cols.size() == v.size() else PackedColorArray()
	dmg.resize(v.size())
	noise.resize(v.size())
	for k in v.size():
		var p := v[k]
		var h := sin(p.x * 12.9898 + p.y * 78.233 + p.z * 37.719) * 43758.5453
		noise[k] = h - floor(h)
	aabb = AABB(v[0], Vector3.ZERO)
	for p in v:
		aabb = aabb.expand(p)
	mesh = MeshUtil.build_mesh(verts, norms, surfaces, colors, dmg)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.name = name
	node = mi


func rebuild() -> void:
	if not dirty or mesh == null:
		return
	dirty = false
	MeshUtil.build_mesh(verts, norms, surfaces, colors, dmg, mesh)


func reset() -> void:
	if orig.size() > 0:
		verts = orig.duplicate()
		dmg = PackedVector2Array()
		dmg.resize(verts.size())
		dirty = true
		rebuild()
	damage = 0.0
	loose = false
	hinge_angle = 0.0
	hinge_vel = 0.0
	broken = false
	if node:
		node.transform = base_transform


func center_local() -> Vector3:
	return aabb.get_center()


## Точки выпуклой оболочки для коллизии (из текущих, деформированных вершин)
func shape_points() -> PackedVector3Array:
	var pts := PackedVector3Array()
	pts.resize(shape_samples.size())
	for k in shape_samples.size():
		pts[k] = verts[shape_samples[k]]
	return pts
