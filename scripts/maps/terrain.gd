class_name Terrain
extends Node3D

## Рельеф на регулярной сетке: высоты из функции + «врезка» дорог (выемки и
## насыпи с плавными откосами). Меш с вершинными цветами (скалы на склонах,
## грунт у обочин), коллизия — HeightMapShape3D.

const GROUND_SHADER := preload("res://shaders/ground.gdshader")

var size := 1000.0
var res := 201
var cell := 5.0
var heights := PackedFloat32Array()
var dirt := PackedFloat32Array()
var half := 500.0

# дороги для точной высоты: хэш сегментов
var _road_cells := {}
var _road_cell := 24.0
var _roads: Array = []   # [{pts: PackedVector3Array, half: float}]


func generate(p_size: float, p_res: int, base: Callable, roads: Array, shoulder: float = 3.0, blend: float = 28.0) -> void:
	size = p_size
	res = p_res
	cell = size / (res - 1)
	half = size * 0.5
	_roads = roads
	_index_roads()
	var total := res * res
	heights.resize(total)
	dirt.resize(total)
	var best_d := PackedFloat32Array()
	var best_h := PackedFloat32Array()
	var best_w := PackedFloat32Array()
	best_d.resize(total)
	best_h.resize(total)
	best_w.resize(total)
	best_d.fill(1e9)
	# «штампуем» расстояние до дороги только вокруг сегментов — быстро даже в GDScript
	for rd in roads:
		var pts: PackedVector3Array = rd["pts"]
		var rhalf: float = rd["half"]
		var reach := rhalf + shoulder + blend + cell
		for k in pts.size() - 1:
			var a := pts[k]
			var b := pts[k + 1]
			var a2 := Vector2(a.x, a.z)
			var ab := Vector2(b.x, b.z) - a2
			var l2 := ab.length_squared()
			var i0 := clampi(int(floor((min(a.x, b.x) - reach + half) / cell)), 0, res - 1)
			var i1 := clampi(int(ceil((max(a.x, b.x) + reach + half) / cell)), 0, res - 1)
			var j0 := clampi(int(floor((min(a.z, b.z) - reach + half) / cell)), 0, res - 1)
			var j1 := clampi(int(ceil((max(a.z, b.z) + reach + half) / cell)), 0, res - 1)
			for j in range(j0, j1 + 1):
				var z := -half + j * cell
				for i in range(i0, i1 + 1):
					var x := -half + i * cell
					var p := Vector2(x, z)
					var t: float = clamp((p - a2).dot(ab) / l2, 0.0, 1.0) if l2 > 1e-6 else 0.0
					var d := p.distance_to(a2 + ab * t)
					var idx := j * res + i
					if d < best_d[idx]:
						best_d[idx] = d
						best_h[idx] = lerp(a.y, b.y, t)
						best_w[idx] = rhalf
	for j in res:
		for i in res:
			var idx := j * res + i
			var x := -half + i * cell
			var z := -half + j * cell
			var h: float = base.call(x, z)
			var d := best_d[idx]
			if d < 1e8:
				var rhalf := best_w[idx]
				var t := smoothstep(rhalf + shoulder, rhalf + shoulder + blend, d)
				h = lerp(best_h[idx] - 0.12, h, t)
				dirt[idx] = 1.0 - smoothstep(rhalf, rhalf + shoulder + 4.0, d)
			heights[idx] = h


func _key(cx: int, cz: int) -> int:
	return (cx + 4096) * 8192 + (cz + 4096)


func _index_roads() -> void:
	_road_cells.clear()
	for ri in _roads.size():
		var pts: PackedVector3Array = _roads[ri]["pts"]
		for k in pts.size() - 1:
			var a := pts[k]
			var b := pts[k + 1]
			var mn := Vector2(min(a.x, b.x), min(a.z, b.z))
			var mx := Vector2(max(a.x, b.x), max(a.z, b.z))
			for cx in range(int(floor(mn.x / _road_cell)) - 1, int(floor(mx.x / _road_cell)) + 2):
				for cz in range(int(floor(mn.y / _road_cell)) - 1, int(floor(mx.y / _road_cell)) + 2):
					var key := _key(cx, cz)
					if not _road_cells.has(key):
						_road_cells[key] = []
					(_road_cells[key] as Array).append(Vector2i(ri, k))


## Возвращает (расстояние до оси ближайшей дороги, высота оси, полуширина)
func _nearest_road(x: float, z: float, max_d: float) -> Vector3:
	var best := Vector3(1e9, 0, 0)
	var r: int = int(ceil(max_d / _road_cell))
	var cx := int(floor(x / _road_cell))
	var cz := int(floor(z / _road_cell))
	var p := Vector2(x, z)
	for ix in range(cx - r, cx + r + 1):
		for iz in range(cz - r, cz + r + 1):
			var key := _key(ix, iz)
			if not _road_cells.has(key):
				continue
			for seg in _road_cells[key]:
				var rd: Dictionary = _roads[seg.x]
				var pts: PackedVector3Array = rd["pts"]
				var a := pts[seg.y]
				var b := pts[seg.y + 1]
				var a2 := Vector2(a.x, a.z)
				var b2 := Vector2(b.x, b.z)
				var ab := b2 - a2
				var t: float = clamp((p - a2).dot(ab) / max(ab.length_squared(), 1e-6), 0.0, 1.0)
				var q := a2 + ab * t
				var d := p.distance_to(q)
				if d < best.x:
					best = Vector3(d, lerp(a.y, b.y, t), rd["half"])
	return best


func grid_height(x: float, z: float) -> float:
	var fx: float = clamp((x + half) / cell, 0.0, res - 1.001)
	var fz: float = clamp((z + half) / cell, 0.0, res - 1.001)
	var i := int(fx)
	var j := int(fz)
	var tx := fx - i
	var tz := fz - j
	var h00 := heights[j * res + i]
	var h10 := heights[j * res + i + 1]
	var h01 := heights[(j + 1) * res + i]
	var h11 := heights[(j + 1) * res + i + 1]
	# та же триангуляция, что и у HeightMapShape
	if tx + tz <= 1.0:
		return h00 + (h10 - h00) * tx + (h01 - h00) * tz
	return h11 + (h01 - h11) * (1.0 - tx) + (h10 - h11) * (1.0 - tz)


## Высота с учётом дороги (для камеры и спавна)
func height_at(x: float, z: float) -> float:
	var rd := _nearest_road(x, z, 2.0 * _road_cell)
	if rd.x < rd.z + 0.5:
		return rd.y
	return grid_height(x, z)


func build(color_a: Color, color_b: Color, rock: Color, dirt_col: Color) -> void:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var col := PackedColorArray()
	var idx := PackedInt32Array()
	v.resize(res * res)
	n.resize(res * res)
	col.resize(res * res)
	for j in res:
		for i in res:
			var k := j * res + i
			v[k] = Vector3(-half + i * cell, heights[k], -half + j * cell)
	for j in res:
		for i in res:
			var k := j * res + i
			var hl := heights[j * res + max(i - 1, 0)]
			var hr := heights[j * res + min(i + 1, res - 1)]
			var hd := heights[max(j - 1, 0) * res + i]
			var hu := heights[min(j + 1, res - 1) * res + i]
			var nn := Vector3(hl - hr, 2.0 * cell, hd - hu).normalized()
			n[k] = nn
			var rock_k := smoothstep(0.78, 0.6, nn.y)
			col[k] = Color(rock_k, dirt[k] * (1.0 - rock_k), 0.0)
	for j in res - 1:
		for i in res - 1:
			var a := j * res + i
			var b := a + 1
			var c := a + res
			var d := c + 1
			# диагональ как у HeightMapShape3D (b–c)
			idx.append_array([a, b, c, b, d, c])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = n
	arr[Mesh.ARRAY_COLOR] = col
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mat := ShaderMaterial.new()
	mat.shader = GROUND_SHADER
	mat.set_shader_parameter("color_a", color_a)
	mat.set_shader_parameter("color_b", color_b)
	mat.set_shader_parameter("rock_color", rock)
	mat.set_shader_parameter("dirt_color", dirt_col)
	mat.set_shader_parameter("use_vertex_color", 1.0)
	mesh.surface_set_material(0, mat)
	# проверка ориентации: нормали должны смотреть вверх
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

	var sb := StaticBody3D.new()
	sb.collision_layer = Car.LAYER_WORLD
	sb.collision_mask = 0
	sb.set_meta("grip", 0.72)
	sb.set_meta("surface", "grass")
	var hs := HeightMapShape3D.new()
	hs.map_width = res
	hs.map_depth = res
	var data := PackedFloat32Array()
	data.resize(res * res)
	for k in res * res:
		data[k] = heights[k] / cell
	hs.map_data = data
	var cs := CollisionShape3D.new()
	cs.shape = hs
	cs.scale = Vector3(cell, cell, cell)
	sb.add_child(cs)
	add_child(sb)
