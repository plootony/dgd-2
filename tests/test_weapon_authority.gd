extends SceneTree


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	change_scene_to_file("res://game/main.tscn")
	await scene_changed
	current_scene.start_offline()
	var player = current_scene.local_player
	var combat = player.combat
	var eye = player.get_eye_position()
	combat.request_shot(1, eye, Vector3.FORWARD, 2)
	assert(combat._shots.is_empty(), "Disabled pistol auto mode rejected")
	combat.request_shot(1, eye, Vector3.FORWARD, 0, NAN)
	assert(combat._shots.is_empty(), "Invalid ADS rejected")
	combat.request_shot(0, eye, Vector3.FORWARD, 1)
	combat.request_shot(0, eye, Vector3.FORWARD, 1)
	assert(combat._shots.size() == 1, "Burst interval validated")
	combat._shots.clear()
	for i in 15:
		combat.request_shot(1, eye, Vector3.FORWARD, 0, 1.0)
	assert(combat._shots.size() == 15)
	var changed = false
	for shot in combat._shots:
		changed = changed or not shot.direction.is_equal_approx(Vector3.FORWARD)
	assert(changed, "Authority applies spread")
	assert(combat._ballistics._heat.has(1))
	print(
		"WEAPON_AUTHORITY_PASSED: allowed modes, cooldown, ADS validation, server spread, rapid pistol"
	)
	quit()
