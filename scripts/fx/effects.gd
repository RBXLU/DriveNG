class_name Effects
extends Node3D

## Частицы на MultiMesh (один draw call на тип) и следы шин.
## Все частицы симулируются на CPU простыми массивами — дёшево и предсказуемо
## для слабых устройств; бюджет задаётся настройкой «Частицы».

class Pool:
	var mmi: MultiMeshInstance3D
	var mm: MultiMesh
	var cap := 0
	var n := 0
	var pos := PackedVector3Array()
	var vel := PackedVector3Array()
	var life := PackedFloat32Array()
	var max_life := PackedFloat32Array()
	var size0 := PackedFloat32Array()
	var size1 := PackedFloat32Array()
	var col := PackedColorArray()
	var gravity := -9.8
	var drag := 0.5
	var fade_in := 0.0
	var buf := PackedFloat32Array()

	func _init(p_cap: int) -> void:
		cap = p_cap
		pos.resize(cap)
		vel.resize(cap)
		life.resize(cap)
		max_life.resize(cap)
		size0.resize(cap)
		size1.resize(cap)
		col.resize(cap)
		buf.resize(cap * 16)

	func spawn(p: Vector3, v: Vector3, l: float, s0: float, s1: float, c: Color) -> void:
		var i := n
		if n >= cap:
			# перезаписываем самую старую (ближе всего к смерти) — просто случайную
			i = randi() % cap
		else:
			n += 1
		pos[i] = p
		vel[i] = v
		life[i] = l
		max_life[i] = l
		size0[i] = s0
		size1[i] = s1
		col[i] = c

	func update(dt: float) -> void:
		var i := 0
		var g := Vector3(0, gravity * dt, 0)
		var dk: float = max(0.0, 1.0 - drag * dt)
		while i < n:
			var l := life[i] - dt
			if l <= 0.0:
				n -= 1
				pos[i] = pos[n]
				vel[i] = vel[n]
				life[i] = life[n]
				max_life[i] = max_life[n]
				size0[i] = size0[n]
				size1[i] = size1[n]
				col[i] = col[n]
				continue
			life[i] = l
			var v := vel[i] * dk + g
			vel[i] = v
			var p := pos[i] + v * dt
			if p.y < 0.02 and gravity < -1.0 and Game.map == null:
				p.y = 0.02
			pos[i] = p
			var t := 1.0 - l / max_life[i]
			var s: float = lerp(size0[i], size1[i], t)
			var c := col[i]
			var a := c.a * (1.0 - t * t)
			if fade_in > 0.0:
				a *= clamp(t / fade_in, 0.0, 1.0)
			var o := i * 16
			buf[o] = s
			buf[o + 1] = 0.0
			buf[o + 2] = 0.0
			buf[o + 3] = p.x
			buf[o + 4] = 0.0
			buf[o + 5] = s
			buf[o + 6] = 0.0
			buf[o + 7] = p.y
			buf[o + 8] = 0.0
			buf[o + 9] = 0.0
			buf[o + 10] = s
			buf[o + 11] = p.z
			buf[o + 12] = c.r
			buf[o + 13] = c.g
			buf[o + 14] = c.b
			buf[o + 15] = a
			i += 1
		mm.visible_instance_count = n
		if n > 0:
			mm.buffer = buf


var sparks_pool: Pool
var glass_pool: Pool
var smoke_pool: Pool
var fire_pool: Pool
var budget := 1.0
var _soft_tex: GradientTexture2D

# следы шин
var skid_mm: MultiMesh
var skid_idx := 0
var skid_cap := 1200
var _skid_last := {}


func _ready() -> void:
	var q: int = int(Settings.get_v("particles"))
	budget = [0.35, 0.7, 1.0][clampi(q, 0, 2)]
	_soft_tex = GradientTexture2D.new()
	var gr := Gradient.new()
	gr.set_color(0, Color(1, 1, 1, 1))
	gr.set_color(1, Color(1, 1, 1, 0))
	gr.add_point(0.45, Color(1, 1, 1, 0.55))
	_soft_tex.gradient = gr
	_soft_tex.fill = GradientTexture2D.FILL_RADIAL
	_soft_tex.fill_from = Vector2(0.5, 0.5)
	_soft_tex.fill_to = Vector2(1.0, 0.5)
	_soft_tex.width = 64
	_soft_tex.height = 64

	sparks_pool = _make_pool(int(260 * budget) + 40, true, true)
	sparks_pool.gravity = -9.8
	sparks_pool.drag = 0.6
	glass_pool = _make_pool(int(260 * budget) + 30, false, false)
	glass_pool.gravity = -9.8
	glass_pool.drag = 0.3
	smoke_pool = _make_pool(int(220 * budget) + 30, false, true)
	smoke_pool.gravity = 0.9
	smoke_pool.drag = 1.2
	smoke_pool.fade_in = 0.15
	fire_pool = _make_pool(int(120 * budget) + 20, true, true)
	fire_pool.gravity = 3.5
	fire_pool.drag = 1.5
	_setup_skids()


func _make_pool(cap: int, additive: bool, soft: bool) -> Pool:
	var p := Pool.new(cap)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.instance_count = cap
	mm.visible_instance_count = 0
	var qm := QuadMesh.new()
	qm.size = Vector2(1, 1)
	mm.mesh = qm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = false
	mat.disable_receive_shadows = true
	if soft:
		mat.albedo_texture = _soft_tex
	if additive:
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.albedo_color = Color(2.5, 2.5, 2.5)
	qm.material = mat
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-5000, -500, -5000), Vector3(10000, 2000, 10000))
	add_child(mmi)
	p.mm = mm
	p.mmi = mmi
	return p


func _process(delta: float) -> void:
	sparks_pool.update(delta)
	glass_pool.update(delta)
	smoke_pool.update(delta)
	fire_pool.update(delta)


# ---------------------------------------------------------------- эмиттеры

func sparks(p: Vector3, base_vel: Vector3, intensity: float) -> void:
	var cnt := int(ceil(6.0 * intensity * budget))
	for i in cnt:
		var v := base_vel + Vector3(randf_range(-1, 1), randf_range(0.2, 1.4), randf_range(-1, 1)) * (3.0 + 5.0 * intensity)
		var c := Color(1.0, randf_range(0.55, 0.8), 0.25, 1.0)
		sparks_pool.spawn(p, v, randf_range(0.2, 0.55), 0.06, 0.02, c)


func impact_burst(p: Vector3, base_vel: Vector3, strength: float) -> void:
	var cnt := int(clamp(strength * 1.6, 4.0, 40.0) * budget)
	for i in cnt:
		var v := base_vel * 0.5 + Vector3(randf_range(-1, 1), randf_range(0.0, 1.5), randf_range(-1, 1)) * (2.0 + strength * 0.5)
		sparks_pool.spawn(p, v, randf_range(0.2, 0.7), 0.07, 0.02, Color(1.0, randf_range(0.5, 0.85), 0.3))
	# облачко пыли/краски
	var dcnt := int(clamp(strength * 0.4, 1.0, 8.0) * budget)
	for i in dcnt:
		smoke_pool.spawn(p + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3)), base_vel * 0.3 + Vector3(randf_range(-1, 1), 0.6, randf_range(-1, 1)), randf_range(0.8, 1.6), 0.5, 2.2, Color(0.55, 0.53, 0.5, 0.35))


func glass(p: Vector3, base_vel: Vector3, count: int, red: bool) -> void:
	var cnt := int(count * budget) + 2
	for i in cnt:
		var v := base_vel * 0.8 + Vector3(randf_range(-1, 1), randf_range(0.3, 2.0), randf_range(-1, 1)) * 2.5
		var c := Color(0.9, 0.15, 0.1, 0.95) if red else Color(0.8, 0.9, 0.95, 0.85)
		glass_pool.spawn(p + Vector3(randf_range(-0.3, 0.3), randf_range(-0.1, 0.2), randf_range(-0.3, 0.3)), v, randf_range(0.6, 1.4), randf_range(0.02, 0.05), 0.03, c)


func smoke(p: Vector3, base_vel: Vector3, color: Color, size: float) -> void:
	if randf() > budget + 0.2:
		return
	var c := color
	c.a = 0.45 if color.v < 0.5 else 0.3
	smoke_pool.spawn(p + Vector3(randf_range(-0.2, 0.2), 0, randf_range(-0.2, 0.2)), base_vel * 0.5 + Vector3(randf_range(-0.3, 0.3), 0.8, randf_range(-0.3, 0.3)), randf_range(1.5, 2.8), 0.4 * size, 2.4 * size, c)


func tire_smoke(p: Vector3, base_vel: Vector3, amount: float, dirt: bool) -> void:
	if randf() > budget * amount:
		return
	var c := Color(0.55, 0.45, 0.33, 0.35) if dirt else Color(0.9, 0.9, 0.92, 0.28)
	smoke_pool.spawn(p + Vector3(0, 0.15, 0), base_vel * 0.2 + Vector3(randf_range(-0.5, 0.5), 0.5, randf_range(-0.5, 0.5)), randf_range(1.0, 2.2), 0.5, 2.6, c)


func fire(p: Vector3, base_vel: Vector3) -> void:
	var cnt := int(3 * budget) + 1
	for i in cnt:
		var c := Color(1.0, randf_range(0.35, 0.6), 0.1, 0.9)
		fire_pool.spawn(p + Vector3(randf_range(-0.35, 0.35), 0, randf_range(-0.35, 0.35)), base_vel * 0.3 + Vector3(randf_range(-0.3, 0.3), 1.5, randf_range(-0.3, 0.3)), randf_range(0.35, 0.7), 0.7, 0.2, c)


# ---------------------------------------------------------------- следы шин

func _setup_skids() -> void:
	skid_cap = int(600 + 1400 * budget)
	skid_mm = MultiMesh.new()
	skid_mm.transform_format = MultiMesh.TRANSFORM_3D
	skid_mm.use_colors = true
	skid_mm.instance_count = skid_cap
	var pm := PlaneMesh.new()
	pm.size = Vector2(1, 1)
	skid_mm.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.02, 0.02, 0.02)
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.95
	mat.render_priority = -1
	pm.material = mat
	for i in skid_cap:
		skid_mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), Vector3(0, -1000, 0)))
		skid_mm.set_instance_color(i, Color(0.03, 0.03, 0.03, 0.0))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = skid_mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-5000, -500, -5000), Vector3(10000, 2000, 10000))
	add_child(mmi)


## Добавляет сегмент следа от последней точки колеса key до p
func skid(key: int, p: Vector3, normal: Vector3, width: float, strength: float, dirt: bool) -> void:
	if not _skid_last.has(key):
		_skid_last[key] = p
		return
	var last: Vector3 = _skid_last[key]
	var seg := p - last
	var l := seg.length()
	if l < 0.25:
		return
	_skid_last[key] = p
	if l > 3.0:
		return
	var z := seg / l
	var x := normal.cross(z).normalized()
	var b := Basis(x * width, normal, z * (l + 0.05))
	var xf := Transform3D(b, (p + last) * 0.5 + normal * 0.025)
	skid_mm.set_instance_transform(skid_idx, xf)
	var c := Color(0.25, 0.2, 0.15, 0.55 * strength) if dirt else Color(0.02, 0.02, 0.02, clamp(0.35 + 0.4 * strength, 0.0, 0.8))
	skid_mm.set_instance_color(skid_idx, c)
	skid_idx = (skid_idx + 1) % skid_cap


func skid_break(key: int) -> void:
	_skid_last.erase(key)
