class_name MapHighway
extends MapLoopRoad

## Шоссе: кольцевая трасса 3+3 полосы с разделителем среди холмов.

var noise := FastNoiseLite.new()


func _init() -> void:
	map_id = "highway"
	lanes_per_dir = 3
	lane_w = 3.6
	median_half = 1.4
	shoulder = 2.8
	lane_speeds = [23.0, 27.0, 31.0]
	terrain_size = 2800.0
	terrain_res = 201
	guard_all = true
	noise.seed = 7
	noise.frequency = 0.0016
	noise.fractal_octaves = 4


func fog_scale() -> float:
	return 0.7


func control_points() -> Array:
	var pts: Array = []
	var r := RandomNumberGenerator.new()
	r.seed = 42
	var n := 16
	for i in n:
		var a := TAU * i / n
		var k := r.randf_range(0.88, 1.12)
		var x := cos(a) * 1000.0 * k
		var z := sin(a) * 640.0 * k
		var y := 10.0 * sin(2.0 * a) + 6.0 * sin(3.0 * a + 1.0) + 12.0
		pts.append(Vector3(x, y, z))
	return pts


func base_height(x: float, z: float) -> float:
	return 14.0 + noise.get_noise_2d(x, z) * 45.0 + noise.get_noise_2d(x * 3.1, z * 3.1) * 6.0


func extra_build() -> void:
	if int(Settings.get_v("quality_level")) < 1:
		return
	# рекламные щиты вдоль трассы
	var batch := BoxBatch.new()
	var sb := static_body(1.0, "asphalt")
	var tg := RoadBuilder.tangents(center_pts, true)
	for i in range(20, center_pts.size(), 110):
		var right := tg[i].cross(Vector3.UP).normalized()
		var p := center_pts[i] + right * (road_half + 12.0)
		p.y = terrain.grid_height(p.x, p.z)
		var yaw := atan2(right.x, right.z)
		var b := Basis(Vector3.UP, yaw)
		solid_box(batch, sb, Transform3D(b, p + Vector3.UP * 3.0), Vector3(0.4, 6.0, 0.4), Color(0.4, 0.4, 0.42))
		batch.add(Transform3D(b, p + Vector3.UP * 7.5), Vector3(9.0, 4.0, 0.3), Color(rng.randf_range(0.3, 1.0), rng.randf_range(0.3, 1.0), rng.randf_range(0.3, 1.0)))
	static_root.add_child(batch.build(concrete_mat()))
