extends "res://characters/combat_actor.gd"
## Master-authoritative pursuit and telegraphed melee. Remote peers only present the state.

enum State { IDLE, CHASE, SCREAM, ATTACK, BITE, FEED_APPROACH, FEED_INTRO, FEED_LOOP, FALL }

@export var run_speed: float = 7.0
@export var crawl_speed: float = 1.2
@export var attack_range: float = 1.65
@export var attack_damage: int = 20
@export var attack_hit_time: float = 0.8
@export var bite_damage: int = 30
@export var bite_hit_time: float = 1.0
@export var detection_range: float = 20.0
@export var crawl_threshold: float = 0.2

var net_grounded: bool = false
var net_alerted: bool = false
var net_prone: bool = false
@export var feed_seconds: float = 7.0
@export var stagger_seconds: float = 0.22
@export var stagger_speed: float = 0.45
# Time, side, sequence. The flinch does not interrupt attacks or feeding.
var net_stagger: Vector3 = Vector3(-100, 1, 0)
var _feed_corpse: Node3D
var _feed_point: Vector3
var _bite_killed: bool = false
# Atomic snapshot: state, network start time, transition sequence (also replays identical clips).
var net_behavior: Vector3 = Vector3.ZERO
var _target: CharacterBody3D
var _attack_target: CharacterBody3D
var _attack_target_life: int = -1
var _hit_applied: bool = false
var _search_time: float = 0.0
var _clip: StringName = &""
var _shown_transition: int = -1
var _was_crawling: bool = false
var _authority: bool = false
var _crawl_time: float = 0.0

@onready var navigation: NavigationAgent3D = $NavigationAgent3D
@onready var name_label: Label3D = $Label
@onready var _spawn_position: Vector3 = global_position + Vector3.UP * 0.8


func _ready() -> void:
	super._ready()
	combat.damaged.connect(_on_damaged)
	collider.shape = collider.shape.duplicate()
	name_label.text += " / ЗОМБИ"


func simulates() -> bool:
	return not Fusion.is_in_room() or replicator.has_authority()


func is_crawling() -> bool:
	return not combat.is_dead() and net_prone


func get_state() -> State:
	return int(net_behavior.x) as State


func _physics_process(delta: float) -> void:
	if combat.is_dead():
		return
	_update_collision()
	if not simulates():
		return
	_search_time -= delta
	if _search_time <= 0.0:
		_search_time = 0.25
		_target = _find_target()
		if is_instance_valid(_target):
			navigation.target_position = _target.global_position
	var direction = Vector3.ZERO
	match get_state():
		State.IDLE, State.CHASE:
			if _is_living(_target):
				_face(_target.global_position, delta)
				if not net_alerted:
					net_alerted = true
					_lock_target()
					_set_state(State.SCREAM)
				elif net_grounded and _can_hit(_target):
					_lock_target()
					_start_melee()
				else:
					_set_state(State.CHASE)
					direction = _path_direction()
			else:
				_set_state(State.IDLE)
		State.SCREAM:
			if not _attack_target_valid():
				_set_state(State.CHASE)
			else:
				_face(_attack_target.global_position, delta)
				if _state_elapsed() >= animation.get_animation("zombie/scream").length:
					_set_state(State.CHASE)
		State.ATTACK, State.BITE:
			var biting = get_state() == State.BITE
			var contact_time = bite_hit_time if biting else attack_hit_time
			if not _hit_applied and _state_elapsed() >= contact_time:
				_hit_applied = true
				if _attack_target_valid() and _can_hit(_attack_target):
					# Recheck health at contact: a healed target must not receive a nonlethal bite.
					if biting and _attack_target.combat.health <= bite_damage:
						var wait = (
							animation.get_animation("zombie/bite").length
							- bite_hit_time
							+ 2.0
							+ animation.get_animation("zombie/feed_intro").length
							+ feed_seconds
							+ 1.0
						)
						_attack_target.combat.apply_damage(
							bite_damage, Vector3.ZERO, wait, combat.DamageSource.ZOMBIE
						)
						_bite_killed = _attack_target.combat.is_dead()
						_feed_corpse = _attack_target.last_corpse
					elif not biting:
						if _attack_target.combat.health <= bite_damage:
							_start_melee()
						else:
							_attack_target.combat.apply_damage(
								attack_damage, -global_basis.z, 5.0, combat.DamageSource.ZOMBIE
							)
			var clip = "zombie/bite" if biting else "zombie/attack"
			if _state_elapsed() >= animation.get_animation(clip).length:
				if biting and _bite_killed and is_instance_valid(_feed_corpse):
					_feed_point = _feed_corpse.get_focus_position()
					_set_state(State.FEED_APPROACH)
				elif _attack_target_valid() and _can_hit(_attack_target):
					_start_melee()
				else:
					_set_state(State.CHASE)
		State.FEED_APPROACH:
			if not is_instance_valid(_feed_corpse):
				_set_state(State.CHASE)
			else:
				_feed_point = _feed_corpse.get_focus_position()
				_face(_feed_point, delta)
				var offset = _feed_point - global_position
				offset.y = 0.0
				if offset.length() <= 0.75 or _state_elapsed() >= 2.0:
					_set_state(State.FEED_INTRO)
				else:
					direction = offset.normalized() * 0.35
		State.FEED_INTRO:
			if not is_instance_valid(_feed_corpse):
				_set_state(State.CHASE)
			elif _state_elapsed() >= animation.get_animation("zombie/feed_intro").length:
				_set_state(State.FEED_LOOP)
		State.FALL:
			if _state_elapsed() >= animation.get_animation("zombie/fall").length:
				net_prone = true
				_crawl_time = 0.0
				_set_state(State.FEED_APPROACH if is_instance_valid(_feed_corpse) else State.CHASE)
		State.FEED_LOOP:
			if not is_instance_valid(_feed_corpse) or _state_elapsed() >= feed_seconds:
				_feed_corpse = null
				_set_state(State.CHASE)
	var speed = crawl_speed if is_crawling() else run_speed
	var desired = direction * speed * (stagger_speed if _stagger_active() else 1.0)
	velocity.x = move_toward(velocity.x, desired.x, delta * 14.0)
	velocity.z = move_toward(velocity.z, desired.z, delta * 14.0)
	if direction.length_squared() > 0.01:
		_face(global_position + direction, delta)
	velocity.y = -0.5 if is_on_floor() else velocity.y - 25.0 * delta
	move_and_slide()
	net_grounded = is_on_floor()
	if global_position.y < -10.0:
		_teleport(get_respawn_position())


func _process(delta: float) -> void:
	if combat.is_dead():
		return
	var authority = simulates()
	if authority != _authority:
		_authority = authority
		physics_interpolation_mode = (
			Node.PHYSICS_INTERPOLATION_MODE_ON if authority else Node.PHYSICS_INTERPOLATION_MODE_OFF
		)
		reset_physics_interpolation()
	_update_animation(delta)
	_update_flinch()


func _set_state(state: State, restart: bool = false) -> void:
	if get_state() == state and not restart:
		return
	net_behavior = Vector3(state, _clock(), net_behavior.z + 1.0)
	_hit_applied = false


func _lock_target() -> void:
	_attack_target = _target
	_attack_target_life = _target.combat.life


func _start_melee() -> void:
	_bite_killed = false
	_set_state(State.BITE if _attack_target.combat.health <= bite_damage else State.ATTACK, true)


func _on_damaged(_amount: int, direction: Vector3) -> void:
	if not simulates() or combat.is_dead():
		return
	if (
		not net_prone
		and get_state() != State.FALL
		and float(combat.health) / combat.max_health < crawl_threshold
	):
		_set_state(State.FALL)
	var side = signf(global_basis.x.dot(direction))
	if is_zero_approx(side):
		side = -net_stagger.y
	net_stagger = Vector3(_clock(), side, net_stagger.z + 1.0)


func _stagger_active() -> bool:
	return _clock() - net_stagger.x < stagger_seconds


func _update_flinch() -> void:
	var progress = clampf((_clock() - net_stagger.x) / stagger_seconds, 0.0, 1.0)
	visual.rotation.y = PI + sin(progress * PI) * deg_to_rad(9.0) * net_stagger.y


func _clock() -> float:
	return Fusion.get_network_time() if Fusion.is_in_room() else Time.get_ticks_msec() / 1000.0


func _state_elapsed() -> float:
	return maxf(0.0, _clock() - net_behavior.y)


func _is_living(actor: Variant) -> bool:
	# A freed Object fails a typed argument check before this function can validate it.
	return (
		is_instance_valid(actor)
		and actor is CharacterBody3D
		and not actor.is_queued_for_deletion()
		and not actor.combat.is_dead()
	)


func _attack_target_valid() -> bool:
	return _is_living(_attack_target) and _attack_target.combat.life == _attack_target_life


func _find_target() -> CharacterBody3D:
	var closest: CharacterBody3D
	var distance = INF
	for player in get_tree().get_nodes_in_group("Players"):
		if not _is_living(player) or not _can_see(player):
			continue
		var candidate = global_position.distance_squared_to(player.global_position)
		if candidate < distance:
			distance = candidate
			closest = player
	if closest == null and net_alerted and _is_living(_target):
		return _target
	return closest


func _can_see(target: CharacterBody3D) -> bool:
	if (
		global_position.distance_squared_to(target.global_position)
		> detection_range * detection_range
	):
		return false
	var query = PhysicsRayQueryParameters3D.create(
		get_eye_position(), target.get_eye_position(), 1, [get_rid()]
	)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _path_direction() -> Vector3:
	var offset = _target.global_position - global_position
	if NavigationServer3D.map_get_iteration_id(navigation.get_navigation_map()) > 0:
		offset = navigation.get_next_path_position() - global_position
		if navigation.is_navigation_finished():
			return Vector3.ZERO
	offset.y = 0.0
	return offset.normalized() if offset.length_squared() > 0.01 else Vector3.ZERO


func _face(position: Vector3, delta: float) -> void:
	var offset = position - global_position
	if Vector2(offset.x, offset.z).length_squared() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-offset.x, -offset.z), 1.0 - exp(-10.0 * delta))


func _can_hit(target: Variant) -> bool:
	if not _is_living(target):
		return false
	var offset = target.global_position - global_position
	if Vector2(offset.x, offset.z).length() > attack_range or absf(offset.y) > 1.0:
		return false
	var horizontal = Vector3(offset.x, 0, offset.z).normalized()
	if horizontal.dot(-global_basis.z) < 0.35:
		return false
	# A low strike still reaches a standing player's legs, but cannot pass through walls.
	var height = 0.35 if is_crawling() else 1.0
	var query = PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP * height,
		target.global_position + Vector3.UP * height,
		3,
		[get_rid()]
	)
	var hit = get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider == target


func _update_collision() -> void:
	var crawling = (
		is_crawling()
		or (
			get_state() == State.FALL
			and _state_elapsed() >= animation.get_animation("zombie/fall").length * 0.65
		)
	)
	if crawling == _was_crawling:
		return
	_was_crawling = crawling
	var capsule = collider.shape as CapsuleShape3D
	capsule.height = 1.6 if crawling else 1.9
	capsule.radius = 0.28 if crawling else 0.32
	collider.rotation.x = PI / 2.0 if crawling else 0.0
	collider.position = Vector3(0, 0.3 if crawling else 0.95, 0)
	name_label.position.y = 0.85 if crawling else 2.1
	_crawl_time = 0.0


func _update_animation(delta: float) -> void:
	var crawling = is_crawling()
	var speed = Vector2(velocity.x, velocity.z).length()
	var clip: StringName
	match get_state():
		State.FALL:
			clip = &"zombie/fall"
		State.SCREAM:
			clip = &"zombie/crawl_scream" if crawling else &"zombie/scream"
		State.ATTACK:
			clip = &"zombie/crawl_attack" if crawling else &"zombie/attack"
		State.BITE:
			clip = &"zombie/crawl_bite" if crawling else &"zombie/bite"
		State.FEED_INTRO:
			clip = &"zombie/crawl_feed_intro" if crawling else &"zombie/feed_intro"
		State.FEED_LOOP:
			clip = &"zombie/crawl_feed_loop" if crawling else &"zombie/feed_loop"
		_:
			clip = &"zombie/crawl" if crawling else (&"Sprint" if speed > 0.2 else &"Idle")
	var one_shot = (
		get_state()
		in [State.SCREAM, State.ATTACK, State.BITE, State.FEED_INTRO, State.FEED_LOOP, State.FALL]
	)
	if clip != _clip or (one_shot and _shown_transition != int(net_behavior.z)):
		animation.play(clip, 0.0 if one_shot or crawling else 0.12)
		_clip = clip
		_shown_transition = int(net_behavior.z)
	if one_shot:
		var length = animation.get_animation(clip).length
		var time = (
			fmod(_state_elapsed(), length)
			if get_state() == State.FEED_LOOP
			else minf(_state_elapsed(), length)
		)
		animation.seek(time, true)
		animation.pause()
	elif crawling:
		if speed > 0.05:
			_crawl_time += delta * clampf(speed / crawl_speed, 0.0, 1.5)
		animation.seek(fmod(_crawl_time, animation.get_animation(clip).length), true)
		animation.pause()
	else:
		animation.speed_scale = clampf(speed / 6.0, 0.4, 1.5) if clip == &"Sprint" else 1.0


func combat_die() -> void:
	super.combat_die()
	name_label.hide()
	_target = null
	_attack_target = null
	_hit_applied = true


func combat_respawn(position: Vector3) -> void:
	if simulates():
		_teleport(position)
		net_alerted = false
		net_prone = false
		net_stagger = Vector3(-100, 1, 0)
		net_behavior = Vector3(State.IDLE, _clock(), net_behavior.z + 1.0)
	super.combat_respawn(position)
	name_label.show()
	_clip = &""
	_target = null
	_attack_target = null
	_search_time = 0.0
	_hit_applied = false
	_feed_corpse = null
	_bite_killed = false
	visual.rotation.y = PI
	_update_collision()


func _teleport(position: Vector3) -> void:
	if Fusion.is_in_room():
		replicator.teleport_3d(position, Vector3.ZERO)
	else:
		global_position = position
		reset_physics_interpolation()
	velocity = Vector3.ZERO


func get_respawn_position() -> Vector3:
	return _spawn_position


func get_eye_position() -> Vector3:
	return global_position + Vector3.UP * (0.35 if is_crawling() else 1.62)
