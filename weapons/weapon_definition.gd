extends Resource
## Weapon data shared by first-person presentation and authoritative damage calculation.

@export var display_name: String
@export_file("*.glb") var model_path: String
@export var damage: int = 34
@export var shot_seconds: float = 0.12
@export var automatic: bool = true
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
