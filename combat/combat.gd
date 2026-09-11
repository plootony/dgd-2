extends Node3D
## Master validates shots and broadcasts state through each networked actor.
## The owner also snapshots that state for late joiners. Revisions reject stale snapshots.
signal damaged(amount: int, direction: Vector3)
signal died(initial_velocity: Vector3)
signal respawned(position: Vector3)

enum DamageSource { PLAYER, ZOMBIE, WORLD }

const MAX_HEALTH = 100
const WeaponCatalog = preload("res://weapons/weapon_catalog.gd")
const RANGE = 200.0
const RESPAWN_SECONDS = 5.0
@export_range(1, 10000) var max_health: int = MAX_HEALTH

var death_source: int = DamageSource.WORLD
var respawn_delay: float = RESPAWN_SECONDS
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
var _ballistics = preload("res://addons/weapon_control/ballistics.gd").new()
var confirmed_hits = 0
var _shown_impact: int = 0
var _shown_surface: int = 0
var actor: CharacterBody3D
var _replicator: FusionSharedReplicator
var _eye_position: Callable
var _respawn_position: Callable


func configure(
	body: CharacterBody3D, network: FusionSharedReplicator, eyes: Callable, spawn: Callable
) -> void:
	if net_state.z == 0.0:
		net_state = Vector3(max_health, 0, 0)
	actor = body
	_replicator = network
	_eye_position = eyes
	_respawn_position = spawn


func is_authority() -> bool:
	return not Fusion.is_in_room() or Fusion.is_master_client()


func is_dead() -> bool:
	return health <= 0


func request_shot(
	slot: int,
	origin: Vector3,
	direction: Vector3,
	mode: int = -1,
	aim: float = 0.0,
	focused: bool = false
) -> void:
	if is_dead():
		return
	_sequence += 1
	if is_authority():
		_queue_shot(_sequence, life, slot, origin, direction, mode, aim, focused)
	else:
		Fusion.rpc_to(
			-1,
			Callable(actor, "rpc_request_shot"),
			_sequence,
			life,
			slot,
			origin,
			direction,
			mode,
			aim,
			focused
		)


func rpc_request_shot(
	sequence: int,
	shot_life: int,
	slot: int,
	origin: Vector3,
	direction: Vector3,
	mode: int = -1,
	aim: float = 0.0,
	focused: bool = false
) -> void:
	if not Fusion.is_master_client():
		return
	if Fusion.get_rpc_sender() != _replicator.get_owner_id():
		return
	_queue_shot(sequence, shot_life, slot, origin, direction, mode, aim, focused)


func _queue_shot(
	sequence: int,
	shot_life: int,
	slot: int,
	origin: Vector3,
	direction: Vector3,
	mode_id: int = -1,
	aim: float = 0.0,
	focused: bool = false
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
	var definition = WeaponCatalog.DEFINITIONS[slot]
	var profile = definition.control_profile
	if mode_id == -1:
		mode_id = profile.initial_mode()
	var mode = profile.mode(mode_id)
	if mode == null or not mode.enabled or not is_finite(aim) or aim < 0.0 or aim > 1.0:
		return
	var unlimited = mode_id == 0 and mode.unlimited_single_clicks
	if not unlimited and now + 0.025 < _next_fire:
		return
	_last_sequence = sequence
	if not unlimited:
		_next_fire = maxf(now, _next_fire) + mode.interval
	direction = _ballistics.apply(
		slot,
		profile,
		mode,
		direction.normalized(),
		aim,
		actor.get("net_crouched") == true,
		Vector2(actor.velocity.x, actor.velocity.z).length() > 0.15,
		actor.get("net_grounded") == true,
		focused and aim > 0.5,
		now
	)
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
		if _dead_time >= respawn_delay:
			respawn_position = _respawn_position.call()
			life += 1
			health = max_health
			respawn_delay = RESPAWN_SECONDS
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
		target.apply_damage(
			WeaponCatalog.DEFINITIONS[shot.slot].damage,
			direction,
			RESPAWN_SECONDS,
			DamageSource.PLAYER
		)
		confirmed_hits += 1
		_publish_impact(hit.position, hit.normal, direction)
	elif target == null and hit.collider is StaticBody3D:
		_publish_surface(hit.position, hit.normal)


func apply_damage(
	amount: int,
	direction: Vector3,
	death_delay: float = RESPAWN_SECONDS,
	source: int = DamageSource.WORLD
) -> void:
	if not is_authority() or is_dead() or amount <= 0:
		return
	death_velocity = actor.velocity + direction.normalized() * 2.5
	var applied_damage = mini(health, amount)
	health = maxi(0, health - amount)
	if is_dead():
		death_source = source
		respawn_delay = maxf(RESPAWN_SECONDS, death_delay)
	_publish_state()
	_sync_presentation()
	if not is_dead():
		damaged.emit(applied_damage, direction)


func _sync_presentation() -> void:
	if life != _shown_life:
		_ballistics.reset()
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
		Fusion.rpc(
			Callable(actor, "rpc_combat_state"),
			net_state,
			death_velocity,
			respawn_position,
			respawn_delay,
			death_source
		)


func receive_state(
	state: Vector3,
	impulse: Vector3,
	spawn_position: Vector3,
	death_delay: float = RESPAWN_SECONDS,
	source: int = DamageSource.WORLD
) -> void:
	var room = Fusion.get_room()
	if room == null or Fusion.get_rpc_sender() != room.get_master_client_id():
		return
	if state.z < net_state.z:
		return
	death_source = source
	respawn_delay = death_delay
	death_velocity = impulse
	respawn_position = spawn_position
	net_state = state
	# Apply on the next physics tick, outside the network callback.


func _publish_impact(point: Vector3, normal: Vector3, direction: Vector3) -> void:
	var space = actor.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		point + direction * 0.03, point + direction * 3.0, 1
	)
	var surface = space.intersect_ray(query)
	if surface.is_empty():
		query = PhysicsRayQueryParameters3D.create(
			point + Vector3.UP * 0.02, point + Vector3.DOWN * 2.5, 1
		)
		surface = space.intersect_ray(query)
	var surface_point: Vector3 = surface.position if not surface.is_empty() else Vector3.ZERO
	var surface_normal: Vector3 = surface.normal if not surface.is_empty() else Vector3.ZERO
	var sequence = _shown_impact + 1
	_show_impact(sequence, point, normal, direction, surface_point, surface_normal)
	if Fusion.is_in_room():
		Fusion.rpc(
			Callable(actor, "rpc_blood_impact"),
			sequence,
			point,
			normal,
			direction,
			surface_point,
			surface_normal
		)


func receive_impact(
	sequence: int,
	point: Vector3,
	normal: Vector3,
	direction: Vector3,
	surface_point: Vector3,
	surface_normal: Vector3
) -> void:
	var room = Fusion.get_room()
	if room == null or Fusion.get_rpc_sender() != room.get_master_client_id():
		return
	_show_impact(sequence, point, normal, direction, surface_point, surface_normal)


func _show_impact(
	sequence: int,
	point: Vector3,
	normal: Vector3,
	direction: Vector3,
	surface_point: Vector3,
	surface_normal: Vector3
) -> void:
	if sequence <= _shown_impact:
		return
	_shown_impact = sequence
	var container = (
		actor.corpse_parent if is_instance_valid(actor.corpse_parent) else actor.get_parent()
	)
	preload("res://effects/blood_impact.gd").spawn(
		container, point, normal, direction, surface_point, surface_normal
	)


func _publish_surface(point: Vector3, normal: Vector3) -> void:
	var sequence = _shown_surface + 1
	_show_surface(sequence, point, normal)
	if Fusion.is_in_room():
		Fusion.rpc(Callable(actor, "rpc_surface_impact"), sequence, point, normal)


func receive_surface(sequence: int, point: Vector3, normal: Vector3) -> void:
	var room = Fusion.get_room()
	if room == null or Fusion.get_rpc_sender() != room.get_master_client_id():
		return
	_show_surface(sequence, point, normal)


func _show_surface(sequence: int, point: Vector3, normal: Vector3) -> void:
	if sequence <= _shown_surface:
		return
	_shown_surface = sequence
	var container = (
		actor.corpse_parent if is_instance_valid(actor.corpse_parent) else actor.get_parent()
	)
	preload("res://effects/surface_impact.gd").spawn(container, point, normal)
