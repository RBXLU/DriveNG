extends Node3D

# Автотест: собрать все машины, дать им встать на колёса, разогнать и врезать в стену.

var frame := 0
var cars: Array = []
var wall: StaticBody3D
var phase := 0
var t0 := 0

func _ready() -> void:
	var floor := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = WorldBoundaryShape3D.new()
	floor.add_child(cs)
	add_child(floor)
	Game.debris_root = self
	var x := 0.0
	var t_start := Time.get_ticks_msec()
	for c in CarDatabase.CARS:
		var t := Time.get_ticks_msec()
		var car := Car.new()
		car.setup(c, c["colors"][0], false)
		add_child(car)
		car.global_position = Vector3(x, 0.05, 0)
		cars.append(car)
		var nv := 0
		for p in car.parts:
			nv += p.verts.size()
		print("%-22s build %3d ms, parts %2d, verts %5d" % [c["id"], Time.get_ticks_msec() - t, car.parts.size(), nv])
		x += 14.0
	print("all built in ", Time.get_ticks_msec() - t_start, " ms")

func _physics_process(_delta: float) -> void:
	frame += 1
	if frame == 90:
		var bad := 0
		for car in cars:
			var y: float = car.global_position.y
			var up: float = car.global_transform.basis.y.y
			var ok: bool = abs(y) < 0.2 and up > 0.99
			if not ok:
				bad += 1
			print("rest %-22s y=%.3f up=%.3f comp0=%.3f sag=%.3f %s" % [car.spec["id"], y, up, car.wheels[0].comp, car.wheels[0].sag, "" if ok else "  <-- BAD"])
		print("REST_BAD=", bad)
		# стена впереди всех машин (перед машины — -Z)
		wall = StaticBody3D.new()
		var ws := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = Vector3(400, 3, 1)
		ws.shape = bx
		wall.add_child(ws)
		add_child(wall)
		wall.global_position = Vector3(150, 1.5, -60)
		for car in cars:
			car.controller = FullThrottle.new()
	if frame > 90 and frame < 900:
		pass
	if frame == 900:
		for car in cars:
			var parts_lost := 0
			for p in car.parts:
				if not p.attached:
					parts_lost += 1
			print("crash %-22s dmg=%.2f engine=%.2f lost=%d glass=%s z=%.1f" % [car.spec["id"], car.total_damage, car.engine_health, parts_lost, car.damage.glass_broken, car.global_position.z])
		get_tree().quit()

class FullThrottle:
	var max_speed := 0.0
	func update(car, _dt):
		car.throttle = 1.0
		car.brake = 0.0
		car.steer = 0.0
		max_speed = max(max_speed, car.speed)
