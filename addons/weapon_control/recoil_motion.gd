extends RefCounted
const Mode = preload("res://addons/weapon_control/fire_mode.gd")
var _rotation := Vector3.ZERO
var _push: float = 0.0
var _sequence: int = 0
var _idle: float = 0.0
var rng = RandomNumberGenerator.new()


func _init() -> void:
	rng.randomize()


func reset() -> void:
	_rotation = Vector3.ZERO
	_push = 0.0
	_sequence = 0
	_idle = 0.0


func shot(mode: Mode, multiplier: float) -> Vector2:
	if _idle > 0.5:
		_sequence = 0
	_idle = 0.0
	var pattern = (
		mode.yaw_pattern[_sequence % mode.yaw_pattern.size()]
		if not mode.yaw_pattern.is_empty()
		else 0.0
	)
	_sequence += 1
	var yaw = (
		-(mode.lateral_drift + pattern + rng.randf_range(-mode.yaw_random, mode.yaw_random))
		* multiplier
	)
	_rotation += Vector3(
		deg_to_rad(mode.visual_pitch * multiplier), deg_to_rad(yaw), deg_to_rad(yaw * 0.5)
	)
	_rotation = _rotation.limit_length(deg_to_rad(mode.visual_angle_limit))
	_push = minf(_push + mode.kickback * multiplier, mode.kickback_limit)
	return Vector2(deg_to_rad(mode.pitch_kick * multiplier), deg_to_rad(yaw))


func step(mode: Mode, delta: float) -> Transform3D:
	_idle += delta
	if mode == null:
		reset()
		return Transform3D.IDENTITY
	var decay = exp(-maxf(mode.visual_recovery, 0.0) * delta)
	_rotation *= decay
	_push *= decay
	return Transform3D(Basis.from_euler(_rotation), Vector3(0, 0, _push))
