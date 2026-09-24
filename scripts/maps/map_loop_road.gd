class_name MapLoopRoad
extends MapBase

## Общая основа для карт с замкнутой трассой на рельефе (шоссе, горы).

var center_pts := PackedVector3Array()   # ось дороги (замкнутая)
var lanes_per_dir := 1
var lane_w := 3.6
var median_half := 0.0
var shoulder := 2.0
var road_half := 6.0
var lane_speeds: Array = [14.0]
var terrain_size := 2000.0
var terrain_res := 181
var lamp_spacing := 0.0
var guard_all := false


## Переопределяется: контрольные точки трассы
func control_points() -> Array:
	return []


func base_height(_x: float, _z: float) -> float:
	return 0.0


func terrain_colors() -> Array:
	return [Color(0.22, 0.35, 0.13), Color(0.3, 0.4, 0.16), Color(0.42, 0.4, 0.37), Color(0.4, 0.33, 0.24)]


func extra_build() -> void:
	pass


func _resample(pts: Array, step: float) -> PackedVector3Array:
	# равномерная перевыборка замкнутой ломаной
	var out := PackedVector3Array()
	var n := pts.size()
	var acc := 0.0
	out.append(pts[0])
	for i in n:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[(i + 1) % n]
		var l := a.distance_to(b)
		var d := step - acc
		while d <= l:
			out.append(a.lerp(b, d / l))
			d += step
		acc = l - (d - step)
	if out[out.size() - 1].distance_to(out[0]) < step * 0.5:
		out.remove_at(out.size() - 1)
	return out


func build_map() -> void:
	road_half = median_half + lanes_per_dir * lane_w + shoulder
	var ctrl := control_points()
	var dense := []
	for p in _catmull(ctrl, 24):
		dense.append(p)
	center_pts = _resample(dense, 6.0)
	_smooth_heights()

	terrain = Terrain.new()
	add_child(terrain)
	var t0 := Time.get_ticks_msec()
	terrain.generate(terrain_size, terrain_res, base_height, [{"pts": _closed(center_pts), "half": road_half}], 4.0, 34.0)
	var tc := terrain_colors()
	terrain.build(tc[0], tc[1], tc[2], tc[3])
	print("terrain: ", Time.get_ticks_msec() - t0, " ms")

	# дорога кусками — для отсечения по видимости
	var rmat := road_mat(road_half * 2.0, lanes_per_dir, median_half, lanes_per_dir == 1)
	var closed := _closed(center_pts)
	var dd := float(Settings.get_v("draw_distance"))
	for chunk in RoadBuilder.chunks(closed, false, 40):
		var d := RoadBuilder.ribbon(chunk, road_half * 2.0, false, 5, 0.06)
		var sb := RoadBuilder.add_static(static_root, d, rmat, 1.0, "asphalt", false)
		# непрерывная разметка между кусками: uv.y считаем от начала каждого куска — не критично
		(sb.get_child(0) as MeshInstance3D).visibility_range_end = dd + 200.0

	# разделитель и отбойники
	var conc := concrete_mat()
	var metal := metal_mat()
	if median_half > 0.0:
		var jersey := PackedVector2Array([Vector2(-0.35, 0.0), Vector2(-0.12, 0.25), Vector2(-0.1, 0.85), Vector2(0.1, 0.85), Vector2(0.12, 0.25), Vector2(0.35, 0.0)])
		for chunk in RoadBuilder.chunks(closed, false, 40):
			var d2 := RoadBuilder.sweep(chunk, jersey, 0.0, false, true)
			var sb2 := RoadBuilder.add_static(static_root, d2, conc, 1.0, "asphalt", true)
			(sb2.get_child(0) as MeshInstance3D).visibility_range_end = dd
	var rail := PackedVector2Array([Vector2(-0.06, 0.45), Vector2(0.06, 0.45), Vector2(0.06, 0.85), Vector2(-0.06, 0.85)])
	for side in [-1.0, 1.0]:
		var runs := _guard_runs(side)
		for run in runs:
			for chunk in RoadBuilder.chunks(run, false, 40):
				if chunk.size() < 2:
					continue
				var d3 := RoadBuilder.sweep(chunk, rail, side * (road_half + 0.4), false, true)
				var sb3 := RoadBuilder.add_static(static_root, d3, metal, 1.0, "asphalt", false)
				(sb3.get_child(0) as MeshInstance3D).visibility_range_end = dd
				# стойки — только коллизия низкой стенки под рельсом
				var low := PackedVector2Array([Vector2(-0.05, 0.0), Vector2(0.05, 0.0), Vector2(0.05, 0.46), Vector2(-0.05, 0.46)])
				var d4 := RoadBuilder.sweep(chunk, low, side * (road_half + 0.4), false, true)
				var sb4 := StaticBody3D.new()
				sb4.collision_layer = Car.LAYER_WORLD
				var cs := CollisionShape3D.new()
				cs.shape = RoadBuilder.trimesh(d4)
				sb4.add_child(cs)
				static_root.add_child(sb4)

	# фонари
	if lamp_spacing > 0.0:
		var tg := RoadBuilder.tangents(center_pts, true)
		var step := int(lamp_spacing / 6.0)
		var qstep := 1 if int(Settings.get_v("quality_level")) >= 2 else 2
		var k := 0
		for i in range(0, center_pts.size(), step * qstep):
			var side2 := 1.0 if k % 2 == 0 else -1.0
			k += 1
			var right := tg[i].cross(Vector3.UP).normalized()
			var p := center_pts[i] + right * side2 * (road_half + 1.2)
			p.y = terrain.grid_height(p.x, p.z)
			var yaw := atan2(right.x * side2, right.z * side2)
			add_prop("lamp", Transform3D(Basis(Vector3.UP, yaw), p))

	# полосы трафика
	net = RoadNetwork.new()
	for dir_i in 2:
		var pts := center_pts.duplicate()
		if dir_i == 1:
			pts.reverse()
		var tg2 := RoadBuilder.tangents(pts, true)
		for k2 in lanes_per_dir:
			var lp := PackedVector3Array()
			var off := median_half + lane_w * (k2 + 0.5)
			for i in pts.size():
				var right := tg2[i].cross(Vector3.UP).normalized()
				lp.append(pts[i] + right * off + Vector3.UP * 0.06)
			lp.append(lp[0])
			var lane := net.add_lane(lp, lane_speeds[min(k2, lane_speeds.size() - 1)])
			lane.loop = true
			net.link(lane, lane)

	# лес
	var trees: Array = []
	var nt := int(1800 * float(Settings.get_v("vegetation")))
	var hs := terrain_size * 0.48
	var tries := 0
	while trees.size() < nt and tries < nt * 4:
		tries += 1
		var x := rng.randf_range(-hs, hs)
		var z := rng.randf_range(-hs, hs)
		var rd := terrain._nearest_road(x, z, 60.0)
		if rd.x < road_half + 10.0:
			continue
		var y := terrain.grid_height(x, z)
		if y < water_level() + 0.5:
			continue
		trees.append(Vector3(x, y - 0.2, z))
	add_trees(trees, func(p: Vector3): return terrain._nearest_road(p.x, p.z, 48.0).x < road_half + 40.0)
	extra_build()

	var sp_tg := RoadBuilder.tangents(center_pts, true)
	var right0 := sp_tg[0].cross(Vector3.UP).normalized()
	var p0 := center_pts[0] + right0 * (median_half + lane_w * (lanes_per_dir - 0.5)) + Vector3.UP * 0.2
	spawns.append(Transform3D(Basis.looking_at(sp_tg[0], Vector3.UP), p0))


func water_level() -> float:
	return -1000.0


func _closed(p: PackedVector3Array) -> PackedVector3Array:
	var c := p.duplicate()
	c.append(p[0])
	return c


func _catmull(ctrl: Array, samples: int) -> Array:
	var out: Array = []
	var n := ctrl.size()
	for i in n:
		var p0: Vector3 = ctrl[(i - 1 + n) % n]
		var p1: Vector3 = ctrl[i]
		var p2: Vector3 = ctrl[(i + 1) % n]
		var p3: Vector3 = ctrl[(i + 2) % n]
		for s in samples:
			var t := float(s) / samples
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	return out


## Сглаживаем высоты трассы и ограничиваем уклон
func _smooth_heights() -> void:
	var n := center_pts.size()
	var h := PackedFloat32Array()
	h.resize(n)
	for i in n:
		h[i] = center_pts[i].y
	for it in 30:
		var h2 := h.duplicate()
		for i in n:
			h2[i] = (h[(i - 2 + n) % n] + h[(i - 1 + n) % n] + h[i] * 2.0 + h[(i + 1) % n] + h[(i + 2) % n]) / 6.0
		h = h2
	for i in n:
		center_pts[i].y = h[i]


## Участки, где нужен отбойник: обрыв/насыпь сбоку или везде (guard_all)
func _guard_runs(side: float) -> Array:
	var runs: Array = []
	var cur := PackedVector3Array()
	var tg := RoadBuilder.tangents(center_pts, true)
	var n := center_pts.size()
	for i in n + 1:
		var k := i % n
		var p := center_pts[k]
		var right := tg[k].cross(Vector3.UP).normalized()
		var need := guard_all
		if not need:
			var q := p + right * side * (road_half + 14.0)
			need = base_height(q.x, q.z) < p.y - 3.0
		if need:
			cur.append(p)
		elif cur.size() > 0:
			if cur.size() > 3:
				runs.append(cur)
			cur = PackedVector3Array()
	if cur.size() > 3:
		runs.append(cur)
	return runs
