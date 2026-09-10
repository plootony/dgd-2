extends SceneTree


func _initialize():
	run.call_deferred()


func run():
	change_scene_to_file("res://game/main.tscn")
	await scene_changed
	current_scene.start_offline()
	var player = current_scene.local_player
	var zombie = current_scene.get_node("Tony")
	player.set_physics_process(false)
	player.global_position = Vector3(9, 0, -13)
	zombie.global_position = Vector3(9, 0, -5)
	zombie.net_alerted = true
	zombie._target = player
	var lateral = 0.0
	for frame in 420:
		await physics_frame
		lateral = maxf(lateral, absf(zombie.global_position.x - 9))
	var distance = zombie.global_position.distance_to(player.global_position)
	print("NAVIGATION lateral=", lateral, " remaining=", distance)
	if lateral < 2.2 or distance > 2.0:
		push_error("Zombie failed to route around the tall block")
		quit(1)
		return
	zombie.global_position = Vector3.ZERO
	zombie.velocity = Vector3.ZERO
	player.global_position = Vector3(0, 0, 5)
	zombie.combat.apply_damage(101, Vector3.ZERO)
	await create_timer(zombie.animation.get_animation("zombie/fall").length + 0.1).timeout
	zombie.global_position = Vector3.ZERO
	zombie.velocity = Vector3.ZERO
	zombie._set_state(zombie.State.CHASE)
	zombie._search_time = 0.0
	for frame in 90:
		await physics_frame
	var skeleton: Skeleton3D = zombie.get_node("Visual/Model/Armature/Skeleton3D")
	var hip_height = skeleton.get_bone_pose_position(skeleton.find_bone("Hips")).y
	print("CRAWL z=", zombie.global_position.z, " hip_height=", hip_height)
	if zombie.global_position.z < 0.3 or zombie.global_position.z > 1.4 or hip_height > 0.4:
		push_error("Crawling must move slowly with a genuinely low skeleton pose")
		quit(1)
		return
	print("ZOMBIE_NAVIGATION_PASSED")
	quit()
