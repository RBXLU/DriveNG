class_name RoadNetwork
extends RefCounted

## Граф полос движения для ИИ: полосы — ломаные с длинами, переходы между
## полосами, перекрёстки со светофорами (две фазы + жёлтый).

class Lane:
	var id := 0
	var pts := PackedVector3Array()
	var cum := PackedFloat32Array()
	var length := 0.0
	var next: Array[int] = []
	var speed := 14.0
	var inter: Intersection = null   # светофор в конце полосы
	var axis := 0                   # 0 — ось X, 1 — ось Z
	var connector := false
	var loop := false

	func finalize() -> void:
		cum.resize(pts.size())
		var d := 0.0
		cum[0] = 0.0
		for i in range(1, pts.size()):
			d += pts[i].distance_to(pts[i - 1])
			cum[i] = d
		length = d

	func _seg(s: float) -> int:
		# бинарный поиск сегмента
		var lo := 0
		var hi := cum.size() - 1
		while hi - lo > 1:
			var mid := (lo + hi) >> 1
			if cum[mid] <= s:
				lo = mid
			else:
				hi = mid
		return lo

	func point_at(s: float) -> Vector3:
		s = clamp(s, 0.0, length)
		var i := _seg(s)
		if i >= pts.size() - 1:
			return pts[pts.size() - 1]
		var seg_len := cum[i + 1] - cum[i]
		var t := (s - cum[i]) / seg_len if seg_len > 1e-5 else 0.0
		return pts[i].lerp(pts[i + 1], t)

	func dir_at(s: float) -> Vector3:
		var i := _seg(clamp(s, 0.0, length))
		i = clampi(i, 0, pts.size() - 2)
		return (pts[i + 1] - pts[i]).normalized()

	## Ближайшая точка на полосе рядом с подсказкой hint (м)
	func project(p: Vector3, hint: float, window: float = 30.0) -> float:
		var best := hint
		var best_d := 1e18
		var i0 := _seg(clamp(hint - window, 0.0, length))
		var i1 := _seg(clamp(hint + window, 0.0, length))
		for i in range(i0, min(i1 + 1, pts.size() - 1)):
			var a := pts[i]
			var b := pts[i + 1]
			var ab := b - a
			var l2 := ab.length_squared()
			var t: float = clamp((p - a).dot(ab) / l2, 0.0, 1.0) if l2 > 1e-6 else 0.0
			var q := a + ab * t
			var d := q.distance_squared_to(p)
			if d < best_d:
				best_d = d
				best = cum[i] + sqrt(l2) * t
		return best


class Intersection:
	var pos := Vector3.ZERO
	var phase := 0          # 0 — зелёный по X, 1 — жёлтый по X, 2 — зелёный по Z, 3 — жёлтый по Z
	var timer := 0.0
	var green_time := 14.0
	var yellow_time := 3.0
	var occupants := 0

	func state_for(axis: int) -> int:
		# 0 зелёный, 1 жёлтый, 2 красный
		if axis == 0:
			return [0, 1, 2, 2][phase]
		return [2, 2, 0, 1][phase]

	func update(dt: float) -> bool:
		timer += dt
		var lim := green_time if phase % 2 == 0 else yellow_time
		if timer >= lim:
			timer = 0.0
			phase = (phase + 1) % 4
			return true
		return false


var lanes: Array[Lane] = []
var intersections: Array[Intersection] = []
signal lights_changed(inter: Intersection)


func add_lane(pts: PackedVector3Array, speed: float) -> Lane:
	var l := Lane.new()
	l.id = lanes.size()
	l.pts = pts
	l.speed = speed
	l.finalize()
	lanes.append(l)
	return l


func link(a: Lane, b: Lane) -> void:
	if not a.next.has(b.id):
		a.next.append(b.id)


func update(dt: float) -> void:
	for it in intersections:
		if it.update(dt):
			lights_changed.emit(it)


## Случайная точка на полосах на расстоянии [min_d, max_d] от pos
func random_spawn(pos: Vector3, min_d: float, max_d: float, rng: RandomNumberGenerator) -> Array:
	if lanes.is_empty():
		return []
	for attempt in 40:
		var l: Lane = lanes[rng.randi() % lanes.size()]
		if l.connector or l.length < 20.0:
			continue
		var s := rng.randf_range(5.0, l.length - 8.0)
		var p := l.point_at(s)
		var d := p.distance_to(pos)
		if d >= min_d and d <= max_d:
			return [l, s]
	return []


## Ближайшая полоса к точке (для старта игрока/ботов)
func nearest(pos: Vector3, dir: Vector3 = Vector3.ZERO) -> Array:
	var best: Array = []
	var bd := 1e18
	for l in lanes:
		if l.connector:
			continue
		var step: int = max(1, l.pts.size() / 60)
		var i := 0
		while i < l.pts.size():
			var d := l.pts[i].distance_squared_to(pos)
			if dir != Vector3.ZERO and i < l.pts.size() - 1:
				if (l.pts[min(i + 1, l.pts.size() - 1)] - l.pts[i]).normalized().dot(dir) < 0.3:
					d += 1e6
			if d < bd:
				bd = d
				best = [l, l.cum[i]]
			i += step
	if not best.is_empty():
		var l2: Lane = best[0]
		best[1] = l2.project(pos, best[1], 80.0)
	return best
