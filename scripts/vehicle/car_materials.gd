class_name CarMaterials
extends RefCounted

## Общие (разделяемые) материалы машин. Каждая краска — отдельный экземпляр.

const PAINT_SHADER := preload("res://shaders/car_paint.gdshader")
const GLASS_SHADER := preload("res://shaders/car_glass.gdshader")

static var _cache := {}


static func paint(color: Color, metallic: float = 0.45, rough: float = 0.28) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = PAINT_SHADER
	m.set_shader_parameter("paint_color", color)
	m.set_shader_parameter("metallic_amount", metallic)
	m.set_shader_parameter("base_roughness", rough)
	m.set_shader_parameter("clearcoat_amount", 1.0 if Settings.get_v("quality_level") >= 2 else 0.0)
	return m


static func _cached(key: String, maker: Callable) -> Material:
	if not _cache.has(key):
		_cache[key] = maker.call()
	return _cache[key]


static func glass() -> Material:
	return _cached("glass", func():
		var m := ShaderMaterial.new()
		m.shader = GLASS_SHADER
		return m)


static func glass_broken() -> Material:
	return _cached("glass_broken", func():
		var m := ShaderMaterial.new()
		m.shader = GLASS_SHADER
		m.set_shader_parameter("broken", 1.0)
		return m)


static func std(key: String, color: Color, metallic: float, rough: float, emission: Color = Color.BLACK, energy: float = 0.0) -> StandardMaterial3D:
	return _cached(key, func():
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.metallic = metallic
		m.roughness = rough
		if energy > 0.0:
			m.emission_enabled = true
			m.emission = emission
			m.emission_energy_multiplier = energy
		m.vertex_color_use_as_albedo = false
		return m)


static func plastic() -> Material:
	return std("plastic", Color(0.06, 0.06, 0.065), 0.0, 0.55)


static func chrome() -> Material:
	return std("chrome", Color(0.85, 0.86, 0.88), 1.0, 0.12)


static func chassis() -> Material:
	return std("chassis", Color(0.04, 0.04, 0.045), 0.3, 0.8)


static func tire() -> Material:
	return std("tire", Color(0.035, 0.035, 0.035), 0.0, 0.88)


static func rim() -> Material:
	return std("rim", Color(0.7, 0.71, 0.74), 0.85, 0.28)


static func rim_dark() -> Material:
	return std("rim_dark", Color(0.12, 0.12, 0.13), 0.7, 0.35)


static func plate() -> Material:
	return std("plate", Color(0.92, 0.92, 0.9), 0.0, 0.4)


static func light_off() -> Material:
	return std("light_off", Color(0.18, 0.18, 0.2), 0.3, 0.15)


static func headlight() -> StandardMaterial3D:
	# у каждой машины свой, чтобы включать/выключать
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.95, 0.95, 0.9)
	m.metallic = 0.2
	m.roughness = 0.1
	m.emission_enabled = true
	m.emission = Color(1.0, 0.95, 0.82)
	m.emission_energy_multiplier = 0.3
	return m


static func taillight() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.5, 0.02, 0.02)
	m.roughness = 0.2
	m.emission_enabled = true
	m.emission = Color(1.0, 0.05, 0.02)
	m.emission_energy_multiplier = 0.4
	return m


static func beacon(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color * 0.5
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 0.2
	return m
