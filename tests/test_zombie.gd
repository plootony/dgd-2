extends SceneTree
var failures = 0
var game: Node
var player: CharacterBody3D
var zombie: CharacterBody3D


func _initialize():
	run.call_deferred()


func check(value: bool, label: String):
	print("PASS " if value else "FAIL ", label)
	if not value:
		failures += 1


func wait_physics(frames: int = 2):
	for frame in frames:
		await physics_frame


func tick(elapsed: float = 0.0):
	zombie.net_behavior.y -= elapsed
	zombie._physics_process(1.0 / 60.0)
	zombie._update_animation(0.0)


func run():
	change_scene_to_file("res://game/main.tscn")
	await scene_changed
	game = current_scene
	game.start_offline()
	player = game.local_player
	zombie = game.get_node("Tony")
	player.set_physics_process(false)
	zombie.set_physics_process(false)
	player.global_position = Vector3(0, 0, 6)
	zombie.global_position = Vector3.ZERO
	zombie.rotation.y = PI
	await wait_physics()
	tick()
	check(zombie.get_state() == zombie.State.SCREAM, "first detection warns once")
	tick(3)
	tick()
	check(zombie.velocity.z > 0, "pursues after warning")
	var speed = Vector2(zombie.velocity.x, zombie.velocity.z).length()
	zombie.combat.apply_damage(1, Vector3.RIGHT)
	check(zombie.get_state() == zombie.State.CHASE, "damage does not interrupt pursuit")
	check(zombie._stagger_active(), "brief slowdown starts")
	zombie.net_stagger.x -= 0.11
	zombie._update_flinch()
	check(absf(zombie.visual.rotation.y - PI) > 0.05, "body turns briefly sideways")
	zombie.net_stagger.x -= 1.0
	zombie._update_flinch()
	check(
		not zombie._stagger_active() and is_equal_approx(zombie.visual.rotation.y, PI),
		"flinch ends automatically"
	)
	check(not zombie.animation.has_animation("zombie/hit"), "slow hit clip removed")
	player.global_position = Vector3(0, 0, 1.3)
	await wait_physics()
	zombie.net_grounded = true
	tick()
	for punch in 4:
		check(zombie.get_state() == zombie.State.ATTACK, "continuous punch without idle")
		var sequence = zombie.net_behavior.z
		zombie.combat.apply_damage(1, Vector3.RIGHT)
		check(zombie.net_behavior.z == sequence, "flinch does not restart attack")
		tick(zombie.attack_hit_time + 0.01)
		check(player.combat.health == 100 - (punch + 1) * 20, "one punch damage event")
		tick()
		check(player.combat.health == 100 - (punch + 1) * 20, "no repeated damage")
		tick(0.51)
	check(
		zombie.animation.get_animation("zombie/attack").length < 1.4, "attack recovery tail trimmed"
	)
	check(zombie.get_state() == zombie.State.BITE, "bite selected only at lethal health")
	player.global_position = Vector3(0, 0, 6)
	await wait_physics()
	tick(zombie.bite_hit_time + 0.01)
	check(player.combat.health == 20, "bite can be dodged")
	tick(5)
	player.global_position = Vector3(0, 0, 1.3)
	await wait_physics()
	tick()
	tick(zombie.bite_hit_time + 0.01)
	check(player.combat.is_dead(), "successful bite is fatal")
	check(
		is_instance_valid(player.last_corpse) and player.last_corpse.is_in_group("AnimatedCorpses"),
		"bite creates animated corpse"
	)
	check(player.combat.respawn_delay > 14, "death view lasts through feeding")
	player._update_death_camera(1.5)
	check(
		player.arm.spring_length > 4 and player.rig.rotation.x < -0.7,
		"death camera rises and looks down"
	)
	tick(4)
	check(zombie.get_state() == zombie.State.FEED_APPROACH, "killer approaches its victim corpse")
	tick(2.1)
	check(zombie.get_state() == zombie.State.FEED_INTRO, "kneeling intro begins")
	tick(3.51)
	check(zombie.get_state() == zombie.State.FEED_LOOP, "intro transitions to eating loop")
	check(zombie._clip == &"zombie/feed_loop", "feeding loop clip selected")
	zombie.combat.apply_damage(1, Vector3.RIGHT)
	check(zombie.get_state() == zombie.State.FEED_LOOP, "flinch does not cancel feeding")
	tick(zombie.feed_seconds + 0.01)
	check(zombie.get_state() == zombie.State.CHASE, "feeding ends after its duration")
	zombie.combat.apply_damage(zombie.combat.health - 24, Vector3.ZERO)
	tick()
	check(zombie.is_crawling(), "low health still enables crawl")
	zombie.combat.apply_damage(1000, Vector3.ZERO)
	check(zombie.combat.is_dead(), "zombie can be killed during any action")
	zombie.combat._dead_time = 5.0
	await wait_physics()
	check(zombie.combat.health == 125 and not zombie.net_alerted, "respawn resets zombie")
	for state in [zombie.State.CHASE, zombie.State.SCREAM, zombie.State.ATTACK, zombie.State.BITE]:
		var removed = load("res://characters/player/player.tscn").instantiate()
		game.add_child(removed)
		zombie._target = removed
		zombie._attack_target = removed
		zombie._attack_target_life = removed.combat.life
		zombie._set_state(state, true)
		zombie._search_time = 1
		removed.queue_free()
		await wait_physics()
		check(
			not zombie._is_living(removed) and not zombie._can_hit(removed),
			"deleted target safely rejected"
		)
		tick(10)
		check(
			zombie.get_state() in [zombie.State.IDLE, zombie.State.CHASE],
			"deleted target cancels action"
		)
	print("ZOMBIE_TEST_FAILURES=", failures)
	quit(1 if failures else 0)
