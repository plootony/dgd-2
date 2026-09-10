extends CharacterBody3D
## Shared actor contract. Controllers specialize movement, eyes and respawn locations.

const Ragdoll = preload("res://combat/ragdoll.gd")

var corpse_parent: Node

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
	Ragdoll.spawn(self, initial_velocity, container)
	combat_die()


@rpc("any_peer", "call_local", "reliable")
func rpc_combat_state(state: Vector3, impulse: Vector3, spawn_position: Vector3) -> void:
	combat.receive_state(state, impulse, spawn_position)
