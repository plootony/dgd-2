extends SceneTree
var weapons: CanvasLayer


func _initialize():
	run.call_deferred()


func step(seconds: float):
	for i in ceili(seconds * 60):
		weapons._process(1.0 / 60.0)


func run():
	weapons = load("res://weapons/first_person_weapons.gd").new()
	root.add_child(weapons)
	weapons.set_active(true)
	weapons.set_process(false)
	for slot in 2:
		weapons.select_slot(slot)
		var player = weapons._players[slot]
		for clip in ["idle", "aim", "shoot", "reload"]:
			assert(player.has_animation("viewmodel/" + clip))
			assert(player.get_animation("viewmodel/" + clip).get_track_count() > 0)
		weapons.update_controls(true, true, false, false)
		var before = weapons.shots_played
		weapons.request_fire()
		step(1.0)
		assert(
			weapons.shots_played - before >= 7 if slot == 0 else weapons.shots_played - before == 1
		)
		weapons.update_controls(true, false, false, false)
		step(0.3)
		weapons.request_reload()
		assert(weapons.action == &"reload")
		before = weapons.shots_played
		weapons.request_fire()
		step(0.5)
		assert(weapons.action == &"reload" and weapons.shots_played == before)
		step(player.get_animation("viewmodel/reload").length)
		assert(weapons.action == &"idle")
		weapons.update_controls(true, false, true, true)
		step(0.5)
		assert(weapons.aim_blend == 1.0 and weapons.run_blend == 0.0)
		var xf = weapons._models[slot].transform
		for point in [
			weapons.WeaponCatalog.DEFINITIONS[slot].rear_sight,
			weapons.WeaponCatalog.DEFINITIONS[slot].front_sight
		]:
			var aligned: Vector3 = xf * point
			assert(absf(aligned.x) < 0.0001 and absf(aligned.y) < 0.0001 and aligned.z < 0.0)
		weapons.update_controls(true, false, false, true)
		step(0.5)
		assert(weapons.run_blend == 1.0)
		weapons.update_controls(false, true, true, true)
		step(0.5)
		assert(weapons.run_blend == 0.0 and weapons.aim_blend == 0.0)
		weapons.request_reload()
		weapons.set_active(false)
		assert(weapons.action == &"idle" and not weapons._image.visible)
		weapons.set_active(true)
		print("ACTIONS_OK slot=", slot)
	print("ALL_ACTION_CHECKS_PASSED")
	quit()
