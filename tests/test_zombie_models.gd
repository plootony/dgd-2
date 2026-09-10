extends SceneTree


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	change_scene_to_file("res://game/main.tscn")
	await scene_changed
	assert(get_nodes_in_group("NPCs").size() == 10)
	for zombie in get_nodes_in_group("NPCs"):
		assert(
			zombie.name_label.text == String(zombie.name).get_slice("_", 0).to_upper() + " / ЗОМБИ"
		)
		assert(zombie.run_speed == 7.0 and zombie.crawl_speed == 1.2)
		assert(
			zombie.get_respawn_position().is_equal_approx(zombie.global_position + Vector3.UP * 0.8)
		)
		assert(zombie.corpse_parent == current_scene.get_node("Corpses"))
		zombie.set_physics_process(false)
		var skeleton = zombie.get_node("Visual/Model/Armature/Skeleton3D")
		for clip in zombie.animation.get_animation_list():
			var animation = zombie.animation.get_animation(clip)
			for track in animation.get_track_count():
				var path = animation.track_get_path(track)
				assert(
					zombie.get_node("Visual/Model").has_node(
						NodePath(path.get_concatenated_names())
					)
				)
				assert(skeleton.find_bone(path.get_subname(0)) >= 0)
			zombie.animation.play(clip)
			zombie.animation.seek(animation.length * 0.5, true)
			zombie.animation.advance(0)
		zombie.combat.apply_damage(1000, Vector3.ZERO)
		assert(zombie.last_corpse.get_parent() == current_scene.get_node("Corpses"))
		assert(zombie.last_corpse.bodies.size() == 15)
		print("MODEL_PASS ", zombie.name, " animations, corpse container, 15 ragdoll bones")
	print("ZOMBIE_MODELS_PASSED")
	quit()
