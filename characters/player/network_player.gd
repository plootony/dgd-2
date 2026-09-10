class_name NetworkPlayer
extends "res://characters/combat_actor.gd"

@export var walk_speed: float = 3.0
@export var run_speed: float = 6.0
@export var crouch_speed: float = 1.5
@export var acceleration: float = 10.0
@export var gravity: float = 25.0
@export var jump_speed: float = 10.0
@export var sensitivity: float = 0.002

var net_crouched: bool = false
var net_grounded: bool = false
var net_pitch: float = 0.0
var net_nickname: String = "Player"
var offline: bool = false
var third_person: bool = true
var input_enabled: bool = true
var _yaw: float = 0.0
var _jump_requested: bool = false
var _height: float = 1.8
var _eye_height: float = 1.62
var _visual_heading: float = PI
var _clip: String = ""
var _land_time: float = 0.0
var _was_grounded: bool = false
var _meshes: Array[MeshInstance3D] = []
var first_person_weapons: CanvasLayer
var _death_camera_time: float = 0.0
var _death_camera_origin: Vector3

@onready var model: Node3D = $Visual/Model
@onready var rig: Node3D = $CameraRig
@onready var arm: SpringArm3D = $CameraRig/SpringArm3D
@onready var camera: Camera3D = $CameraRig/SpringArm3D/Camera3D
@onready var nickname: Label3D = $Nickname


func is_local() -> bool:
	return offline or replicator.has_authority()


func _ready() -> void:
	super._ready()
	_yaw = rotation.y
	collider.shape = collider.shape.duplicate()
	for node in model.find_children("*", "MeshInstance3D", true, false):
		_meshes.append(node)
	arm.add_excluded_object(get_rid())
	rig.top_level = true
	rig.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if is_local():
		camera.current = true
		first_person_weapons = preload("res://weapons/first_person_weapons.gd").new()
		first_person_weapons.name = "FirstPersonWeapons"
		add_child(first_person_weapons)
		first_person_weapons.shot_fired.connect(fire_weapon)
	else:
		physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		camera.current = false
	nickname.visible = not is_local()
	_update_view()


func _unhandled_input(event: InputEvent) -> void:
	if not is_local() or not input_enabled or combat.is_dead():
		return
	if event.is_action_pressed("view_toggle"):
		third_person = not third_person
		_update_view()
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event.is_action_pressed("weapon_1"):
		first_person_weapons.select_slot(0)
	elif event.is_action_pressed("weapon_2"):
		first_person_weapons.select_slot(1)
	if not third_person:
		if event.is_action_pressed("fire"):
			first_person_weapons.request_fire()
		if event.is_action_pressed("reload"):
			first_person_weapons.request_reload()
	if event is InputEventMouseMotion:
		var mouse: Vector2 = event.screen_relative
		if OS.has_feature("web") and (absf(mouse.x) > 300 or absf(mouse.y) > 300):
			return
		var aim_sensitivity = lerpf(1.0, 0.55, first_person_weapons.aim_blend)
		_yaw -= mouse.x * sensitivity * aim_sensitivity
		net_pitch = clampf(
			net_pitch - mouse.y * sensitivity * aim_sensitivity, deg_to_rad(-89), deg_to_rad(89)
		)
	if event.is_action_pressed("jump"):
		_jump_requested = true


func _physics_process(delta: float) -> void:
	if not is_local() or combat.is_dead():
		return
	rotation.y = _yaw
	var active = input_enabled and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var want_crouch = active and Input.is_action_pressed("crouch")
	if want_crouch or (net_crouched and not _can_stand()):
		net_crouched = true
	else:
		net_crouched = false
	_apply_height()
	var axis = (
		Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if active
		else Vector2.ZERO
	)
	var aiming = active and not third_person and Input.is_action_pressed("aim")
	var speed = (
		crouch_speed
		if net_crouched
		else (run_speed if active and Input.is_action_pressed("run") and not aiming else walk_speed)
	)
	var desired = global_basis * Vector3(axis.x, 0, axis.y) * speed
	var horizontal = Vector3(velocity.x, 0, velocity.z).lerp(desired, minf(acceleration * delta, 1))
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if is_on_floor():
		velocity.y = -0.5
		if active and _jump_requested and not net_crouched:
			velocity.y = jump_speed
	else:
		velocity.y -= gravity * delta
	_jump_requested = false
	move_and_slide()
	net_grounded = is_on_floor()
	if position.y < -12:
		respawn(Vector3(0, 1, 8))


func _can_stand() -> bool:
	var shape = CapsuleShape3D.new()
	shape.radius = 0.32
	shape.height = 1.78
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, global_position + Vector3(0, 0.92, 0))
	query.collision_mask = 3
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _apply_height() -> void:
	var height = 1.1 if net_crouched else 1.8
	if not is_equal_approx(height, _height):
		_height = height
		(collider.shape as CapsuleShape3D).height = height
		collider.position.y = height * 0.5


func _process(delta: float) -> void:
	if combat.is_dead():
		if is_local():
			_update_death_camera(delta)
		return
	if not is_local():
		_apply_height()
	nickname.text = net_nickname
	nickname.position.y = _height + 0.25
	_update_animation(delta)
	if not is_local():
		return
	var controls = input_enabled and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var running = (
		controls
		and Input.is_action_pressed("run")
		and not net_crouched
		and net_grounded
		and Vector2(velocity.x, velocity.z).length() > 3.1
	)
	first_person_weapons.update_controls(
		controls, Input.is_action_pressed("fire"), Input.is_action_pressed("aim"), running
	)
	var target_height = 0.95 if net_crouched else 1.62
	var target = get_global_transform_interpolated().origin + Vector3(0, target_height, 0)
	# Only smooth eye-height; position comes from Godot's local physics interpolation.
	_eye_height = lerpf(_eye_height, target_height, 1 - exp(-12 * delta))
	target.y = get_global_transform_interpolated().origin.y + _eye_height
	rig.global_position = target
	rig.global_rotation = Vector3(net_pitch, _yaw, 0)


func _update_animation(delta: float) -> void:
	var horizontal = Vector3(velocity.x, 0, velocity.z)
	var speed = horizontal.length()
	if net_grounded and not _was_grounded:
		_land_time = 0.12
	_was_grounded = net_grounded
	_land_time = maxf(0, _land_time - delta)
	var next = "Idle"
	if not net_grounded:
		next = "Jump"
	elif net_crouched:
		next = "Crouch_Fwd" if speed > 0.15 else "Crouch_Idle"
	elif speed > 4:
		next = "Sprint"
	elif speed > 0.15:
		next = "Walk"
	elif _land_time > 0:
		next = "Jump_Land"
	if next != _clip:
		animation.play(next, 0.12)
		_clip = next
	animation.speed_scale = (
		clampf(speed / (1.5 if net_crouched else (6.0 if next == "Sprint" else 3.0)), 0.5, 1.5)
		if next in ["Walk", "Sprint", "Crouch_Fwd"]
		else 1.0
	)
	if speed > 0.15:
		var local_velocity = global_basis.inverse() * horizontal
		_visual_heading = atan2(-local_velocity.x, -local_velocity.z) + PI
	visual.rotation.y = lerp_angle(visual.rotation.y, _visual_heading, 1 - exp(-12 * delta))


func _update_view() -> void:
	if not is_local():
		return
	arm.spring_length = 3.5 if third_person else 0.0
	if first_person_weapons != null:
		first_person_weapons.set_active(not third_person and not combat.is_dead())
	for mesh in _meshes:
		mesh.cast_shadow = (
			GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			if third_person
			else GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		)


func respawn(pos: Vector3) -> void:
	if offline:
		global_position = pos
		reset_physics_interpolation()
	else:
		replicator.teleport_3d(pos, Vector3(0, _yaw, 0))
	velocity = Vector3.ZERO
	net_grounded = false


func combat_die() -> void:
	super.combat_die()
	nickname.hide()
	_jump_requested = false
	if is_local():
		first_person_weapons.set_active(false)
		_death_camera_time = 0.0
		_death_camera_origin = camera.global_position
		rig.global_position = _death_camera_origin
		arm.spring_length = 0.0


func _update_death_camera(delta: float) -> void:
	_death_camera_time += delta
	var focus = (
		last_corpse.get_focus_position() if is_instance_valid(last_corpse) else global_position
	)
	var progress = smoothstep(0.0, 1.5, _death_camera_time)
	arm.spring_length = 4.5 * progress
	rig.global_position = _death_camera_origin.lerp(focus + Vector3.UP * 0.3, progress)
	rig.global_rotation = Vector3(lerpf(net_pitch, deg_to_rad(-45), progress), _yaw, 0)


func combat_respawn(pos: Vector3) -> void:
	if is_local():
		first_person_weapons.reset_ammunition()
		respawn(pos)
		rig.global_position = global_position + Vector3.UP * _eye_height
		rig.global_rotation = Vector3(net_pitch, _yaw, 0)
		_death_camera_time = 0.0
	super.combat_respawn(pos)
	nickname.visible = not is_local()
	_clip = ""
	_update_view()


@rpc("any_peer", "reliable")
func rpc_request_shot(
	sequence: int, shot_life: int, slot: int, origin: Vector3, direction: Vector3
) -> void:
	combat.rpc_request_shot(sequence, shot_life, slot, origin, direction)


func get_eye_position() -> Vector3:
	return global_position + Vector3.UP * (0.95 if net_crouched else 1.62)


func get_respawn_position() -> Vector3:
	return Vector3(randf_range(-3, 3), 1, 8)


func fire_weapon(slot: int) -> void:
	if not is_local() or combat.is_dead() or third_person or not input_enabled:
		return
	combat.request_shot(slot, camera.global_position, -camera.global_basis.z)


func _create_corpse(initial_velocity: Vector3, container: Node) -> Node3D:
	var corpse: Node3D
	if combat.death_source == combat.DamageSource.PLAYER:
		corpse = super._create_corpse(initial_velocity, container)
	else:
		corpse = preload("res://combat/animated_corpse.gd").spawn(self, container)
	preload("res://effects/blood_pool.gd").attach(corpse)
	return corpse
