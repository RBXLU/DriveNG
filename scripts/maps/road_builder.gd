class_name RoadBuilder
extends RefCounted

## Построение дорожных лент, отбойников и стен вдоль ломаной + трёхмерная коллизия.

## Касательные (горизонтальные) для каждой точки
static func tangents(pts: PackedVector3Array, closed: bool) -> PackedVector3Array:
	var n := pts.size()
	var t := PackedVector3Array()
	t.resize(n)
	for i in n:
		var a: Vector3
		var b: Vector3
		if closed:
			a = pts[(i - 1 + n) % n]
			b = pts[(i + 1) % n]
		else:
			a = pts[max(i - 1, 0)]
			b = pts[min(i + 1, n - 1)]
		var d := b - a
		d.y = 0.0
		t[i] = d.normalized() if d.length_squared() > 1e-8 else Vector3.FORWARD
	return t


## Лента дороги. offset — смещение центра вбок (м), uv.x — метры от левой кромки.
static func ribbon(pts: PackedVector3Array, width: float, closed: bool, cols: int = 3, lift: float = 0.0) -> Dictionary:
	var tg := tangents(pts, closed)
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()
	var n := pts.size()
	var dist := 0.0
	for i in n:
		if i > 0:
			dist += pts[i].distance_to(pts[i - 1])
		var side := tg[i].cross(Vector3.UP).normalized()
		for c in cols:
			var k := float(c) / (cols - 1)
			var off := (k - 0.5) * width
			v.append(pts[i] + side * off + Vector3.UP * lift)
			uv.append(Vector2(k * width, dist))
	var rows := n if not closed else n + 1
	if closed:
		dist += pts[0].distance_to(pts[n - 1])
		var side0 := tg[0].cross(Vector3.UP).normalized()
		for c in cols:
			var k := float(c) / (cols - 1)
			v.append(pts[0] + side0 * (k - 0.5) * width + Vector3.UP * lift)
			uv.append(Vector2(k * width, dist))
	for r in rows - 1:
		for c in cols - 1:
			var a := r * cols + c
			var b := a + 1
			var cc := a + cols + 1
			var d := a + cols
			# по часовой при взгляде сверху (лицевая сторона вверх в Godot)
			idx.append_array([a, cc, b, a, d, cc])
	return {"v": v, "uv": uv, "i": idx}


## Протяжка профиля (x — вбок от линии, y — вверх) вдоль ломаной со смещением offset
static func sweep(pts: PackedVector3Array, profile: PackedVector2Array, offset: float, closed: bool, closed_profile: bool = true) -> Dictionary:
	var tg := tangents(pts, closed)
	var v := PackedVector3Array()
	var idx := PackedInt32Array()
	var n := pts.size()
	var pn := profile.size()
	var rows := n + (1 if closed else 0)
	for r in rows:
		var i := r % n
		var side := tg[i].cross(Vector3.UP).normalized()
		var base := pts[i] + side * offset
		for p in profile:
			v.append(base + side * p.x + Vector3.UP * p.y)
	var segs := pn if closed_profile else pn - 1
	for r in rows - 1:
		for j in segs:
			var a := r * pn + j
			var b := r * pn + (j + 1) % pn
			var c := (r + 1) * pn + (j + 1) % pn
			var d := (r + 1) * pn + j
			idx.append_array([a, b, c, a, c, d])
	return {"v": v, "i": idx, "closed": closed_profile}


static func mesh_from(d: Dictionary, mat: Material, flip_check: bool = true) -> ArrayMesh:
	var v: PackedVector3Array = d["v"]
	var idx: PackedInt32Array = d["i"]
	if d.get("closed", false):
		idx = MeshUtil.fix_winding(v, idx)
	var n := MeshUtil.normals(v, idx)
	# для открытых поверхностей проверяем, что нормали смотрят вверх
	if flip_check and not d.get("closed", false):
		var up := 0.0
		for k in n:
			up += k.y
		if up < 0.0 and d.get("up", true):
			var i := 0
			while i < idx.size():
				var t := idx[i + 1]
				idx[i + 1] = idx[i + 2]
				idx[i + 2] = t
				i += 3
			n = MeshUtil.normals(v, idx)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = n
	if d.has("uv"):
		arr[Mesh.ARRAY_TEX_UV] = d["uv"]
	if d.has("c"):
		arr[Mesh.ARRAY_COLOR] = d["c"]
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.surface_set_material(0, mat)
	return m


static func trimesh(d: Dictionary) -> ConcavePolygonShape3D:
	var v: PackedVector3Array = d["v"]
	var idx: PackedInt32Array = d["i"]
	var faces := PackedVector3Array()
	faces.resize(idx.size())
	for k in idx.size():
		faces[k] = v[idx[k]]
	var s := ConcavePolygonShape3D.new()
	s.set_faces(faces)
	s.backface_collision = true
	return s


## Добавляет в parent статическое тело с мешем и трёхмерной коллизией
static func add_static(parent: Node, d: Dictionary, mat: Material, grip: float, surface: String, shadows: bool = true) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.collision_layer = Car.LAYER_WORLD
	sb.collision_mask = 0
	sb.set_meta("grip", grip)
	sb.set_meta("surface", surface)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh_from(d, mat)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sb.add_child(mi)
	var cs := CollisionShape3D.new()
	cs.shape = trimesh(d)
	sb.add_child(cs)
	parent.add_child(sb)
	return sb


## Разбивает длинную ленту на куски (для отсечения по видимости)
static func chunks(pts: PackedVector3Array, closed: bool, per_chunk: int) -> Array:
	var out: Array = []
	var n := pts.size()
	var total := n if closed else n - 1
	var s := 0
	while s < total:
		var e: int = min(s + per_chunk, total)
		var c := PackedVector3Array()
		for i in range(s, e + 1):
			c.append(pts[i % n])
		out.append(c)
		s = e
	return out
