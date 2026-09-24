class_name MapDerby
extends MapBase

## Дерби-арена: грунтовая площадка, бетонные стены, трибуны, прожекторы.

const A := 72.0
const B := 48.0


func _init() -> void:
	map_id = "derby"


func build_map() -> void:
	flat_ground(1200.0, ground_mat(Color(0.42, 0.33, 0.22), Color(0.48, 0.38, 0.26), Color(0.35, 0.28, 0.2), 0.0, 0.95), 0.82, "dirt")
	# стена-эллипс
	var ring := PackedVector3Array()
	var n := 72
	for i in n:
		var a := TAU * i / n
		ring.append(Vector3(cos(a) * A, 0, sin(a) * B))
	var closed := ring.duplicate()
	closed.append(ring[0])
	var wall := PackedVector2Array([Vector2(-0.5, 0.0), Vector2(-0.2, 0.3), Vector2(-0.2, 1.4), Vector2(0.2, 1.4), Vector2(0.2, 0.3), Vector2(0.5, 0.0)])
	var d := RoadBuilder.sweep(closed, wall, 0.0, false, true)
	RoadBuilder.add_static(static_root, d, concrete_mat(), 1.0, "asphalt", true)
	# шины вдоль стены
	for i in range(0, n, 2):
		var a := TAU * (i + 0.5) / n
		var p := Vector3(cos(a) * (A - 1.4), 0, sin(a) * (B - 1.4))
		add_prop("tires", Transform3D(Basis.IDENTITY, p))
	# центральный холм и блоки
	var batch := BoxBatch.new()
	var sb := static_body(0.85, "dirt")
	ramp(batch, sb, Vector3(0, 0, 9), 0.0, 8.0, 1.3, 8.0)
	ramp(batch, sb, Vector3(0, 0, -9), PI, 8.0, 1.3, 8.0)
	for p in [Vector3(-35, 0.5, 0), Vector3(35, 0.5, 0), Vector3(0, 0.5, -30), Vector3(0, 0.5, 30)]:
		solid_box(batch, sb, Transform3D(Basis(Vector3.UP, rng.randf() * PI), p), Vector3(3.0, 1.0, 1.0), Color(0.9, 0.9, 0.88))
	# трибуны
	for side in [-1.0, 1.0]:
		for step in 6:
			var y := 1.0 + step * 0.9
			var z: float = side * (B + 6.0 + step * 1.5)
			batch.add(Transform3D(Basis.IDENTITY, Vector3(0, y * 0.5, z)), Vector3(110.0 - step * 6.0, y, 1.5), Color(0.55, 0.57, 0.6))
	static_root.add_child(batch.build(concrete_mat()))
	# прожекторы
	for p in [Vector3(-A - 6, 0, -B - 6), Vector3(A + 6, 0, -B - 6), Vector3(-A - 6, 0, B + 6), Vector3(A + 6, 0, B + 6)]:
		var pole := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.6, 22.0, 0.6)
		pole.mesh = bm
		pole.position = p + Vector3.UP * 11.0
		pole.material_override = metal_mat()
		static_root.add_child(pole)
		var head := MeshInstance3D.new()
		var hm := BoxMesh.new()
		hm.size = Vector3(3.0, 1.5, 0.5)
		head.mesh = hm
		head.position = p + Vector3.UP * 22.5
		var em := StandardMaterial3D.new()
		em.albedo_color = Color(1, 0.95, 0.85)
		em.emission_enabled = true
		em.emission = Color(1, 0.95, 0.85)
		em.emission_energy_multiplier = 6.0 if night else 0.5
		head.material_override = em
		static_root.add_child(head)
		if night and int(Settings.get_v("quality_level")) >= 1:
			var l := OmniLight3D.new()
			l.position = p * 0.8 + Vector3.UP * 20.0
			l.omni_range = 110.0
			l.light_energy = 2.2
			l.light_color = Color(1.0, 0.93, 0.8)
			l.shadow_enabled = false
			static_root.add_child(l)
	var trees: Array = []
	for i in int(300 * float(Settings.get_v("vegetation"))):
		var a := rng.randf() * TAU
		var r := rng.randf_range(1.6, 4.0)
		trees.append(Vector3(cos(a) * A * r, 0, sin(a) * B * r))
	add_trees(trees, func(_p: Vector3): return false)
	# точки старта по кругу, лицом к центру
	for i in 9:
		var a := TAU * i / 9.0 + 0.35
		var p := Vector3(cos(a) * (A - 12.0), 0.1, sin(a) * (B - 10.0))
		spawns.append(Transform3D(Basis.looking_at(-p.normalized(), Vector3.UP), p))
