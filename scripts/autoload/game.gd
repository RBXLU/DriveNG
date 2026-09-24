extends Node

## Глобальное состояние: выбор игрока, текущий мир, реестры машин и обломков.

signal hud_message(text: String)

const MAPS := [
	{"id": "testgrounds", "name": "Краш-полигон", "desc": "Огромная бетонная площадка: стены для краш-тестов, трамплины, отбойники, фонарные столбы, конусы и ряды припаркованных машин.", "traffic": false},
	{"id": "city", "name": "Город", "desc": "Сетка кварталов со светофорами, тротуарами, фонарями и плотным городским трафиком.", "traffic": true},
	{"id": "highway", "name": "Шоссе", "desc": "Кольцевая шестиполосная трасса с отбойником посередине и быстрым потоком машин.", "traffic": true},
	{"id": "mountain", "name": "Горный перевал", "desc": "Серпантин среди холмов и леса: отбойники, обрывы, озеро. Встречные машины на узкой дороге.", "traffic": true},
	{"id": "derby", "name": "Дерби-арена", "desc": "Грунтовая арена за бетонными стенами. Боты таранят всех подряд — выживает последний.", "traffic": false},
]

const TIMES := ["День", "Закат", "Ночь"]
const TRAFFIC := ["Нет", "Мало", "Средне", "Много"]

var selected_car := "vostok_2107"
var selected_color := 0
var selected_map := "testgrounds"
var time_of_day := 0
var traffic_density := 2

var world: Node = null
var map: Node = null
var player: Car = null
var cars: Array[Car] = []
var fx: Node = null
var audio: Node = null
var debris_root: Node3D = null
var debris: Array[RigidBody3D] = []
var slowmo_levels := [1.0, 0.5, 0.25, 0.1]
var slowmo_index := 0


func register_car(c: Car) -> void:
	if not cars.has(c):
		cars.append(c)


func unregister_car(c: Car) -> void:
	cars.erase(c)


func register_debris(b: RigidBody3D) -> void:
	debris.append(b)
	var maxd: int = int(Settings.get_v("max_debris"))
	while debris.size() > maxd:
		var old: RigidBody3D = debris.pop_front()
		if is_instance_valid(old):
			old.queue_free()


func clear_world_refs() -> void:
	cars.clear()
	debris.clear()
	player = null
	map = null
	fx = null
	debris_root = null
	world = null
	set_slowmo(0)


func set_slowmo(i: int) -> void:
	slowmo_index = clampi(i, 0, slowmo_levels.size() - 1)
	Engine.time_scale = slowmo_levels[slowmo_index]


func cycle_slowmo() -> void:
	set_slowmo((slowmo_index + 1) % slowmo_levels.size())


func message(text: String) -> void:
	hud_message.emit(text)


func car_color() -> Color:
	var spec := CarDatabase.get_car(selected_car)
	var cols: Array = spec["colors"]
	return cols[clampi(selected_color, 0, cols.size() - 1)]


func map_info(id: String) -> Dictionary:
	for m in MAPS:
		if m["id"] == id:
			return m
	return MAPS[0]
