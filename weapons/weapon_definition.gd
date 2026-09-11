extends Resource
const SwayProfile = preload("res://addons/weapon_sway/sway_profile.gd")
const ControlProfile = preload("res://addons/weapon_control/weapon_profile.gd")
## Weapon data shared by first-person presentation and authoritative damage calculation.

@export var display_name: String
@export var sway_profile: SwayProfile
@export var control_profile: ControlProfile
@export_file("*.glb") var model_path: String
@export var magazine_size: int = 30
@export var starting_reserve: int = 90
@export var muzzle_skeleton: NodePath
@export var muzzle_bone: StringName
@export var muzzle_position: Vector3
@export var damage: int = 34
@export var shot_seconds: float = 0.12
@export var automatic: bool = true
## Semi-auto clicks can interrupt the shot animation without a firing cooldown.
@export var unlimited_click_fire: bool = false
@export var hip_position: Vector3
@export var rear_sight: Vector3
@export var front_sight: Vector3
@export var sight_distance: float = 0.18
@export var run_pitch_degrees: float = -10.0
@export var run_vertical_offset: float = -0.025
@export var idle_cycle_seconds: float = 0.0
@export var source_fps: float = 30.0
@export var clip_suffixes: Dictionary = {}
@export var clip_frames: Dictionary = {}


func fires_on_every_click() -> bool:
	return unlimited_click_fire and not automatic
