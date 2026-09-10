extends SceneTree
var failures = 0


func _initialize():
	run.call_deferred()


func check(value: bool, label: String):
	print("PASS " if value else "FAIL ", label)
	if not value:
		failures += 1


func run():
	change_scene_to_file("res://game/main.tscn")
	await scene_changed
	current_scene.start_offline()
	var player = current_scene.local_player
	current_scene.get_node("Tony").set_physics_process(false)
	player.set_physics_process(false)
	player.global_position = Vector3(0, 0, 6)
	await physics_frame
	await physics_frame
	player.combat.apply_damage(100, Vector3.FORWARD, 5.0, player.combat.DamageSource.ZOMBIE)
	var corpse = player.last_corpse
	check(corpse.is_in_group("AnimatedCorpses"), "zombie damage selects animated corpse")
	check(get_nodes_in_group("Ragdolls").is_empty(), "zombie kill creates no ragdoll")
	check(
		corpse.animator.current_animation == "death/death_forward",
		"Standing React Death Forward is playing"
	)
	var before = corpse.get_focus_position()
	await create_timer(4.0).timeout
	check(corpse.get_focus_position().y < before.y - 0.4, "death animation falls to ground")
	check(not corpse.animator.is_playing(), "death animation stops on final pose")
	var final_position = corpse.get_focus_position()
	await create_timer(0.2).timeout
	check(corpse.get_focus_position().is_equal_approx(final_position), "final corpse pose is held")
	player.combat._dead_time = player.combat.respawn_delay
	await physics_frame
	await physics_frame
	check(
		not player.combat.is_dead() and is_instance_valid(corpse),
		"animated corpse persists after respawn"
	)
	player.combat.apply_damage(100, Vector3.FORWARD, 5.0, player.combat.DamageSource.PLAYER)
	check(player.last_corpse.is_in_group("Ragdolls"), "player damage selects physical ragdoll")
	check(player.last_corpse.bodies.size() == 15, "PvP corpse retains physical bones")
	corpse._age = 20.0
	await process_frame
	await process_frame
	check(not is_instance_valid(corpse), "animated corpse expires")
	print("DEATH_SOURCE_FAILURES=", failures)
	quit(1 if failures else 0)
