extends Node3D
## Master validates shots and broadcasts state through each networked actor.
## The owner also snapshots that state for late joiners. Revisions reject stale snapshots.
signal died(initial_velocity: Vector3)
signal respawned(position: Vector3)

const MAX_HEALTH = 100
const WeaponCatalog = preload("res://weapons/weapon_catalog.gd")
const RANGE = 200.0
const RESPAWN_SECONDS = 5.0
var health: int = MAX_HEALTH
var life: int = 0
var death_velocity: Vector3 = Vector3.ZERO
var respawn_position: Vector3 = Vector3.ZERO
var net_state: Vector3 = Vector3(MAX_HEALTH, 0, 0):
	set(value):
		if value.z < net_state.z:
			return
		net_state = value
		health = roundi(value.x)
		life = roundi(value.y)
var _shown_dead = false
var _shown_life = 0
var _dead_time = 0.0
var _next_fire = 0.0
var _sequence = 0
var _last_sequence = -1
var _shots: Array[Dictionary] = []
var confirmed_hits = 0
var actor: CharacterBody3D
var _replicator: FusionSharedReplicator
var _eye_position: Callable
var _respawn_position: Callable


func configure(
	body: CharacterBody3D, network: FusionSharedReplicator, eyes: Callable, spawn: Callable
) -> void:
	actor = body
	_replicator = network
	_eye_position = eyes
	_respawn_position = spawn


func is_authority() -> bool:
	return not Fusion.is_in_room() or Fusion.is_master_client()


func is_dead() -> bool:
	return health <= 0


func request_shot(slot: int, origin: Vector3, direction: Vector3) -> void:
	if is_dead():
		return
	_sequence += 1
	if is_authority():
		_queue_shot(_sequence, life, slot, origin, direction)
	else:
		Fusion.rpc_to(
			-1, Callable(actor, "rpc_request_shot"), _sequence, life, slot, origin, direction
		)


func rpc_request_shot(
	sequence: int, shot_life: int, slot: int, origin: Vector3, direction: Vector3
) -> void:
	if not Fusion.is_master_client():
		return
	if Fusion.get_rpc_sender() != _replicator.get_owner_id():
		return
	_queue_shot(sequence, shot_life, slot, origin, direction)


func _queue_shot(
	sequence: int, shot_life: int, slot: int, origin: Vector3, direction: Vector3
) -> void:
	if not is_authority() or is_dead() or shot_life != life:
		return
	if not WeaponCatalog.is_valid_slot(slot) or sequence <= _last_sequence:
		return
	if not origin.is_finite() or not direction.is_finite():
		return
	if direction.length_squared() < 0.9 or direction.length_squared() > 1.1:
		return
	# Allow a small amount of network movement discrepancy, never a remote camera.
	var eye = _eye_position.call()
	if origin.distance_to(eye) > 2.0:
		return
	var now = Time.get_ticks_msec() / 1000.0
	if now + 0.025 < _next_fire:
		return
	_last_sequence = sequence
	_next_fire = maxf(now, _next_fire) + WeaponCatalog.DEFINITIONS[slot].shot_seconds
	_shots.append(
		{"origin": origin, "direction": direction.normalized(), "life": life, "slot": slot}
	)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(actor):
		return
	_sync_presentation()
	if not is_authority():
		_shots.clear()
		return
	if is_dead():
		_shots.clear()
		_dead_time += delta
		if _dead_time >= RESPAWN_SECONDS:
			respawn_position = _respawn_position.call()
			life += 1
			health = MAX_HEALTH
			_dead_time = 0.0
			_publish_state()
			_sync_presentation()
		return
	var pending = _shots
	_shots = []
	for shot in pending:
		if shot.life == life and not is_dead():
			_resolve_shot(shot)


func _resolve_shot(shot: Dictionary) -> void:
	var origin: Vector3 = shot.origin
	var direction: Vector3 = shot.direction
	var eye = _eye_position.call()
	var space = get_world_3d().direct_space_state
	# Prevent a camera clipped through a wall from shooting through it.
	var obstruction = PhysicsRayQueryParameters3D.create(eye, origin, 1, [actor.get_rid()])
	if eye.distance_squared_to(origin) > 0.0001 and not space.intersect_ray(obstruction).is_empty():
		return
	var query = PhysicsRayQueryParameters3D.create(
		origin, origin + direction * RANGE, 3, [actor.get_rid()]
	)
	var hit = space.intersect_ray(query)
	if hit.is_empty():
		return
	var target = hit.collider.get_node_or_null("Combat")
	if target != null and target != self and not target.is_dead():
		target.apply_damage(WeaponCatalog.DEFINITIONS[shot.slot].damage, direction)
		confirmed_hits += 1


func apply_damage(amount: int, direction: Vector3) -> void:
	if not is_authority() or is_dead() or amount <= 0:
		return
	death_velocity = actor.velocity + direction.normalized() * 2.5
	health = maxi(0, health - amount)
	_publish_state()
	_sync_presentation()


func _sync_presentation() -> void:
	if life != _shown_life:
		_shown_life = life
		_shown_dead = false
		_shots.clear()
		respawned.emit(respawn_position)
	if is_dead() and not _shown_dead:
		_shown_dead = true
		_dead_time = 0.0
		died.emit(death_velocity)


func _publish_state() -> void:
	net_state = Vector3(health, life, net_state.z + 1)
	if Fusion.is_in_room():
		Fusion.rpc(Callable(actor, "rpc_combat_state"), net_state, death_velocity, respawn_position)


func receive_state(state: Vector3, impulse: Vector3, spawn_position: Vector3) -> void:
	var room = Fusion.get_room()
	if room == null or Fusion.get_rpc_sender() != room.get_master_client_id():
		return
	if state.z < net_state.z:
		return
	death_velocity = impulse
	respawn_position = spawn_position
	net_state = state
	# Apply on the next physics tick, outside the network callback.
