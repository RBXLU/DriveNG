class_name TouchControls
extends Control

## Сенсорное управление: мультитач-кнопки (TouchScreenButton) нажимают те же
## действия ввода, что и клавиатура.

var buttons := {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	UIKit.full_rect(self)
	var tilt := int(Settings.get_v("touch_steer")) == 1
	if not tilt:
		_add("steer_left", "◀", Vector2(150, 150), true, true)
		_add("steer_right", "▶", Vector2(150, 150), true, true)
	_add("throttle", "ГАЗ", Vector2(150, 190), false, true, Color(0.2, 0.75, 0.35, 0.45))
	_add("brake", "ТОРМ", Vector2(140, 140), false, true, Color(0.85, 0.2, 0.15, 0.45))
	_add("handbrake", "РУЧН", Vector2(110, 110), true, false)
	_add("reset_car", "⟲", Vector2(80, 80), true, false)
	_add("camera", "КАМ", Vector2(80, 80), true, false)
	_add("pause", "II", Vector2(80, 80), true, false)
	_add("slowmo", "×½", Vector2(80, 80), true, false)
	resized.connect(_layout)
	_layout()


func _add(action: String, text: String, sz: Vector2, round_btn: bool, passby: bool, col: Color = Color(1, 1, 1, 0.22)) -> void:
	var b := TouchScreenButton.new()
	var s := int(max(sz.x, sz.y))
	b.texture_normal = UIKit.touch_tex(s, col, round_btn)
	var pc := col
	pc.a = min(1.0, col.a + 0.3)
	b.texture_pressed = UIKit.touch_tex(s, pc, round_btn)
	b.action = action
	b.passby_press = passby
	var shape := RectangleShape2D.new()
	shape.size = Vector2(s, s)
	b.shape = shape
	b.shape_centered = true
	add_child(b)
	var l := UIKit.label(text, 22 if s > 100 else 18, Color(1, 1, 1, 0.9), HORIZONTAL_ALIGNMENT_CENTER)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size = Vector2(s, s)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(l)
	buttons[action] = [b, s]


func _place(action: String, pos: Vector2) -> void:
	if buttons.has(action):
		(buttons[action][0] as TouchScreenButton).position = pos


func _layout() -> void:
	var w := size.x
	var h := size.y
	_place("steer_left", Vector2(24, h - 180))
	_place("steer_right", Vector2(190, h - 180))
	_place("throttle", Vector2(w - 176, h - 214))
	_place("brake", Vector2(w - 330, h - 164))
	_place("handbrake", Vector2(w - 150, h - 350))
	_place("pause", Vector2(w * 0.5 - 180, 12))
	_place("camera", Vector2(w * 0.5 - 88, 12))
	_place("reset_car", Vector2(w * 0.5 + 4, 12))
	_place("slowmo", Vector2(w * 0.5 + 96, 12))
