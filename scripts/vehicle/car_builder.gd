class_name CarBuilder
extends RefCounted

## Процедурная сборка машины из спецификации: кузов (лофт по сечениям с арками),
## остеклённая кабина, навесные детали (капот, багажник, двери, бамперы, фары,
## зеркала, спойлер), шасси, колёса, точки для выпуклых форм коллизии.
## Координаты модели: Y вверх, перед машины — в сторону -Z, земля на y = 0.

# Доли: высоты — от H, продольные позиции u — от кормы (0) к носу (1)
const TEMPLATES := {
	"sedan": {"nose": 0.5, "hood": 0.6, "belt": 0.63, "trunk": 0.66, "tail": 0.6, "cab_f": 0.64, "roof_f": 0.53, "roof_r": 0.3, "cab_r": 0.19, "roof_w": 0.84, "plan": 0.32, "edge": 0.09, "doors": 4, "trunk_lid": true, "pillars": [0.5]},
	"fastback": {"nose": 0.48, "hood": 0.58, "belt": 0.62, "trunk": 0.65, "tail": 0.62, "cab_f": 0.65, "roof_f": 0.55, "roof_r": 0.33, "cab_r": 0.1, "roof_w": 0.82, "plan": 0.34, "edge": 0.1, "doors": 4, "pillars": [0.55]},
	"hatch": {"nose": 0.49, "hood": 0.58, "belt": 0.62, "trunk": 0.64, "tail": 0.64, "cab_f": 0.66, "roof_f": 0.54, "roof_r": 0.1, "cab_r": 0.02, "roof_w": 0.84, "plan": 0.3, "edge": 0.1, "doors": 4, "pillars": [0.55]},
	"hatch_small": {"nose": 0.5, "hood": 0.6, "belt": 0.62, "trunk": 0.64, "tail": 0.64, "cab_f": 0.68, "roof_f": 0.57, "roof_r": 0.08, "cab_r": 0.02, "roof_w": 0.86, "plan": 0.34, "edge": 0.12, "doors": 2, "pillars": []},
	"wagon": {"nose": 0.5, "hood": 0.6, "belt": 0.62, "trunk": 0.64, "tail": 0.64, "cab_f": 0.64, "roof_f": 0.54, "roof_r": 0.05, "cab_r": 0.02, "roof_w": 0.86, "plan": 0.26, "edge": 0.08, "doors": 4, "pillars": [0.42, 0.8]},
	"coupe": {"nose": 0.47, "hood": 0.57, "belt": 0.61, "trunk": 0.64, "tail": 0.6, "cab_f": 0.62, "roof_f": 0.5, "roof_r": 0.3, "cab_r": 0.15, "roof_w": 0.8, "plan": 0.36, "edge": 0.1, "doors": 2, "trunk_lid": true, "pillars": []},
	"coupe911": {"nose": 0.42, "hood": 0.52, "belt": 0.6, "trunk": 0.63, "tail": 0.6, "cab_f": 0.66, "roof_f": 0.55, "roof_r": 0.34, "cab_r": 0.12, "roof_w": 0.78, "plan": 0.42, "edge": 0.12, "doors": 2, "trunk_lid": true, "pillars": []},
	"muscle": {"nose": 0.52, "hood": 0.6, "belt": 0.62, "trunk": 0.64, "tail": 0.62, "cab_f": 0.58, "roof_f": 0.47, "roof_r": 0.3, "cab_r": 0.17, "roof_w": 0.8, "plan": 0.3, "edge": 0.08, "doors": 2, "trunk_lid": true, "pillars": []},
	"supercar": {"nose": 0.4, "hood": 0.52, "belt": 0.58, "trunk": 0.62, "tail": 0.62, "cab_f": 0.68, "roof_f": 0.56, "roof_r": 0.38, "cab_r": 0.18, "roof_w": 0.74, "plan": 0.38, "edge": 0.1, "doors": 2, "trunk_lid": true, "pillars": []},
	"suv": {"nose": 0.56, "hood": 0.61, "belt": 0.6, "trunk": 0.62, "tail": 0.62, "cab_f": 0.72, "roof_f": 0.63, "roof_r": 0.05, "cab_r": 0.02, "roof_w": 0.88, "plan": 0.24, "edge": 0.1, "doors": 4, "pillars": [0.47, 0.82]},
	"suv3": {"nose": 0.56, "hood": 0.6, "belt": 0.6, "trunk": 0.62, "tail": 0.62, "cab_f": 0.72, "roof_f": 0.63, "roof_r": 0.05, "cab_r": 0.02, "roof_w": 0.88, "plan": 0.2, "edge": 0.08, "doors": 2, "pillars": [0.65]},
	"pickup": {"nose": 0.57, "hood": 0.62, "belt": 0.58, "trunk": 0.58, "tail": 0.58, "cab_f": 0.69, "roof_f": 0.62, "roof_r": 0.44, "cab_r": 0.42, "roof_w": 0.88, "plan": 0.24, "edge": 0.08, "doors": 4, "bed": true, "pillars": [0.5], "rear_cap_paint": true},
	"minivan": {"nose": 0.47, "hood": 0.48, "belt": 0.5, "trunk": 0.5, "tail": 0.5, "cab_f": 0.97, "roof_f": 0.9, "roof_r": 0.03, "cab_r": 0.0, "roof_w": 0.9, "plan": 0.55, "edge": 0.2, "doors": 2, "front_doors": true, "pillars": [0.3, 0.55, 0.8], "no_hood": true},
	"van": {"nose": 0.42, "hood": 0.47, "belt": 0.47, "trunk": 0.47, "tail": 0.47, "cab_f": 0.86, "roof_f": 0.76, "roof_r": 0.01, "cab_r": 0.0, "roof_w": 0.93, "plan": 0.3, "edge": 0.14, "doors": 2, "front_doors": true, "pillars": [], "side_glass_from": 0.62, "rear_cap_paint": true},
	"bus": {"nose": 0.33, "hood": 0.33, "belt": 0.33, "trunk": 0.33, "tail": 0.33, "cab_f": 0.995, "roof_f": 0.985, "roof_r": 0.01, "cab_r": 0.0, "roof_w": 0.96, "plan": 0.18, "edge": 0.2, "doors": 0, "pillars": [0.08, 0.2, 0.32, 0.44, 0.56, 0.68, 0.8, 0.92], "no_hood": true, "rear_cap_paint": true},
	"truck": {"nose": 0.42, "hood": 0.44, "belt": 0.5, "trunk": 0.33, "tail": 0.33, "cab_f": 0.995, "roof_f": 0.95, "roof_r": 0.78, "cab_r": 0.775, "roof_w": 0.94, "plan": 0.16, "edge": 0.12, "doors": 2, "front_doors": true, "pillars": [], "roof_h": 0.9, "cargo": true, "no_hood": true, "rear_cap_paint": true},
}

var spec: Dictionary
var t: Dictionary
var L: float
var W: float
var H: float
var clr: float
var wr: float
var ww: float
var axles_z: Array[float] = []
var paint_mat: ShaderMaterial
var paint2_mat: ShaderMaterial
var head_mat: StandardMaterial3D
var tail_mat: StandardMaterial3D
var parts: Array[CarPart] = []
var model: Node3D


func build(p_spec: Dictionary, color: Color) -> Dictionary:
	spec = p_spec
	t = TEMPLATES.get(spec["body"], TEMPLATES["sedan"])
	L = spec["L"]
	W = spec["W"]
	H = spec["H"]
	clr = spec["clearance"]
	wr = spec["wheel_r"]
	ww = spec["wheel_w"]
	var fo: float = spec.get("front_overhang", (L - spec["wheelbase"]) * 0.5)
	var zf := -L * 0.5 + fo
	var zr: float = zf + spec["wheelbase"]
	axles_z = [zf]
	if spec.get("axles", 2) == 3:
		axles_z.append(zr - 0.68)
		axles_z.append(zr + 0.68)
	else:
		axles_z.append(zr)

	var metallic := 0.45
	var rough := 0.28
	if spec.get("boxy", false):
		metallic = 0.15
		rough = 0.35
	paint_mat = CarMaterials.paint(color, metallic, rough)
	var c2: Color = spec.get("color2", color)
	paint2_mat = CarMaterials.paint(c2, 0.2, 0.35) if spec.has("color2") else paint_mat
	head_mat = CarMaterials.headlight()
	tail_mat = CarMaterials.taillight()

	model = Node3D.new()
	model.name = "Model"
	parts.clear()

	_build_body()
	_build_chassis()
	_build_cabin()
	if not t.get("no_hood", false):
		_build_hood()
	if t.get("trunk_lid", false):
		_build_trunk()
	_build_doors()
	_build_bumper(true)
	_build_bumper(false)
	_build_lights()
	_build_mirrors()
	_build_extras()
	if t.get("bed", false):
		_build_bed()
	if t.get("cargo", false):
		_build_cargo()
	var wheels := _build_wheels()

	for p in parts:
		p.base_transform = p.node.transform
		model.add_child(p.node)

	var com_y := clr + (H - clr) * 0.3
	var mid_z := (axles_z[0] + axles_z[axles_z.size() - 1]) * 0.5
	var wb: float = spec["wheelbase"]
	var com_z := mid_z
	match spec.get("engine", "front"):
		"front": com_z -= wb * 0.06
		"mid": com_z += wb * 0.04
		"rear": com_z += wb * 0.1

	return {
		"model": model,
		"parts": parts,
		"wheels": wheels,
		"com": Vector3(0, com_y, com_z),
		"paint": paint_mat,
		"paint2": paint2_mat,
		"head_mat": head_mat,
		"tail_mat": tail_mat,
	}


# ---------------------------------------------------------------- профиль кузова

func z_of(u: float) -> float:
	return (0.5 - u) * L


func u_of(z: float) -> float:
	return 0.5 - z / L


func _smooth_keys(keys: Array, u: float) -> float:
	if u <= keys[0][0]:
		return keys[0][1]
	for k in range(1, keys.size()):
		if u <= keys[k][0]:
			var a: Array = keys[k - 1]
			var b: Array = keys[k]
			var s: float = (u - a[0]) / max(1e-5, b[0] - a[0])
			s = s * s * (3.0 - 2.0 * s)
			return lerp(float(a[1]), float(b[1]), s)
	return keys[keys.size() - 1][1]


func belt(u: float) -> float:
	var cab_r: float = t["cab_r"]
	var cab_f: float = t["cab_f"]
	var raw := [
		[0.0, t["tail"]], [0.05, t["trunk"]], [cab_r + 0.03, t["belt"]], [cab_f - 0.02, t["belt"]],
		[cab_f + 0.05, t["hood"]], [0.965, lerp(float(t["nose"]), float(t["hood"]), 0.3)], [1.0, t["nose"]],
	]
	var keys: Array = []
	var last := -1.0
	for k in raw:
		var uu: float = clamp(k[0], 0.0, 1.0)
		if uu <= last + 0.004:
			if keys.size() > 0 and k[0] > 0.9:
				continue
			uu = last + 0.004
		keys.append([uu, k[1]])
		last = uu
	return _smooth_keys(keys, u) * H


func arch_top(z: float) -> float:
	var top := -1.0
	var ra := wr + 0.06
	for az in axles_z:
		var dz := z - az
		if abs(dz) < ra:
			top = max(top, wr + sqrt(ra * ra - dz * dz) - 0.02)
	return top


func bottom(u: float) -> float:
	var b := clr
	var e: float = min(u, 1.0 - u)
	b += 0.07 * (1.0 - smoothstep(0.0, 0.08, e))
	b = max(b, arch_top(z_of(u)))
	return b


func half_w(u: float) -> float:
	var hw := W * 0.5
	var pr: float = t["plan"] * hw
	var d_front := (1.0 - u) * L
	var d_rear := u * L
	if d_front < pr:
		var q := pr - d_front
		hw -= pr - sqrt(max(pr * pr - q * q, 0.0))
	var prr := pr * 0.85
	if d_rear < prr:
		var q2 := prr - d_rear
		hw -= prr - sqrt(max(prr * prr - q2 * q2, 0.0))
	return max(hw, 0.15)


## Контур кузова в плане: z передней/задней грани на данном x
func outline_z(x: float, front: bool) -> float:
	var hw := W * 0.5
	var pr: float = t["plan"] * hw * (1.0 if front else 0.85)
	var flat := hw - pr
	var ax: float = abs(x)
	var d := 0.0
	if ax > flat:
		var q: float = min(ax - flat, pr)
		d = pr - sqrt(max(pr * pr - q * q, 0.0))
	return (-L * 0.5 + d) if front else (L * 0.5 - d)


## Параметры сечения нижней части кузова
func section(u: float) -> Dictionary:
	var hw := half_w(u)
	var y0 := bottom(u)
	var y1c := belt(u)
	var at := arch_top(z_of(u))
	var y1s: float = max(y1c, at + 0.06) if at > 0.0 else y1c
	y1c = max(y1c, y0 + 0.08)
	y1s = max(y1s, y0 + 0.08)
	var rt: float = min(float(t["edge"]), (y1s - y0) * 0.45, hw * 0.35)
	return {"hw": hw, "y0": y0, "y1c": y1c, "y1s": y1s, "rt": rt, "tumble": min(0.04, hw * 0.04)}


func side_x(sec: Dictionary, y: float) -> float:
	var hw: float = sec["hw"]
	var ymid: float = (sec["y0"] + sec["y1s"]) * 0.5
	var ytop: float = sec["y1s"] - sec["rt"]
	if y <= ymid:
		return hw
	var k: float = clamp((y - ymid) / max(0.01, ytop - ymid), 0.0, 1.0)
	return hw - sec["tumble"] * k


func top_y(sec: Dictionary, x: float) -> float:
	var xa: float = sec["hw"] - sec["tumble"] - sec["rt"]
	var k: float = clamp(abs(x) / max(0.01, xa), 0.0, 1.0)
	return lerp(float(sec["y1c"]), float(sec["y1s"]), k * k)


func _ring_low(sec: Dictionary) -> PackedVector2Array:
	var hw: float = sec["hw"]
	var y0: float = sec["y0"]
	var y1s: float = sec["y1s"]
	var rt: float = sec["rt"]
	var tb: float = sec["tumble"]
	var rb: float = min(0.05, (y1s - y0) * 0.2)
	var half: Array[Vector2] = []
	half.append(Vector2(hw - rb, y0))
	half.append(Vector2(hw - rb + rb * 0.7071, y0 + rb - rb * 0.7071))
	half.append(Vector2(hw, y0 + rb))
	half.append(Vector2(hw, lerp(y0 + rb, y1s - rt, 0.5)))
	var cx := hw - tb - rt
	var cy := y1s - rt
	for a in [0.0, 30.0, 60.0, 90.0]:
		var r := deg_to_rad(a)
		half.append(Vector2(cx + rt * cos(r), cy + rt * sin(r)))
	half.append(Vector2(cx * 0.5, top_y(sec, cx * 0.5)))
	var ring := PackedVector2Array()
	ring.append(Vector2(0, y0))
	for p in half:
		ring.append(p)
	ring.append(Vector2(0, sec["y1c"]))
	for i in range(half.size() - 1, -1, -1):
		ring.append(Vector2(-half[i].x, half[i].y))
	return ring


func _section_us(n: int) -> PackedFloat32Array:
	var us := PackedFloat32Array()
	for k in n:
		var s := float(k) / (n - 1)
		us.append(lerp(s, 0.5 - 0.5 * cos(PI * s), 0.35))
	return us


func _build_body() -> void:
	var n: int = clamp(int(L / 0.1), 34, 90)
	var us := _section_us(n)
	var rings: Array = []
	var zs := PackedFloat32Array()
	for u in us:
		rings.append(_ring_low(section(u)))
		zs.append(z_of(u))
	var d := MeshUtil.loft(rings, zs, true, true, true)
	var v: PackedVector3Array = d["v"]
	var idx := MeshUtil.fix_winding(v, d["i"])
	var p := CarPart.new()
	p.name = "body"
	p.kind = "body"
	p.deformable = true
	p.max_deform = 1.0
	p.setup_mesh(v, [{"i": idx, "mat": paint_mat}])
	# точки для выпуклой формы: каждое 3-е сечение, каждая 2-я точка кольца
	var rn: int = d["n"]
	var samples := PackedInt32Array()
	for k in range(0, n, 3):
		for j in range(0, rn, 2):
			samples.append(k * rn + j)
	for j in range(0, rn, 2):
		samples.append((n - 1) * rn + j)
	p.shape_samples = samples
	parts.append(p)


func _build_chassis() -> void:
	var y_top: float = min(belt(0.5), belt(0.2), belt(0.8)) - 0.12
	var h: float = max(0.1, y_top - clr)
	var cw: float = max(0.3, W - 2.0 * ww - 0.2)
	var d := MeshUtil.box(Vector3(cw, h, L - 0.5), Vector3(0, clr + h * 0.5, 0), Vector3i(2, 2, 14))
	var v: PackedVector3Array = d["v"]
	var idx := MeshUtil.fix_winding(v, d["i"])
	var p := CarPart.new()
	p.name = "chassis"
	p.kind = "chassis"
	p.deformable = true
	p.setup_mesh(v, [{"i": idx, "mat": CarMaterials.chassis()}])
	parts.append(p)


# ---------------------------------------------------------------- кабина

func _cab_height_factor(u: float) -> float:
	var cab_r: float = t["cab_r"]
	var cab_f: float = t["cab_f"]
	var roof_r: float = t["roof_r"]
	var roof_f: float = t["roof_f"]
	var k := 1.0
	if u < roof_r - 1e-4:
		k = (u - cab_r) / max(1e-4, roof_r - cab_r)
	elif u > roof_f + 1e-4:
		k = (cab_f - u) / max(1e-4, cab_f - roof_f)
	k = clamp(k, 0.0, 1.0)
	return sin(k * PI * 0.5)


func _build_cabin() -> void:
	var cab_r: float = t["cab_r"]
	var cab_f: float = t["cab_f"]
	var roof_r: float = t["roof_r"]
	var roof_f: float = t["roof_f"]
	var roof_y: float = H * t.get("roof_h", 1.0)
	var us: Array[float] = [cab_r, lerp(cab_r, roof_r, 0.4), lerp(cab_r, roof_r, 0.75), roof_r]
	var n_roof: int = clamp(int((roof_f - roof_r) * L / 0.4), 2, 40)
	for i in range(1, n_roof):
		us.append(lerp(roof_r, roof_f, float(i) / n_roof))
	var pw := 0.055 / L
	var pillar_ranges: Array = []
	for pp in t.get("pillars", []):
		var pu: float = lerp(roof_r, roof_f, pp)
		us.append(pu - pw)
		us.append(pu + pw)
		pillar_ranges.append(Vector2(pu - pw - 1e-4, pu + pw + 1e-4))
	us.append_array([roof_f, lerp(roof_f, cab_f, 0.3), lerp(roof_f, cab_f, 0.65), cab_f])
	us.sort()
	var clean: Array[float] = []
	for u in us:
		if clean.is_empty() or u - clean[clean.size() - 1] > 0.0015:
			clean.append(u)
	us = clean

	var rings: Array = []
	var zs := PackedFloat32Array()
	var sec_u: Array[float] = []
	for u in us:
		var sec := section(u)
		var yb: float = belt(u) - 0.005
		var k := _cab_height_factor(u)
		var yt: float = lerp(yb, roof_y, k)
		var hwb: float = sec["hw"] - sec["tumble"] - 0.03
		var hwt: float = lerp(hwb, hwb * float(t["roof_w"]), k)
		var rt: float = min(float(t["edge"]) * 0.8, (yt - yb) * 0.4, hwt * 0.3)
		var crown := 0.035 * k
		var half: Array[Vector2] = []
		half.append(Vector2(hwb, yb))
		half.append(Vector2(lerp(hwb, hwt, 0.55), lerp(yb, yt - rt, 0.55)))
		var cx := hwt - rt
		var cy := yt - rt
		for a in [0.0, 45.0, 90.0]:
			var r := deg_to_rad(a)
			half.append(Vector2(cx + rt * cos(r), cy + rt * sin(r)))
		var ring := PackedVector2Array()
		for p in half:
			ring.append(p)
		ring.append(Vector2(0, yt + crown))
		for i in range(half.size() - 1, -1, -1):
			ring.append(Vector2(-half[i].x, half[i].y))
		rings.append(ring)
		zs.append(z_of(u))
		sec_u.append(u)

	var d := MeshUtil.loft(rings, zs, true, true, true)
	var v: PackedVector3Array = d["v"]
	var all_idx: PackedInt32Array = d["i"]
	var flipped := MeshUtil.signed_volume(v, all_idx) > 0.0
	var rn: int = d["n"]
	var nsec := rings.size()
	var paint_i := PackedInt32Array()
	var glass_i := PackedInt32Array()
	var side_glass_from: float = t.get("side_glass_from", -1.0)
	var rear_cap_paint: bool = t.get("rear_cap_paint", false)
	# классификация граней лофта: сегменты кольца 0,1,8,9 — боковое стекло;
	# 2,3,6,7 — рамка/стойки; 4,5 — крыша (или лобовое/заднее стекло); 10 — дно
	var tri := 0
	for k in nsec - 1:
		var ua: float = sec_u[k]
		var ub: float = sec_u[k + 1]
		var in_roof := ua >= roof_r - 1e-4 and ub <= roof_f + 1e-4
		var in_pillar := false
		for pr in pillar_ranges:
			if ua >= pr.x and ub <= pr.y:
				in_pillar = true
		for j in rn:
			var paint := false
			match j:
				0, 1, 8, 9:
					paint = in_pillar or (side_glass_from > 0.0 and ub <= side_glass_from + 1e-4)
				2, 3, 6, 7:
					paint = true
				4, 5:
					paint = in_roof
				_:
					paint = true
			var base := tri * 6
			var dst := paint_i if paint else glass_i
			for q in 6:
				dst.append(all_idx[base + q])
			tri += 1
	# крышки: задняя (первая) и передняя
	var cap_tris := (all_idx.size() - tri * 6) / 3
	var per_cap := cap_tris / 2
	for c in cap_tris:
		var is_rear := c < per_cap
		var dst2 := paint_i if (is_rear and rear_cap_paint) else glass_i
		for q in 3:
			dst2.append(all_idx[tri * 6 + c * 3 + q])
	if flipped:
		_flip(paint_i)
		_flip(glass_i)
	var p := CarPart.new()
	p.name = "cabin"
	p.kind = "cabin"
	p.deformable = true
	p.max_deform = 0.7
	p.setup_mesh(v, [{"i": paint_i, "mat": paint_mat}, {"i": glass_i, "mat": CarMaterials.glass(), "glass": true}])
	var samples := PackedInt32Array()
	for k in range(0, nsec, 2):
		for j in rn:
			samples.append(k * rn + j)
	for j in rn:
		samples.append((nsec - 1) * rn + j)
	p.shape_samples = samples
	parts.append(p)


func _flip(idx: PackedInt32Array) -> void:
	var i := 0
	while i < idx.size():
		var tmp := idx[i + 1]
		idx[i + 1] = idx[i + 2]
		idx[i + 2] = tmp
		i += 3


# ---------------------------------------------------------------- навесные панели

func _panel_part(name: String, kind: String, grid: Array, normals: Array, thick: float, pivot: Vector3, mat: Material) -> CarPart:
	var g2: Array = []
	for row in grid:
		var r2: Array = []
		for pt in row:
			r2.append(pt - pivot)
		g2.append(r2)
	var d := MeshUtil.slab(g2, normals, thick)
	var v: PackedVector3Array = d["v"]
	var idx := MeshUtil.fix_winding(v, d["i"])
	var p := CarPart.new()
	p.name = name
	p.kind = kind
	p.deformable = true
	p.detachable = true
	p.setup_mesh(v, [{"i": idx, "mat": mat}], d["c"])
	p.node.position = pivot
	return p


func _build_hood() -> void:
	var u0: float = float(t["cab_f"]) + 0.012
	var u1 := 0.972
	if u1 - u0 < 0.05:
		return
	var rows := 9
	var cols := 7
	var grid: Array = []
	var nrm: Array = []
	for r in rows:
		var u: float = lerp(u0, u1, float(r) / (rows - 1))
		var sec := section(u)
		var xa: float = sec["hw"] - sec["tumble"] - sec["rt"] * 0.6
		var row: Array = []
		var nrow: Array = []
		for c in cols:
			var x: float = lerp(-xa, xa, float(c) / (cols - 1))
			row.append(Vector3(x, top_y(sec, x) + 0.01, z_of(u)))
			nrow.append(Vector3.UP)
		grid.append(row)
		nrm.append(nrow)
	var pivot: Vector3 = grid[0][cols / 2]
	var p := _panel_part("hood", "hood", grid, nrm, 0.03, pivot, paint_mat)
	p.mass = 16.0
	p.hinged = true
	p.hinge_axis = Vector3.RIGHT
	p.hinge_sign = 1.0
	p.hinge_max = 1.35
	p.loosen_at = 0.1
	p.detach_at = 0.42
	p.front = true
	parts.append(p)


func _build_trunk() -> void:
	var u0 := 0.035
	var u1: float = float(t["cab_r"]) - 0.008
	if u1 - u0 < 0.05:
		return
	var rows := 6
	var cols := 7
	var grid: Array = []
	var nrm: Array = []
	for r in rows:
		var u: float = lerp(u1, u0, float(r) / (rows - 1))
		var sec := section(u)
		var xa: float = sec["hw"] - sec["tumble"] - sec["rt"] * 0.6
		var row: Array = []
		var nrow: Array = []
		for c in cols:
			var x: float = lerp(-xa, xa, float(c) / (cols - 1))
			row.append(Vector3(x, top_y(sec, x) + 0.01, z_of(u)))
			nrow.append(Vector3.UP)
		grid.append(row)
		nrm.append(nrow)
	var pivot: Vector3 = grid[0][cols / 2]
	var p := _panel_part("trunk", "trunk", grid, nrm, 0.03, pivot, paint_mat)
	p.mass = 12.0
	p.hinged = true
	p.hinge_axis = Vector3.RIGHT
	p.hinge_sign = -1.0
	p.hinge_max = 1.3
	p.loosen_at = 0.1
	p.detach_at = 0.42
	p.front = false
	parts.append(p)


func _build_doors() -> void:
	var nd: int = t.get("doors", 0)
	if nd == 0:
		return
	var ra := wr + 0.06
	var u_front_arch_rear := u_of(axles_z[0] + ra) - 0.012
	var u_rear_arch_front := u_of(axles_z[axles_z.size() - 1] - ra) + 0.012
	var ranges: Array = []
	if t.get("front_doors", false):
		var ua := u_front_arch_rear
		ranges.append(Vector2(ua - 1.05 / L, ua))
	else:
		var u_hi: float = min(u_front_arch_rear, float(t["cab_f"]) - 0.01)
		var u_lo: float = max(u_rear_arch_front, float(t["cab_r"]) + 0.01)
		if nd == 4:
			var pil: Array = t.get("pillars", [0.5])
			var pu: float = lerp(float(t["roof_r"]), float(t["roof_f"]), pil[0] if pil.size() > 0 else 0.5)
			pu = clamp(pu, u_lo + 0.08, u_hi - 0.08)
			ranges.append(Vector2(pu + 0.004, u_hi))
			ranges.append(Vector2(u_lo, pu - 0.004))
		else:
			ranges.append(Vector2(u_lo, u_hi))
	var door_mat: Material = paint2_mat if spec.get("extra", "") == "police" else paint_mat
	var di := 0
	for rg in ranges:
		for s in [-1, 1]:
			var rows := 7
			var cols := 5
			var grid: Array = []
			var nrm: Array = []
			for r in rows:
				# ряд 0 — передняя кромка (петля)
				var u: float = lerp(rg.y, rg.x, float(r) / (rows - 1))
				var sec := section(u)
				var ylo: float = sec["y0"] + 0.05
				var yhi: float = min(float(sec["y1s"]) - float(sec["rt"]) * 0.4, belt(u) - 0.01)
				var row: Array = []
				var nrow: Array = []
				for c in cols:
					var y: float = lerp(ylo, yhi, float(c) / (cols - 1))
					row.append(Vector3(s * (side_x(sec, y) + 0.008), y, z_of(u)))
					nrow.append(Vector3(s, 0, 0))
				grid.append(row)
				nrm.append(nrow)
			var pivot: Vector3 = grid[0][cols / 2]
			var names := ["fl", "fr", "rl", "rr"]
			var nm: String = names[di * 2 + (0 if s < 0 else 1)]
			var p := _panel_part("door_" + nm, "door", grid, nrm, 0.035, pivot, door_mat)
			p.mass = 22.0
			p.hinged = true
			p.hinge_axis = Vector3.UP
			p.hinge_sign = float(s)
			p.hinge_max = 1.25
			p.loosen_at = 0.09
			p.detach_at = 0.36
			p.side = s
			p.front = di == 0
			parts.append(p)
		di += 1


func _build_bumper(front: bool) -> void:
	var sec := section(0.985 if front else 0.015)
	var y0: float = sec["y0"] - 0.02
	var bh: float = clamp((float(sec["y1c"]) - y0) * 0.45, 0.12, 0.3)
	if spec["body"] in ["bus", "truck"]:
		bh = 0.35
	var hw := W * 0.5 - 0.03
	var path := PackedVector3Array()
	var n := 16
	for i in n + 1:
		var x: float = lerp(hw, -hw, float(i) / n) if front else lerp(-hw, hw, float(i) / n)
		path.append(Vector3(x, 0, outline_z(x, front)))
	var prof := PackedVector2Array([
		Vector2(-0.12, 0), Vector2(0.01, 0), Vector2(0.035, 0.03), Vector2(0.045, bh * 0.5),
		Vector2(0.035, bh - 0.03), Vector2(0.01, bh), Vector2(-0.12, bh),
	])
	var rings: Array = []
	var v := PackedVector3Array()
	var idx := PackedInt32Array()
	var pn := prof.size()
	for i in path.size():
		var tng: Vector3
		if i == 0:
			tng = path[1] - path[0]
		elif i == path.size() - 1:
			tng = path[i] - path[i - 1]
		else:
			tng = path[i + 1] - path[i - 1]
		tng = tng.normalized()
		var side := tng.cross(Vector3.UP).normalized()
		for pp in prof:
			v.append(path[i] + side * pp.x + Vector3(0, y0 + pp.y, 0))
	for i in path.size() - 1:
		for j in pn:
			var j2 := (j + 1) % pn
			var a := i * pn + j
			var b := i * pn + j2
			var c := (i + 1) * pn + j2
			var dd := (i + 1) * pn + j
			idx.append_array([a, b, c, a, c, dd])
	# торцы
	for e in [0, path.size() - 1]:
		var base: int = e * pn
		for j in range(1, pn - 1):
			idx.append_array([base, base + j, base + j + 1])
	idx = MeshUtil.fix_winding(v, idx)
	var mat: Material = CarMaterials.chrome() if spec.get("chrome", false) else (CarMaterials.plastic() if spec["body"] in ["suv3", "van", "truck", "pickup", "minivan"] else paint_mat)
	var p := CarPart.new()
	p.name = "bumper_f" if front else "bumper_r"
	p.kind = "bumper"
	p.deformable = true
	p.detachable = true
	p.mass = 8.0 if L < 6.0 else 40.0
	p.detach_at = 0.2
	p.front = front
	p.setup_mesh(v, [{"i": idx, "mat": mat}])
	parts.append(p)


# ---------------------------------------------------------------- мелкие детали

func _small_part(name: String, kind: String, mesh: Mesh, mat: Material, xf: Transform3D, detach: bool = false) -> CarPart:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = xf
	mi.name = name
	var p := CarPart.new()
	p.name = name
	p.kind = kind
	p.node = mi
	p.detachable = detach
	var ab := mesh.get_aabb()
	p.aabb = AABB(xf * ab.position, Vector3.ZERO).expand(xf * ab.end)
	p.mass = 1.5
	parts.append(p)
	return p


func _face_xf(x: float, y: float, front: bool, depth_off: float) -> Transform3D:
	var z := outline_z(x, front)
	var z2 := outline_z(x + 0.02 * signf(x + 1e-5), front)
	var slope: float = abs(z2 - z) / 0.02
	var yaw: float = atan(slope) * sign(x + 1e-5)
	var b := Basis(Vector3.UP, -yaw if front else yaw)
	var off := (-depth_off) if front else depth_off
	return Transform3D(b, Vector3(x, y, z + off))


func _build_lights() -> void:
	var round_l: bool = spec.get("round_lights", false)
	var sec_f := section(0.99)
	var sec_r := section(0.01)
	var hw := W * 0.5
	var pr: float = t["plan"] * hw
	var bump_top_f: float = sec_f["y0"] + clamp((float(sec_f["y1c"]) - float(sec_f["y0"])) * 0.45, 0.12, 0.3)
	var nose_y: float = sec_f["y1c"]
	var hy: float = clamp(nose_y - 0.09, bump_top_f + 0.06, nose_y - 0.03)
	var lx: float = clamp(hw - pr * 0.75 - 0.12, hw * 0.45, hw - 0.18)
	var head_mesh: Mesh
	if round_l:
		var cm := CylinderMesh.new()
		cm.top_radius = 0.085
		cm.bottom_radius = 0.085
		cm.height = 0.05
		cm.radial_segments = 12
		cm.rings = 1
		head_mesh = cm
	else:
		var bm := BoxMesh.new()
		bm.size = Vector3(0.3, 0.1, 0.05)
		head_mesh = bm
	var big: bool = spec["body"] in ["bus", "truck", "van"]
	for s in [-1, 1]:
		var xf := _face_xf(s * lx, hy, true, 0.01)
		if round_l:
			xf.basis = xf.basis * Basis(Vector3.RIGHT, PI * 0.5)
		if big:
			xf.basis = xf.basis.scaled(Vector3(1.2, 1.2, 1.2))
		var p := _small_part("head_" + ("l" if s < 0 else "r"), "light", head_mesh, head_mat, xf, true)
		p.light_type = "head"
		p.side = s
		p.front = true
	# решётка радиатора
	if not spec.get("ev", false) and spec.get("engine", "front") == "front":
		var gw: float = max(0.2, 2.0 * (lx - 0.2))
		var gm := BoxMesh.new()
		gm.size = Vector3(gw, 0.12, 0.04)
		var gxf := Transform3D(Basis.IDENTITY, Vector3(0, hy - 0.01, outline_z(0, true) - 0.005))
		_small_part("grille", "trim", gm, CarMaterials.chrome() if spec.get("chrome", false) else CarMaterials.plastic(), gxf)
	# задние фонари
	var tail_y: float = sec_r["y1c"] - 0.1
	var tm := BoxMesh.new()
	tm.size = Vector3(0.32 if not big else 0.25, 0.1, 0.05)
	var tx: float = clamp(hw - pr * 0.6 - 0.14, hw * 0.45, hw - 0.16)
	for s in [-1, 1]:
		var xf := _face_xf(s * tx, tail_y, false, 0.01)
		var p := _small_part("tail_" + ("l" if s < 0 else "r"), "light", tm, tail_mat, xf, true)
		p.light_type = "tail"
		p.side = s
		p.front = false
	# номера
	var plm := BoxMesh.new()
	plm.size = Vector3(0.52, 0.11, 0.02)
	var bf_y: float = sec_f["y0"] + 0.1
	_small_part("plate_f", "trim", plm, CarMaterials.plate(), Transform3D(Basis.IDENTITY, Vector3(0, bf_y, outline_z(0, true) - 0.05)), true)
	var br_y: float = max(float(sec_r["y0"]) + 0.12, tail_y - 0.2)
	_small_part("plate_r", "trim", plm, CarMaterials.plate(), Transform3D(Basis.IDENTITY, Vector3(0, br_y, outline_z(0, false) + 0.03)), true)


func _build_mirrors() -> void:
	var u: float = float(t["cab_f"]) - 0.02
	if t.get("front_doors", false):
		u = u_of(axles_z[0] + wr) - 0.02
	var sec := section(u)
	var y: float = belt(u) + 0.08
	var mm := BoxMesh.new()
	mm.size = Vector3(0.14, 0.11, 0.07) if L < 6.0 else Vector3(0.12, 0.35, 0.08)
	for s in [-1, 1]:
		var xf := Transform3D(Basis.IDENTITY, Vector3(s * (float(sec["hw"]) + 0.08), y, z_of(u)))
		var p := _small_part("mirror_" + ("l" if s < 0 else "r"), "mirror", mm, paint_mat, xf, true)
		p.side = s
		p.mass = 1.0


func _build_extras() -> void:
	var roof_y: float = H * t.get("roof_h", 1.0)
	var roof_u: float = (float(t["roof_r"]) + float(t["roof_f"])) * 0.5
	match spec.get("extra", ""):
		"police":
			var bm := BoxMesh.new()
			bm.size = Vector3(0.5, 0.1, 0.22)
			var red := CarMaterials.beacon(Color(1.0, 0.05, 0.05))
			var blue := CarMaterials.beacon(Color(0.1, 0.25, 1.0))
			var pl := _small_part("beacon_l", "beacon", bm, red, Transform3D(Basis.IDENTITY, Vector3(-0.27, roof_y + 0.07, z_of(roof_u))), true)
			var prr := _small_part("beacon_r", "beacon", bm, blue, Transform3D(Basis.IDENTITY, Vector3(0.27, roof_y + 0.07, z_of(roof_u))), true)
			pl.side = -1
			prr.side = 1
		"taxi":
			var tm := BoxMesh.new()
			tm.size = Vector3(0.55, 0.16, 0.16)
			var ym := CarMaterials.beacon(Color(1.0, 0.8, 0.2))
			_small_part("taxi_sign", "beacon", tm, ym, Transform3D(Basis.IDENTITY, Vector3(0, roof_y + 0.1, z_of(roof_u))), true)
	var sp: String = spec.get("spoiler", "")
	if sp != "":
		var u := 0.04
		var sec := section(u)
		var y: float = sec["y1c"]
		var wm := BoxMesh.new()
		var xf := Transform3D(Basis.IDENTITY, Vector3(0, y, z_of(u)))
		match sp:
			"wing":
				wm.size = Vector3(W * 0.82, 0.035, 0.26)
				xf.origin.y += 0.24
				var post := BoxMesh.new()
				post.size = Vector3(0.04, 0.24, 0.12)
				for s in [-1, 1]:
					_small_part("wing_post", "spoiler", post, CarMaterials.plastic(), Transform3D(Basis.IDENTITY, Vector3(s * W * 0.3, y + 0.12, z_of(u))), true)
			"ducktail":
				wm.size = Vector3(W * 0.7, 0.05, 0.22)
				xf.origin.y += 0.04
				xf.basis = Basis(Vector3.RIGHT, -0.15)
			_:
				wm.size = Vector3(W * 0.78, 0.03, 0.08)
				xf.origin.y += 0.015
		var p := _small_part("spoiler", "spoiler", wm, paint_mat, xf, true)
		p.mass = 5.0
	# выхлопная труба
	var em := CylinderMesh.new()
	em.top_radius = 0.035
	em.bottom_radius = 0.035
	em.height = 0.18
	em.radial_segments = 8
	var ex_x := W * 0.3
	var exf := Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(ex_x, clr + 0.07, outline_z(ex_x, false) - 0.03))
	_small_part("exhaust", "trim", em, CarMaterials.chrome(), exf, true)


func _build_bed() -> void:
	var u0 := 0.03
	var u1: float = float(t["cab_r"]) - 0.015
	var y := belt(0.2) - 0.05
	var z0 := z_of(u1)
	var z1 := z_of(u0)
	var hw := W * 0.5 - 0.1
	var d := MeshUtil.box(Vector3(hw * 2.0, 0.04, z1 - z0), Vector3(0, y, (z0 + z1) * 0.5), Vector3i(2, 1, 6))
	var v: PackedVector3Array = d["v"]
	var idx := MeshUtil.fix_winding(v, d["i"])
	var p := CarPart.new()
	p.name = "bed"
	p.kind = "trim"
	p.deformable = true
	p.setup_mesh(v, [{"i": idx, "mat": CarMaterials.chassis()}])
	parts.append(p)


func _build_cargo() -> void:
	var u1: float = float(t["cab_r"]) - 0.015
	var z0 := z_of(u1)
	var z1 := z_of(0.0) - 0.05
	var y0 := belt(0.3) - 0.05
	var y1 := H * 0.97
	var d := MeshUtil.box(Vector3(W - 0.04, y1 - y0, z1 - z0), Vector3(0, (y0 + y1) * 0.5, (z0 + z1) * 0.5), Vector3i(4, 5, 14))
	var v: PackedVector3Array = d["v"]
	var idx := MeshUtil.fix_winding(v, d["i"])
	var p := CarPart.new()
	p.name = "cargo"
	p.kind = "cargo"
	p.deformable = true
	p.max_deform = 1.2
	p.setup_mesh(v, [{"i": idx, "mat": paint2_mat}])
	var samples := PackedInt32Array()
	for k in range(0, v.size(), 3):
		samples.append(k)
	p.shape_samples = samples
	parts.append(p)


# ---------------------------------------------------------------- колёса

static var _tire_mesh: ArrayMesh
static var _rim_mesh: ArrayMesh


static func tire_mesh() -> ArrayMesh:
	if _tire_mesh == null:
		_tire_mesh = MeshUtil.simple_mesh(MeshUtil.cylinder_x(18, 0.28), CarMaterials.tire())
	return _tire_mesh


static func rim_mesh() -> ArrayMesh:
	if _rim_mesh == null:
		var d := MeshUtil.cylinder_x(14, 0.0)
		d = MeshUtil.transform(d, Transform3D(Basis.IDENTITY.scaled(Vector3(0.9, 0.66, 0.66)), Vector3(0.06, 0, 0)))
		d["c"] = PackedColorArray()
		for k in (d["v"] as PackedVector3Array).size():
			(d["c"] as PackedColorArray).append(Color.WHITE)
		# спицы
		for s in 5:
			var a := TAU * s / 5.0
			var sp := MeshUtil.box(Vector3(0.12, 0.62, 0.14), Vector3(0.52, 0.31, 0), Vector3i(1, 1, 1))
			sp = MeshUtil.transform(sp, Transform3D(Basis(Vector3.RIGHT, a), Vector3.ZERO))
			MeshUtil.append(d, sp)
		var hub := MeshUtil.transform(MeshUtil.cylinder_x(10, 0.0), Transform3D(Basis.IDENTITY.scaled(Vector3(0.14, 0.2, 0.2)), Vector3(0.55, 0, 0)))
		MeshUtil.append(d, hub)
		_rim_mesh = MeshUtil.simple_mesh(d, CarMaterials.rim())
	return _rim_mesh


func _build_wheels() -> Array:
	var wheels: Array = []
	var x_off := W * 0.5 - ww * 0.5 - (0.05 if L > 6.0 else 0.015)
	var rim_mat := CarMaterials.rim_dark() if spec["class"] == "Спорт" and randf() < 0.5 else CarMaterials.rim()
	for ai in axles_z.size():
		var z: float = axles_z[ai]
		for s in [-1, 1]:
			var pos := Vector3(s * x_off, wr, z)
			var pivot := Node3D.new()
			pivot.name = "wheel_%d_%d" % [ai, s]
			pivot.position = pos
			var spin := Node3D.new()
			spin.name = "spin"
			pivot.add_child(spin)
			var tire := MeshInstance3D.new()
			tire.mesh = tire_mesh()
			tire.scale = Vector3(ww * s, wr, wr)
			spin.add_child(tire)
			var rim := MeshInstance3D.new()
			rim.mesh = rim_mesh()
			rim.material_override = rim_mat
			rim.scale = Vector3(ww * s, wr, wr)
			spin.add_child(rim)
			var p := CarPart.new()
			p.name = pivot.name
			p.kind = "wheel"
			p.node = pivot
			p.detachable = true
			p.mass = 12.0 + wr * 40.0
			p.aabb = AABB(pos - Vector3(ww * 0.5, wr, wr), Vector3(ww, wr * 2.0, wr * 2.0))
			p.side = s
			p.front = ai == 0
			p.wheel_index = wheels.size()
			p.detach_at = 0.3
			parts.append(p)
			wheels.append({
				"pos": pos, "radius": wr, "width": ww, "side": s,
				"steer": ai == 0, "front": ai == 0, "part": p,
			})
	return wheels
