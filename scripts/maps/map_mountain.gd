class_name MapMountain
extends MapLoopRoad

## Горный перевал: узкий серпантин вокруг горы, обрывы с отбойниками, озеро.

const WATER_SHADER := preload("res://shaders/water.gdshader")
const WATER_LEVEL := 6.0
var noise := FastNoiseLite.new()


func _init() -> void:
	map_id = "mountain"
	lanes_per_dir = 1
	lane_w = 3.5
	median_half = 0.0
	shoulder = 1.3
	lane_speeds = [15.0]
	terrain_size = 1800.0
	terrain_res = 201
	lamp_spacing = 0.0
	noise.seed = 3
	noise.frequency = 0.004
	noise.fractal_octaves = 5


func water_level() -> float:
	return WATER_LEVEL


func base_height(x: float, z: float) -> float:
	var r := Vector2(x, z).length()
	var mountain := 150.0 * exp(-pow(r / 420.0, 2.0))
	var hills := noise.get_noise_2d(x, z) * 38.0 + 22.0
	var ridge: float = abs(noise.get_noise_2d(x * 0.6 + 300.0, z * 0.6)) * 30.0
	# впадина озера на юго-западе
	var lake := 40.0 * exp(-pow(Vector2(x + 520.0, z - 480.0).length() / 170.0, 2.0))
	return mountain + hills + ridge - lake


func control_points() -> Array:
	var pts: Array = []
	var n := 22
	for i in n:
		var a := TAU * i / n
		# волнистый радиус — серпантин то поднимается к вершине, то уходит вниз
		var r := 520.0 + 170.0 * sin(a * 3.0) + 60.0 * cos(a * 5.0)
		var x := cos(a) * r
		var z := sin(a) * r
		var y: float = max(base_height(x, z) + 1.0, WATER_LEVEL + 3.0)
		pts.append(Vector3(x, y, z))
	return pts


func terrain_colors() -> Array:
	return [Color(0.2, 0.32, 0.12), Color(0.28, 0.36, 0.15), Color(0.45, 0.43, 0.4), Color(0.42, 0.35, 0.25)]


func surface_at(p: Vector3, _c: Object) -> Vector2:
	if p.y < WATER_LEVEL:
		return Vector2(0.35, 1.0)
	return Vector2(-1.0, 0.0)


func extra_build() -> void:
	var w := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(terrain_size, terrain_size)
	w.mesh = pm
	w.position.y = WATER_LEVEL
	var m := ShaderMaterial.new()
	m.shader = WATER_SHADER
	w.material_override = m
	w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	static_root.add_child(w)
