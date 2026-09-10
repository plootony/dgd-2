extends Node3D
## Cosmetic local physics. Health/death/respawn are replicated; bone transforms are not.
const LIFETIME = 20.0
const MAX_CORPSES = 12
# Bone, end bone, capsule radius, mass. Both character rigs share these suffixes.
const SEGMENTS = [
	["Hips", "Spine1", 0.13, 12.0],
	["Spine1", "Neck", 0.15, 16.0],
	["Head", "", 0.095, 5.0],
	["LeftArm", "LeftForeArm", 0.055, 3.0],
	["RightArm", "RightForeArm", 0.055, 3.0],
	["LeftForeArm", "LeftHand", 0.045, 2.0],
	["RightForeArm", "RightHand", 0.045, 2.0],
	["LeftHand", "LeftHandMiddle1", 0.04, 0.7],
	["RightHand", "RightHandMiddle1", 0.04, 0.7],
	["LeftUpLeg", "LeftLeg", 0.075, 7.0],
	["RightUpLeg", "RightLeg", 0.075, 7.0],
	["LeftLeg", "LeftFoot", 0.06, 4.0],
	["RightLeg", "RightFoot", 0.06, 4.0],
	["LeftFoot", "LeftToeBase", 0.055, 1.0],
	["RightFoot", "RightToeBase", 0.055, 1.0],
]
var simulator: PhysicalBoneSimulator3D
var bodies: Array[PhysicalBone3D] = []
var _age = 0.0


static func spawn(actor: CharacterBody3D, initial_velocity: Vector3, container: Node) -> Node3D:
	var corpse = load("res://combat/ragdoll.gd").new()
	corpse.name = "Ragdoll"
	container.add_child(corpse)
	corpse.add_to_group("Ragdolls")
	corpse.global_transform = actor.global_transform
	corpse.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var source: Node3D = actor.get_node("Visual")
	var copy: Node3D = source.duplicate()
	# Keep the current pose, with no animation player left to overwrite physics.
	for animator in copy.find_children("*", "AnimationPlayer", true, false):
		animator.free()
	corpse.add_child(copy)
	copy.visible = true
	for mesh in copy.find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var skeleton: Skeleton3D = copy.find_children("*", "Skeleton3D", true, false)[0]
	var original: Skeleton3D = source.find_children("*", "Skeleton3D", true, false)[0]
	for i in skeleton.get_bone_count():
		skeleton.set_bone_pose_position(i, original.get_bone_pose_position(i))
		skeleton.set_bone_pose_rotation(i, original.get_bone_pose_rotation(i))
		skeleton.set_bone_pose_scale(i, original.get_bone_pose_scale(i))
	corpse._build(skeleton)
	corpse._start.call_deferred(initial_velocity)
	var corpses = actor.get_tree().get_nodes_in_group("Ragdolls")
	while corpses.size() > MAX_CORPSES:
		corpses.pop_front().queue_free()
	return corpse


func _build(skeleton: Skeleton3D) -> void:
	var names = {}
	for i in skeleton.get_bone_count():
		names[String(skeleton.get_bone_name(i)).trim_prefix("mixamorig1_")] = i
	simulator = PhysicalBoneSimulator3D.new()
	simulator.name = "RagdollPhysics"
	skeleton.add_child(simulator)
	for segment in SEGMENTS:
		if not names.has(segment[0]):
			continue
		var id: int = names[segment[0]]
		var rest = skeleton.get_bone_global_rest(id)
		var end = Vector3(0, 0.18, 0)
		if names.has(segment[1]):
			end = rest.affine_inverse() * skeleton.get_bone_global_rest(names[segment[1]]).origin
		var bone = PhysicalBone3D.new()
		bone.name = "Physics_" + segment[0]
		simulator.add_child(bone)
		bone.set("bone_name", skeleton.get_bone_name(id))
		bone.mass = segment[3]
		bone.collision_layer = 4
		bone.collision_mask = 1  # Environment only: no self collisions or blocking living players.
		bone.friction = 0.8
		bone.linear_damp = 0.15
		bone.angular_damp = 1.5
		bone.body_offset = Transform3D(Basis(Quaternion(Vector3.UP, end.normalized())), end * 0.5)
		bone.joint_offset = bone.body_offset.affine_inverse()
		bone.joint_type = PhysicalBone3D.JOINT_TYPE_CONE
		bone.set("joint_constraints/swing_span", 45.0)
		bone.set("joint_constraints/twist_span", 25.0)
		var shape = CapsuleShape3D.new()
		shape.radius = segment[2]
		shape.height = maxf(end.length(), shape.radius * 2.0)
		var collision = CollisionShape3D.new()
		collision.shape = shape
		bone.add_child(collision)
		bodies.append(bone)


func _start(initial_velocity: Vector3) -> void:
	simulator.physical_bones_start_simulation()
	for bone in bodies:
		bone.linear_velocity = initial_velocity


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()


func get_focus_position() -> Vector3:
	if not bodies.is_empty() and is_instance_valid(bodies[0]):
		return bodies[0].global_position
	return global_position
