extends Node3D

# Визуальный тест: несколько машин (часть — разбитые), снимок экрана в user://shots.
var frame := 0
var cam: Camera3D
var shots := []
var cars := []

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var ids: Array = ["vostok_2107", "kaiser_golfer", "hayato_landmaster", "bellini_furia", "liberty_interceptor", "gazel"]
	var tod := 0
	for a in args:
		if a.begins_with("cars="):
			ids = a.substr(5).split(",")
		if a.begins_with("tod="):
			tod = int(a.substr(4))
	var atm := Atmosphere.new()
	add_child(atm)
	atm.setup(tod)
	var floor := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(400, 400)
	floor.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.42, 0.42, 0.4)
	fm.roughness = 0.9
	floor.material_override = fm
	add_child(floor)
	var x := -float(ids.size() - 1) * 3.2 * 0.5
	var i := 0
	for id in ids:
		var spec := CarDatabase.get_car(id)
		var car := Car.new()
		car.setup(spec, spec["colors"][0], false)
		car.freeze = true
		add_child(car)
		car.global_position = Vector3(x, 0, 0)
		car.rotation.y = 0.5 + PI
		cars.append(car)
		if i % 2 == 1:
			# удар спереди-слева
			var L: float = spec["L"]
			car.damage.dent(Vector3(-0.4, 0.6, -L * 0.5), Vector3(0.3, 0, 1).normalized(), 0.45, 0.9)
			car.damage.dent(Vector3(float(spec["W"]) * 0.5, 0.7, 0.2), Vector3(-1, 0, 0), 0.25, 0.8)
			for p in car.parts:
				if p.kind == "hood":
					p.loose = true
			car.damage.break_glass()
		x += 3.2
		i += 1
	cam = Camera3D.new()
	add_child(cam)
	cam.fov = 60
	cam.global_position = Vector3(0, 3.2, 9.5)
	cam.look_at(Vector3(0, 0.6, 0))

func _process(_d: float) -> void:
	frame += 1
	for c in cars:
		for p in c.parts:
			p.rebuild()
	if frame == 40:
		var img := get_viewport().get_texture().get_image()
		var path := "user://shot_%s.png" % str(Time.get_ticks_msec())
		for a in OS.get_cmdline_user_args():
			if a.begins_with("out="):
				path = a.substr(4)
		img.save_png(path)
		print("saved ", path)
		get_tree().quit()
