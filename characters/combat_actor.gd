extends CharacterBody3D
## Shared actor contract. Controllers specialize movement, eyes and respawn locations.

const Ragdoll = preload("res://combat/ragdoll.gd")

var corpse_parent: Node
var last_corpse: Node3D

@onready var combat = $Combat
@onready var replicator: FusionSharedReplicator = $FusionReplicator
@onready var collider: CollisionShape3D = $CollisionShape3D
@onready var visual: Node3D = $Visual
@onready var animation: AnimationPlayer = $Visual/Model/Locomotion


func _ready() -> void:
	combat.configure(self, replicator, get_eye_position, get_respawn_position)
	combat.died.connect(_on_combat_died)
	combat.respawned.connect(combat_respawn)


func get_eye_position() -> Vector3:
	return global_position + Vector3.UP * 1.62


func get_respawn_position() -> Vector3:
	return global_position


func combat_die() -> void:
	animation.pause()
	visual.hide()
	collider.set_deferred("disabled", true)
	velocity = Vector3.ZERO


func combat_respawn(_position: Vector3) -> void:
	visual.show()
	collider.set_deferred("disabled", false)
	velocity = Vector3.ZERO


func _on_combat_died(initial_velocity: Vector3) -> void:
	var container = corpse_parent if is_instance_valid(corpse_parent) else get_parent()
	last_corpse = _create_corpse(initial_velocity, container)
	combat_die()


func _create_corpse(initial_velocity: Vector3, container: Node) -> Node3D:
	return Ragdoll.spawn(self, initial_velocity, container)


@rpc("any_peer", "call_local", "reliable")
func rpc_combat_state(
	state: Vector3,
	impulse: Vector3,
	spawn_position: Vector3,
	respawn_delay: float = 5.0,
	source: int = 2
) -> void:
	combat.receive_state(state, impulse, spawn_position, respawn_delay, source)


@rpc("any_peer", "reliable")
func rpc_blood_impact(
	sequence: int,
	point: Vector3,
	normal: Vector3,
	direction: Vector3,
	surface_point: Vector3,
	surface_normal: Vector3
) -> void:
	combat.receive_impact(sequence, point, normal, direction, surface_point, surface_normal)


@rpc("any_peer", "reliable")
func rpc_surface_impact(sequence: int, point: Vector3, normal: Vector3) -> void:
	combat.receive_surface(sequence, point, normal)
