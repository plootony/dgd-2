extends SceneTree
var failures = 0


func _initialize():
	run.call_deferred()


func check(value: bool, label: String):
	print("PASS " if value else "FAIL ", label)
	if not value:
		failures += 1


func run():
	var weapons = load("res://weapons/first_person_weapons.gd").new()
	root.add_child(weapons)
	weapons.set_active(true)
	weapons.set_process(false)
	var ammo = weapons.ammunition
	check(
		ammo.magazines == [30, 15] and ammo.reserves == [90, 45], "starting magazines and reserve"
	)
	weapons.request_reload()
	check(weapons.action == &"idle", "full magazine cannot reload")
	weapons.update_controls(true, true, false, false)
	for i in 35:
		weapons._process(0.13)
	check(
		weapons.shots_played == 30 and ammo.magazines[0] == 0,
		"empty magazine blocks animation and damaging shot"
	)
	var count = weapons.shots_played
	weapons._flashes[0]._process(0.1)
	weapons._process(0.13)
	check(
		not weapons._flashes[0].visible and weapons.shots_played == count,
		"empty trigger produces no flash"
	)
	weapons.update_controls(true, false, false, false)
	weapons.request_reload()
	weapons._process(0.1)
	check(ammo.magazines[0] == 0 and ammo.reserves[0] == 90, "reload does not transfer ammo early")
	weapons.select_slot(1)
	check(ammo.reload_slot == -1 and ammo.magazines[0] == 0, "switch cancels pending reload")
	weapons.select_slot(0)
	weapons.request_reload()
	weapons._process(weapons._players[0].get_animation("viewmodel/reload").length + 0.01)
	check(
		ammo.magazines[0] == 30 and ammo.reserves[0] == 60,
		"completed reload transfers one magazine"
	)
	weapons.select_slot(1)
	weapons.update_controls(true, false, false, false)
	weapons.request_fire()
	weapons._process(0.01)
	check(ammo.magazines[1] == 14 and ammo.magazines[0] == 30, "weapons retain independent ammo")
	check(weapons._flashes[1].visible, "valid pistol shot flashes")
	weapons._flashes[1]._process(0.1)
	check(not weapons._flashes[1].visible, "flash expires promptly")
	weapons.request_reload()
	weapons.set_active(false)
	check(
		ammo.magazines[1] == 14 and ammo.reserves[1] == 45,
		"hiding weapon cancels reload without granting ammo"
	)
	weapons.set_active(true)
	ammo.magazines[1] = 0
	ammo.reserves[1] = 3
	weapons.request_reload()
	weapons._process(4.0)
	check(
		ammo.magazines[1] == 3 and ammo.reserves[1] == 0,
		"partial reserve loads only available bullets"
	)
	weapons.request_reload()
	check(weapons.action == &"idle", "no reserve prevents reload")
	weapons.reset_ammunition()
	check(
		ammo.magazines == [30, 15] and ammo.reserves == [90, 45],
		"respawn reset restores starting inventory"
	)
	check("15 / 45" in weapons._ammo_label.text, "HUD shows selected magazine and reserve")
	print("AMMUNITION_FAILURES=", failures)
	quit(1 if failures else 0)
