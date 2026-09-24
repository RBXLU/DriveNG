class_name Atmosphere
extends Node3D

## Окружение: небо, солнце/луна, туман, тонмаппинг, свечение, SSAO — всё
## зависит от времени суток и пресета качества.

const SKY_SHADER := preload("res://shaders/sky.gdshader")

const TIMES := [
	{   # день
		"sun_elev": 52.0, "sun_az": 35.0, "sun_color": Color(1.0, 0.95, 0.86), "sun_energy": 1.35,
		"zenith": Color(0.16, 0.36, 0.74), "horizon": Color(0.62, 0.74, 0.88), "ground": Color(0.28, 0.29, 0.28),
		"ambient": 1.0, "fog": Color(0.66, 0.76, 0.88), "clouds": 0.42, "cloud_color": Color(1, 1, 1), "stars": 0.0, "exposure": 1.0,
	},
	{   # закат
		"sun_elev": 7.0, "sun_az": 250.0, "sun_color": Color(1.0, 0.58, 0.3), "sun_energy": 1.15,
		"zenith": Color(0.13, 0.2, 0.42), "horizon": Color(0.98, 0.58, 0.34), "ground": Color(0.2, 0.16, 0.14),
		"ambient": 0.75, "fog": Color(0.85, 0.55, 0.4), "clouds": 0.5, "cloud_color": Color(1.0, 0.72, 0.55), "stars": 0.0, "exposure": 1.05,
	},
	{   # ночь
		"sun_elev": 38.0, "sun_az": 140.0, "sun_color": Color(0.55, 0.65, 0.95), "sun_energy": 0.14,
		"zenith": Color(0.006, 0.01, 0.028), "horizon": Color(0.035, 0.045, 0.08), "ground": Color(0.02, 0.02, 0.025),
		"ambient": 0.35, "fog": Color(0.035, 0.045, 0.075), "clouds": 0.3, "cloud_color": Color(0.12, 0.13, 0.17), "stars": 1.0, "exposure": 1.25,
	},
]

var env: Environment
var world_env: WorldEnvironment
var sun: DirectionalLight3D
var sky_mat: ShaderMaterial
var tod := 0
var fog_scale := 1.0


func setup(time_of_day: int, p_fog_scale: float = 1.0) -> void:
	tod = clampi(time_of_day, 0, 2)
	fog_scale = p_fog_scale
	var t: Dictionary = TIMES[tod]
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	sky_mat.set_shader_parameter("zenith_color", t["zenith"])
	sky_mat.set_shader_parameter("horizon_color", t["horizon"])
	sky_mat.set_shader_parameter("ground_color", t["ground"])
	sky_mat.set_shader_parameter("sun_color", t["sun_color"])
	sky_mat.set_shader_parameter("cloud_amount", t["clouds"])
	sky_mat.set_shader_parameter("cloud_color", t["cloud_color"])
	sky_mat.set_shader_parameter("stars", t["stars"])
	sky_mat.set_shader_parameter("sun_disk", 0.25 if tod == 2 else 1.0)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	sky.process_mode = Sky.PROCESS_MODE_QUALITY

	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = t["ambient"]
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = t["exposure"]
	env.fog_enabled = true
	env.fog_light_color = t["fog"]
	env.fog_sun_scatter = 0.15
	env.fog_sky_affect = 0.25
	env.glow_intensity = 0.55
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.08
	world_env = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	sun = DirectionalLight3D.new()
	sun.light_color = t["sun_color"]
	sun.light_energy = t["sun_energy"]
	sun.rotation_degrees = Vector3(-float(t["sun_elev"]), float(t["sun_az"]), 0)
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.directional_shadow_blend_splits = true
	sun.shadow_blur = 1.0
	add_child(sun)
	apply_quality()
	if not Settings.changed.is_connected(_on_settings):
		Settings.changed.connect(_on_settings)


func _on_settings(_k: String) -> void:
	apply_quality()


func apply_quality() -> void:
	if env == null:
		return
	var q: int = int(Settings.get_v("quality_level"))
	var shadows: int = int(Settings.get_v("shadows"))
	sun.shadow_enabled = shadows > 0 and tod != 2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL if shadows <= 1 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	if q >= 4:
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = float(Settings.get_v("shadow_distance"))
	var dd: float = Settings.get_v("draw_distance")
	env.fog_enabled = bool(Settings.get_v("fog"))
	env.fog_density = clamp(1.1 / dd, 0.0007, 0.005) * fog_scale
	env.fog_aerial_perspective = 0.3
	env.glow_enabled = bool(Settings.get_v("glow"))
	var forward := RenderingServer.get_current_rendering_method() == "forward_plus"
	env.ssao_enabled = bool(Settings.get_v("ssao")) and forward
	env.ssao_intensity = 1.6
	env.ssao_radius = 1.2
	env.ssr_enabled = q >= 4 and forward
	sky_mat.set_shader_parameter("clouds_enabled", 1.0 if Settings.get_v("clouds") else 0.0)
	env.sky.radiance_size = Sky.RADIANCE_SIZE_64 if q <= 1 else Sky.RADIANCE_SIZE_128


func is_night() -> bool:
	return tod == 2
