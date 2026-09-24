class_name MapCity
extends MapBase

## Город: сетка N×N кварталов, две полосы в каждую сторону, светофоры.

const CITY_SHADER := preload("res://shaders/city_ground.gdshader")
const N := 6               # кварталов по стороне
const PITCH := 110.0
const ROAD_HALF := 7.0
const LANE_W := 3.5
const CURB_H := 0.15

var half := N * PITCH * 0.5   # 330
var light_mm: MultiMesh
var light_index := {}         # Intersection -> [instance ids по оси X], [по оси Z]


func _init() -> void:
	map_id = "city"


func node_pos(i: int, j: int) -> Vector3:
	return Vector3(-half + i * PITCH, 0, -half + j * PITCH)


func surface_at(p: Vector3, _c: Object) -> Vector2:
	if max(abs(p.x), abs(p.z)) > half + ROAD_HALF + 1.0:
		return Vector2(0.72, 1.0)
	return Vector2(-1.0, 0.0)


func build_map() -> void:
	var gm := ShaderMaterial.new()
	gm.shader = CITY_SHADER
	gm.set_shader_parameter("pitch", PITCH)
	gm.set_shader_parameter("road_half", ROAD_HALF)
	gm.set_shader_parameter("city_half", half)
	flat_ground(3000.0, gm, 1.0, "asphalt")

	var bmat := ShaderMaterial.new()
	bmat.shader = BUILDING_SHADER
	bmat.set_shader_parameter("night", 1.0 if night else 0.0)
	var walk := ground_mat(Color(0.55, 0.54, 0.52), Color(0.6, 0.59, 0.56), Color(0.48, 0.47, 0.45), 2.0, 0.8)

	var palette := [Color(0.72, 0.68, 0.6), Color(0.6, 0.62, 0.66), Color(0.78, 0.74, 0.66), Color(0.55, 0.45, 0.38), Color(0.85, 0.83, 0.8), Color(0.45, 0.5, 0.56), Color(0.68, 0.55, 0.45)]
	var tree_pts: Array = []
	var lamp_pts: Array = []
	var inner := PITCH - 2.0 * ROAD_HALF   # 96
	for bi in N:
		for bj in N:
			var c := node_pos(bi, bj) + Vector3(PITCH * 0.5, 0, PITCH * 0.5)
			var sb := static_body(1.0, "asphalt")
			var walk_batch := BoxBatch.new()
			var bb := BoxBatch.new()
			# тротуар-бордюр
			solid_box(walk_batch, sb, Transform3D(Basis.IDENTITY, c + Vector3(0, CURB_H * 0.5, 0)), Vector3(inner, CURB_H, inner), Color.WHITE)
			var park := rng.randf() < 0.14 or (bi == N / 2 and bj == N / 2)
			if park:
				# парк: трава, деревья
				var grass := MeshInstance3D.new()
				var pmm := PlaneMesh.new()
				pmm.size = Vector2(inner - 8.0, inner - 8.0)
				grass.mesh = pmm
				grass.position = c + Vector3(0, CURB_H + 0.01, 0)
				grass.material_override = ground_mat(Color(0.22, 0.36, 0.13), Color(0.3, 0.42, 0.16), Color(0.3, 0.28, 0.2))
				grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				static_root.add_child(grass)
				for k in int(26 * float(Settings.get_v("vegetation"))) + 4:
					tree_pts.append(c + Vector3(rng.randf_range(-40, 40), CURB_H, rng.randf_range(-40, 40)))
			else:
				# здания по участкам 2×2 (иногда одно большое)
				var lots := 2 if rng.randf() < 0.75 else 1
				var lot := (inner - 10.0) / lots
				for li in lots:
					for lj in lots:
						var lc := c + Vector3(-(inner - 10.0) * 0.5 + lot * (li + 0.5), 0, -(inner - 10.0) * 0.5 + lot * (lj + 0.5))
						var w := lot - rng.randf_range(2.0, 8.0)
						var d := lot - rng.randf_range(2.0, 8.0)
						var dist_c := Vector2(lc.x, lc.z).length() / half
						var h: float = rng.randf_range(10.0, 28.0) + (1.0 - clamp(dist_c, 0.0, 1.0)) * rng.randf_range(10.0, 60.0)
						var col: Color = palette[rng.randi() % palette.size()]
						var xf := Transform3D(Basis.IDENTITY, lc + Vector3(0, CURB_H + h * 0.5, 0))
						bb.add(xf, Vector3(w, h, d), col, rng.randf() * 100.0)
						add_box_shape(sb, xf, Vector3(w, h, d))
						# надстройка на крыше
						if rng.randf() < 0.5:
							var rw := w * rng.randf_range(0.3, 0.6)
							var rh := rng.randf_range(2.0, 6.0)
							bb.add(Transform3D(Basis.IDENTITY, lc + Vector3(0, CURB_H + h + rh * 0.5, 0)), Vector3(rw, rh, rw), col * 0.9, rng.randf() * 100.0)
			var wm := walk_batch.build(walk, false)
			static_root.add_child(wm)
			if not bb.v.is_empty():
				var bm := bb.build(bmat, int(Settings.get_v("shadows")) > 0)
				bm.visibility_range_end = float(Settings.get_v("draw_distance")) + 150.0
				static_root.add_child(bm)
			# фонари по периметру квартала
			for k in 3:
				var t := -inner * 0.5 + inner * (k + 0.5) / 3.0
				lamp_pts.append([c + Vector3(t, CURB_H, -inner * 0.5 + 1.0), 0.0])
				lamp_pts.append([c + Vector3(t, CURB_H, inner * 0.5 - 1.0), PI])
				lamp_pts.append([c + Vector3(-inner * 0.5 + 1.0, CURB_H, t), PI * 0.5])
				lamp_pts.append([c + Vector3(inner * 0.5 - 1.0, CURB_H, t), -PI * 0.5])
	# уличные деревья вдоль тротуаров (реже)
	var lamp_step := 1 if int(Settings.get_v("quality_level")) >= 2 else 2
	for i in range(0, lamp_pts.size(), lamp_step):
		var lp: Array = lamp_pts[i]
		# столб смотрит на дорогу: плафон вынесен вперёд по -Z
		add_prop("lamp", Transform3D(Basis(Vector3.UP, lp[1]), lp[0]))
	add_trees(tree_pts, func(_p: Vector3): return true)

	# окрестности: трава, лес по кругу
	var ring: Array = []
	for i in int(700 * float(Settings.get_v("vegetation"))):
		var a := rng.randf() * TAU
		var r := rng.randf_range(half + 40.0, half + 420.0)
		ring.append(Vector3(cos(a) * r, 0, sin(a) * r))
	add_trees(ring, func(p: Vector3): return max(abs(p.x), abs(p.z)) < half + 90.0)

	_build_network()
	_build_lights()
	# точка спавна на правой полосе улицы, идущей на север (-Z): правая сторона = +X
	spawns.append(Transform3D(Basis.looking_at(Vector3(0, 0, -1), Vector3.UP), node_pos(3, 4) + Vector3(LANE_W * 1.5, 0.1, -40)))


# ---------------------------------------------------------------- граф полос

func _lane_pts(a: Vector3, b: Vector3) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var n: int = max(2, int(a.distance_to(b) / 8.0) + 1)
	for k in n:
		pts.append(a.lerp(b, float(k) / (n - 1)))
	return pts


func _bezier(a: Vector3, c: Vector3, b: Vector3) -> PackedVector3Array:
	var pts := PackedVector3Array()
	for k in 9:
		var t := k / 8.0
		pts.append(a.lerp(c, t).lerp(c.lerp(b, t), t))
	return pts


func _build_network() -> void:
	net = RoadNetwork.new()
	var inters := {}
	for i in N + 1:
		for j in N + 1:
			var it := RoadNetwork.Intersection.new()
			it.pos = node_pos(i, j)
			it.phase = rng.randi() % 4
			it.timer = rng.randf() * 10.0
			net.intersections.append(it)
			inters[Vector2i(i, j)] = it
	# полосы улиц: для каждого направления 2 полосы
	# incoming[node][dir] = [lane_inner, lane_outer]; outgoing так же
	var incoming := {}
	var outgoing := {}
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for i in N + 1:
		for j in N + 1:
			for d in dirs:
				var ni: int = i + d.x
				var nj: int = j + d.y
				if ni < 0 or nj < 0 or ni > N or nj > N:
					continue
				var a := node_pos(i, j)
				var b := node_pos(ni, nj)
				var dir := Vector3(d.x, 0, d.y)
				var right := dir.cross(Vector3.UP)
				var ls: Array = []
				for k in 2:
					var off := right * (LANE_W * (k + 0.5))
					var p0 := a + dir * (ROAD_HALF + 1.0) + off
					var p1 := b - dir * (ROAD_HALF + 1.0) + off
					var lane := net.add_lane(_lane_pts(p0, p1), 13.0 if k == 0 else 11.5)
					lane.inter = inters[Vector2i(ni, nj)]
					lane.axis = 0 if d.y == 0 else 1
					ls.append(lane)
				var kin := Vector2i(ni, nj)
				if not incoming.has(kin):
					incoming[kin] = {}
				incoming[kin][d] = ls
				var kout := Vector2i(i, j)
				if not outgoing.has(kout):
					outgoing[kout] = {}
				outgoing[kout][d] = ls
	# соединители на перекрёстках
	for key in incoming:
		var ins: Dictionary = incoming[key]
		var outs: Dictionary = outgoing.get(key, {})
		for din in ins:
			var in_lanes: Array = ins[din]
			for dout in outs:
				if dout == -din:
					continue   # без разворотов
				var out_lanes: Array = outs[dout]
				var pairs: Array = []
				if dout == din:
					pairs = [[0, 0], [1, 1]]
				elif _is_right(din, dout):
					pairs = [[1, 1]]
				else:
					pairs = [[0, 0]]
				for pr in pairs:
					var li: RoadNetwork.Lane = in_lanes[pr[0]]
					var lo: RoadNetwork.Lane = out_lanes[pr[1]]
					var a: Vector3 = li.pts[li.pts.size() - 1]
					var b: Vector3 = lo.pts[0]
					var pts: PackedVector3Array
					if dout == din:
						pts = _lane_pts(a, b)
					else:
						# контрольная точка — пересечение линий полос
						var do3 := Vector3(dout.x, 0, dout.y)
						var c := Vector3(b.x, 0, a.z) if do3.x == 0 else Vector3(a.x, 0, b.z)
						pts = _bezier(a, c, b)
					var con := net.add_lane(pts, 8.0 if dout != din else 12.0)
					con.connector = true
					net.link(li, con)
					net.link(con, lo)


func _is_right(din: Vector2i, dout: Vector2i) -> bool:
	# поворот направо: dout = din, повёрнутый по часовой (вид сверху, +X вправо, +Z вниз)
	var right := Vector3(din.x, 0, din.y).cross(Vector3.UP)
	return Vector2i(int(round(right.x)), int(round(right.z))) == dout


# ---------------------------------------------------------------- светофоры

func _build_lights() -> void:
	var pole_mm := MultiMesh.new()
	pole_mm.transform_format = MultiMesh.TRANSFORM_3D
	var pole := BoxMesh.new()
	pole.size = Vector3(0.15, 4.0, 0.15)
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.2, 0.21, 0.22)
	pm.metallic = 0.6
	pm.roughness = 0.4
	pole.material = pm
	pole_mm.mesh = pole
	light_mm = MultiMesh.new()
	light_mm.transform_format = MultiMesh.TRANSFORM_3D
	light_mm.use_colors = true
	var head := BoxMesh.new()
	head.size = Vector3(0.35, 0.35, 0.2)
	var hm := StandardMaterial3D.new()
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.vertex_color_use_as_albedo = true
	hm.albedo_color = Color(3.0, 3.0, 3.0)
	head.material = hm
	light_mm.mesh = head
	var pole_xfs: Array = []
	var head_xfs: Array = []
	var head_info: Array = []
	for it in net.intersections:
		var ids_x: Array = []
		var ids_z: Array = []
		# для каждого подхода — столб справа перед перекрёстком
		for d in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
			var right: Vector3 = (d as Vector3).cross(Vector3.UP)
			var p: Vector3 = it.pos - d * (ROAD_HALF + 1.2) + right * (ROAD_HALF + 1.2)
			if max(abs(p.x), abs(p.z)) > half + ROAD_HALF + 2.0:
				continue
			pole_xfs.append(Transform3D(Basis.IDENTITY, p + Vector3(0, 2.0 + CURB_H, 0)))
			var hxf := Transform3D(Basis.looking_at(-d, Vector3.UP), p + Vector3(0, 3.8 + CURB_H, 0) - right * 0.2)
			head_xfs.append(hxf)
			if d.z == 0:
				ids_x.append(head_xfs.size() - 1)
			else:
				ids_z.append(head_xfs.size() - 1)
		light_index[it] = [ids_x, ids_z]
	pole_mm.instance_count = pole_xfs.size()
	for k in pole_xfs.size():
		pole_mm.set_instance_transform(k, pole_xfs[k])
	light_mm.instance_count = head_xfs.size()
	for k in head_xfs.size():
		light_mm.set_instance_transform(k, head_xfs[k])
	var pmi := MultiMeshInstance3D.new()
	pmi.multimesh = pole_mm
	static_root.add_child(pmi)
	var lmi := MultiMeshInstance3D.new()
	lmi.multimesh = light_mm
	lmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	static_root.add_child(lmi)
	for it in net.intersections:
		_refresh_light(it)
	net.lights_changed.connect(_refresh_light)


func _refresh_light(it: RoadNetwork.Intersection) -> void:
	if not light_index.has(it):
		return
	var cols := [Color(0.1, 1.0, 0.3), Color(1.0, 0.75, 0.05), Color(1.0, 0.08, 0.05)]
	var ids: Array = light_index[it]
	for axis in 2:
		var c: Color = cols[it.state_for(axis)]
		for k in ids[axis]:
			light_mm.set_instance_color(k, c)
