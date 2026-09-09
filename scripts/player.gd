class_name NetworkPlayer
extends CharacterBody3D

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

@onready var replicator: FusionSharedReplicator = $FusionReplicator
@onready var collider: CollisionShape3D = $CollisionShape3D
@onready var visual: Node3D = $Visual
@onready var model: Node3D = $Visual/Model
@onready var animation: AnimationPlayer = $Visual/Model/Locomotion
@onready var rig: Node3D = $CameraRig
@onready var arm: SpringArm3D = $CameraRig/SpringArm3D
@onready var camera: Camera3D = $CameraRig/SpringArm3D/Camera3D
@onready var nickname: Label3D = $Nickname

func is_local() -> bool:
	return offline or replicator.has_authority()

func _ready() -> void:
	_yaw = rotation.y
	collider.shape = collider.shape.duplicate()
	for node in model.find_children("*","MeshInstance3D",true,false): _meshes.append(node)
	arm.add_excluded_object(get_rid())
	rig.top_level = true
	rig.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if is_local():
		camera.current = true
		get_tree().current_scene.local_player = self
	else:
		physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		camera.current = false
	nickname.visible = not is_local()
	_update_view()

func _unhandled_input(event: InputEvent) -> void:
	if not is_local() or not input_enabled: return
	if event.is_action_pressed("view_toggle"):
		third_person = not third_person
		_update_view()
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return
	if event is InputEventMouseMotion:
		var mouse: Vector2 = event.screen_relative
		if OS.has_feature("web") and (absf(mouse.x)>300 or absf(mouse.y)>300): return
		_yaw -= mouse.x * sensitivity
		net_pitch = clampf(net_pitch - mouse.y * sensitivity, deg_to_rad(-89), deg_to_rad(89))
	if event.is_action_pressed("jump"): _jump_requested = true

func _physics_process(delta: float) -> void:
	if not is_local(): return
	rotation.y = _yaw
	var active = input_enabled and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var want_crouch = active and Input.is_action_pressed("crouch")
	if want_crouch or (net_crouched and not _can_stand()): net_crouched = true
	else: net_crouched = false
	_apply_height()
	var axis = Input.get_vector("move_left","move_right","move_forward","move_back") if active else Vector2.ZERO
	var speed = crouch_speed if net_crouched else (run_speed if active and Input.is_action_pressed("run") else walk_speed)
	var desired = global_basis * Vector3(axis.x,0,axis.y) * speed
	var horizontal = Vector3(velocity.x,0,velocity.z).lerp(desired,minf(acceleration*delta,1))
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if is_on_floor():
		velocity.y = -0.5
		if active and _jump_requested and not net_crouched: velocity.y = jump_speed
	else: velocity.y -= gravity * delta
	_jump_requested = false
	move_and_slide()
	net_grounded = is_on_floor()
	if position.y < -12: respawn(Vector3(0,1,8))

func _can_stand() -> bool:
	var shape = CapsuleShape3D.new()
	shape.radius = 0.32
	shape.height = 1.78
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, global_position + Vector3(0,0.92,0))
	query.collision_mask = 3
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func _apply_height() -> void:
	var height = 1.1 if net_crouched else 1.8
	if not is_equal_approx(height,_height):
		_height = height
		(collider.shape as CapsuleShape3D).height = height
		collider.position.y = height*0.5

func _process(delta: float) -> void:
	if not is_local(): _apply_height()
	nickname.text = net_nickname
	nickname.position.y = _height+0.25
	_update_animation(delta)
	if not is_local(): return
	var target_height = 0.95 if net_crouched else 1.62
	var target = get_global_transform_interpolated().origin + Vector3(0,target_height,0)
	# Only smooth eye-height; position comes from Godot's local physics interpolation.
	_eye_height = lerpf(_eye_height,target_height,1-exp(-12*delta))
	target.y = get_global_transform_interpolated().origin.y + _eye_height
	rig.global_position = target
	rig.global_rotation = Vector3(net_pitch,_yaw,0)

func _update_animation(delta: float) -> void:
	var horizontal = Vector3(velocity.x,0,velocity.z)
	var speed = horizontal.length()
	if net_grounded and not _was_grounded: _land_time = 0.12
	_was_grounded = net_grounded
	_land_time = maxf(0,_land_time-delta)
	var next = "Idle"
	if not net_grounded: next = "Jump"
	elif net_crouched: next = "Crouch_Fwd" if speed>0.15 else "Crouch_Idle"
	elif speed>4: next = "Sprint"
	elif speed>0.15: next = "Walk"
	elif _land_time>0: next = "Jump_Land"
	if next != _clip:
		animation.play(next,0.12)
		_clip = next
	animation.speed_scale = clampf(speed / (1.5 if net_crouched else (6.0 if next=="Sprint" else 3.0)),0.5,1.5) if next in ["Walk","Sprint","Crouch_Fwd"] else 1.0
	if speed>0.15:
		var local_velocity = global_basis.inverse()*horizontal
		_visual_heading = atan2(-local_velocity.x,-local_velocity.z)+PI
	visual.rotation.y = lerp_angle(visual.rotation.y,_visual_heading,1-exp(-12*delta))

func _update_view() -> void:
	if not is_local(): return
	arm.spring_length = 3.5 if third_person else 0.0
	for mesh in _meshes:
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if third_person else GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY

func respawn(pos: Vector3) -> void:
	if offline:
		global_position = pos
		reset_physics_interpolation()
	else: replicator.teleport_3d(pos,Vector3(0,_yaw,0))
	velocity = Vector3.ZERO
	net_grounded = false
