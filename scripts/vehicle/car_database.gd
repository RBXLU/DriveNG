class_name CarDatabase
extends RefCounted

## База автомобилей. Названия вымышленные (как в BeamNG), но характеристики
## взяты с реальных прототипов (поле "based"). Размеры — в метрах, масса — кг,
## мощность — л.с., момент — Н·м.

const CLASSES := ["Все", "Легковые", "Спорт", "Внедорожники", "Коммерческие", "Тяжёлые"]

const CARS: Array[Dictionary] = [
	{
		"id": "vostok_2107", "name": "Восток 2107", "based": "ВАЗ-2107", "class": "Легковые", "year": 1982,
		"body": "sedan", "boxy": true, "round_lights": false, "chrome": true,
		"L": 4.13, "W": 1.62, "H": 1.44, "clearance": 0.17, "wheelbase": 2.42, "wheel_r": 0.29, "wheel_w": 0.17,
		"mass": 1030, "hp": 72, "torque": 116, "torque_rpm": 3400, "redline": 6000, "idle": 800,
		"drive": "RWD", "gears": [3.67, 2.10, 1.36, 1.0, 0.82], "final": 4.1, "reverse": 3.53,
		"engine": "front", "sound": "i4", "grip": 0.92, "spring_hz": 1.3, "damping": 0.3,
		"cd": 0.48, "area": 1.9, "strength": 0.85, "steer_max": 34, "brake": 1500,
		"colors": [Color(0.92, 0.9, 0.84), Color(0.55, 0.05, 0.08), Color(0.12, 0.32, 0.55), Color(0.78, 0.72, 0.52), Color(0.2, 0.45, 0.25)],
	},
	{
		"id": "vostok_2109", "name": "Восток Спутник", "based": "ВАЗ-2109", "class": "Легковые", "year": 1987,
		"body": "hatch", "boxy": true,
		"L": 4.0, "W": 1.65, "H": 1.40, "clearance": 0.16, "wheelbase": 2.46, "wheel_r": 0.28, "wheel_w": 0.17,
		"mass": 945, "hp": 70, "torque": 106, "torque_rpm": 3400, "redline": 6200, "idle": 850,
		"drive": "FWD", "gears": [3.64, 1.95, 1.36, 0.94, 0.78], "final": 3.9, "reverse": 3.53,
		"engine": "front", "sound": "i4", "grip": 0.93, "spring_hz": 1.4, "damping": 0.3,
		"cd": 0.4, "area": 1.85, "strength": 0.85, "steer_max": 34, "brake": 1500,
		"colors": [Color(0.85, 0.85, 0.87), Color(0.08, 0.08, 0.09), Color(0.35, 0.05, 0.1), Color(0.1, 0.35, 0.3)],
	},
	{
		"id": "vostok_niva", "name": "Восток Нива 4x4", "based": "ВАЗ-2121 «Нива»", "class": "Внедорожники", "year": 1977,
		"body": "suv3", "boxy": true, "round_lights": true,
		"L": 3.74, "W": 1.68, "H": 1.64, "clearance": 0.22, "wheelbase": 2.2, "wheel_r": 0.36, "wheel_w": 0.19,
		"mass": 1210, "hp": 80, "torque": 127, "torque_rpm": 4000, "redline": 5800, "idle": 850,
		"drive": "AWD", "gears": [3.67, 2.10, 1.36, 1.0, 0.82], "final": 4.3, "reverse": 3.53,
		"engine": "front", "sound": "i4", "grip": 0.95, "spring_hz": 1.3, "damping": 0.32,
		"cd": 0.52, "area": 2.3, "strength": 1.0, "steer_max": 36, "brake": 1600,
		"colors": [Color(0.85, 0.83, 0.75), Color(0.2, 0.35, 0.15), Color(0.6, 0.12, 0.08), Color(0.25, 0.3, 0.4)],
	},
	{
		"id": "volna_24", "name": "Волна 24", "based": "ГАЗ-24 «Волга»", "class": "Легковые", "year": 1970,
		"body": "sedan", "boxy": true, "round_lights": true, "chrome": true,
		"L": 4.74, "W": 1.8, "H": 1.49, "clearance": 0.18, "wheelbase": 2.8, "wheel_r": 0.33, "wheel_w": 0.19,
		"mass": 1420, "hp": 95, "torque": 186, "torque_rpm": 2400, "redline": 5000, "idle": 700,
		"drive": "RWD", "gears": [3.5, 2.26, 1.45, 1.0], "final": 4.1, "reverse": 3.54,
		"engine": "front", "sound": "i4", "grip": 0.9, "spring_hz": 1.1, "damping": 0.25,
		"cd": 0.5, "area": 2.1, "strength": 1.15, "steer_max": 33, "brake": 1700,
		"colors": [Color(0.05, 0.05, 0.06), Color(0.9, 0.9, 0.88), Color(0.3, 0.45, 0.5), Color(0.85, 0.75, 0.4)],
	},
	{
		"id": "buhanka", "name": "Буханка 452", "based": "УАЗ-452", "class": "Внедорожники", "year": 1965,
		"body": "minivan", "round_lights": true,
		"L": 4.36, "W": 1.94, "H": 2.07, "clearance": 0.22, "wheelbase": 2.3, "wheel_r": 0.37, "wheel_w": 0.21,
		"mass": 1850, "hp": 112, "torque": 208, "torque_rpm": 2500, "redline": 4600, "idle": 750,
		"drive": "AWD", "gears": [4.12, 2.64, 1.58, 1.0], "final": 4.6, "reverse": 5.22,
		"engine": "front", "sound": "i4", "grip": 0.93, "spring_hz": 1.2, "damping": 0.3,
		"cd": 0.65, "area": 3.4, "strength": 1.1, "steer_max": 36, "brake": 2000, "roll_factor": 0.35,
		"colors": [Color(0.35, 0.42, 0.25), Color(0.85, 0.85, 0.8), Color(0.5, 0.55, 0.6), Color(0.75, 0.55, 0.2)],
	},
	{
		"id": "gazel", "name": "Газель Некст", "based": "ГАЗель Next", "class": "Коммерческие", "year": 2013,
		"body": "van",
		"L": 5.6, "W": 2.07, "H": 2.3, "clearance": 0.2, "wheelbase": 3.15, "wheel_r": 0.36, "wheel_w": 0.21,
		"front_overhang": 1.0,
		"mass": 2500, "hp": 150, "torque": 330, "torque_rpm": 1600, "redline": 4200, "idle": 750,
		"drive": "RWD", "gears": [5.1, 2.8, 1.6, 1.0, 0.79], "final": 4.3, "reverse": 4.8,
		"engine": "front", "sound": "diesel", "grip": 0.9, "spring_hz": 1.3, "damping": 0.3,
		"cd": 0.55, "area": 4.2, "strength": 1.2, "steer_max": 38, "brake": 3000, "roll_factor": 0.4,
		"colors": [Color(0.92, 0.92, 0.92), Color(0.15, 0.3, 0.6), Color(0.75, 0.1, 0.1), Color(0.95, 0.75, 0.1)],
	},
	{
		"id": "citybus", "name": "Ситибус 5292", "based": "ЛиАЗ-5292", "class": "Тяжёлые", "year": 2004,
		"body": "bus",
		"L": 12.0, "W": 2.5, "H": 3.0, "clearance": 0.3, "wheelbase": 5.84, "wheel_r": 0.5, "wheel_w": 0.3,
		"front_overhang": 2.6,
		"mass": 11500, "hp": 290, "torque": 1200, "torque_rpm": 1300, "redline": 2600, "idle": 600,
		"drive": "RWD", "gears": [3.4, 1.9, 1.4, 1.0, 0.75], "final": 5.7, "reverse": 4.5,
		"engine": "rear", "sound": "diesel", "grip": 0.85, "spring_hz": 1.2, "damping": 0.35,
		"cd": 0.7, "area": 7.5, "strength": 1.8, "steer_max": 40, "brake": 12000, "roll_factor": 0.3,
		"colors": [Color(0.95, 0.95, 0.95), Color(0.1, 0.4, 0.8), Color(0.9, 0.55, 0.1), Color(0.2, 0.55, 0.2)],
	},
	{
		"id": "titan_truck", "name": "Титан 65", "based": "КАМАЗ-65117", "class": "Тяжёлые", "year": 2010,
		"body": "truck", "axles": 3,
		"L": 8.9, "W": 2.5, "H": 3.3, "clearance": 0.35, "wheelbase": 4.4, "wheel_r": 0.55, "wheel_w": 0.35,
		"front_overhang": 1.45,
		"mass": 9500, "hp": 300, "torque": 1275, "torque_rpm": 1300, "redline": 2500, "idle": 600,
		"drive": "RWD", "gears": [7.8, 4.9, 3.1, 1.9, 1.3, 1.0, 0.8], "final": 4.9, "reverse": 7.0,
		"engine": "front", "sound": "diesel", "grip": 0.85, "spring_hz": 1.3, "damping": 0.35,
		"cd": 0.8, "area": 8.0, "strength": 2.0, "steer_max": 36, "brake": 14000, "roll_factor": 0.3,
		"colors": [Color(0.85, 0.35, 0.05), Color(0.1, 0.3, 0.6), Color(0.8, 0.1, 0.08), Color(0.95, 0.95, 0.9)],
		"color2": Color(0.3, 0.35, 0.25),
	},
	{
		"id": "kaiser_golfer", "name": "Кайзер Гольфер GTI", "based": "Volkswagen Golf GTI", "class": "Спорт", "year": 2020,
		"body": "hatch",
		"L": 4.28, "W": 1.79, "H": 1.44, "clearance": 0.13, "wheelbase": 2.63, "wheel_r": 0.33, "wheel_w": 0.225,
		"mass": 1430, "hp": 245, "torque": 370, "torque_rpm": 1600, "redline": 6800, "idle": 800,
		"drive": "FWD", "gears": [3.36, 2.09, 1.47, 1.1, 1.11, 0.92, 0.75], "final": 3.4, "reverse": 3.0,
		"engine": "front", "sound": "i4", "grip": 1.02, "spring_hz": 1.8, "damping": 0.38,
		"cd": 0.3, "area": 2.2, "strength": 1.0, "steer_max": 33, "brake": 2400,
		"colors": [Color(0.75, 0.05, 0.05), Color(0.95, 0.95, 0.95), Color(0.12, 0.12, 0.14), Color(0.2, 0.3, 0.55)],
	},
	{
		"id": "kaiser_s5", "name": "Кайзер S5 Спорт", "based": "BMW M5 (F90)", "class": "Спорт", "year": 2018,
		"body": "sedan",
		"L": 4.97, "W": 1.9, "H": 1.47, "clearance": 0.12, "wheelbase": 2.98, "wheel_r": 0.35, "wheel_w": 0.275,
		"mass": 1855, "hp": 600, "torque": 750, "torque_rpm": 1800, "redline": 7200, "idle": 750,
		"drive": "AWD", "gears": [5.0, 3.2, 2.14, 1.72, 1.31, 1.0, 0.82, 0.64], "final": 3.15, "reverse": 3.46,
		"engine": "front", "sound": "v8", "grip": 1.1, "spring_hz": 2.0, "damping": 0.4,
		"cd": 0.32, "area": 2.3, "strength": 1.1, "steer_max": 32, "brake": 3600, "downforce": 0.15,
		"colors": [Color(0.12, 0.25, 0.45), Color(0.08, 0.08, 0.09), Color(0.6, 0.62, 0.65), Color(0.55, 0.5, 0.35)],
	},
	{
		"id": "sturm_911", "name": "Штурм 911", "based": "Porsche 911 Carrera S", "class": "Спорт", "year": 2019,
		"body": "coupe911", "spoiler": "ducktail", "round_lights": true,
		"L": 4.52, "W": 1.85, "H": 1.30, "clearance": 0.11, "wheelbase": 2.45, "wheel_r": 0.34, "wheel_w": 0.28,
		"front_overhang": 1.0,
		"mass": 1515, "hp": 450, "torque": 530, "torque_rpm": 2300, "redline": 7500, "idle": 850,
		"drive": "RWD", "gears": [3.9, 2.3, 1.65, 1.29, 1.08, 0.88, 0.62], "final": 3.5, "reverse": 3.4,
		"engine": "rear", "sound": "boxer", "grip": 1.12, "spring_hz": 2.2, "damping": 0.42,
		"cd": 0.29, "area": 2.0, "strength": 1.0, "steer_max": 31, "brake": 3600, "downforce": 0.25,
		"colors": [Color(0.95, 0.75, 0.1), Color(0.95, 0.95, 0.95), Color(0.1, 0.1, 0.11), Color(0.75, 0.1, 0.08), Color(0.15, 0.4, 0.3)],
	},
	{
		"id": "hayato_crona", "name": "Хаято Крона", "based": "Toyota Corolla", "class": "Легковые", "year": 2019,
		"body": "sedan",
		"L": 4.63, "W": 1.78, "H": 1.43, "clearance": 0.14, "wheelbase": 2.7, "wheel_r": 0.32, "wheel_w": 0.205,
		"mass": 1310, "hp": 140, "torque": 175, "torque_rpm": 4400, "redline": 6600, "idle": 750,
		"drive": "FWD", "gears": [3.54, 2.05, 1.38, 1.03, 0.82, 0.67], "final": 4.1, "reverse": 3.2,
		"engine": "front", "sound": "i4", "grip": 0.98, "spring_hz": 1.5, "damping": 0.33,
		"cd": 0.28, "area": 2.15, "strength": 0.95, "steer_max": 34, "brake": 2200,
		"colors": [Color(0.8, 0.8, 0.82), Color(0.9, 0.9, 0.9), Color(0.15, 0.15, 0.17), Color(0.6, 0.1, 0.12), Color(0.25, 0.4, 0.6)],
	},
	{
		"id": "hayato_skyrider", "name": "Хаято Скайрайдер GT", "based": "Nissan GT-R (R35)", "class": "Спорт", "year": 2017,
		"body": "coupe", "spoiler": "wing",
		"L": 4.71, "W": 1.9, "H": 1.37, "clearance": 0.11, "wheelbase": 2.78, "wheel_r": 0.35, "wheel_w": 0.285,
		"mass": 1750, "hp": 570, "torque": 637, "torque_rpm": 3300, "redline": 7100, "idle": 800,
		"drive": "AWD", "gears": [4.06, 2.3, 1.6, 1.25, 1.0, 0.8], "final": 3.7, "reverse": 3.38,
		"engine": "front", "sound": "v6", "grip": 1.15, "spring_hz": 2.3, "damping": 0.42,
		"cd": 0.26, "area": 2.1, "strength": 1.05, "steer_max": 31, "brake": 3800, "downforce": 0.3,
		"colors": [Color(0.6, 0.62, 0.65), Color(0.95, 0.95, 0.95), Color(0.1, 0.1, 0.12), Color(0.1, 0.2, 0.55), Color(0.85, 0.35, 0.05)],
	},
	{
		"id": "hayato_landmaster", "name": "Хаято Лендмастер", "based": "Toyota Land Cruiser 200", "class": "Внедорожники", "year": 2016,
		"body": "suv",
		"L": 4.95, "W": 1.98, "H": 1.95, "clearance": 0.23, "wheelbase": 2.85, "wheel_r": 0.4, "wheel_w": 0.285,
		"mass": 2600, "hp": 309, "torque": 439, "torque_rpm": 3400, "redline": 5600, "idle": 700,
		"drive": "AWD", "gears": [3.33, 1.96, 1.35, 1.0, 0.73, 0.59], "final": 3.9, "reverse": 3.0,
		"engine": "front", "sound": "v8", "grip": 0.98, "spring_hz": 1.3, "damping": 0.33,
		"cd": 0.38, "area": 3.2, "strength": 1.3, "steer_max": 35, "brake": 3600, "roll_factor": 0.42,
		"colors": [Color(0.08, 0.08, 0.09), Color(0.92, 0.92, 0.9), Color(0.55, 0.57, 0.6), Color(0.35, 0.3, 0.25)],
	},
	{
		"id": "liberty_stallion", "name": "Либерти Сталлион GT", "based": "Ford Mustang GT", "class": "Спорт", "year": 2018,
		"body": "muscle", "spoiler": "lip",
		"L": 4.79, "W": 1.92, "H": 1.38, "clearance": 0.13, "wheelbase": 2.72, "wheel_r": 0.35, "wheel_w": 0.255,
		"mass": 1750, "hp": 450, "torque": 529, "torque_rpm": 4600, "redline": 7400, "idle": 750,
		"drive": "RWD", "gears": [3.66, 2.43, 1.69, 1.32, 1.0, 0.65], "final": 3.55, "reverse": 3.24,
		"engine": "front", "sound": "v8", "grip": 1.03, "spring_hz": 1.8, "damping": 0.38,
		"cd": 0.35, "area": 2.2, "strength": 1.05, "steer_max": 33, "brake": 3200,
		"colors": [Color(0.1, 0.25, 0.6), Color(0.85, 0.1, 0.08), Color(0.08, 0.08, 0.09), Color(0.95, 0.6, 0.05), Color(0.9, 0.9, 0.9)],
	},
	{
		"id": "liberty_fseries", "name": "Либерти F-серия", "based": "Ford F-150", "class": "Внедорожники", "year": 2018,
		"body": "pickup",
		"L": 5.9, "W": 2.03, "H": 1.96, "clearance": 0.24, "wheelbase": 3.68, "wheel_r": 0.41, "wheel_w": 0.275,
		"front_overhang": 0.95,
		"mass": 2100, "hp": 395, "torque": 542, "torque_rpm": 4500, "redline": 6000, "idle": 700,
		"drive": "RWD", "gears": [4.7, 2.99, 2.15, 1.77, 1.52, 1.28, 1.0, 0.85, 0.69, 0.64], "final": 3.3, "reverse": 4.8,
		"engine": "front", "sound": "v8", "grip": 0.96, "spring_hz": 1.4, "damping": 0.33,
		"cd": 0.45, "area": 3.4, "strength": 1.3, "steer_max": 36, "brake": 3400, "roll_factor": 0.42,
		"colors": [Color(0.7, 0.08, 0.06), Color(0.9, 0.9, 0.9), Color(0.1, 0.1, 0.11), Color(0.25, 0.3, 0.38), Color(0.5, 0.45, 0.35)],
	},
	{
		"id": "liberty_interceptor", "name": "Либерти Интерсептор", "based": "Ford Crown Victoria Police", "class": "Легковые", "year": 2005,
		"body": "sedan", "extra": "police",
		"L": 5.39, "W": 1.99, "H": 1.47, "clearance": 0.15, "wheelbase": 2.91, "wheel_r": 0.34, "wheel_w": 0.235,
		"mass": 1800, "hp": 250, "torque": 404, "torque_rpm": 4000, "redline": 5800, "idle": 650,
		"drive": "RWD", "gears": [2.84, 1.55, 1.0, 0.7], "final": 3.55, "reverse": 2.32,
		"engine": "front", "sound": "v8", "grip": 0.97, "spring_hz": 1.5, "damping": 0.34,
		"cd": 0.36, "area": 2.4, "strength": 1.2, "steer_max": 34, "brake": 3000,
		"colors": [Color(0.06, 0.06, 0.07)], "color2": Color(0.95, 0.95, 0.95),
	},
	{
		"id": "liberty_cab", "name": "Либерти Такси", "based": "Ford Crown Victoria Taxi", "class": "Легковые", "year": 2005,
		"body": "sedan", "extra": "taxi",
		"L": 5.39, "W": 1.99, "H": 1.47, "clearance": 0.15, "wheelbase": 2.91, "wheel_r": 0.34, "wheel_w": 0.225,
		"mass": 1780, "hp": 224, "torque": 373, "torque_rpm": 4000, "redline": 5600, "idle": 650,
		"drive": "RWD", "gears": [2.84, 1.55, 1.0, 0.7], "final": 3.27, "reverse": 2.32,
		"engine": "front", "sound": "v8", "grip": 0.93, "spring_hz": 1.2, "damping": 0.3,
		"cd": 0.36, "area": 2.4, "strength": 1.2, "steer_max": 34, "brake": 2800,
		"colors": [Color(0.98, 0.78, 0.08)],
	},
	{
		"id": "bellini_furia", "name": "Беллини Фурия", "based": "Lamborghini Huracán", "class": "Спорт", "year": 2015,
		"body": "supercar", "spoiler": "lip",
		"L": 4.46, "W": 1.93, "H": 1.17, "clearance": 0.1, "wheelbase": 2.62, "wheel_r": 0.345, "wheel_w": 0.3,
		"mass": 1422, "hp": 610, "torque": 560, "torque_rpm": 6500, "redline": 8500, "idle": 950,
		"drive": "AWD", "gears": [3.13, 2.59, 1.96, 1.57, 1.29, 1.08, 0.9], "final": 3.8, "reverse": 2.8,
		"engine": "mid", "sound": "v10", "grip": 1.2, "spring_hz": 2.5, "damping": 0.45,
		"cd": 0.33, "area": 1.9, "strength": 0.95, "steer_max": 30, "brake": 4200, "downforce": 0.35,
		"colors": [Color(0.55, 0.85, 0.1), Color(0.95, 0.55, 0.05), Color(0.9, 0.9, 0.9), Color(0.08, 0.08, 0.1), Color(0.7, 0.05, 0.08)],
	},
	{
		"id": "nordhaus_240", "name": "Нордхаус 240", "based": "Volvo 240 Estate", "class": "Легковые", "year": 1985,
		"body": "wagon", "boxy": true, "chrome": true,
		"L": 4.79, "W": 1.71, "H": 1.46, "clearance": 0.16, "wheelbase": 2.64, "wheel_r": 0.31, "wheel_w": 0.185,
		"mass": 1350, "hp": 115, "torque": 185, "torque_rpm": 2750, "redline": 5800, "idle": 800,
		"drive": "RWD", "gears": [4.03, 2.16, 1.37, 1.0, 0.83], "final": 3.73, "reverse": 3.68,
		"engine": "front", "sound": "i4", "grip": 0.92, "spring_hz": 1.3, "damping": 0.3,
		"cd": 0.46, "area": 2.1, "strength": 1.4, "steer_max": 34, "brake": 1900,
		"colors": [Color(0.25, 0.35, 0.28), Color(0.85, 0.83, 0.78), Color(0.45, 0.12, 0.1), Color(0.3, 0.35, 0.5)],
	},
	{
		"id": "minima", "name": "Минима Купер S", "based": "MINI Cooper S", "class": "Легковые", "year": 2015,
		"body": "hatch_small", "round_lights": true,
		"L": 3.85, "W": 1.73, "H": 1.41, "clearance": 0.13, "wheelbase": 2.5, "wheel_r": 0.31, "wheel_w": 0.205,
		"mass": 1250, "hp": 192, "torque": 280, "torque_rpm": 1250, "redline": 6500, "idle": 800,
		"drive": "FWD", "gears": [3.92, 2.13, 1.37, 1.03, 0.84, 0.69], "final": 3.6, "reverse": 3.7,
		"engine": "front", "sound": "i4", "grip": 1.02, "spring_hz": 1.9, "damping": 0.38,
		"cd": 0.33, "area": 2.0, "strength": 0.9, "steer_max": 34, "brake": 2400,
		"colors": [Color(0.1, 0.35, 0.2), Color(0.75, 0.05, 0.05), Color(0.9, 0.9, 0.9), Color(0.2, 0.45, 0.75), Color(0.1, 0.1, 0.1)],
	},
	{
		"id": "voltra_s", "name": "Вольтра S", "based": "Tesla Model S", "class": "Спорт", "year": 2020,
		"body": "fastback", "ev": true,
		"L": 4.97, "W": 1.96, "H": 1.44, "clearance": 0.13, "wheelbase": 2.96, "wheel_r": 0.35, "wheel_w": 0.245,
		"mass": 2200, "hp": 670, "torque": 1000, "torque_rpm": 0, "redline": 16000, "idle": 0,
		"drive": "AWD", "gears": [1.0], "final": 9.7, "reverse": 9.7,
		"engine": "front", "sound": "ev", "grip": 1.05, "spring_hz": 1.7, "damping": 0.38,
		"cd": 0.24, "area": 2.3, "strength": 1.1, "steer_max": 33, "brake": 3600,
		"colors": [Color(0.9, 0.9, 0.9), Color(0.08, 0.08, 0.09), Color(0.7, 0.05, 0.05), Color(0.1, 0.25, 0.55), Color(0.45, 0.47, 0.5)],
	},
]


static func get_car(id: String) -> Dictionary:
	for c in CARS:
		if c["id"] == id:
			return c
	return CARS[0]


static func index_of(id: String) -> int:
	for i in CARS.size():
		if CARS[i]["id"] == id:
			return i
	return 0


static func random_traffic_id(rng: RandomNumberGenerator, allow_heavy: bool) -> String:
	# Взвешенный выбор: обычные машины встречаются чаще спортивных
	var pool: Array[String] = []
	for c in CARS:
		var w := 3
		match c["class"]:
			"Спорт": w = 1
			"Тяжёлые": w = 1 if allow_heavy else 0
			"Коммерческие": w = 2
		if c.get("extra", "") == "police":
			w = 1
		for i in w:
			pool.append(c["id"])
	return pool[rng.randi() % pool.size()]


## Максимальная скорость (оценка) и разгон — для карточки в меню
static func estimate_top_speed(c: Dictionary) -> float:
	var p: float = c["hp"] * 735.5
	var rho_cda: float = 0.5 * 1.225 * c["cd"] * c["area"]
	var v := pow(p * 0.85 / rho_cda, 1.0 / 3.0)
	# ограничение по передаточным числам
	var gears: Array = c["gears"]
	var top_ratio: float = gears[gears.size() - 1] * c["final"]
	var v_gear: float = (c["redline"] / 60.0) * TAU / top_ratio * c["wheel_r"]
	return min(v, v_gear) * 3.6


static func power_to_weight(c: Dictionary) -> float:
	return c["hp"] / (c["mass"] / 1000.0)
