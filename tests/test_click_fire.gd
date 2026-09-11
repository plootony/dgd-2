extends SceneTree


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	change_scene_to_file("res://game/main.tscn")
	await scene_changed
	for zombie in get_nodes_in_group("NPCs"):
		zombie.set_physics_process(false)
	current_scene.start_offline()
	var player = current_scene.local_player
	player.set_process(false)
	player.set_physics_process(false)
	player.third_person = false
	player._update_view()
	player.rig.global_position = player.get_eye_position()
	player.camera.position = Vector3.ZERO
	var weapons = player.first_person_weapons
	weapons.set_process(false)
	weapons.select_slot(1)
	weapons.update_controls(true, false, false, false)
	var shots = weapons.shots_played
	var origin = player.camera.global_position
	# Use the actual firing path; same-frame clicks must each spend ammo and queue a raycast.
	for i in 15:
		weapons.request_fire()
		assert(weapons.shots_played == shots + i + 1)
	assert(weapons.ammunition.magazines[1] == 0)
	assert(player.combat._shots.size() == 15)
	weapons.request_fire()
	assert(weapons.shots_played == shots + 15)
	weapons.reset_ammunition()
	weapons.update_controls(true, true, false, false)
	weapons._process(1.0)
	assert(weapons.shots_played == shots + 15, "Holding the trigger must not fire a semi-auto")
	weapons.request_fire()
	weapons.request_reload()
	weapons.request_fire()
	assert(weapons.shots_played == shots + 16 and weapons.action == &"reload")
	weapons.reset_ammunition()
	weapons.update_controls(false, false, false, false)
	weapons.request_fire()
	assert(weapons.shots_played == shots + 16)
	weapons.set_active(false)
	weapons.request_fire()
	assert(weapons.shots_played == shots + 16)
	# Unlimited pistol fire must not turn off the rifle's server cooldown.
	var combat = player.combat
	combat._shots.clear()
	combat._next_fire = 0.0
	combat.request_shot(0, origin, Vector3.FORWARD)
	combat.request_shot(0, origin, Vector3.FORWARD)
	assert(combat._shots.size() == 1)
	combat.request_shot(1, origin, Vector3.FORWARD)
	combat.request_shot(0, origin, Vector3.FORWARD)
	assert(combat._shots.size() == 2)
	print(
		"CLICK_FIRE_PASSED: 15 immediate clicks, ammo, authority, empty/reload/menu, rifle cooldown"
	)
	quit()
