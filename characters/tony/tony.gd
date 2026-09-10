extends "res://characters/combat_actor.gd"
## Master simulates the shared NPC; without a room it runs as a local preview.
@export var run_speed: float = 6.0
var net_grounded: bool = false
var _target = Vector3(4, 0, 8)
var _action_time: float = 0
var _jump_time: float = 2
var _idle: bool = false
var _clip: String = ""
var _authority: bool = false
var jumps_performed: int = 0


func simulates() -> bool:
	return not Fusion.is_in_room() or replicator.has_authority()


func _physics_process(delta: float) -> void:
	if not simulates() or combat.is_dead():
		return
	_action_time -= delta
	_jump_time -= delta
	var offset = _target - global_position
	offset.y = 0
	if _action_time <= 0 or offset.length() < 0.7:
		_idle = randf() < 0.18
		_action_time = randf_range(0.8, 1.5) if _idle else randf_range(2, 4)
		_target = Vector3(randf_range(-10, 12), 0, randf_range(0, 13))
		offset = _target - global_position
		offset.y = 0
	var desired = Vector3.ZERO if _idle else offset.normalized() * run_speed
	velocity.x = lerpf(velocity.x, desired.x, minf(10 * delta, 1))
	velocity.z = lerpf(velocity.z, desired.z, minf(10 * delta, 1))
	if desired.length_squared() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(-desired.x, -desired.z), 1 - exp(-10 * delta))
	if is_on_floor():
		velocity.y = -0.5
		if not _idle and (_jump_time <= 0 or (is_on_wall() and _jump_time < 1)):
			velocity.y = 10
			_jump_time = randf_range(1.8, 3.5)
			jumps_performed += 1
	else:
		velocity.y -= 25 * delta
	move_and_slide()
	net_grounded = is_on_floor()
	if position.y < -10:
		if Fusion.is_in_room():
			replicator.teleport_3d(Vector3(4, 1, 7), Vector3.ZERO)
		else:
			position = Vector3(4, 1, 7)
			reset_physics_interpolation()
		velocity = Vector3.ZERO


func _process(_delta: float) -> void:
	if combat.is_dead():
		return
	var authority = simulates()
	if authority != _authority:
		_authority = authority
		physics_interpolation_mode = (
			Node.PHYSICS_INTERPOLATION_MODE_ON if authority else Node.PHYSICS_INTERPOLATION_MODE_OFF
		)
		reset_physics_interpolation()
	var speed = Vector2(velocity.x, velocity.z).length()
	var next = "Jump" if not net_grounded else ("Sprint" if speed > 0.2 else "Idle")
	if next != _clip:
		animation.play(next, 0.15)
		_clip = next
	animation.speed_scale = clampf(speed / run_speed, 0.5, 1.3) if next == "Sprint" else 1.0


func combat_die() -> void:
	super.combat_die()
	$Label.hide()


func combat_respawn(pos: Vector3) -> void:
	if simulates():
		if Fusion.is_in_room():
			replicator.teleport_3d(pos, Vector3.ZERO)
		else:
			global_position = pos
			reset_physics_interpolation()
	super.combat_respawn(pos)
	$Label.show()
	_clip = ""
	_action_time = 0.0


func get_respawn_position() -> Vector3:
	return Vector3(4, 1, 7)
