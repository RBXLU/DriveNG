class_name InputSetup
extends RefCounted

## Регистрирует действия ввода: клавиатура + геймпад (раскладка Xbox).

static func _key(action: String, keys: Array) -> void:
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)


static func _joy_btn(action: String, btn: int) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = btn
	InputMap.action_add_event(action, e)


static func _joy_axis(action: String, axis: int, dir: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = dir
	InputMap.action_add_event(action, e)


static func setup() -> void:
	var defs := {
		"throttle": [KEY_W, KEY_UP],
		"brake": [KEY_S, KEY_DOWN],
		"steer_left": [KEY_A, KEY_LEFT],
		"steer_right": [KEY_D, KEY_RIGHT],
		"handbrake": [KEY_SPACE],
		"reset_car": [KEY_R],
		"repair_car": [KEY_BACKSPACE, KEY_F5],
		"camera": [KEY_C],
		"lights": [KEY_L],
		"beacons": [KEY_K],
		"slowmo": [KEY_T],
		"pause": [KEY_ESCAPE, KEY_P],
		"shift_up": [KEY_E, KEY_SHIFT],
		"shift_down": [KEY_Q, KEY_CTRL],
		"engine": [KEY_I],
		"spawn_menu": [KEY_F2, KEY_B],
		"hud_toggle": [KEY_F1],
	}
	for a in defs:
		if not InputMap.has_action(a):
			InputMap.add_action(a, 0.2)
		_key(a, defs[a])
	_joy_axis("throttle", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_joy_axis("brake", JOY_AXIS_TRIGGER_LEFT, 1.0)
	_joy_axis("steer_left", JOY_AXIS_LEFT_X, -1.0)
	_joy_axis("steer_right", JOY_AXIS_LEFT_X, 1.0)
	_joy_btn("handbrake", JOY_BUTTON_A)
	_joy_btn("reset_car", JOY_BUTTON_Y)
	_joy_btn("camera", JOY_BUTTON_BACK)
	_joy_btn("pause", JOY_BUTTON_START)
	_joy_btn("shift_up", JOY_BUTTON_RIGHT_SHOULDER)
	_joy_btn("shift_down", JOY_BUTTON_LEFT_SHOULDER)
	_joy_btn("slowmo", JOY_BUTTON_X)
	_joy_btn("lights", JOY_BUTTON_DPAD_UP)
	_joy_btn("repair_car", JOY_BUTTON_DPAD_DOWN)
