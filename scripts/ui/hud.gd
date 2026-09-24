class_name HUD
extends Control

## Игровой интерфейс: спидометр-тахометр, передача, схема повреждений,
## сообщения, FPS, подсказки, счёт дерби.

var car: Car
var gauge: Gauge
var damage_w: DamageWidget
var msg_box: VBoxContainer
var fps_label: Label
var info_label: Label
var hint_label: Label
var derby_label: Label
var _dmg_t := 0.0
var _hint_t := 14.0
var _last_msg := ""
var _last_msg_t := 0


class Gauge extends Control:
	var car: Car

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if car == null or not is_instance_valid(car):
			return
		var c := size * 0.5
		var r: float = min(size.x, size.y) * 0.46
		draw_circle(c, r + 6.0, Color(0.05, 0.06, 0.08, 0.78))
		var a0 := deg_to_rad(135.0)
		var a1 := deg_to_rad(405.0)
		draw_arc(c, r - 8.0, a0, a1, 64, Color(1, 1, 1, 0.12), 10.0, true)
		var red_from := a0 + (a1 - a0) * 0.85
		draw_arc(c, r - 8.0, red_from, a1, 16, Color(0.9, 0.15, 0.1, 0.8), 10.0, true)
		var rr: float = clamp(car.rpm / max(car.redline * 1.0, 1.0), 0.0, 1.02)
		var col := UIKit.ACCENT if rr < 0.85 else Color(1.0, 0.2, 0.1)
		if rr > 0.01:
			draw_arc(c, r - 8.0, a0, a0 + (a1 - a0) * min(rr, 1.0), 48, col, 10.0, true)
		# деления
		for i in 11:
			var a := a0 + (a1 - a0) * i / 10.0
			var d := Vector2(cos(a), sin(a))
			draw_line(c + d * (r - 20.0), c + d * (r - 26.0 if i % 2 else r - 32.0), Color(1, 1, 1, 0.5), 2.0, true)
		var f := get_theme_default_font()
		var spd := int(round(Settings.speed_value(abs(car.speed))))
		var st := str(spd)
		var fs := int(r * 0.62)
		var tw := f.get_string_size(st, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		draw_string(f, c + Vector2(-tw * 0.5, fs * 0.28), st, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
		var unit := Settings.speed_unit()
		var uw := f.get_string_size(unit, HORIZONTAL_ALIGNMENT_CENTER, -1, 16).x
		draw_string(f, c + Vector2(-uw * 0.5, fs * 0.28 + 22), unit, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UIKit.MUTED)
		var g := car.gear_label()
		var gw := f.get_string_size(g, HORIZONTAL_ALIGNMENT_CENTER, -1, 30).x
		var gp := c + Vector2(0, r * 0.62)
		draw_rect(Rect2(gp - Vector2(22, 26), Vector2(44, 36)), Color(1, 1, 1, 0.08), true)
		draw_string(f, gp + Vector2(-gw * 0.5, 2), g, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, UIKit.ACCENT)
		var rpm_s := "%d об/мин" % int(car.rpm)
		if car.is_ev:
			rpm_s = "%d кВт" % int(car.max_power * car.throttle_eff / 1000.0)
		var rw := f.get_string_size(rpm_s, HORIZONTAL_ALIGNMENT_CENTER, -1, 13).x
		draw_string(f, c + Vector2(-rw * 0.5, -r * 0.42), rpm_s, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UIKit.MUTED)
		# индикаторы
		var ix := c.x - r * 0.62
		var iy := c.y + r * 0.95
		var labels := []
		if car.tcs_factor < 0.95:
			labels.append(["TCS", Color(1.0, 0.8, 0.1)])
		if car.handbrake > 0.1:
			labels.append(["(P)", Color(1.0, 0.25, 0.2)])
		if not car.engine_running:
			labels.append(["ДВС", Color(1.0, 0.25, 0.2)])
		if car.lights_on:
			labels.append(["ФАРЫ", Color(0.4, 0.8, 1.0)])
		for i in labels.size():
			draw_string(f, Vector2(ix + i * 52, iy), labels[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, labels[i][1])


class DamageWidget extends Control:
	var car: Car
	var zones := {"front": 0.0, "rear": 0.0, "left": 0.0, "right": 0.0, "roof": 0.0}
	var wheels_state: Array = []

	func refresh() -> void:
		if car == null or not is_instance_valid(car):
			return
		var L: float = car.spec["L"]
		var W: float = car.spec["W"]
		var acc := {"front": [0.0, 0], "rear": [0.0, 0], "left": [0.0, 0], "right": [0.0, 0], "roof": [0.0, 0]}
		for p in car.parts:
			if p.kind != "body" and p.kind != "cabin":
				continue
			var v := p.verts
			var o := p.orig
			var step: int = max(1, v.size() / 300)
			var i := 0
			while i < v.size():
				var q := o[i]
				var dd := (v[i] - q).length()
				var zone := ""
				if p.kind == "cabin":
					zone = "roof"
				elif q.z < -L * 0.25:
					zone = "front"
				elif q.z > L * 0.25:
					zone = "rear"
				elif q.x < 0.0:
					zone = "left"
				else:
					zone = "right"
				acc[zone][0] = max(acc[zone][0], dd)
				i += step
		for k in zones:
			zones[k] = clamp(acc[k][0] / 0.45, 0.0, 1.0)
		wheels_state.clear()
		for w in car.wheels:
			wheels_state.append(-1.0 if w.detached else clamp(w.damage / 0.3 + (0.5 if w.burst else 0.0), 0.0, 1.0))
		queue_redraw()

	func _col(v: float) -> Color:
		if v < 0.0:
			return Color(0.2, 0.2, 0.22, 0.6)
		if v < 0.5:
			return Color(0.25, 0.85, 0.35).lerp(Color(1.0, 0.85, 0.15), v * 2.0)
		return Color(1.0, 0.85, 0.15).lerp(Color(0.95, 0.15, 0.1), (v - 0.5) * 2.0)

	func _draw() -> void:
		if car == null or not is_instance_valid(car):
			return
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.06, 0.08, 0.72), true)
		var f := get_theme_default_font()
		draw_string(f, Vector2(10, 22), "Повреждения", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UIKit.MUTED)
		var cw := 56.0
		var ch := 112.0
		var o := Vector2(26, 36)
		draw_rect(Rect2(o + Vector2(0, 0), Vector2(cw, ch * 0.22)), _col(zones["front"]), true)
		draw_rect(Rect2(o + Vector2(0, ch * 0.78), Vector2(cw, ch * 0.22)), _col(zones["rear"]), true)
		draw_rect(Rect2(o + Vector2(0, ch * 0.24), Vector2(cw * 0.22, ch * 0.52)), _col(zones["left"]), true)
		draw_rect(Rect2(o + Vector2(cw * 0.78, ch * 0.24), Vector2(cw * 0.22, ch * 0.52)), _col(zones["right"]), true)
		draw_rect(Rect2(o + Vector2(cw * 0.26, ch * 0.3), Vector2(cw * 0.48, ch * 0.4)), _col(zones["roof"]), true)
		# колёса
		var pos := [Vector2(-9, ch * 0.12), Vector2(cw + 1, ch * 0.12), Vector2(-9, ch * 0.7), Vector2(cw + 1, ch * 0.7)]
		for i in min(4, wheels_state.size()):
			var wi: int = i
			if wheels_state.size() > 4 and i >= 2:
				wi = wheels_state.size() - 4 + i
			draw_rect(Rect2(o + pos[i], Vector2(8, 22)), _col(wheels_state[wi]), true)
		# двигатель и прочее
		var x := o.x + cw + 30
		var eh := car.engine_health
		draw_string(f, Vector2(x, 56), "Двигатель", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UIKit.TEXT)
		draw_rect(Rect2(Vector2(x, 62), Vector2(96, 8)), Color(1, 1, 1, 0.1), true)
		draw_rect(Rect2(Vector2(x, 62), Vector2(96 * eh, 8)), _col(1.0 - eh), true)
		var status := "норма"
		if not car.engine_running:
			status = "заглох" if eh > 0.0 else "уничтожен"
		elif car.on_fire > 0.0:
			status = "ПОЖАР!"
		elif car.radiator_leak > 0.0:
			status = "течь радиатора"
		elif eh < 0.5:
			status = "повреждён"
		draw_string(f, Vector2(x, 88), status, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UIKit.MUTED)
		var lost := 0
		for p in car.parts:
			if not p.attached:
				lost += 1
		draw_string(f, Vector2(x, 112), "Оторвано: %d" % lost, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UIKit.TEXT)
		draw_string(f, Vector2(x, 132), "Стёкла: %s" % ("разбиты" if car.damage.glass_broken else "целы"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UIKit.TEXT)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	UIKit.full_rect(self)
	gauge = Gauge.new()
	gauge.custom_minimum_size = Vector2(230, 230)
	gauge.size = Vector2(230, 230)
	gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(gauge)
	damage_w = DamageWidget.new()
	damage_w.size = Vector2(230, 160)
	damage_w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(damage_w)
	msg_box = UIKit.vbox(6)
	msg_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	msg_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	msg_box.position = Vector2(-300, 70)
	msg_box.size = Vector2(600, 200)
	msg_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	add_child(msg_box)
	fps_label = UIKit.label("", 16, UIKit.MUTED)
	fps_label.position = Vector2(14, 10)
	add_child(fps_label)
	info_label = UIKit.label("", 17, UIKit.TEXT)
	info_label.position = Vector2(14, 32)
	add_child(info_label)
	hint_label = UIKit.label("W/S — газ/тормоз   A/D — руль   Пробел — ручник   C — камера   R — на колёса\nBackspace — ремонт   T — замедление   L — фары   B — заспавнить машину   Esc — меню", 15, Color(1, 1, 1, 0.75))
	hint_label.position = Vector2(14, 58)
	hint_label.size = Vector2(900, 60)
	add_child(hint_label)
	derby_label = UIKit.label("", 26, UIKit.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	derby_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	derby_label.position = Vector2(-250, 16)
	derby_label.size = Vector2(500, 40)
	add_child(derby_label)
	Game.hud_message.connect(show_message)
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	var s := size
	var touch := Settings.is_touch_ui()
	if touch:
		gauge.position = Vector2(s.x * 0.5 - 90, s.y - 190)
		gauge.size = Vector2(180, 180)
		damage_w.position = Vector2(s.x - 240, 10)
		damage_w.visible = true
		hint_label.visible = false
	else:
		gauge.position = Vector2(s.x - 250, s.y - 250)
		gauge.size = Vector2(230, 230)
		damage_w.position = Vector2(16, s.y - 176)


func set_car(c: Car) -> void:
	car = c
	gauge.car = c
	damage_w.car = c
	damage_w.refresh()


func show_message(text: String) -> void:
	# одинаковые сообщения подряд не дублируем
	var now := Time.get_ticks_msec()
	if text == _last_msg and now - _last_msg_t < 1500:
		return
	_last_msg = text
	_last_msg_t = now
	var l := UIKit.label(text, 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 6)
	msg_box.add_child(l)
	# queue_free удаляет узел только в конце кадра — сначала отцепляем, иначе цикл вечный
	while msg_box.get_child_count() > 4:
		var old := msg_box.get_child(0)
		msg_box.remove_child(old)
		old.queue_free()
	var tw := l.create_tween()
	tw.tween_interval(2.2)
	tw.tween_property(l, "modulate:a", 0.0, 0.8)
	tw.tween_callback(l.queue_free)


func set_derby(alive: int, total: int) -> void:
	derby_label.text = "Соперников осталось: %d из %d" % [alive, total]


func _process(delta: float) -> void:
	var rdt: float = delta / max(Engine.time_scale, 0.01)
	fps_label.visible = bool(Settings.get_v("show_fps"))
	if fps_label.visible:
		fps_label.text = "FPS: %d   рендер: %d%%" % [Engine.get_frames_per_second(), int(get_viewport().scaling_3d_scale * 100.0)]
	var ts := Engine.time_scale
	info_label.text = ("ЗАМЕДЛЕНИЕ ×%s" % str(ts)) if ts < 0.99 else ""
	if _hint_t > 0.0:
		_hint_t -= rdt
		if _hint_t <= 0.0:
			var tw := create_tween()
			tw.tween_property(hint_label, "modulate:a", 0.0, 1.0)
	_dmg_t -= rdt
	if _dmg_t <= 0.0:
		_dmg_t = 0.4
		damage_w.refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("hud_toggle"):
		visible = not visible
