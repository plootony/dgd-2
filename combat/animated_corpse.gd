extends Node3D
## Detached nonphysical death presentation, shared by camera and feeding through get_focus_position.
const LIFETIME = 20.0
const MAX_CORPSES = 12
var skeleton: Skeleton3D
var animator: AnimationPlayer
var _age: float = 0.0


static func spawn(actor: CharacterBody3D, container: Node) -> Node3D:
	var corpse = load("res://combat/animated_corpse.gd").new()
	container.add_child(corpse)
	corpse.name = "AnimatedCorpse"
	corpse.add_to_group("AnimatedCorpses")
	corpse.global_transform = actor.global_transform
	corpse.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var floor_query = PhysicsRayQueryParameters3D.create(
		actor.global_position + Vector3.UP * 0.2, actor.global_position + Vector3.DOWN * 100.0, 1
	)
	var floor_hit = actor.get_world_3d().direct_space_state.intersect_ray(floor_query)
	if not floor_hit.is_empty():
		corpse.global_position.y = floor_hit.position.y
	var copy = actor.get_node("Visual").duplicate()
	for player in copy.find_children("*", "AnimationPlayer", true, false):
		player.free()
	corpse.add_child(copy)
	copy.show()
	for mesh in copy.find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	corpse.skeleton = copy.find_child("Skeleton3D", true, false)
	corpse.animator = AnimationPlayer.new()
	copy.get_node("Model").add_child(corpse.animator)
	corpse.animator.add_animation_library(
		"death", preload("res://characters/player/death_animations.res")
	)
	corpse.animator.play("death/death_forward")
	corpse.animator.advance(0)
	var corpses = actor.get_tree().get_nodes_in_group("AnimatedCorpses")
	while corpses.size() > MAX_CORPSES:
		corpses.pop_front().queue_free()
	return corpse


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()


func get_focus_position() -> Vector3:
	var hips = skeleton.find_bone("mixamorig1_Hips")
	return skeleton.global_transform * skeleton.get_bone_global_pose(hips).origin
