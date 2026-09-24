class_name CarAudio
extends Node3D

## Звуки одной машины: двигатель (нагрузка/сброс), шины, ветер, скрежет.

var car: Car
var eng_on: AudioStreamPlayer3D
var eng_off: AudioStreamPlayer3D
var tire: AudioStreamPlayer3D
var dirt: AudioStreamPlayer3D
var wind: AudioStreamPlayer3D
var scrape: AudioStreamPlayer3D
var pitch_k := 1.0


func _make(stream: AudioStream, unit: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.unit_size = unit
	p.max_distance = 120.0
	p.volume_db = -80.0
	p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
	add_child(p)
	p.play()
	return p


func setup(c: Car) -> void:
	car = c
	var type: String = car.spec.get("sound", "i4")
	match type:
		"diesel": pitch_k = 0.75
		"v8": pitch_k = 0.85
		"v10": pitch_k = 1.15
		"ev": pitch_k = 1.0
	var unit := 9.0 if car.is_player else 6.0
	eng_on = _make(AudioManager.engine_stream(type, true), unit)
	if car.is_player:
		eng_off = _make(AudioManager.engine_stream(type, false), unit)
		tire = _make(AudioManager.noise_loop("tire", 0.9, 950.0, 0.8), 8.0)
		dirt = _make(AudioManager.noise_loop("dirt", 0.12, 0.0, 0.8), 8.0)
		wind = _make(AudioManager.noise_loop("wind", 0.05, 0.0, 1.2), 10.0)
		scrape = _make(AudioManager.noise_loop("scrape", 0.8, 2400.0, 0.6), 8.0)
	else:
		tire = _make(AudioManager.noise_loop("tire", 0.9, 950.0, 0.8), 5.0)


func _process(_delta: float) -> void:
	if not is_instance_valid(car):
		return
	var ts: float = clamp(Engine.time_scale * 1.3, 0.35, 1.0)
	var ve: float = float(Settings.get_v("volume_engine"))
	var vf: float = float(Settings.get_v("volume_fx"))
	var r: float = car.rpm / maxf(car.redline, 1.0)
	var pitch := lerpf(0.55, 2.25, clamp(r, 0.0, 1.1)) * pitch_k * ts
	if car.is_ev:
		pitch = lerpf(0.35, 2.6, clamp(r, 0.0, 1.0)) * ts
	var running := car.engine_running
	var base := (-6.0 if car.is_player else -12.0) + linear_to_db(max(ve, 0.0001))
	var thr := car.throttle_eff
	var vol_on := base + lerpf(-14.0, 0.0, thr) + r * 4.0
	if car.is_ev:
		vol_on = base - 6.0 + clamp(abs(car.speed) * 0.4, 0.0, 8.0)
	eng_on.pitch_scale = max(0.05, pitch)
	eng_on.volume_db = vol_on if running else -80.0
	if eng_off != null:
		eng_off.pitch_scale = max(0.05, pitch)
		eng_off.volume_db = (base + lerpf(-2.0, -18.0, thr) - 2.0) if running and not car.is_ev else -80.0
	var fx_db := linear_to_db(max(vf, 0.0001))
	var slip := car.slip_sound
	var on_dirt := false
	for w in car.wheels:
		if w.grounded and w.surface_type != "asphalt":
			on_dirt = true
	if tire != null:
		var tv := -80.0
		if slip > 1.2 and not on_dirt:
			tv = clamp(-24.0 + slip * 3.0, -24.0, 2.0) + fx_db
		tire.volume_db = tv
		tire.pitch_scale = clamp(0.85 + slip * 0.02, 0.8, 1.2) * ts
	if dirt != null:
		var dv := -80.0
		if on_dirt and abs(car.speed) > 1.0:
			dv = clamp(-26.0 + abs(car.speed) * 0.5 + slip * 1.5, -26.0, 0.0) + fx_db
		dirt.volume_db = dv
	if wind != null:
		var sp: float = abs(car.speed)
		wind.volume_db = (clamp(-40.0 + sp * 0.8, -40.0, 0.0) if sp > 5.0 else -80.0) + fx_db
		wind.pitch_scale = clamp(0.6 + sp * 0.012, 0.6, 1.6)
	if scrape != null:
		scrape.volume_db = (clamp(-20.0 + car.scrape * 1.2, -20.0, 4.0) + fx_db) if car.scrape > 2.0 else -80.0
		scrape.pitch_scale = clamp(0.8 + car.scrape * 0.02, 0.8, 1.4) * ts
