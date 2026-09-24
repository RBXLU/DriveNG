class_name UIKit
extends RefCounted

## Тема и фабрики элементов интерфейса.

const ACCENT := Color(1.0, 0.5, 0.12)
const BG := Color(0.06, 0.07, 0.09, 0.9)
const BG2 := Color(0.11, 0.12, 0.15, 0.95)
const TEXT := Color(0.93, 0.94, 0.96)
const MUTED := Color(0.62, 0.65, 0.7)

static var _theme: Theme


static func sb(color: Color, radius: int = 10, border: Color = Color.TRANSPARENT, bw: int = 0, pad: int = 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(bw)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.6
	s.content_margin_bottom = pad * 0.6
	s.anti_aliasing = true
	return s


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font_size = 20
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("normal", "Button", sb(Color(0.14, 0.15, 0.19, 0.95), 10, Color(1, 1, 1, 0.06), 1, 16))
	t.set_stylebox("hover", "Button", sb(Color(0.2, 0.21, 0.26, 0.98), 10, ACCENT, 2, 16))
	t.set_stylebox("pressed", "Button", sb(ACCENT.darkened(0.2), 10, ACCENT, 2, 16))
	t.set_stylebox("focus", "Button", sb(Color(0, 0, 0, 0), 10, ACCENT.lightened(0.2), 2, 16))
	t.set_stylebox("disabled", "Button", sb(Color(0.1, 0.1, 0.12, 0.8), 10))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_font_size("font_size", "Button", 21)
	t.set_stylebox("panel", "PanelContainer", sb(BG, 14, Color(1, 1, 1, 0.05), 1, 18))
	t.set_stylebox("panel", "Panel", sb(BG, 14))
	for tp in ["OptionButton"]:
		t.set_stylebox("normal", tp, sb(Color(0.14, 0.15, 0.19, 0.95), 8, Color(1, 1, 1, 0.08), 1, 10))
		t.set_stylebox("hover", tp, sb(Color(0.2, 0.21, 0.26, 0.98), 8, ACCENT, 1, 10))
		t.set_stylebox("pressed", tp, sb(Color(0.2, 0.21, 0.26, 0.98), 8, ACCENT, 1, 10))
		t.set_stylebox("focus", tp, sb(Color(0, 0, 0, 0), 8, ACCENT, 1, 10))
		t.set_font_size("font_size", tp, 18)
	t.set_stylebox("panel", "PopupMenu", sb(BG2, 8, Color(1, 1, 1, 0.1), 1, 8))
	t.set_font_size("font_size", "PopupMenu", 18)
	t.set_stylebox("slider", "HSlider", sb(Color(0.2, 0.21, 0.25), 4, Color.TRANSPARENT, 0, 3))
	t.set_stylebox("grabber_area", "HSlider", sb(ACCENT.darkened(0.1), 4, Color.TRANSPARENT, 0, 3))
	t.set_stylebox("grabber_area_highlight", "HSlider", sb(ACCENT, 4, Color.TRANSPARENT, 0, 3))
	t.set_font_size("font_size", "CheckBox", 18)
	t.set_color("font_color", "CheckBox", TEXT)
	t.set_stylebox("panel", "TabContainer", sb(BG2, 10, Color.TRANSPARENT, 0, 14))
	t.set_stylebox("tab_selected", "TabContainer", sb(ACCENT.darkened(0.15), 8, Color.TRANSPARENT, 0, 14))
	t.set_stylebox("tab_unselected", "TabContainer", sb(Color(0.12, 0.13, 0.16), 8, Color.TRANSPARENT, 0, 14))
	t.set_stylebox("tab_hovered", "TabContainer", sb(Color(0.2, 0.2, 0.25), 8, Color.TRANSPARENT, 0, 14))
	t.set_font_size("font_size", "TabContainer", 19)
	t.set_stylebox("background", "ProgressBar", sb(Color(0.15, 0.16, 0.2, 0.9), 5, Color.TRANSPARENT, 0, 0))
	t.set_stylebox("fill", "ProgressBar", sb(ACCENT, 5, Color.TRANSPARENT, 0, 0))
	t.set_stylebox("panel", "ItemList", sb(Color(0.08, 0.09, 0.11, 0.9), 10, Color(1, 1, 1, 0.05), 1, 8))
	t.set_stylebox("selected", "ItemList", sb(ACCENT.darkened(0.25), 6, Color.TRANSPARENT, 0, 6))
	t.set_stylebox("selected_focus", "ItemList", sb(ACCENT.darkened(0.1), 6, Color.TRANSPARENT, 0, 6))
	t.set_stylebox("hovered", "ItemList", sb(Color(1, 1, 1, 0.06), 6, Color.TRANSPARENT, 0, 6))
	t.set_font_size("font_size", "ItemList", 19)
	t.set_color("font_color", "ItemList", TEXT)
	t.set_constant("v_separation", "ItemList", 6)
	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	_theme = t
	return t


static func label(text: String, size: int = 20, color: Color = TEXT, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func button(text: String, cb: Callable, min_w: int = 260) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 52)
	b.pressed.connect(cb)
	b.focus_mode = Control.FOCUS_ALL
	return b


static func vbox(sep: int = 10) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep: int = 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func panel() -> PanelContainer:
	return PanelContainer.new()


static func spacer(h: int = 10) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


static func full_rect(c: Control) -> void:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Строка настройки: подпись + элемент
static func row(title: String, ctrl: Control) -> HBoxContainer:
	var h := hbox(14)
	var l := label(title, 18, TEXT)
	l.custom_minimum_size = Vector2(290, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	h.add_child(l)
	ctrl.custom_minimum_size.x = max(ctrl.custom_minimum_size.x, 260)
	h.add_child(ctrl)
	return h


static func option(items: Array, selected: int, cb: Callable) -> OptionButton:
	var o := OptionButton.new()
	for it in items:
		o.add_item(str(it))
	o.select(clampi(selected, 0, items.size() - 1))
	o.item_selected.connect(cb)
	return o


static func slider(min_v: float, max_v: float, step: float, value: float, cb: Callable, fmt: String = "%.2f") -> HBoxContainer:
	var h := hbox(8)
	var s := HSlider.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(190, 30)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var l := label(fmt % value, 17, MUTED)
	l.custom_minimum_size = Vector2(62, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	s.value_changed.connect(func(v: float):
		l.text = fmt % v
		cb.call(v))
	h.add_child(s)
	h.add_child(l)
	return h


static func check(value: bool, cb: Callable) -> CheckBox:
	var c := CheckBox.new()
	c.button_pressed = value
	c.text = "Вкл" if value else "Выкл"
	c.toggled.connect(func(v: bool):
		c.text = "Вкл" if v else "Выкл"
		cb.call(v))
	return c


## Текстура круглой/скруглённой кнопки для сенсорного управления
static func touch_tex(size: int, color: Color, round_btn: bool = true) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := size * 0.5
	for y in size:
		for x in size:
			var a := 0.0
			if round_btn:
				var d := Vector2(x + 0.5 - c, y + 0.5 - c).length()
				a = clamp(c - d, 0.0, 1.0)
				var ring: float = clamp(1.0 - abs(d - (c - 3.0)) / 2.0, 0.0, 1.0)
				var col := color
				col.a = color.a * a + ring * 0.35
				img.set_pixel(x, y, col)
			else:
				var r := 18.0
				var dx: float = max(abs(x + 0.5 - c) - (c - r), 0.0)
				var dy: float = max(abs(y + 0.5 - c) - (c - r), 0.0)
				a = clamp(r - Vector2(dx, dy).length(), 0.0, 1.0)
				var col2 := color
				col2.a = color.a * a
				img.set_pixel(x, y, col2)
	return ImageTexture.create_from_image(img)
