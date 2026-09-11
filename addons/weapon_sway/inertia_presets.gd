extends RefCounted
## Presets change inertia only, leaving breathing and stance settings intact.
const NAMES = [
	"01 · Невесомое",
	"02 · Лёгкое",
	"03 · Быстрый пистолет",
	"04 · Упругое",
	"05 · Сбалансированное",
	"06 · Тяжёлый автомат",
	"07 · Вязкое",
	"08 · Тяжёлое и упругое",
	"09 · Очень вязкое",
	"10 · Максимальный вес"
]
# mass, stiffness, damping, lag, angle, translation gain, roll
const SETTINGS = [
	[0.5, 240.0, 20.0, 0.018, 1.0, 0.10, 0.10],
	[0.7, 220.0, 22.0, 0.025, 1.4, 0.13, 0.15],
	[0.9, 210.0, 25.0, 0.035, 1.8, 0.16, 0.20],
	[1.2, 200.0, 22.0, 0.045, 2.3, 0.19, 0.25],
	[1.5, 180.0, 30.0, 0.055, 2.8, 0.22, 0.30],
	[2.0, 170.0, 33.0, 0.070, 3.4, 0.25, 0.35],
	[2.3, 155.0, 43.0, 0.085, 3.8, 0.28, 0.38],
	[3.0, 150.0, 32.0, 0.100, 4.5, 0.31, 0.42],
	[3.5, 130.0, 52.0, 0.120, 5.0, 0.34, 0.45],
	[4.5, 110.0, 50.0, 0.150, 6.0, 0.38, 0.50],
]


static func values(index: int) -> Dictionary:
	if index < 0 or index >= SETTINGS.size():
		return {}
	var row = SETTINGS[index]
	return {
		"enabled": true,
		"spring_enabled": true,
		"spring_mass": row[0],
		"spring_stiffness": row[1],
		"spring_damping": row[2],
		"lag_seconds": row[3],
		"max_angle_degrees": row[4],
		"position_gain": row[5],
		"max_offset": 0.035,
		"roll_ratio": row[6],
		"aim_multiplier": 0.1,
	}
