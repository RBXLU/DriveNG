class_name CarMaterials
extends RefCounted

## Общие (разделяемые) материалы машин. Каждая краска — отдельный экземпляр.

const PAINT_SHADER := preload("res://shaders/car_paint.gdshader")
const GLASS_SHADER := preload("res://shaders/car_glass.gdshader")
const GLASS_CLEAR_SHADER := preload("res://shaders/car_glass_clear.gdshader")

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


## На высоком качестве стекло полупрозрачное (виден салон), иначе — непрозрачное
static func _clear_glass() -> bool:
	return int(Settings.get_v("quality_level")) >= 3


static func glass() -> Material:
	var clear := _clear_glass()
	return _cached("glass_%s" % clear, func():
		var m := ShaderMaterial.new()
		m.shader = GLASS_CLEAR_SHADER if clear else GLASS_SHADER
		return m)


static func glass_broken() -> Material:
	var clear := _clear_glass()
	return _cached("glass_broken_%s" % clear, func():
		var m := ShaderMaterial.new()
		m.shader = GLASS_CLEAR_SHADER if clear else GLASS_SHADER
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
	return std("rim", Color(0.82, 0.83, 0.86), 0.75, 0.3)


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


## Материал с цветом из вершин (молдинги, решётки, салон)
static func trim() -> StandardMaterial3D:
	return _cached("trim", func():
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.albedo_color = Color.WHITE
		m.roughness = 0.45
		m.metallic = 0.15
		return m)


static func trim_chrome() -> StandardMaterial3D:
	return _cached("trim_chrome", func():
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.albedo_color = Color.WHITE
		m.roughness = 0.12
		m.metallic = 1.0
		return m)


static func interior() -> StandardMaterial3D:
	return _cached("interior", func():
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.roughness = 0.85
		return m)


static func rim_steel() -> Material:
	return std("rim_steel", Color(0.32, 0.33, 0.35), 0.6, 0.45)


static func brake_disc() -> Material:
	return std("brake_disc", Color(0.38, 0.38, 0.4), 0.9, 0.35)


static func caliper(sport: bool) -> Material:
	if sport:
		return std("caliper_red", Color(0.75, 0.06, 0.04), 0.2, 0.35)
	return std("caliper", Color(0.2, 0.2, 0.22), 0.5, 0.5)
