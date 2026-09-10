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
	var zombie = current_scene.get_node("Tony")
	zombie.set_physics_process(false)
	player.set_physics_process(false)
	for source in [player.combat.DamageSource.ZOMBIE, player.combat.DamageSource.PLAYER]:
		player.position = Vector3(0, 0, 6)
		await physics_frame
		player.combat.apply_damage(100, Vector3.ZERO, 10.0, source)
		var corpse = player.last_corpse
		var pool = corpse.get_node("BloodPool")
		check(pool._pool == null, "no pool in the air during initial fall")
		await create_timer(4.8).timeout
		check(is_instance_valid(pool._pool), "pool appears below corpse for source %d" % source)
		if is_instance_valid(pool._pool):
			check(absf(pool._pool.global_position.y) < 0.03, "pool lies on the floor")
			var size = pool._pool.scale.x
			pool._physics_process(2.0)
			check(pool._pool.scale.x > size, "pool grows gradually")
		corpse.queue_free()
		await process_frame
		await process_frame
		check(not is_instance_valid(pool), "pool is removed with corpse")
		player.combat._dead_time = 10.0
		await physics_frame
		await physics_frame
	zombie.combat.apply_damage(1000, Vector3.ZERO)
	check(not zombie.last_corpse.has_node("BloodPool"), "pool is only added to player corpses")
	print("BLOOD_POOL_FAILURES=", failures)
	quit(1 if failures else 0)
