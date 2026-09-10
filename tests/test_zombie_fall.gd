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
	var zombie = current_scene.get_node("Tony")
	var player = current_scene.local_player
	player.set_physics_process(false)
	zombie.set_physics_process(false)
	zombie.combat.apply_damage(100, Vector3.ZERO)
	check(zombie.get_state() != zombie.State.FALL, "exactly twenty percent does not fall")
	zombie._target = player
	zombie._lock_target()
	zombie._set_state(zombie.State.ATTACK)
	zombie.combat.apply_damage(1, Vector3.ZERO)
	zombie._update_collision()
	zombie._update_animation(0)
	check(
		zombie.get_state() == zombie.State.FALL and zombie._clip == &"zombie/fall",
		"threshold interrupts attack with Fall Flat"
	)
	check(
		not zombie.is_crawling() and is_zero_approx(zombie.collider.rotation.x),
		"starts upright rather than instantly prone"
	)
	var transition = zombie.net_behavior
	zombie.combat.apply_damage(1, Vector3.ZERO)
	check(zombie.net_behavior == transition, "additional shot does not restart fall")
	var length = zombie.animation.get_animation("zombie/fall").length
	zombie.net_behavior.y -= length * 0.7
	zombie._physics_process(1.0 / 60.0)
	check(is_equal_approx(zombie.collider.rotation.x, PI / 2), "collision lowers during fall")
	check(player.combat.health == 100, "falling zombie does not strike")
	zombie.net_behavior.y -= length * 0.31
	zombie._physics_process(1.0 / 60.0)
	zombie._update_animation(0)
	check(zombie.is_crawling() and zombie._clip == &"zombie/crawl", "completed fall enters crawl")
	var skeleton = zombie.get_node("Visual/Model/Armature/Skeleton3D")
	check(
		skeleton.get_bone_pose_position(skeleton.find_bone("Hips")).y < 0.4,
		"crawl begins in a low pose"
	)
	zombie.combat.apply_damage(1000, Vector3.ZERO)
	zombie.combat._dead_time = 5.0
	await physics_frame
	await physics_frame
	check(not zombie.net_prone and zombie.combat.health == 125, "respawn clears prone state")
	zombie.combat.apply_damage(101, Vector3.ZERO)
	check(zombie.get_state() == zombie.State.FALL, "new life may fall again")
	zombie.combat.apply_damage(1000, Vector3.ZERO)
	check(zombie.combat.is_dead() and not zombie.visual.visible, "lethal shot overrides fall")
	print("FALL_FAILURES=", failures)
	quit(1 if failures else 0)
