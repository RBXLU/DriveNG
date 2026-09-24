extends Node

## Точка входа: меню, запуск сессии, пауза, настройки, применение графики.

var ui_layer: CanvasLayer
var root_ui: Control
var screen: Control
var garage: Garage
var world: World
var hud: HUD
var touch: TouchControls
var in_game := false
var paused := false
var _fps_acc := 0.0
var _fps_frames := 0
var _dyn_scale := 1.0
var _car_filter := 0
var _test := {}
var _test_frames := 0
var _settings_back := "menu"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	InputSetup.setup()
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)
	root_ui = Control.new()
	root_ui.theme = UIKit.theme()
	root_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(root_ui)
	UIKit.full_rect(root_ui)
	apply_display_settings()
	Settings.changed.connect(_on_settings_changed)
	_parse_test_args()
	if _test.has("uitest"):
		_ui_walkthrough()
		return
	if _test.has("autostart"):
		Game.selected_map = _test["autostart"]
		Game.selected_car = _test.get("car", Game.selected_car)
		Game.time_of_day = int(_test.get("tod", 0))
		Game.traffic_density = int(_test.get("traffic", 2))
		start_game()
	else:
		_show_garage()
		show_main_menu()


func _parse_test_args() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			_test[kv[0]] = kv[1]


# ---------------------------------------------------------------- экран

func _clear_screen() -> void:
	if screen != null and is_instance_valid(screen):
		screen.queue_free()
	screen = null


func _set_screen(c: Control) -> void:
	_clear_screen()
	screen = c
	root_ui.add_child(c)


func _show_garage() -> void:
	if garage == null:
		garage = Garage.new()
		add_child(garage)
	garage.show_car(Game.selected_car, Game.car_color())


func _page(title: String, sub: String = "") -> Array:
	# полупрозрачная панель слева на всю высоту
	var c := Control.new()
	UIKit.full_rect(c)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grad := ColorRect.new()
	grad.color = Color(0.03, 0.035, 0.045, 0.55)
	grad.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	grad.offset_right = 560
	grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(grad)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	margin.offset_right = 560
	for k in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(k, 40)
	c.add_child(margin)
	var v := UIKit.vbox(12)
	margin.add_child(v)
	var t := UIKit.label(title, 40, Color.WHITE)
	v.add_child(t)
	if sub != "":
		v.add_child(UIKit.label(sub, 18, UIKit.MUTED))
	v.add_child(UIKit.spacer(8))
	return [c, v]


func show_main_menu() -> void:
	_show_garage()
	var pv := _page("DRIVE NG", "Симулятор реалистичных разрушений")
	var v: VBoxContainer = pv[1]
	var title: Label = v.get_child(0)
	title.add_theme_color_override("font_color", UIKit.ACCENT)
	title.add_theme_font_size_override("font_size", 56)
	v.add_child(UIKit.button("Играть", show_map_select))
	v.add_child(UIKit.button("Гараж", func(): show_car_select("menu")))
	v.add_child(UIKit.button("Настройки", func(): show_settings("menu")))
	v.add_child(UIKit.button("Управление", func(): show_controls("menu")))
	if not OS.has_feature("web") and not OS.has_feature("mobile"):
		v.add_child(UIKit.button("Выход", func(): get_tree().quit()))
	v.add_child(UIKit.spacer(20))
	var spec := CarDatabase.get_car(Game.selected_car)
	v.add_child(UIKit.label("Машина: %s" % spec["name"], 18, UIKit.MUTED))
	v.add_child(UIKit.label("Графика: %s" % Settings.QUALITY_NAMES[int(Settings.get_v("quality_level"))], 16, UIKit.MUTED))
	_set_screen(pv[0])
	_focus_first(v)


## Фокус на первую кнопку (для геймпада/клавиатуры)
func _focus_first(v: Control) -> void:
	for c in v.get_children():
		if c is Button:
			(c as Button).grab_focus()
			return


func show_map_select() -> void:
	var pv := _page("Карта", "Выберите место для экспериментов")
	var v: VBoxContainer = pv[1]
	var list := ItemList.new()
	list.custom_minimum_size = Vector2(0, 230)
	for m in Game.MAPS:
		list.add_item(m["name"])
	var sel := 0
	for i in Game.MAPS.size():
		if Game.MAPS[i]["id"] == Game.selected_map:
			sel = i
	list.select(sel)
	v.add_child(list)
	var desc := UIKit.label(Game.MAPS[sel]["desc"], 17, UIKit.MUTED)
	desc.custom_minimum_size = Vector2(0, 70)
	v.add_child(desc)
	list.item_selected.connect(func(i: int):
		Game.selected_map = Game.MAPS[i]["id"]
		desc.text = Game.MAPS[i]["desc"])
	v.add_child(UIKit.row("Время суток", UIKit.option(Game.TIMES, Game.time_of_day, func(i): Game.time_of_day = i)))
	v.add_child(UIKit.row("Трафик", UIKit.option(Game.TRAFFIC, Game.traffic_density, func(i): Game.traffic_density = i)))
	var h := UIKit.hbox(10)
	h.add_child(UIKit.button("Назад", show_main_menu, 150))
	h.add_child(UIKit.button("Выбрать машину →", func(): show_car_select("new"), 260))
	v.add_child(UIKit.spacer(8))
	v.add_child(h)
	_set_screen(pv[0])
	list.grab_focus()


func show_car_select(context: String) -> void:
	if context != "ingame":
		_show_garage()
	var pv := _page("Гараж", "%d машин на основе реальных прототипов" % CarDatabase.CARS.size())
	var v: VBoxContainer = pv[1]
	var filter := UIKit.option(CarDatabase.CLASSES, _car_filter, func(_i): pass)
	v.add_child(UIKit.row("Класс", filter))
	var list := ItemList.new()
	list.custom_minimum_size = Vector2(0, 250)
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(list)
	var info := UIKit.label("", 16, UIKit.TEXT)
	info.custom_minimum_size = Vector2(0, 120)
	v.add_child(info)
	var colors := UIKit.hbox(8)
	v.add_child(colors)
	var ids: Array = []
	var fill := func():
		list.clear()
		ids.clear()
		var cls: String = CarDatabase.CLASSES[_car_filter]
		for c in CarDatabase.CARS:
			if _car_filter == 0 or c["class"] == cls:
				list.add_item("%s  (%s)" % [c["name"], c["based"]])
				ids.append(c["id"])
		for i in ids.size():
			if ids[i] == Game.selected_car:
				list.select(i)
				list.ensure_current_is_visible()
	var refresh := func():
		var c := CarDatabase.get_car(Game.selected_car)
		var gearbox := "электро, 1 ступень" if c.get("ev", false) else "%d ступ." % (c["gears"] as Array).size()
		info.text = "%s · %d г. · %s\n%d л.с. · %d Н·м · %d кг · привод %s · %s\nМакс. скорость ≈ %d км/ч · %.0f л.с./т · прочность ×%.2f" % [
			c["based"], c["year"], c["class"], c["hp"], c["torque"], c["mass"], c["drive"], gearbox,
			int(CarDatabase.estimate_top_speed(c)), CarDatabase.power_to_weight(c), c.get("strength", 1.0)]
		for ch in colors.get_children():
			ch.queue_free()
		var cols: Array = c["colors"]
		for i in cols.size():
			var b := Button.new()
			b.custom_minimum_size = Vector2(44, 44)
			var st := UIKit.sb(cols[i], 22, Color.WHITE if i == Game.selected_color else Color(1, 1, 1, 0.2), 3 if i == Game.selected_color else 1, 0)
			b.add_theme_stylebox_override("normal", st)
			b.add_theme_stylebox_override("hover", UIKit.sb(cols[i].lightened(0.15), 22, UIKit.ACCENT, 3, 0))
			b.add_theme_stylebox_override("pressed", st)
			var idx := i
			b.pressed.connect(func():
				Game.selected_color = idx
				if garage != null:
					garage.show_car(Game.selected_car, Game.car_color())
				info.get_meta("refresh").call())
			colors.add_child(b)
		if garage != null and context != "ingame":
			garage.show_car(Game.selected_car, Game.car_color())
	info.set_meta("refresh", refresh)
	fill.call()
	refresh.call()
	filter.item_selected.connect(func(i: int):
		_car_filter = i
		fill.call())
	list.item_selected.connect(func(i: int):
		Game.selected_car = ids[i]
		Game.selected_color = 0
		refresh.call())
	var h := UIKit.hbox(10)
	match context:
		"new":
			h.add_child(UIKit.button("Назад", show_map_select, 150))
			h.add_child(UIKit.button("Поехали! →", start_game, 260))
		"ingame":
			h.add_child(UIKit.button("Назад", show_pause_menu, 150))
			h.add_child(UIKit.button("Пересесть", func():
				world.change_player_car(Game.selected_car, Game.car_color())
				hud.set_car(world.player)
				resume(), 260))
		_:
			h.add_child(UIKit.button("Готово", show_main_menu, 200))
	v.add_child(h)
	_set_screen(pv[0])
	list.grab_focus()


func show_controls(back: String) -> void:
	var pv := _page("Управление")
	var v: VBoxContainer = pv[1]
	var rows := [
		["Газ / тормоз (задний ход)", "W / S, ↑ / ↓, триггеры"],
		["Руль", "A / D, ← / →, левый стик"],
		["Ручник", "Пробел, A (геймпад)"],
		["Поставить на колёса", "R, Y"],
		["Ремонт", "Backspace / F5"],
		["Камера", "C, Back"],
		["Замедление времени", "T, X"],
		["Передачи (механика)", "E / Q, Shift / Ctrl, бамперы"],
		["Фары / мигалки", "L / K"],
		["Двигатель вкл/выкл", "I"],
		["Заспавнить машину", "B / F2"],
		["Скрыть интерфейс", "F1"],
		["Пауза", "Esc, Start"],
	]
	for r in rows:
		var h := UIKit.hbox(10)
		var a := UIKit.label(r[0], 17, UIKit.TEXT)
		a.custom_minimum_size = Vector2(230, 0)
		h.add_child(a)
		h.add_child(UIKit.label(r[1], 17, UIKit.ACCENT))
		v.add_child(h)
	v.add_child(UIKit.label("На телефоне — экранные кнопки или наклон (в настройках). В режиме «Облёт» камеру вращают пальцем/мышью.", 15, UIKit.MUTED))
	v.add_child(UIKit.button("Назад", func(): _back(back), 200))
	_set_screen(pv[0])


func _back(to: String) -> void:
	if to == "pause":
		show_pause_menu()
	else:
		show_main_menu()


# ---------------------------------------------------------------- настройки

func show_settings(back: String) -> void:
	if back == "keep":
		back = _settings_back
	_settings_back = back
	var pv := _page("Настройки")
	var c: Control = pv[0]
	var v: VBoxContainer = pv[1]
	# настройки шире — расширяем панель
	(c.get_child(0) as ColorRect).offset_right = 760
	(c.get_child(1) as MarginContainer).offset_right = 760
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(tabs)
	tabs.add_child(_settings_graphics())
	tabs.add_child(_settings_game())
	tabs.add_child(_settings_audio())
	tabs.set_tab_title(0, "Графика")
	tabs.set_tab_title(1, "Игра")
	tabs.set_tab_title(2, "Звук")
	var h := UIKit.hbox(10)
	h.add_child(UIKit.button("Назад", func(): _back(back), 180))
	h.add_child(UIKit.button("Сбросить (авто)", func():
		Settings.apply_preset(Settings.detect_quality())
		show_settings(back), 240))
	v.add_child(h)
	_set_screen(c)


func _scroll(inner: Control) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(inner)
	return s


func _settings_graphics() -> Control:
	var v := UIKit.vbox(8)
	var S := Settings
	v.add_child(UIKit.row("Пресет качества", UIKit.option(S.QUALITY_NAMES, int(S.get_v("quality_level")), func(i):
		S.apply_preset(i)
		show_settings("keep"))))
	v.add_child(UIKit.row("Разрешение рендера", UIKit.slider(0.4, 1.0, 0.05, float(S.get_v("render_scale")), func(x): S.set_v("render_scale", x), "%.2f")))
	v.add_child(UIKit.row("Авто-разрешение (держать FPS)", UIKit.check(bool(S.get_v("auto_resolution")), func(x): S.set_v("auto_resolution", x))))
	v.add_child(UIKit.row("Тени", UIKit.option(["Выкл", "Низкие", "Высокие"], int(S.get_v("shadows")), func(i): S.set_v("shadows", i))))
	v.add_child(UIKit.row("Дальность теней, м", UIKit.slider(20, 200, 10, float(S.get_v("shadow_distance")), func(x): S.set_v("shadow_distance", x), "%d")))
	v.add_child(UIKit.row("Дальность прорисовки, м", UIKit.slider(200, 1500, 50, float(S.get_v("draw_distance")), func(x): S.set_v("draw_distance", x), "%d")))
	v.add_child(UIKit.row("Сглаживание MSAA", UIKit.option(["Выкл", "2x", "4x"], [0, 2, 4].find(int(S.get_v("msaa"))), func(i): S.set_v("msaa", [0, 2, 4][i]))))
	v.add_child(UIKit.row("Сглаживание FXAA", UIKit.check(bool(S.get_v("fxaa")), func(x): S.set_v("fxaa", x))))
	v.add_child(UIKit.row("Свечение (bloom)", UIKit.check(bool(S.get_v("glow")), func(x): S.set_v("glow", x))))
	v.add_child(UIKit.row("Затенение SSAO", UIKit.check(bool(S.get_v("ssao")), func(x): S.set_v("ssao", x))))
	v.add_child(UIKit.row("Туман", UIKit.check(bool(S.get_v("fog")), func(x): S.set_v("fog", x))))
	v.add_child(UIKit.row("Облака", UIKit.check(bool(S.get_v("clouds")), func(x): S.set_v("clouds", x))))
	v.add_child(UIKit.row("Частицы", UIKit.option(["Мало", "Средне", "Много"], int(S.get_v("particles")), func(i): S.set_v("particles", i))))
	v.add_child(UIKit.row("Растительность*", UIKit.slider(0.0, 1.0, 0.05, float(S.get_v("vegetation")), func(x): S.set_v("vegetation", x))))
	v.add_child(UIKit.row("Макс. обломков", UIKit.slider(4, 100, 1, float(S.get_v("max_debris")), func(x): S.set_v("max_debris", int(x)), "%d")))
	v.add_child(UIKit.row("Макс. машин в трафике*", UIKit.slider(0, 24, 1, float(S.get_v("traffic")), func(x): S.set_v("traffic", int(x)), "%d")))
	v.add_child(UIKit.row("Частота физики, Гц", UIKit.option(["60", "90", "120"], [60, 90, 120].find(int(S.get_v("physics_hz"))), func(i): S.set_v("physics_hz", [60, 90, 120][i]))))
	v.add_child(UIKit.row("Лимит FPS", UIKit.option(["Без лимита", "30", "60", "120"], [0, 30, 60, 120].find(int(S.get_v("fps_limit"))), func(i): S.set_v("fps_limit", [0, 30, 60, 120][i]))))
	v.add_child(UIKit.row("Вертикальная синхронизация", UIKit.check(bool(S.get_v("vsync")), func(x): S.set_v("vsync", x))))
	v.add_child(UIKit.row("Показывать FPS", UIKit.check(bool(S.get_v("show_fps")), func(x): S.set_v("show_fps", x))))
	if not OS.has_feature("mobile"):
		v.add_child(UIKit.row("Лёгкий рендер OpenGL**", UIKit.check(RenderingServer.get_current_rendering_method() == "gl_compatibility", _toggle_renderer)))
	v.add_child(UIKit.label("* применяется при следующей загрузке карты.  ** требует перезапуска.\nТекущий рендер: %s, видеокарта: %s" % [RenderingServer.get_current_rendering_method(), RenderingServer.get_video_adapter_name()], 14, UIKit.MUTED))
	var s := _scroll(v)
	s.name = "Графика"
	return s


func _settings_game() -> Control:
	var v := UIKit.vbox(8)
	var S := Settings
	v.add_child(UIKit.row("Коробка передач", UIKit.option(["Автомат", "Механика"], int(S.get_v("gearbox")), func(i): S.set_v("gearbox", i))))
	v.add_child(UIKit.row("ABS", UIKit.check(bool(S.get_v("abs")), func(x): S.set_v("abs", x))))
	v.add_child(UIKit.row("Антипробуксовка (TCS)", UIKit.check(bool(S.get_v("tcs")), func(x): S.set_v("tcs", x))))
	v.add_child(UIKit.row("Стабилизация (ESC)", UIKit.check(bool(S.get_v("esc")), func(x): S.set_v("esc", x))))
	v.add_child(UIKit.row("Единицы скорости", UIKit.option(["км/ч", "mph"], int(S.get_v("units")), func(i): S.set_v("units", i))))
	v.add_child(UIKit.row("Сила повреждений", UIKit.slider(0.25, 3.0, 0.05, float(S.get_v("damage_mult")), func(x): S.set_v("damage_mult", x), "×%.2f")))
	v.add_child(UIKit.row("Поле зрения (FOV)", UIKit.slider(55, 100, 1, float(S.get_v("fov")), func(x): S.set_v("fov", x), "%d°")))
	v.add_child(UIKit.row("Чувствительность руля", UIKit.slider(0.4, 2.0, 0.05, float(S.get_v("steer_sens")), func(x): S.set_v("steer_sens", x))))
	v.add_child(UIKit.row("Тряска камеры", UIKit.check(bool(S.get_v("camera_shake")), func(x): S.set_v("camera_shake", x))))
	v.add_child(UIKit.row("Сенсорные кнопки", UIKit.option(["Авто", "Всегда", "Никогда"], int(S.get_v("touch_controls")), func(i): S.set_v("touch_controls", i))))
	v.add_child(UIKit.row("Руль на телефоне", UIKit.option(["Кнопки", "Наклон"], int(S.get_v("touch_steer")), func(i): S.set_v("touch_steer", i))))
	var s := _scroll(v)
	s.name = "Игра"
	return s


func _settings_audio() -> Control:
	var v := UIKit.vbox(8)
	var S := Settings
	v.add_child(UIKit.row("Общая громкость", UIKit.slider(0.0, 1.0, 0.05, float(S.get_v("volume_master")), func(x): S.set_v("volume_master", x))))
	v.add_child(UIKit.row("Двигатель", UIKit.slider(0.0, 1.0, 0.05, float(S.get_v("volume_engine")), func(x): S.set_v("volume_engine", x))))
	v.add_child(UIKit.row("Эффекты", UIKit.slider(0.0, 1.0, 0.05, float(S.get_v("volume_fx")), func(x): S.set_v("volume_fx", x))))
	var s := _scroll(v)
	s.name = "Звук"
	return s


func _toggle_renderer(low: bool) -> void:
	var path := OS.get_executable_path().get_base_dir().path_join("override.cfg")
	if OS.has_feature("editor"):
		path = ProjectSettings.globalize_path("res://override.cfg")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		Game.message("Не удалось записать override.cfg")
		return
	if low:
		f.store_string("[rendering]\nrenderer/rendering_method=\"gl_compatibility\"\n")
	else:
		f.store_string("[rendering]\nrenderer/rendering_method=\"forward_plus\"\n")
	f.close()
	var d := AcceptDialog.new()
	d.title = "Перезапуск"
	d.dialog_text = "Рендер сменится после перезапуска игры."
	root_ui.add_child(d)
	d.popup_centered()


func _on_settings_changed(_k: String) -> void:
	apply_display_settings()


func apply_display_settings() -> void:
	var vp := get_viewport()
	var scale: float = float(Settings.get_v("render_scale"))
	_dyn_scale = scale
	vp.scaling_3d_scale = scale
	var forward := RenderingServer.get_current_rendering_method() != "gl_compatibility"
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if forward and scale < 0.99 else Viewport.SCALING_3D_MODE_BILINEAR
	match int(Settings.get_v("msaa")):
		2: vp.msaa_3d = Viewport.MSAA_2X
		4: vp.msaa_3d = Viewport.MSAA_4X
		_: vp.msaa_3d = Viewport.MSAA_DISABLED
	if forward:
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if Settings.get_v("fxaa") else Viewport.SCREEN_SPACE_AA_DISABLED
	Engine.max_fps = int(Settings.get_v("fps_limit"))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if Settings.get_v("vsync") else DisplayServer.VSYNC_DISABLED)
	Engine.physics_ticks_per_second = int(Settings.get_v("physics_hz"))
	Engine.max_physics_steps_per_frame = 3 if int(Settings.get_v("quality_level")) <= 1 else 5
	if world != null and world.camera != null:
		world.camera.fov = Settings.get_v("fov")
		world.camera.far = float(Settings.get_v("draw_distance")) + 200.0


# ---------------------------------------------------------------- игра

func start_game() -> void:
	var load_c := Control.new()
	UIKit.full_rect(load_c)
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.045, 0.06)
	UIKit.full_rect(bg)
	load_c.add_child(bg)
	var info := Game.map_info(Game.selected_map)
	var l := UIKit.label("Загрузка: %s…" % info["name"], 34, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	l.offset_left = -400
	l.offset_right = 400
	load_c.add_child(l)
	var tip := UIKit.label("Совет: нажмите T, чтобы замедлить время и рассмотреть аварию.", 18, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	tip.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	tip.offset_left = -500
	tip.offset_right = 500
	tip.offset_top = -80
	load_c.add_child(tip)
	_set_screen(load_c)
	await get_tree().process_frame
	await get_tree().process_frame
	if garage != null:
		garage.queue_free()
		garage = null
	world = World.new()
	world.name = "World"
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	var t0 := Time.get_ticks_msec()
	world.start(Game.selected_map, Game.selected_car, Game.car_color(), Game.time_of_day, Game.traffic_density)
	print("world built in ", Time.get_ticks_msec() - t0, " ms")
	world.pause_requested.connect(toggle_pause)
	world.spawn_menu_requested.connect(func():
		if not paused:
			pause()
		show_spawn_menu())
	hud = HUD.new()
	hud.process_mode = Node.PROCESS_MODE_PAUSABLE
	root_ui.add_child(hud)
	root_ui.move_child(hud, 0)
	hud.set_car(world.player)
	world.derby_state.connect(hud.set_derby)
	world.derby_finished.connect(_on_derby_finished)
	if Settings.is_touch_ui():
		touch = TouchControls.new()
		touch.process_mode = Node.PROCESS_MODE_PAUSABLE
		root_ui.add_child(touch)
		root_ui.move_child(touch, 1)
	in_game = true
	_clear_screen()
	Game.message(info["name"])


func toggle_pause() -> void:
	if paused:
		resume()
	else:
		pause()
		show_pause_menu()


func pause() -> void:
	paused = true
	get_tree().paused = true


func resume() -> void:
	paused = false
	get_tree().paused = false
	_clear_screen()


func show_pause_menu() -> void:
	var pv := _page("Пауза", Game.map_info(Game.selected_map)["name"])
	var v: VBoxContainer = pv[1]
	v.add_child(UIKit.button("Продолжить", resume))
	v.add_child(UIKit.button("Починить машину", func():
		world.repair_player()
		hud.set_car(world.player)
		resume()))
	v.add_child(UIKit.button("Вернуться на старт", func():
		world.respawn_player()
		hud.set_car(world.player)
		resume()))
	if world.map.map_id == "testgrounds":
		v.add_child(UIKit.button("Краш-тест…", show_crash_menu))
	v.add_child(UIKit.button("Заспавнить машину…", show_spawn_menu))
	v.add_child(UIKit.button("Пересесть в другую машину…", func(): show_car_select("ingame")))
	v.add_child(UIKit.button("Замедление: ×%s" % str(Game.slowmo_levels[Game.slowmo_index]), func():
		Game.cycle_slowmo()
		show_pause_menu()))
	v.add_child(UIKit.button("Настройки", func(): show_settings("pause")))
	v.add_child(UIKit.button("Управление", func(): show_controls("pause")))
	v.add_child(UIKit.button("Главное меню", to_main_menu))
	var st := UIKit.label("Макс. скорость: %d км/ч · Пробег: %.1f км" % [int(world.max_speed * 3.6), world.distance / 1000.0], 15, UIKit.MUTED)
	v.add_child(st)
	_set_screen(pv[0])
	_focus_first(v)


func show_crash_menu() -> void:
	var pv := _page("Краш-тест", "Машина получит скорость в 45 м до препятствия")
	var v: VBoxContainer = pv[1]
	var target := ["wall"]
	v.add_child(UIKit.row("Препятствие", UIKit.option(["Бетонная стена", "Столб", "Стена под углом 30°", "Автобус (боком)"], 0, func(i): target[0] = ["wall", "pole", "angle", "bus"][i])))
	for kmh in [30, 50, 64, 80, 100, 130, 180]:
		var k: float = kmh
		v.add_child(UIKit.button("%d км/ч" % kmh, func():
			resume()
			world.crash_test(k, target[0])))
	v.add_child(UIKit.label("64 км/ч — скорость стандартного теста Euro NCAP. Нажмите T для замедления.", 15, UIKit.MUTED))
	v.add_child(UIKit.button("Назад", show_pause_menu))
	_set_screen(pv[0])


func show_spawn_menu() -> void:
	var pv := _page("Заспавнить машину")
	var v: VBoxContainer = pv[1]
	var names: Array = []
	for c in CarDatabase.CARS:
		names.append(c["name"])
	var chosen := [CarDatabase.index_of(Game.selected_car)]
	v.add_child(UIKit.row("Машина", UIKit.option(names, chosen[0], func(i): chosen[0] = i)))
	var mk := func(mode: String) -> Callable:
		return func():
			world.spawn_car(CarDatabase.CARS[chosen[0]]["id"], mode)
			resume()
	v.add_child(UIKit.button("Припарковать впереди", mk.call("parked")))
	v.add_child(UIKit.button("Лоб в лоб (едет на вас)", mk.call("ram")))
	if world.map.net != null:
		v.add_child(UIKit.button("Пустить в поток", mk.call("traffic")))
	v.add_child(UIKit.button("Убрать заспавненные и обломки", func():
		world.clear_spawned()
		resume()))
	v.add_child(UIKit.button("Назад", show_pause_menu))
	_set_screen(pv[0])


func _on_derby_finished(win: bool) -> void:
	pause()
	var pv := _page("Победа!" if win else "Вы разбиты", "Дерби-арена")
	var v: VBoxContainer = pv[1]
	v.add_child(UIKit.label("Вы остались последним на ходу!" if win else "Ваша машина больше не может ехать.", 20, UIKit.TEXT))
	v.add_child(UIKit.button("Ещё раз", func():
		world.restart_derby()
		hud.set_car(world.player)
		resume()))
	v.add_child(UIKit.button("Главное меню", to_main_menu))
	_set_screen(pv[0])


func to_main_menu() -> void:
	paused = false
	get_tree().paused = false
	in_game = false
	if hud != null:
		hud.queue_free()
		hud = null
	if touch != null:
		touch.queue_free()
		touch = null
	if world != null:
		world.queue_free()
		world = null
	Engine.time_scale = 1.0
	await get_tree().process_frame
	_show_garage()
	show_main_menu()


# ---------------------------------------------------------------- динамическое разрешение и тесты

func _process(delta: float) -> void:
	if _test.has("menushot") and not in_game:
		_test_frames += 1
		if _test_frames == int(_test.get("frames", "60")):
			get_viewport().get_texture().get_image().save_png(_test["menushot"])
			print("menu shot saved")
			get_tree().quit()
	if in_game and not paused and Settings.get_v("auto_resolution"):
		_fps_acc += delta / max(Engine.time_scale, 0.01)
		_fps_frames += 1
		if _fps_acc >= 1.0:
			var fps := _fps_frames / _fps_acc
			_fps_acc = 0.0
			_fps_frames = 0
			var max_s: float = float(Settings.get_v("render_scale"))
			var target := 58.0 if int(Settings.get_v("fps_limit")) == 0 or int(Settings.get_v("fps_limit")) >= 60 else float(Settings.get_v("fps_limit")) - 2.0
			if fps < target - 8.0 and _dyn_scale > 0.5:
				_dyn_scale = max(0.5, _dyn_scale - 0.05)
				get_viewport().scaling_3d_scale = _dyn_scale
			elif fps > target and _dyn_scale < max_s:
				_dyn_scale = min(max_s, _dyn_scale + 0.05)
				get_viewport().scaling_3d_scale = _dyn_scale
	if _test.has("autostart") and in_game:
		_test_frames += 1
		_test_hook()


func _test_hook() -> void:
	# автотесты: drive=1 — газ в пол; shot=путь — снимок; frames=N — выход
	if _test.get("drive", "0") == "1" and world.player != null:
		Input.action_press("throttle", 1.0)
	if _test.has("crashtest") and _test_frames == 3:
		world.crash_test(float(_test["crashtest"]), _test.get("target", "wall"))
	if _test.has("slow") and _test_frames == 3:
		Game.set_slowmo(int(_test["slow"]))
	var frames := int(_test.get("frames", "0"))
	if _test.has("trace") and _test_frames % 10 == 0:
		var pl := world.player
		print("f%d t=%d v=%.1f z=%.2f dmg=%.2f" % [_test_frames, Time.get_ticks_msec(), pl.speed * 3.6, pl.global_position.z, pl.total_damage])
	if _test.has("cam") and _test_frames == 2:
		for i in int(_test["cam"]):
			world.camera.next_mode()
	if frames > 0 and _test_frames == frames:
		if _test.has("shot"):
			var img := get_viewport().get_texture().get_image()
			img.save_png(_test["shot"])
			print("shot saved ", _test["shot"])
		var p := world.player
		print("player speed %.1f km/h, pos %s, gear %s, rpm %d, dmg %.2f, cars %d, fps %d" % [p.speed * 3.6, str(p.global_position), p.gear_label(), int(p.rpm), p.total_damage, Game.cars.size(), Engine.get_frames_per_second()])
		get_tree().quit()


# ---------------------------------------------------------------- автотест интерфейса

func _wait(n: int = 10) -> void:
	for i in n:
		await get_tree().process_frame


func _snap(name: String) -> void:
	await _wait(8)
	var dir: String = _test.get("uitest")
	if dir != "1":
		get_viewport().get_texture().get_image().save_png(dir.path_join(name + ".png"))
	print("UI step ok: ", name)


func _ui_walkthrough() -> void:
	_show_garage()
	show_main_menu()
	await _snap("01_menu")
	show_map_select()
	await _snap("02_maps")
	show_car_select("new")
	await _snap("03_garage")
	show_settings("menu")
	await _snap("04_settings")
	show_controls("menu")
	await _snap("05_controls")
	Game.selected_map = "testgrounds"
	start_game()
	await _wait(30)
	await _snap("06_game")
	pause()
	show_pause_menu()
	await _snap("07_pause")
	show_spawn_menu()
	await _snap("08_spawn")
	world.spawn_car("vostok_2107", "parked")
	world.spawn_car("gazel", "ram")
	show_crash_menu()
	await _snap("09_crash")
	show_car_select("ingame")
	await _snap("10_car_ingame")
	world.change_player_car("kaiser_golfer", Color.RED)
	hud.set_car(world.player)
	show_settings("pause")
	await _snap("11_settings_pause")
	Settings.apply_preset(1)
	await _wait(5)
	resume()
	world.crash_test(64.0, "wall")
	await _wait(120)
	await _snap("12_after_crash")
	world.repair_player()
	world.clear_spawned()
	await _wait(10)
	await to_main_menu()
	await _snap("13_back_to_menu")
	print("UI WALKTHROUGH DONE")
	get_tree().quit()
