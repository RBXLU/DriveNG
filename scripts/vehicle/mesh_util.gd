class_name MeshUtil
extends RefCounted

## Процедурная геометрия: лофт по сечениям, коробки, плиты-панели,
## нормали и выравнивание порядка обхода (Godot: лицевые грани — по часовой).


## Сечения rings (PackedVector2Array x,y) расставляются по zs.
## Все кольца должны иметь одинаковое число точек. closed — замкнутое кольцо.
static func loft(rings: Array, zs: PackedFloat32Array, closed: bool, cap_start: bool, cap_end: bool) -> Dictionary:
	var v := PackedVector3Array()
	var idx := PackedInt32Array()
	var n: int = (rings[0] as PackedVector2Array).size()
	var nr := rings.size()
	for k in nr:
		var ring: PackedVector2Array = rings[k]
		for j in n:
			v.append(Vector3(ring[j].x, ring[j].y, zs[k]))
	var segs := n if closed else n - 1
	for k in nr - 1:
		for j in segs:
			var j2 := (j + 1) % n
			var a := k * n + j
			var b := k * n + j2
			var c := (k + 1) * n + j2
			var d := (k + 1) * n + j
			idx.append_array([a, b, c, a, c, d])
	if cap_start:
		_cap(v, idx, rings[0], zs[0], false)
	if cap_end:
		_cap(v, idx, rings[nr - 1], zs[nr - 1], true)
	return {"v": v, "i": idx, "n": n}


static func _cap(v: PackedVector3Array, idx: PackedInt32Array, ring: PackedVector2Array, z: float, flip: bool) -> void:
	var base := v.size()
	var c := Vector2.ZERO
	for p in ring:
		c += p
	c /= ring.size()
	v.append(Vector3(c.x, c.y, z))
	for p in ring:
		v.append(Vector3(p.x, p.y, z))
	var n := ring.size()
	for j in n:
		var a := base + 1 + j
		var b := base + 1 + (j + 1) % n
		if flip:
			idx.append_array([base, b, a])
		else:
			idx.append_array([base, a, b])


## Разбитый на сегменты параллелепипед (для шасси, кузова грузовика и т.п.)
static func box(size: Vector3, center: Vector3, seg: Vector3i) -> Dictionary:
	var v := PackedVector3Array()
	var idx := PackedInt32Array()
	var h := size * 0.5
	# 6 граней: ось нормали, оси u,v
	var faces := [
		[Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0), seg.z, seg.y],
		[Vector3(-1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0), seg.z, seg.y],
		[Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1), seg.x, seg.z],
		[Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1), seg.x, seg.z],
		[Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, 1, 0), seg.x, seg.y],
		[Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, 1, 0), seg.x, seg.y],
	]
	for f in faces:
		var nrm: Vector3 = f[0]
		var au: Vector3 = f[1]
		var av: Vector3 = f[2]
		var su: int = max(1, f[3])
		var sv: int = max(1, f[4])
		var base := v.size()
		for iv in sv + 1:
			for iu in su + 1:
				var pu := (float(iu) / su) * 2.0 - 1.0
				var pv := (float(iv) / sv) * 2.0 - 1.0
				var p := nrm + au * pu + av * pv
				v.append(center + p * h)
		for iv in sv:
			for iu in su:
				var a := base + iv * (su + 1) + iu
				var b := a + 1
				var c := a + su + 2
				var d := a + su + 1
				# как и loft: против часовой снаружи (fix_winding перевернёт для Godot)
				idx.append_array([a, c, b, a, d, c])
	return {"v": v, "i": idx}


## Панель-«плита» толщиной thick по сетке внешних точек grid[rows][cols]
## с нормалями наружу normals[rows][cols]. Кромки окрашиваются в тёмный (шов).
static func slab(grid: Array, normals: Array, thick: float) -> Dictionary:
	var rows := grid.size()
	var cols: int = (grid[0] as Array).size()
	var v := PackedVector3Array()
	var col := PackedColorArray()
	var idx := PackedInt32Array()
	var center := Vector3.ZERO
	for r in rows:
		for c in cols:
			v.append(grid[r][c])
			col.append(Color.WHITE)
			center += grid[r][c]
	center /= rows * cols
	var avg_n := Vector3.ZERO
	for r in rows:
		for c in cols:
			avg_n += normals[r][c]
	avg_n = avg_n.normalized()
	var inner := v.size()
	for r in rows:
		for c in cols:
			v.append(grid[r][c] - normals[r][c] * thick)
			col.append(Color(0.35, 0.35, 0.35))
	# каждая грань ориентируется явно по желаемой нормали (Godot: по часовой снаружи)
	var tri := func(a: int, b: int, c: int, want: Vector3) -> void:
		var fn := (v[c] - v[a]).cross(v[b] - v[a])
		if fn.dot(want) < 0.0:
			idx.append_array([a, c, b])
		else:
			idx.append_array([a, b, c])
	for r in rows - 1:
		for c in cols - 1:
			var a := r * cols + c
			var b := a + 1
			var cc := a + cols + 1
			var d := a + cols
			var nn: Vector3 = normals[r][c]
			tri.call(a, b, cc, nn)
			tri.call(a, cc, d, nn)
			tri.call(inner + a, inner + b, inner + cc, -nn)
			tri.call(inner + a, inner + cc, inner + d, -nn)
	# кромки (отдельные вершины, тёмные — видимый шов панели)
	var loop: Array = []
	for c in cols:
		loop.append(Vector2i(0, c))
	for r in range(1, rows):
		loop.append(Vector2i(r, cols - 1))
	for c in range(cols - 2, -1, -1):
		loop.append(Vector2i(rows - 1, c))
	for r in range(rows - 2, 0, -1):
		loop.append(Vector2i(r, 0))
	var ln := loop.size()
	var eb := v.size()
	for p in loop:
		v.append(grid[p.x][p.y])
		col.append(Color(0.12, 0.12, 0.12))
	for p in loop:
		v.append(grid[p.x][p.y] - normals[p.x][p.y] * thick)
		col.append(Color(0.12, 0.12, 0.12))
	for j in ln:
		var j2 := (j + 1) % ln
		var a := eb + j
		var b := eb + j2
		var cc := eb + ln + j2
		var d := eb + ln + j
		var mid := (v[a] + v[b]) * 0.5
		var out := mid - center
		out -= avg_n * out.dot(avg_n)
		tri.call(a, b, cc, out)
		tri.call(a, cc, d, out)
	return {"v": v, "i": idx, "c": col, "oriented": true}


## Знаковый объём (для CCW-наружу положителен)
static func signed_volume(v: PackedVector3Array, idx: PackedInt32Array) -> float:
	var s := 0.0
	var c := Vector3.ZERO
	for p in v:
		c += p
	c /= max(1, v.size())
	var i := 0
	while i < idx.size():
		var a := v[idx[i]] - c
		var b := v[idx[i + 1]] - c
		var d := v[idx[i + 2]] - c
		s += a.dot(b.cross(d))
		i += 3
	return s / 6.0


## Godot рисует лицевыми грани с обходом по часовой стрелке (снаружи).
## Если объём положителен (CCW) — переворачиваем все треугольники.
static func fix_winding(v: PackedVector3Array, idx: PackedInt32Array) -> PackedInt32Array:
	if signed_volume(v, idx) > 0.0:
		var i := 0
		while i < idx.size():
			var t := idx[i + 1]
			idx[i + 1] = idx[i + 2]
			idx[i + 2] = t
			i += 3
	return idx


## Гладкие нормали (для треугольников с обходом по часовой — наружу)
static func normals(v: PackedVector3Array, idx: PackedInt32Array) -> PackedVector3Array:
	var n := PackedVector3Array()
	n.resize(v.size())
	var i := 0
	while i < idx.size():
		var ia := idx[i]
		var ib := idx[i + 1]
		var ic := idx[i + 2]
		var a := v[ia]
		var fn := (v[ic] - a).cross(v[ib] - a)
		n[ia] += fn
		n[ib] += fn
		n[ic] += fn
		i += 3
	for k in n.size():
		var l := n[k].length()
		n[k] = n[k] / l if l > 1e-9 else Vector3.UP
	return n


static func append(dst: Dictionary, src: Dictionary) -> void:
	var off: int = (dst["v"] as PackedVector3Array).size()
	var sv: PackedVector3Array = src["v"]
	var si: PackedInt32Array = src["i"]
	var dv: PackedVector3Array = dst["v"]
	var di: PackedInt32Array = dst["i"]
	dv.append_array(sv)
	for k in si:
		di.append(k + off)
	dst["v"] = dv
	dst["i"] = di
	if dst.has("c"):
		var dc: PackedColorArray = dst["c"]
		if src.has("c"):
			dc.append_array(src["c"])
		else:
			for k in sv.size():
				dc.append(Color.WHITE)
		dst["c"] = dc


static func transform(src: Dictionary, xf: Transform3D) -> Dictionary:
	var sv: PackedVector3Array = src["v"]
	var out := PackedVector3Array()
	out.resize(sv.size())
	for k in sv.size():
		out[k] = xf * sv[k]
	var d := src.duplicate()
	d["v"] = out
	return d


## Цилиндр вдоль оси X (для колёс, фар и т.п.), радиус 1, ширина 1 (от -0.5 до 0.5)
static func cylinder_x(seg: int, bevel: float = 0.0) -> Dictionary:
	var rings: Array = []
	var zs := PackedFloat32Array()
	var profile: Array = []
	if bevel > 0.0:
		profile = [[-0.5, 1.0 - bevel], [-0.5 + bevel * 0.5, 1.0 - bevel * 0.15], [-0.5 + bevel, 1.0], [0.5 - bevel, 1.0], [0.5 - bevel * 0.5, 1.0 - bevel * 0.15], [0.5, 1.0 - bevel]]
	else:
		profile = [[-0.5, 1.0], [0.5, 1.0]]
	for pr in profile:
		var ring := PackedVector2Array()
		for s in seg:
			var a := TAU * s / seg
			ring.append(Vector2(cos(a), sin(a)) * pr[1])
		rings.append(ring)
		zs.append(pr[0])
	var d := loft(rings, zs, true, true, true)
	# лофт идёт вдоль Z — поворачиваем так, чтобы ось стала X (столбцы базиса = образы осей)
	var xf := Transform3D(Basis(Vector3(0, 0, -1), Vector3(0, 1, 0), Vector3(1, 0, 0)), Vector3.ZERO)
	return transform(d, xf)


static func build_mesh(v: PackedVector3Array, n: PackedVector3Array, surfaces: Array, colors: PackedColorArray = PackedColorArray(), uv2: PackedVector2Array = PackedVector2Array(), mesh: ArrayMesh = null) -> ArrayMesh:
	if mesh == null:
		mesh = ArrayMesh.new()
	else:
		mesh.clear_surfaces()
	for s in surfaces:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = n
		if colors.size() == v.size():
			arr[Mesh.ARRAY_COLOR] = colors
		if uv2.size() == v.size():
			arr[Mesh.ARRAY_TEX_UV2] = uv2
		arr[Mesh.ARRAY_INDEX] = s["i"]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		mesh.surface_set_material(mesh.get_surface_count() - 1, s["mat"])
	return mesh


## Простой меш из словаря {v,i[,c]} с автоматическими нормалями и выравниванием обхода
static func simple_mesh(d: Dictionary, mat: Material) -> ArrayMesh:
	var v: PackedVector3Array = d["v"]
	var idx: PackedInt32Array = fix_winding(v, d["i"])
	var n := normals(v, idx)
	var cols: PackedColorArray = d.get("c", PackedColorArray())
	return build_mesh(v, n, [{"i": idx, "mat": mat}], cols)


# ---------------------------------------------------------------- помощники деталей

## Повернутый/смещённый параллелепипед (1 сегмент)
static func obox(xf: Transform3D, size: Vector3) -> Dictionary:
	return transform(box(size, Vector3.ZERO, Vector3i(1, 1, 1)), xf)


## Цилиндр вдоль оси X с радиусом r и длиной w, преобразованный xf
static func ocyl(xf: Transform3D, r: float, w: float, seg: int = 10) -> Dictionary:
	var d := cylinder_x(seg, 0.0)
	return transform(d, xf * Transform3D(Basis.IDENTITY.scaled(Vector3(w, r, r)), Vector3.ZERO))


## Труба с профилем вдоль ломаной. a[i], b[i] — оси профиля в точке i.
static func tube(pts: PackedVector3Array, a: PackedVector3Array, b: PackedVector3Array, profile: PackedVector2Array, caps: bool = true) -> Dictionary:
	var v := PackedVector3Array()
	var idx := PackedInt32Array()
	var pn := profile.size()
	for i in pts.size():
		for pr in profile:
			v.append(pts[i] + a[i] * pr.x + b[i] * pr.y)
	for i in pts.size() - 1:
		for j in pn:
			var j2 := (j + 1) % pn
			idx.append_array([i * pn + j, i * pn + j2, (i + 1) * pn + j2, i * pn + j, (i + 1) * pn + j2, (i + 1) * pn + j])
	if caps:
		for e in [0, pts.size() - 1]:
			var base: int = e * pn
			for j in range(1, pn - 1):
				idx.append_array([base, base + j, base + j + 1])
	return {"v": v, "i": idx}


## Прямоугольный профиль со скруглением (для труб)
static func rect_profile(w: float, h: float) -> PackedVector2Array:
	var x := w * 0.5
	var y := h * 0.5
	var c: float = min(w, h) * 0.25
	return PackedVector2Array([Vector2(-x + c, -y), Vector2(x - c, -y), Vector2(x, -y + c), Vector2(x, y - c), Vector2(x - c, y), Vector2(-x + c, y), Vector2(-x, y - c), Vector2(-x, -y + c)])


static func colorize(d: Dictionary, c: Color) -> Dictionary:
	var cols := PackedColorArray()
	cols.resize((d["v"] as PackedVector3Array).size())
	cols.fill(c)
	d["c"] = cols
	return d


## Выравнивает обход отдельного замкнутого примитива (перед объединением)
static func fixed(d: Dictionary) -> Dictionary:
	if not d.get("oriented", false):
		d["i"] = fix_winding(d["v"], d["i"])
	return d


static func empty() -> Dictionary:
	return {"v": PackedVector3Array(), "i": PackedInt32Array(), "c": PackedColorArray()}


## Добавить примитив с выравниванием обхода и цветом
static func add(dst: Dictionary, src: Dictionary, c: Color = Color.WHITE) -> void:
	fixed(src)
	if not src.has("c"):
		colorize(src, c)
	append(dst, src)
