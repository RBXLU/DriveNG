class_name Garage
extends Node3D

## Фон меню: машина на вращающемся подиуме.

var car: Car
var cam: Camera3D
var pivot: Node3D
var _t := 0.0
var _id := ""
var _color := Color.WHITE


func _ready() -> void:
	var atm := Atmosphere.new()
	add_child(atm)
	atm.setup(1)
	atm.sun.shadow_enabled = int(Settings.get_v("shadows")) > 0
	# подиум
	var floor := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 5.0
	cm.bottom_radius = 5.2
	cm.height = 0.2
	cm.radial_segments = 48
	floor.mesh = cm
	floor.position.y = -0.1
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.08, 0.085, 0.1)
	fm.metallic = 0.3
	fm.roughness = 0.25
	floor.material_override = fm
	add_child(floor)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(300, 300)
	ground.mesh = pm
	ground.position.y = -0.2
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.3, 0.3, 0.3)
	gm.roughness = 0.9
	ground.material_override = gm
	add_child(ground)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 5.1
	tm.outer_radius = 5.25
	ring.mesh = tm
	var rm := StandardMaterial3D.new()
	rm.albedo_color = UIKit.ACCENT
	rm.emission_enabled = true
	rm.emission = UIKit.ACCENT
	rm.emission_energy_multiplier = 2.0
	ring.material_override = rm
	add_child(ring)
	pivot = Node3D.new()
	add_child(pivot)
	cam = Camera3D.new()
	cam.fov = 45
	add_child(cam)
	cam.current = true


func show_car(id: String, color: Color) -> void:
	if id == _id and color == _color and car != null:
		return
	_id = id
	_color = color
	if car != null:
		car.queue_free()
	var spec := CarDatabase.get_car(id)
	car = Car.new()
	car.setup(spec, color, false)
	car.freeze = true
	car.controller = null
	pivot.add_child(car)
	car.position = Vector3(0, 0.0, 0)


func _process(delta: float) -> void:
	_t += delta
	pivot.rotation.y = _t * 0.25
	if car != null:
		var L: float = car.spec["L"]
		var d: float = clamp(L * 1.25 + 3.0, 6.5, 19.0)
		# сдвигаем кадр: машина справа, слева — панель меню
		cam.position = Vector3(d * 0.62, 1.5 + L * 0.08, d * 0.78)
		cam.look_at(Vector3(0, 0.7, 0))
		var aspect: float = get_viewport().get_visible_rect().size.aspect()
		cam.h_offset = -d * 0.2 * clamp(aspect / 1.78, 0.6, 1.4)
