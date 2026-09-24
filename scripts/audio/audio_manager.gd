class_name AudioManager
extends Node3D

## Процедурный звук: всё синтезируется при запуске (никаких ассетов).
## Двигатель — серия «вспышек» цилиндров с резонансами (разный характер для
## рядной четвёрки, V8, оппозитника, дизеля, электромотора), шины, ветер,
## скрежет, удары металла и бьющееся стекло.

const RATE := 22050
const ENGINE_BASE_HZ := 40.0   # частота вспышек в записанной петле

static var _engine_cache := {}
static var _sfx_cache := {}

var _pool: Array[AudioStreamPlayer3D] = []
var _pool_i := 0
var _cars_audio := {}    # car -> CarAudio
var _assign_t := 0.0


func _ready() -> void:
	for i in 10:
		var p := AudioStreamPlayer3D.new()
		p.unit_size = 12.0
		p.max_distance = 180.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(p)
		_pool.append(p)
	_apply_volume()
	Settings.changed.connect(func(_k): _apply_volume())


func _apply_volume() -> void:
	var v: float = Settings.get_v("volume_master")
	AudioServer.set_bus_volume_db(0, linear_to_db(max(v, 0.0001)))


# ---------------------------------------------------------------- синтез

static func _to_wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		var s := int(clamp(samples[i], -1.0, 1.0) * 32000.0)
		data.encode_s16(i * 2, s)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w


static func _normalize(s: PackedFloat32Array, peak: float) -> void:
	var m := 0.0001
	for x in s:
		m = max(m, abs(x))
	var k := peak / m
	for i in s.size():
		s[i] *= k


## Петля двигателя: type — i4/v6/v8/v10/boxer/diesel/ev; load — «под нагрузкой»
static func engine_stream(type: String, load: bool) -> AudioStreamWAV:
	var key := type + ("_on" if load else "_off")
	if _engine_cache.has(key):
		return _engine_cache[key]
	var dur := 0.5
	var n := int(RATE * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	if type == "ev":
		# электромотор: чистый вой с гармониками (частота кратна длине петли)
		for i in n:
			var t := float(i) / RATE
			var f := ENGINE_BASE_HZ * 6.0
			s[i] = sin(TAU * f * t) * 0.6 + sin(TAU * f * 2.0 * t) * 0.25 + sin(TAU * f * 3.0 * t) * (0.15 if load else 0.05)
		_normalize(s, 0.6)
	else:
		var res: Array = []   # резонансы [частота, затухание, громкость]
		var jitter := 0.12
		var uneven := 0.0
		var noise_amt := 0.08
		match type:
			"i4":
				res = [[170.0, 32.0, 1.0], [420.0, 55.0, 0.45], [900.0, 90.0, 0.2]]
			"v6":
				res = [[140.0, 26.0, 1.0], [360.0, 45.0, 0.5], [760.0, 80.0, 0.2]]
				uneven = 0.05
			"v8":
				res = [[95.0, 18.0, 1.0], [250.0, 30.0, 0.55], [600.0, 70.0, 0.2]]
				uneven = 0.14
				jitter = 0.18
			"v10":
				res = [[150.0, 22.0, 1.0], [480.0, 40.0, 0.6], [1100.0, 90.0, 0.3]]
				uneven = 0.06
			"boxer":
				res = [[120.0, 20.0, 1.0], [330.0, 35.0, 0.55], [700.0, 70.0, 0.25]]
				uneven = 0.1
			"diesel":
				res = [[80.0, 16.0, 1.0], [210.0, 30.0, 0.5], [1600.0, 140.0, 0.35]]
				noise_amt = 0.25
				jitter = 0.08
		if not load:
			noise_amt *= 0.5
		var firings := int(ENGINE_BASE_HZ * dur)
		var period := 1.0 / ENGINE_BASE_HZ
		for k in firings:
			var t0 := k * period
			if uneven > 0.0:
				t0 += period * uneven * (1.0 if k % 2 == 0 else -1.0) * 0.5
			var amp := 1.0 + rng.randf_range(-jitter, jitter)
			var start := int(t0 * RATE)
			var length := int(period * RATE * 2.2)
			for j in length:
				var idx := (start + j) % n
				var tt := float(j) / RATE
				var v := 0.0
				for r in res:
					var fr: float = r[0] * (1.0 if load else 0.85)
					v += sin(TAU * fr * tt) * exp(-tt * r[1]) * r[2]
				v += rng.randf_range(-1.0, 1.0) * noise_amt * exp(-tt * 60.0)
				s[idx] += v * amp * (1.0 if load else 0.6)
		# сглаживаем «щелчки» слабым ФНЧ
		var prev := 0.0
		for i in n:
			prev = prev + (s[i] - prev) * (0.55 if load else 0.35)
			s[i] = prev
		_normalize(s, 0.7)
	var w := _to_wav(s, true)
	_engine_cache[key] = w
	return w


static func noise_loop(key: String, lp: float, bp_freq: float, dur: float) -> AudioStreamWAV:
	if _sfx_cache.has(key):
		return _sfx_cache[key]
	var n := int(RATE * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	var y1 := 0.0
	var b0 := 0.0
	var b1 := 0.0
	for i in n:
		var x := rng.randf_range(-1.0, 1.0)
		y1 += (x - y1) * lp
		var v := y1
		if bp_freq > 0.0:
			# простой резонатор
			var f := 2.0 * sin(PI * bp_freq * (1.0 + 0.08 * sin(float(i) / RATE * TAU * 3.0)) / RATE)
			b0 += f * b1
			b1 += f * (v - b0 - 0.15 * b1)
			v = b1
		s[i] = v
	# плавная петля
	var fade := int(RATE * 0.05)
	for i in fade:
		var k := float(i) / fade
		s[i] = s[i] * k + s[n - fade + i] * (1.0 - k)
	s.resize(n - fade)
	_normalize(s, 0.6)
	var w := _to_wav(s, true)
	_sfx_cache[key] = w
	return w


static func crash_sound(variant: int) -> AudioStreamWAV:
	var key := "crash_%d" % variant
	if _sfx_cache.has(key):
		return _sfx_cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234 + variant * 77
	var n := int(RATE * 1.1)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	# удар (низкий «бум»), шумовые всплески «мнущегося» металла, звон
	for i in n:
		var t := float(i) / RATE
		var thump := sin(TAU * (55.0 + variant * 7.0) * t) * exp(-t * 14.0)
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.35
		var crunch := lp * exp(-t * 7.0) * (0.6 + 0.4 * sin(t * 90.0 + variant))
		s[i] = thump * 0.9 + crunch * 0.9
	for k in 5 + variant:
		var st := int(rng.randf_range(0.0, 0.35) * RATE)
		var f := rng.randf_range(600.0, 2400.0)
		var dec := rng.randf_range(10.0, 30.0)
		for j in int(RATE * 0.5):
			if st + j >= n:
				break
			var t := float(j) / RATE
			s[st + j] += sin(TAU * f * t) * exp(-t * dec) * 0.18
	_normalize(s, 0.95)
	var w := _to_wav(s, false)
	_sfx_cache[key] = w
	return w


static func glass_sound() -> AudioStreamWAV:
	if _sfx_cache.has("glass"):
		return _sfx_cache["glass"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 999
	var n := int(RATE * 1.0)
	var s := PackedFloat32Array()
	s.resize(n)
	var hp := 0.0
	var prev := 0.0
	for i in n:
		var t := float(i) / RATE
		var x := rng.randf_range(-1.0, 1.0)
		hp = 0.7 * (hp + x - prev)
		prev = x
		s[i] = hp * exp(-t * 9.0) * 0.6
	for k in 26:
		var st := int(rng.randf_range(0.0, 0.7) * RATE)
		var f := rng.randf_range(2500.0, 6500.0)
		for j in int(RATE * 0.15):
			if st + j >= n:
				break
			var t := float(j) / RATE
			s[st + j] += sin(TAU * f * t) * exp(-t * 45.0) * 0.25
	_normalize(s, 0.8)
	var w := _to_wav(s, false)
	_sfx_cache["glass"] = w
	return w


static func thud_sound() -> AudioStreamWAV:
	if _sfx_cache.has("thud"):
		return _sfx_cache["thud"]
	var n := int(RATE * 0.35)
	var s := PackedFloat32Array()
	s.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.08
		s[i] = (sin(TAU * 70.0 * t) * 0.8 + lp * 2.0) * exp(-t * 18.0)
	_normalize(s, 0.8)
	var w := _to_wav(s, false)
	_sfx_cache["thud"] = w
	return w


# ---------------------------------------------------------------- воспроизведение

func play_at(stream: AudioStream, pos: Vector3, vol_db: float, pitch: float = 1.0) -> void:
	var p := _pool[_pool_i]
	_pool_i = (_pool_i + 1) % _pool.size()
	p.stream = stream
	p.global_position = pos
	p.volume_db = vol_db + linear_to_db(max(float(Settings.get_v("volume_fx")), 0.0001))
	p.pitch_scale = pitch * clamp(Engine.time_scale * 1.5, 0.35, 1.0)
	p.play()


func play_crash(pos: Vector3, strength: float) -> void:
	if strength < 1.5:
		return
	if strength < 4.0:
		play_at(thud_sound(), pos, -10.0 + strength * 2.0, randf_range(0.85, 1.15))
		return
	var v := clampi(int(strength / 5.0), 0, 3)
	play_at(crash_sound(v), pos, clamp(-8.0 + strength * 0.7, -8.0, 6.0), randf_range(0.85, 1.1))


func play_glass(pos: Vector3) -> void:
	play_at(glass_sound(), pos, 0.0, randf_range(0.9, 1.1))


## Движок звука машин: включаем 3D-звук только у ближайших к камере
func _process(delta: float) -> void:
	_assign_t -= delta
	if _assign_t > 0.0:
		return
	_assign_t = 0.4
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var cp := cam.global_position
	var list: Array = []
	for c in Game.cars:
		if is_instance_valid(c):
			list.append([c.global_position.distance_squared_to(cp), c])
	list.sort_custom(func(a, b): return a[0] < b[0])
	var max_n := 4 if int(Settings.get_v("quality_level")) >= 1 else 2
	var want := {}
	for i in min(max_n, list.size()):
		var c: Car = list[i][1]
		if list[i][0] < 90.0 * 90.0 or c.is_player:
			want[c] = true
	for c in Game.cars:
		if c.is_player:
			want[c] = true
	# удаляем лишние
	for c in _cars_audio.keys():
		if not want.has(c) or not is_instance_valid(c):
			var ca = _cars_audio[c]
			if is_instance_valid(ca):
				ca.queue_free()
			_cars_audio.erase(c)
	for c in want:
		if not _cars_audio.has(c):
			var ca := CarAudio.new()
			c.add_child(ca)
			ca.setup(c)
			_cars_audio[c] = ca
