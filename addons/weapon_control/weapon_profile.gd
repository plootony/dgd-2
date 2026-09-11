@tool
class_name WeaponControlProfile
extends Resource

const Mode = preload("res://addons/weapon_control/fire_mode.gd")
enum FireMode { SINGLE, BURST, AUTO }
const MODE_NAMES = ["Одиночный", "Очередь", "Автоматический"]
@export var display_name: String = "Оружие"
@export_enum("Одиночный", "Очередь", "Автоматический") var default_mode: int = FireMode.SINGLE
@export var single: Mode = Mode.new()
@export var burst: Mode = Mode.new()
@export var automatic: Mode = Mode.new()
@export_group("Множители стойки и движения")
@export_range(0.0, 3.0, 0.05) var crouch_spread: float = 0.7
@export_range(0.0, 3.0, 0.05) var moving_spread: float = 1.6
@export_range(0.0, 3.0, 0.05) var airborne_spread: float = 2.0
@export_range(0.0, 3.0, 0.05) var focused_spread: float = 0.6
@export_range(0.0, 3.0, 0.05) var crouch_recoil: float = 0.8
@export_range(0.0, 3.0, 0.05) var moving_recoil: float = 1.2
@export_range(0.0, 3.0, 0.05) var focused_recoil: float = 0.75


func mode(id: int) -> Mode:
	return [single, burst, automatic][id] if id >= 0 and id < 3 else null


func available_modes() -> Array[int]:
	var result: Array[int] = []
	for id in 3:
		if mode(id) != null and mode(id).enabled:
			result.append(id)
	return result


func initial_mode() -> int:
	var available = available_modes()
	return (
		default_mode
		if default_mode in available
		else (available[0] if not available.is_empty() else -1)
	)


func spread_multiplier(crouched: bool, moving: bool, grounded: bool, focused: bool) -> float:
	return (
		(crouch_spread if crouched else 1.0)
		* (moving_spread if moving else 1.0)
		* (1.0 if grounded else airborne_spread)
		* (focused_spread if focused else 1.0)
	)


func recoil_multiplier(crouched: bool, moving: bool, focused: bool) -> float:
	return (
		(crouch_recoil if crouched else 1.0)
		* (moving_recoil if moving else 1.0)
		* (focused_recoil if focused else 1.0)
	)
