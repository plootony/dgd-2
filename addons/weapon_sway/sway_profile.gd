@tool
class_name WeaponSwayProfile
extends Resource
## One reusable configuration per weapon. Runtime motion lives in SwayMotion.

@export var display_name: String = "Оружие"
@export var enabled: bool = true
@export_group("Инерция при поворотах камеры")
## Disable to keep the original exponential smoothing.
@export var spring_enabled: bool = false
@export_range(0.1, 10.0, 0.1) var spring_mass: float = 1.5
@export_range(1.0, 500.0, 1.0) var spring_stiffness: float = 180.0
@export_range(1.0, 150.0, 1.0) var spring_damping: float = 30.0
## Angular velocity multiplied by this duration determines the trailing angle.
@export_range(0.0, 0.3, 0.005, "suffix:s") var lag_seconds: float = 0.045
@export_range(1.0, 40.0, 0.5) var response_speed: float = 14.0
@export_range(1.0, 40.0, 0.5) var return_speed: float = 10.0
@export_range(0.0, 10.0, 0.1, "degrees") var max_angle_degrees: float = 2.5
## Camera-space translation in metres per radian of sway.
@export_range(0.0, 1.0, 0.01) var position_gain: float = 0.22
@export_range(0.0, 0.1, 0.001, "suffix:m") var max_offset: float = 0.015
@export_range(0.0, 1.0, 0.01) var roll_ratio: float = 0.3
## Zero preserves exact iron-sight alignment at full ADS.
@export_range(0.0, 1.0, 0.01) var aim_multiplier: float = 0.0

@export_group("Покачивание по Лиссажу")
@export var pattern_enabled: bool = true
## Horizontal and vertical angular amplitudes in degrees.
@export var base_amplitude_degrees: Vector2 = Vector2(0.3, 0.2)
@export_range(0.01, 3.0, 0.01, "suffix:Hz") var base_frequency_hz: float = 0.2
@export var frequency_ratio: Vector2 = Vector2(1.0, 2.0)
@export_range(-180.0, 180.0, 1.0, "degrees") var phase_degrees: float = 90.0
@export_range(0.0, 1.0, 0.01) var pattern_aim_multiplier: float = 1.0
@export_range(1.0, 30.0, 0.5) var context_response: float = 8.0

@export_group("Множители покачивания")
@export_range(0.0, 2.0, 0.01) var crouch_amplitude_multiplier: float = 0.5
@export_range(0.0, 2.0, 0.01) var prone_amplitude_multiplier: float = 0.3
@export_range(0.0, 3.0, 0.01) var moving_amplitude_multiplier: float = 1.15
@export_range(0.0, 3.0, 0.01) var moving_speed_multiplier: float = 1.5
@export_range(0.0, 2.0, 0.01) var focus_amplitude_multiplier: float = 0.4
@export_range(0.0, 2.0, 0.01) var focus_speed_multiplier: float = 0.4
