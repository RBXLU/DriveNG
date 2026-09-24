extends Node

## Настройки игры: пресеты графики, управление, звук. Хранятся в user://settings.cfg.

signal changed(key: String)

const PATH := "user://settings.cfg"

const QUALITY_NAMES := ["Очень низкое", "Низкое", "Среднее", "Высокое", "Ультра"]

# Пресеты графики. Всё, что сильно бьёт по слабым GPU/CPU, отключается на низких.
const PRESETS := [
	{"render_scale": 0.6, "shadows": 0, "shadow_distance": 40.0, "draw_distance": 300.0, "msaa": 0, "fxaa": false, "glow": false, "ssao": false, "fog": true, "particles": 0, "max_debris": 8, "traffic": 4, "physics_hz": 60, "vegetation": 0.25, "clouds": false, "reflections": false},
	{"render_scale": 0.75, "shadows": 1, "shadow_distance": 50.0, "draw_distance": 450.0, "msaa": 0, "fxaa": true, "glow": false, "ssao": false, "fog": true, "particles": 1, "max_debris": 16, "traffic": 7, "physics_hz": 60, "vegetation": 0.5, "clouds": true, "reflections": false},
	{"render_scale": 1.0, "shadows": 1, "shadow_distance": 70.0, "draw_distance": 700.0, "msaa": 0, "fxaa": true, "glow": true, "ssao": false, "fog": true, "particles": 1, "max_debris": 30, "traffic": 10, "physics_hz": 90, "vegetation": 0.75, "clouds": true, "reflections": true},
	{"render_scale": 1.0, "shadows": 2, "shadow_distance": 100.0, "draw_distance": 1000.0, "msaa": 2, "fxaa": false, "glow": true, "ssao": true, "fog": true, "particles": 2, "max_debris": 50, "traffic": 14, "physics_hz": 120, "vegetation": 1.0, "clouds": true, "reflections": true},
	{"render_scale": 1.0, "shadows": 2, "shadow_distance": 150.0, "draw_distance": 1500.0, "msaa": 4, "fxaa": false, "glow": true, "ssao": true, "fog": true, "particles": 2, "max_debris": 80, "traffic": 18, "physics_hz": 120, "vegetation": 1.0, "clouds": true, "reflections": true},
]

var data := {
	"quality_level": -1,
	"auto_resolution": true,
	"fps_limit": 0,
	"vsync": true,
	"show_fps": false,
	"volume_master": 0.8,
	"volume_engine": 0.9,
	"volume_fx": 1.0,
	"units": 0,              # 0 км/ч, 1 mph
	"gearbox": 0,            # 0 автомат, 1 механика
	"abs": true,
	"tcs": true,
	"esc": true,
	"damage_mult": 1.0,
	"fov": 72.0,
	"steer_sens": 1.0,
	"camera_shake": true,
	"touch_controls": 0,     # 0 авто, 1 всегда, 2 никогда
	"touch_steer": 0,        # 0 кнопки, 1 наклон
	"force_low_renderer": false,
}


func _ready() -> void:
	# значения из пресета «Среднее» по умолчанию
	for k in PRESETS[2]:
		data[k] = PRESETS[2][k]
	load_settings()
	if int(data["quality_level"]) < 0:
		apply_preset(detect_quality(), false)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("quality="):
			apply_preset(int(a.substr(8)), false)
	save_settings()


func get_v(key: String, def: Variant = null) -> Variant:
	return data.get(key, def)


func set_v(key: String, value: Variant, save := true) -> void:
	data[key] = value
	if save:
		save_settings()
	changed.emit(key)


func apply_preset(level: int, emit := true) -> void:
	level = clampi(level, 0, PRESETS.size() - 1)
	data["quality_level"] = level
	for k in PRESETS[level]:
		data[k] = PRESETS[level][k]
	save_settings()
	if emit:
		changed.emit("preset")


## Грубая автоматическая оценка мощности устройства
func detect_quality() -> int:
	var level := 2
	var cores := OS.get_processor_count()
	var mobile := OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")
	var method := str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "forward_plus"))
	var gpu := RenderingServer.get_video_adapter_name().to_lower()
	if mobile:
		level = 1
		if cores <= 4:
			level = 0
		if gpu.contains("adreno (tm) 7") or gpu.contains("adreno (tm) 8") or gpu.contains("immortalis"):
			level = 2
	else:
		if cores <= 2:
			level = 0
		elif cores <= 4:
			level = 1
		if gpu.contains("intel") and (gpu.contains("hd") or gpu.contains("uhd")):
			level = min(level, 1)
		if gpu.contains("llvmpipe") or gpu.contains("swiftshader") or gpu.contains("software"):
			level = 0
		if gpu.contains("rtx") or gpu.contains("radeon rx 6") or gpu.contains("radeon rx 7") or gpu.contains("radeon rx 9"):
			level = 3
	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
		level = min(level, 2)
	return level


func is_touch_ui() -> bool:
	match int(data["touch_controls"]):
		1: return true
		2: return false
	return DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for k in cfg.get_section_keys("settings") if cfg.has_section("settings") else []:
		data[k] = cfg.get_value("settings", k)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for k in data:
		cfg.set_value("settings", k, data[k])
	cfg.save(PATH)


func speed_unit() -> String:
	return "км/ч" if int(data["units"]) == 0 else "mph"


func speed_value(ms: float) -> float:
	return ms * (3.6 if int(data["units"]) == 0 else 2.23694)
