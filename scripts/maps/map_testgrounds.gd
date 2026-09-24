class_name MapTestGrounds
extends MapBase

## Краш-полигон: бетонная площадка с объектами для экспериментов.

const PAD := 460.0


func _init() -> void:
	map_id = "testgrounds"


func surface_at(p: Vector3, _c: Object) -> Vector2:
	if abs(p.x) > PAD or abs(p.z) > PAD:
		return Vector2(0.7, 1.0)
	return Vector2(-1.0, 0.0)


func build_map() -> void:
	flat_ground(PAD * 2.0, ground_mat(Color(0.33, 0.33, 0.32), Color(0.37, 0.36, 0.34), Color(0.28, 0.28, 0.27), 8.0, 0.85), 1.0, "asphalt")
	# трава вокруг площадки (только визуал — сцепление задаёт surface_at)
	var grass := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(4000, 4000)
	grass.mesh = pm
	grass.position.y = -0.03
	grass.material_override = ground_mat(Color(0.22, 0.35, 0.13), Color(0.3, 0.4, 0.16), Color(0.35, 0.3, 0.2))
	grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	static_root.add_child(grass)

	var batch := BoxBatch.new()
	var sb := static_body(1.0, "asphalt")
	var wall_col := Color(0.95, 0.95, 0.93)

	# стена для краш-тестов в конце разгонной полосы + отбойные шины
	solid_box(batch, sb, Transform3D(Basis.IDENTITY, Vector3(0, 2.0, -400)), Vector3(70, 4, 3), wall_col)
	# отбойник из шин — по краям стены (центр оставлен для чистого краш-теста)
	for x in range(-34, -12, 2):
		add_prop("tires", Transform3D(Basis.IDENTITY, Vector3(x, 0, -397.5)))
		add_prop("tires", Transform3D(Basis.IDENTITY, Vector3(-x, 0, -397.5)))
	# полосатая разметка разгонной полосы: столбики-конусы
	for z in range(-360, 200, 40):
		add_prop("cone", Transform3D(Basis.IDENTITY, Vector3(-9, 0, z)))
		add_prop("cone", Transform3D(Basis.IDENTITY, Vector3(9, 0, z)))
	# косая стена (удар под углом 30°)
	solid_box(batch, sb, Transform3D(Basis(Vector3.UP, deg_to_rad(30)), Vector3(90, 2.0, -330)), Vector3(40, 4, 2.5), wall_col)
	# бетонный столб (удар в столб — машина «обнимает» его)
	solid_box(batch, sb, Transform3D(Basis.IDENTITY, Vector3(-60, 2.5, -330)), Vector3(0.6, 5, 0.6), Color(0.7, 0.7, 0.68))
	# блоки-отбойники вдоль коридора
	for z in range(-300, -120, 4):
		solid_box(batch, sb, Transform3D(Basis.IDENTITY, Vector3(-140, 0.45, z)), Vector3(0.6, 0.9, 3.6), Color(0.85, 0.85, 0.82))
		solid_box(batch, sb, Transform3D(Basis.IDENTITY, Vector3(-126, 0.45, z)), Vector3(0.6, 0.9, 3.6), Color(0.85, 0.85, 0.82))

	# трамплины
	ramp(batch, sb, Vector3(-60, 0, 60), 0.0, 12.0, 1.6, 6.0)
	ramp(batch, sb, Vector3(-100, 0, 180), 0.0, 24.0, 4.5, 8.0)
	# посадочная горка после большого трамплина
	ramp(batch, sb, Vector3(-100, 0, 80), PI, 30.0, 3.5, 10.0)
	# узкая рампа под одну сторону — для переворотов
	ramp(batch, sb, Vector3(62, 0, 120), 0.0, 9.0, 1.4, 1.3)
	# «горбы»
	for i in 6:
		ramp(batch, sb, Vector3(170, 0, 160 - i * 18), 0.0, 3.0, 0.35, 7.0)
		ramp(batch, sb, Vector3(170, 0, 160 - i * 18 - 6.0), PI, 3.0, 0.35, 7.0)

	# ряд фонарей (срезаются при ударе)
	for z in range(-250, 251, 25):
		add_prop("lamp", Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-30, 0, z)))
	# слалом
	for i in 14:
		add_prop("cone", Transform3D(Basis.IDENTITY, Vector3(30 + (i % 2) * 2.0, 0, 150 - i * 14)))
	# пирамида бочек и ящиков
	for row in 4:
		for k in 4 - row:
			add_prop("barrel", Transform3D(Basis.IDENTITY, Vector3(48 + k * 0.65 + row * 0.33, row * 0.92, -60)))
	for k in 6:
		add_prop("crate", Transform3D(Basis.IDENTITY, Vector3(60 + (k % 3) * 0.95, (k / 3) * 0.92, -90)))
	# водоналивные барьеры поперёк полосы
	for x in range(-10, 11, 2):
		add_prop("water_barrier", Transform3D(Basis.IDENTITY, Vector3(x, 0, -220)))
	# знаки
	for i in 6:
		add_prop("sign", Transform3D(Basis.IDENTITY, Vector3(-18, 0, 60 - i * 30)))

	# парковка машин для тарана
	var ids := ["vostok_2107", "hayato_crona", "gazel", "nordhaus_240", "liberty_cab", "minima", "hayato_landmaster", "volna_24"]
	for i in ids.size():
		add_parked_car(ids[i], Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(120, 0.05, -40 + i * 8.0)))
	# автобус поперёк — мишень
	add_parked_car("citybus", Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, 0.05, -150)))

	# ангары и вышки по краям — для масштаба
	for i in 5:
		var x := -300.0 + i * 150.0
		solid_box(batch, sb, Transform3D(Basis.IDENTITY, Vector3(x, 7, -470)), Vector3(60, 14, 30), Color(0.55, 0.58, 0.62))
	for i in 4:
		solid_box(batch, sb, Transform3D(Basis.IDENTITY, Vector3(470, 10, -300 + i * 200)), Vector3(8, 20, 8), Color(0.7, 0.3, 0.2))

	var mi := batch.build(concrete_mat())
	static_root.add_child(mi)

	# деревья за площадкой
	var pts: Array = []
	var n := int(500 * float(Settings.get_v("vegetation")))
	for i in n:
		var a := rng.randf() * TAU
		var r := rng.randf_range(PAD + 30.0, PAD + 350.0)
		pts.append(Vector3(cos(a) * r, 0, sin(a) * r))
	add_trees(pts, func(p: Vector3): return p.length() < PAD + 80.0)

	spawns.append(Transform3D(Basis.IDENTITY, Vector3(0, 0.1, 240)))
	spawns.append(Transform3D(Basis.IDENTITY, Vector3(-100, 0.1, 230)))
