@tool
class_name WeaponFireMode
extends Resource

@export var enabled: bool = true
@export_group("Режим стрельбы")
@export_range(0.02, 2.0, 0.01, "suffix:s") var interval: float = 0.12
@export var unlimited_single_clicks: bool = false
@export_range(2, 10, 1) var burst_count: int = 3
@export_group("Разброс — половина угла конуса")
@export_range(0.0, 15.0, 0.05, "degrees") var hip_spread: float = 1.5
@export_range(0.0, 15.0, 0.05, "degrees") var ads_spread: float = 0.15
@export_range(0.0, 5.0, 0.01, "degrees") var spread_per_shot: float = 0.12
@export_range(0.0, 15.0, 0.05, "degrees") var max_extra_spread: float = 2.0
@export_range(0.0, 20.0, 0.1) var spread_recovery: float = 3.0
@export_group("Отдача камеры за выстрел")
@export_range(0.0, 10.0, 0.05, "degrees") var pitch_kick: float = 0.8
@export_range(0.0, 5.0, 0.05, "degrees") var yaw_random: float = 0.15
## Positive means drift to the right. Pattern adds a repeatable horizontal sequence.
@export_range(-5.0, 5.0, 0.01, "degrees") var lateral_drift: float = 0.04
@export var yaw_pattern: PackedFloat32Array = PackedFloat32Array([-0.1, 0.1, 0.15, -0.05])
@export_range(0.0, 2.0, 0.01) var ads_recoil_multiplier: float = 0.65
@export_group("Процедурная отдача оружия")
@export_range(0.0, 15.0, 0.1, "degrees") var visual_pitch: float = 2.0
@export_range(0.0, 0.12, 0.001, "suffix:m") var kickback: float = 0.02
@export_range(1.0, 40.0, 0.5) var visual_recovery: float = 14.0
@export_range(0.0, 25.0, 0.1, "degrees") var visual_angle_limit: float = 10.0
@export_range(0.0, 0.2, 0.001, "suffix:m") var kickback_limit: float = 0.08
