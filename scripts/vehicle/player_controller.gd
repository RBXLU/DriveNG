class_name PlayerController
extends RefCounted

## Управление игроком: клавиатура (сглаженный руль), геймпад (аналог),
## сенсор (кнопки или наклон устройства).

var steer_s := 0.0
var touch_steer := 0.0   # выставляется сенсорным интерфейсом (-1..1), NAN — не используется
var use_touch_steer := false


func update(car: Car, dt: float) -> void:
	var sens: float = Settings.get_v("steer_sens")
	car.throttle = Input.get_action_strength("throttle")
	car.brake = Input.get_action_strength("brake")
	car.handbrake = Input.get_action_strength("handbrake")
	var joy := 0.0
	if Input.get_connected_joypads().size() > 0:
		joy = Input.get_joy_axis(Input.get_connected_joypads()[0], JOY_AXIS_LEFT_X)
	var raw := Input.get_action_strength("steer_right") - Input.get_action_strength("steer_left")
	if abs(joy) > 0.08:
		# аналоговый руль: нелинейная кривая для точности в центре
		steer_s = sign(joy) * pow(abs(joy), 1.4) * clamp(sens, 0.3, 2.0)
	elif int(Settings.get_v("touch_steer")) == 1 and Settings.is_touch_ui():
		var acc := Input.get_accelerometer()
		var tilt: float = clamp(acc.x / 5.5 * sens, -1.0, 1.0) if abs(acc.x) > 0.25 else 0.0
		steer_s = move_toward(steer_s, tilt, dt * 6.0)
	else:
		# клавиатура: руль «набирается» постепенно и быстрее возвращается к центру
		var spd: float = abs(car.speed)
		var rate: float = lerp(4.0, 1.8, clamp(spd / 40.0, 0.0, 1.0)) * sens
		if raw == 0.0 or sign(raw) != sign(steer_s):
			rate = 6.0
		steer_s = move_toward(steer_s, raw, rate * dt)
	car.steer = clamp(steer_s, -1.0, 1.0)
	if Input.is_action_just_pressed("shift_up"):
		car.want_shift = 1
	if Input.is_action_just_pressed("shift_down"):
		car.want_shift = -1
