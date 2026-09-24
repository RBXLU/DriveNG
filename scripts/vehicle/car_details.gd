class_name CarDetails
extends RefCounted

## Мелкая детализация машины. Всё объединяется в несколько деформируемых мешей
## по материалам (краска / тёмный пластик / хром / салон) — это 3–4 draw call
## на машину вместо десятков, а вмятины применяются и к деталям тоже.
## На дальности детали скрываются (visibility range) — силуэт при этом не меняется.

var b: CarBuilder
var buckets := {}
var chrome := false
var q := 2


func _init(builder: CarBuilder) -> void:
	b = builder
	chrome = b.spec.get("chrome", false)
	q = b.detail


func _bucket(key: String) -> Dictionary:
	if not buckets.has(key):
		buckets[key] = MeshUtil.empty()
	return buckets[key]


func _add(key: String, d: Dictionary, c: Color = Color.WHITE) -> void:
	MeshUtil.add(_bucket(key), d, c)


func _dark() -> Color:
	return Color(0.05, 0.05, 0.055)


func build() -> void:
	if q >= 1:
		_arches()
		_skirts()
		_moldings()
		_grille()
		_headlight_bezels()
		_wipers()
		_exhausts()
		_type_specific()
	else:
		_grille()
		_exhausts()
	if q >= 2:
		_roof()
		_spare()
	if q >= 3:
		_interior()
	_finish()


func _finish() -> void:
	var mats := {
		"paint": b.paint_mat,
		"paint2": b.paint2_mat,
		"dark": CarMaterials.trim(),
		"chrome": CarMaterials.trim_chrome(),
		"interior": CarMaterials.interior(),
	}
	var ranges := {"paint": 160.0, "paint2": 160.0, "dark": 130.0, "chrome": 90.0, "interior": 40.0}
	for key in buckets:
		var d: Dictionary = buckets[key]
		var v: PackedVector3Array = d["v"]
		if v.is_empty():
			continue
		var p := CarPart.new()
		p.name = "trim_" + key
		p.kind = "trim"
		p.deformable = true
		p.max_deform = 1.0
		p.setup_mesh(v, [{"i": d["i"], "mat": mats[key]}], d["c"])
		(p.node as GeometryInstance3D).visibility_range_end = ranges[key]
		(p.node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		b.parts.append(p)


# ---------------------------------------------------------------- кузовные детали

## Расширители колёсных арок
func _arches() -> void:
	if b.spec["body"] == "bus":
		return
	var offroad: bool = b.spec["body"] in ["suv", "suv3", "pickup", "van", "minivan", "truck"]
	var key := "dark" if offroad else "paint"
	var ra := b.wr + 0.075
	var prof := PackedVector2Array([Vector2(-0.01, 0.0), Vector2(0.06, 0.0), Vector2(0.065, 0.02), Vector2(0.05, 0.035), Vector2(-0.01, 0.03)])
	if offroad:
		prof = PackedVector2Array([Vector2(-0.01, 0.0), Vector2(0.09, 0.0), Vector2(0.095, 0.03), Vector2(0.07, 0.05), Vector2(-0.01, 0.045)])
	for az in b.axles_z:
		for s in [-1.0, 1.0]:
			var pts := PackedVector3Array()
			var ax := PackedVector3Array()
			var bx := PackedVector3Array()
			var n := 14
			for k in n + 1:
				var ang: float = lerp(0.12, PI - 0.12, float(k) / n)
				var rd := Vector3(0, sin(ang), cos(ang))
				var p: Vector3 = Vector3(0, b.wr, az) + rd * ra
				var sec := b.section(b.u_of(p.z))
				p.x = s * (b.side_x(sec, p.y) + 0.004)
				pts.append(p)
				ax.append(rd)
				bx.append(Vector3(s, 0, 0))
			_add(key, MeshUtil.tube(pts, ax, bx, prof, true), _dark() if offroad else Color.WHITE)


## Накладки порогов между арками
func _skirts() -> void:
	if b.axles_z.size() < 2 or b.spec["body"] == "bus":
		return
	var ra := b.wr + 0.09
	var z0: float = b.axles_z[0] + ra
	var z1: float = b.axles_z[b.axles_z.size() - 1] - ra
	if b.axles_z.size() == 3:
		z1 = b.axles_z[1] - ra
	if z1 - z0 < 0.3:
		return
	var sec := b.section(b.u_of((z0 + z1) * 0.5))
	var y: float = float(sec["y0"]) + 0.045
	for s in [-1.0, 1.0]:
		var x: float = s * (float(sec["hw"]) - 0.005)
		_add("dark", MeshUtil.obox(Transform3D(Basis.IDENTITY, Vector3(x, y, (z0 + z1) * 0.5)), Vector3(0.035, 0.08, z1 - z0)), Color(0.07, 0.07, 0.075))


## Молдинг по нижней кромке окон
func _moldings() -> void:
	var cab_r: float = b.t["cab_r"]
	var cab_f: float = b.t["cab_f"]
	var u0 := cab_r + 0.012
	var u1 := cab_f - 0.012
	var n := 16
	var key := "chrome" if chrome else "dark"
	var col := Color(0.85, 0.86, 0.88) if chrome else Color(0.06, 0.06, 0.065)
	for s in [-1.0, 1.0]:
		var pts := PackedVector3Array()
		var ax := PackedVector3Array()
		var bx := PackedVector3Array()
		for k in n + 1:
			var u: float = lerp(u0, u1, float(k) / n)
			var sec := b.section(u)
			var hwb: float = float(sec["hw"]) - float(sec["tumble"]) - 0.02
			pts.append(Vector3(s * hwb, b.belt(u) + 0.006, b.z_of(u)))
			ax.append(Vector3(s, 0, 0))
			bx.append(Vector3.UP)
		_add(key, MeshUtil.tube(pts, ax, bx, MeshUtil.rect_profile(0.03, 0.022), true), col)


## Решётка радиатора: рамка, ламели, эмблема
func _grille() -> void:
	var ev: bool = b.spec.get("ev", false)
	var front_engine: bool = b.spec.get("engine", "front") == "front"
	var sec := b.section(0.99)
	var nose_y: float = sec["y1c"]
	var bump_top: float = float(sec["y0"]) + clamp((nose_y - float(sec["y0"])) * 0.45, 0.12, 0.3)
	var hy: float = clamp(nose_y - 0.1, bump_top + 0.05, nose_y - 0.04)
	var z := b.outline_z(0.0, true) - 0.006
	var hw := b.W * 0.5
	var pr: float = b.t["plan"] * hw
	var lx: float = clamp(hw - pr * 0.75 - 0.12, hw * 0.45, hw - 0.18)
	var big: bool = b.spec["body"] in ["bus", "truck", "van"]
	var gw: float = max(0.25, 2.0 * (lx - 0.22))
	var gh := 0.13
	if big:
		gw = b.W * 0.55
		gh = 0.35
		hy = bump_top + 0.3
	var frame_key := "chrome" if chrome else "dark"
	var frame_col := Color(0.85, 0.86, 0.88) if chrome else Color(0.08, 0.08, 0.085)
	if front_engine and not ev:
		# рамка
		_add(frame_key, MeshUtil.obox(Transform3D(Basis.IDENTITY, Vector3(0, hy + gh * 0.5, z)), Vector3(gw, 0.02, 0.03)), frame_col)
		_add(frame_key, MeshUtil.obox(Transform3D(Basis.IDENTITY, Vector3(0, hy - gh * 0.5, z)), Vector3(gw, 0.02, 0.03)), frame_col)
		_add(frame_key, MeshUtil.obox(Transform3D(Basis.IDENTITY, Vector3(-gw * 0.5, hy, z)), Vector3(0.02, gh, 0.03)), frame_col)
		_add(frame_key, MeshUtil.obox(Transform3D(Basis.IDENTITY, Vector3(gw * 0.5, hy, z)), Vector3(0.02, gh, 0.03)), frame_col)
		# фон и ламели
		_add("dark", MeshUtil.obox(Transform3D(Basis.IDENTITY, Vector3(0, hy, z + 0.012)), Vector3(gw, gh, 0.01)), Color(0.03, 0.03, 0.035))
		var nsl := 4 if not big else 7
		for k in nsl:
			var yy := hy - gh * 0.5 + gh * (k + 0.5) / nsl
			_add(frame_key, MeshUtil.obox(Transform3D(Basis.IDENTITY, Vector3(0, yy, z - 0.004)), Vector3(gw - 0.03, 0.01, 0.015)), frame_col.darkened(0.15))
	# эмблема
	var ey := hy + (0.0 if front_engine and not ev else gh * 0.1)
	_add("chrome", MeshUtil.ocyl(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, ey, z - 0.012)), 0.035, 0.012, 10), Color(0.9, 0.9, 0.92))
	if not front_engine or ev:
		# «пустая» морда: только эмблема и тонкая планка
		_add("dark", MeshUtil.obox(Transform3D(Basis.IDENTITY, Vector3(0, hy - 0.04, z)), Vector3(gw * 0.8, 0.012, 0.012)), Color(0.08, 0.08, 0.085))


## Корпуса фар (рамка вокруг линзы)
func _headlight_bezels() -> void:
	for p in b.parts:
		if p.kind != "light":
			continue
		var xf: Transform3D = p.node.transform
		var ab := (p.node as MeshInstance3D).mesh.get_aabb()
		var sz := ab.size + Vector3(0.03, 0.03, 0.0)
		sz.z = 0.03
		var back := 1.0 if p.front else -1.0
		var c := xf * (ab.get_center() + Vector3(0, 0, 0.022 * back))
		_add("chrome" if chrome else "dark", MeshUtil.obox(Transform3D(xf.basis.orthonormalized(), c), sz), Color(0.7, 0.72, 0.75) if chrome else Color(0.12, 0.12, 0.13))


## Дворники у основания лобового стекла
func _wipers() -> void:
	var cab_f: float = b.t["cab_f"]
	var u := cab_f - 0.015
	var y := b.belt(u) + 0.02
	var z := b.z_of(u)
	var len := b.W * 0.36
	for s in [-1.0, 1.0]:
		var bas := Basis(Vector3.BACK, 0.06) * Basis(Vector3.UP, 0.12 * s)
		_add("dark", MeshUtil.obox(Transform3D(bas, Vector3(s * b.W * 0.2 - 0.05, y, z + 0.03)), Vector3(len, 0.015, 0.02)), Color(0.04, 0.04, 0.045))


func _exhausts() -> void:
	var body: String = b.spec["body"]
	if b.spec.get("ev", false) or body == "truck":
		return
	var sport: bool = b.spec["class"] == "Спорт" or body == "muscle"
	var y := b.clr + 0.08
	var xs: Array = [b.W * 0.3]
	if sport:
		xs = [-b.W * 0.32, -b.W * 0.24, b.W * 0.24, b.W * 0.32] if b.spec["hp"] > 500 else [-b.W * 0.3, b.W * 0.3]
	if body == "bus":
		xs = [-b.W * 0.35]
	for x in xs:
		var z: float = b.outline_z(x, false) - 0.05
		var r := 0.045 if sport else 0.03
		_add("chrome", MeshUtil.ocyl(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(x, y, z)), r, 0.22, 10), Color(0.8, 0.8, 0.82))
		_add("dark", MeshUtil.ocyl(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(x, y, z + 0.112)), r * 0.7, 0.01, 10), Color(0.02, 0.02, 0.02))


# ---------------------------------------------------------------- крыша и запаска

func _roof() -> void:
	var body: String = b.spec["body"]
	var roof_y: float = b.H * b.t.get("roof_h", 1.0)
	var roof_r: float = b.t["roof_r"]
	var roof_f: float = b.t["roof_f"]
	if body in ["suv", "suv3", "wagon", "minivan"]:
		# рейлинги
		var u0 := roof_r + 0.02
		var u1 := roof_f - 0.02
		var sec := b.section((u0 + u1) * 0.5)
		var hwr: float = (float(sec["hw"]) - float(sec["tumble"])) * float(b.t["roof_w"]) * 0.78
		var key := "chrome" if body == "suv" else "dark"
		var col := Color(0.75, 0.76, 0.78) if body == "suv" else Color(0.08, 0.08, 0.085)
		for s in [-1.0, 1.0]:
			var z0 := b.z_of(u0)
			var z1 := b.z_of(u1)
			_add(key, MeshUtil.obox(Transform3D(Basis.IDENTITY, Vector3(s * hwr, roof_y + 0.08, (z0 + z1) * 0.5)), Vector3(0.035, 0.03, abs(z1 - z0))), col)
			for k in 3:
				var zz: float = lerp(z0, z1, k / 2.0)
				_add(key, MeshUtil.obox(Transform3D(Basis.IDENTITY, Vector3(s * hwr, roof_y + 0.04, zz)), Vector3(0.04, 0.07, 0.06)), col)
	# антенна
	if not body in ["bus", "truck"]:
		var u := roof_r + 0.02 if not b.spec.get("boxy", false) else 0.9
		var sec2 := b.section(u)
		var ay: float = roof_y if not b.spec.get("boxy", false) else float(sec2["y1s"])
		var ax: float = 0.0 if not b.spec.get("boxy", false) else float(sec2["hw"]) - 0.1
		if b.spec.get("boxy", false):
			_add("chrome", MeshUtil.obox(Transform3D(Basis(Vector3.BACK, 0.08), Vector3(ax, ay + 0.35, b.z_of(u))), Vector3(0.008, 0.7, 0.008)), Color(0.85, 0.85, 0.87))
		else:
			# «плавник»
			_add("dark", MeshUtil.obox(Transform3D(Basis.IDENTITY, Vector3(0, ay + 0.03, b.z_of(u))), Vector3(0.05, 0.06, 0.16)), Color(0.06, 0.06, 0.07))


## Запасное колесо на задней двери (внедорожники и «буханка»)
func _spare() -> void:
	if not b.spec["body"] in ["suv3", "minivan"]:
		return
	var tail := b.section(0.01)
	var y: float = lerp(float(tail["y0"]), b.H * 0.75, 0.45)
	var z := b.outline_z(0.0, false) + b.ww * 0.5 + 0.02
	var node := Node3D.new()
	node.name = "spare"
	node.position = Vector3(0, y, z)
	node.rotation.y = PI * 0.5
	var tire := MeshInstance3D.new()
	tire.mesh = CarBuilder.tire_mesh()
	tire.scale = Vector3(b.ww, b.wr, b.wr)
	node.add_child(tire)
	var rim := MeshInstance3D.new()
	rim.mesh = CarBuilder.rim_mesh("steel")
	rim.material_override = CarMaterials.rim_steel()
	rim.scale = Vector3(b.ww, b.wr, b.wr)
	node.add_child(rim)
	var p := CarPart.new()
	p.name = "spare"
	p.kind = "spare"
	p.node = node
	p.detachable = true
	p.mass = 18.0
	p.aabb = AABB(Vector3(-b.wr, y - b.wr, z - b.ww * 0.5), Vector3(b.wr * 2.0, b.wr * 2.0, b.ww))
	b.parts.append(p)


# ---------------------------------------------------------------- особые модели

func _type_specific() -> void:
	match b.spec["body"]:
		"truck":
			_truck()
		"bus":
			_bus()
	if b.spec.get("extra", "") == "police":
		_push_bar()


func _truck() -> void:
	var W := b.W
	# топливные баки между осями
	var z0: float = b.axles_z[0] + b.wr + 0.35
	for s in [-1.0, 1.0]:
		_add("chrome", MeshUtil.ocyl(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(s * (W * 0.5 - 0.32), 0.78, z0 + 0.7)), 0.28, 1.1, 14), Color(0.8, 0.8, 0.82))
		# ступеньки кабины
		_add("dark", MeshUtil.obox(Transform3D(Basis.IDENTITY, Vector3(s * (W * 0.5 - 0.12), 0.55, b.axles_z[0] + b.wr + 0.12)), Vector3(0.25, 0.04, 0.35)), Color(0.1, 0.1, 0.1))
		# брызговики
		var zr: float = b.axles_z[b.axles_z.size() - 1] + b.wr + 0.12
		_add("dark", MeshUtil.obox(Transform3D(Basis.IDENTITY, Vector3(s * (W * 0.5 - b.ww * 0.5 - 0.05), 0.55, zr)), Vector3(b.ww + 0.1, 0.55, 0.02)), Color(0.05, 0.05, 0.05))
	# козырёк над лобовым стеклом
	var cf: float = b.t["cab_f"]
	_add("paint", MeshUtil.obox(Transform3D(Basis(Vector3.RIGHT, -0.25), Vector3(0, b.H * 0.9 + 0.02, b.z_of(cf) + 0.1)), Vector3(W * 0.9, 0.04, 0.35)))
	# рёбра фургона
	var cr: float = b.t["cab_r"]
	var zc0 := b.z_of(cr - 0.015)
	var zc1 := b.z_of(0.0) - 0.05
	var y0 := b.belt(0.3) - 0.05
	var y1 := b.H * 0.97
	var k := 0.0
	while zc0 + k < zc1:
		for s in [-1.0, 1.0]:
			_add("paint2", MeshUtil.obox(Transform3D(Basis.IDENTITY, Vector3(s * (W * 0.5 - 0.005), (y0 + y1) * 0.5, zc0 + k)), Vector3(0.03, y1 - y0, 0.06)), Color(0.85, 0.85, 0.85))
		k += 1.2


func _bus() -> void:
	var W := b.W
	var L := b.L
	var y0: float = b.clr + 0.15
	# двери на правом борту
	for dz in [-L * 0.5 + 1.2, -0.3, L * 0.5 - 2.4]:
		_add("dark", MeshUtil.obox(Transform3D(Basis.IDENTITY, Vector3(W * 0.5 + 0.012, y0 + 1.1, dz)), Vector3(0.02, 2.2, 1.25)), Color(0.08, 0.1, 0.12))
		_add("chrome", MeshUtil.obox(Transform3D(Basis.IDENTITY, Vector3(W * 0.5 + 0.02, y0 + 1.1, dz)), Vector3(0.012, 2.2, 0.03)), Color(0.8, 0.8, 0.82))
	# маршрутное табло
	var zf := b.outline_z(0.0, true) - 0.01
	_add("dark", MeshUtil.obox(Transform3D(Basis.IDENTITY, Vector3(0, b.H - 0.25, zf)), Vector3(W * 0.7, 0.28, 0.03)), Color(0.03, 0.03, 0.03))
	var lb := Label3D.new()
	lb.text = "25  ЦЕНТР"
	lb.font_size = 64
	lb.pixel_size = 0.004
	lb.modulate = Color(1.0, 0.6, 0.1)
	lb.shaded = false
	lb.position = Vector3(0, b.H - 0.25, zf - 0.02)
	lb.rotation.y = PI
	lb.visibility_range_end = 80.0
	b.model.add_child(lb)
	# решётка моторного отсека сзади
	var zr := b.outline_z(0.0, false) + 0.01
	for k in 6:
		_add("dark", MeshUtil.obox(Transform3D(Basis.IDENTITY, Vector3(0, 0.9 + k * 0.08, zr)), Vector3(W * 0.6, 0.03, 0.02)), Color(0.05, 0.05, 0.05))


func _push_bar() -> void:
	var sec := b.section(0.99)
	var z := b.outline_z(0.0, true) - 0.2
	var y0: float = float(sec["y0"]) + 0.05
	for x in [-0.28, 0.28]:
		_add("dark", MeshUtil.obox(Transform3D(Basis.IDENTITY, Vector3(x, y0 + 0.3, z)), Vector3(0.05, 0.6, 0.05)), Color(0.05, 0.05, 0.05))
	_add("dark", MeshUtil.obox(Transform3D(Basis.IDENTITY, Vector3(0, y0 + 0.5, z)), Vector3(0.75, 0.05, 0.05)), Color(0.05, 0.05, 0.05))
	_add("dark", MeshUtil.obox(Transform3D(Basis.IDENTITY, Vector3(0, y0 + 0.2, z)), Vector3(0.75, 0.05, 0.05)), Color(0.05, 0.05, 0.05))


# ---------------------------------------------------------------- салон

func _interior() -> void:
	var cab_r: float = b.t["cab_r"]
	var cab_f: float = b.t["cab_f"]
	var roof_r: float = b.t["roof_r"]
	var roof_f: float = b.t["roof_f"]
	var belt_y := b.belt((roof_r + roof_f) * 0.5)
	var floor_y: float = b.clr + 0.28
	var hw := b.W * 0.5 - 0.12
	var palette := [Color(0.12, 0.12, 0.13), Color(0.35, 0.3, 0.24), Color(0.4, 0.12, 0.1), Color(0.55, 0.5, 0.42)]
	var seat_c: Color = palette[abs(hash(b.spec["id"])) % palette.size()]
	var dash_c := Color(0.07, 0.07, 0.075)
	var zf := b.z_of(lerp(roof_f, cab_f, 0.35))
	var zr := b.z_of(roof_r)
	# торпедо
	_add("interior", MeshUtil.obox(Transform3D(Basis.IDENTITY, Vector3(0, belt_y - 0.08, zf + 0.12)), Vector3(hw * 2.0, 0.22, 0.4)), dash_c)
	# руль (левый)
	var sx := -hw * 0.48
	var sz := zf + 0.42
	var sy := belt_y + 0.02
	var pts := PackedVector3Array()
	var ax := PackedVector3Array()
	var bx := PackedVector3Array()
	var tilt := Basis(Vector3.RIGHT, -0.45)
	for k in 17:
		var ang := TAU * k / 16.0
		var rd := tilt * Vector3(cos(ang), sin(ang), 0)
		pts.append(Vector3(sx, sy, sz) + rd * 0.18)
		ax.append(rd)
		bx.append(tilt * Vector3(0, 0, 1))
	_add("interior", MeshUtil.tube(pts, ax, bx, MeshUtil.rect_profile(0.03, 0.03), false), Color(0.04, 0.04, 0.04))
	_add("interior", MeshUtil.obox(Transform3D(tilt, Vector3(sx, sy, sz)), Vector3(0.05, 0.3, 0.03)), Color(0.05, 0.05, 0.05))
	# сиденья: передние и задний диван
	var rows: Array = [lerp(zf, zr, 0.35)]
	if b.spec["body"] in ["bus"]:
		rows = []
		var zz := zf + 1.5
		while zz < b.L * 0.5 - 1.5:
			rows.append(zz)
			zz += 0.85
	elif abs(zr - zf) > 1.7 and int(b.t.get("doors", 2)) == 4:
		rows.append(lerp(zf, zr, 0.9))
	for ri in rows.size():
		var z: float = rows[ri] if typeof(rows[ri]) == TYPE_FLOAT else float(rows[ri])
		var bench: bool = ri > 0 and b.spec["body"] != "bus"
		var xs: Array = [0.0] if bench else [-hw * 0.48, hw * 0.48]
		var sw := hw * 1.8 if bench else hw * 0.72
		for x in xs:
			_add("interior", MeshUtil.obox(Transform3D(Basis.IDENTITY, Vector3(x, floor_y + 0.08, z)), Vector3(sw, 0.14, 0.5)), seat_c)
			_add("interior", MeshUtil.obox(Transform3D(Basis(Vector3.RIGHT, 0.2), Vector3(x, floor_y + 0.45, z + 0.28)), Vector3(sw, 0.62, 0.12)), seat_c)
			if not bench:
				_add("interior", MeshUtil.obox(Transform3D(Basis.IDENTITY, Vector3(x, floor_y + 0.86, z + 0.34)), Vector3(sw * 0.45, 0.16, 0.1)), seat_c.darkened(0.15))
	# тоннель
	if b.spec["body"] != "bus":
		_add("interior", MeshUtil.obox(Transform3D(Basis.IDENTITY, Vector3(0, floor_y + 0.1, zf + 0.7)), Vector3(0.22, 0.2, 0.8)), dash_c)
