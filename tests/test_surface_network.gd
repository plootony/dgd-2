extends SceneTree
var role = "host"
var failures = 0


func check(value: bool, label: String):
	print("NET_PASS " if value else "NET_FAIL ", role, " ", label)
	if not value:
		failures += 1


func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="):
			role = arg.trim_prefix("--role=")
	run.call_deferred()


func run():
	change_scene_to_file("res://game/main.tscn")
	await scene_changed
	var scene = current_scene
	scene.get_node("Tony").set_physics_process(false)
	var deadline = Time.get_ticks_msec() + 45000
	while (
		not is_instance_valid(scene.local_player) or scene.get_node("Players").get_child_count() < 2
	):
		if Time.get_ticks_msec() > deadline:
			print("NET_FAIL connection timeout ", role)
			quit(1)
			return
		await process_frame
	var p = scene.local_player
	p.set_physics_process(false)
	p.set_process(false)
	p.respawn(Vector3(0, 0, 0) if role == "host" else Vector3(0, 0, 6))
	var tony = scene.get_node("Tony")
	tony.set_physics_process(false)
	tony.set_process(false)
	if Fusion.is_master_client():
		tony.replicator.teleport_3d(Vector3(4, 0, 0), Vector3.ZERO)
	p.third_person = false
	p._update_view()
	p.first_person_weapons.set_process(false)
	p.net_nickname = "combat_fixture_ready"
	await create_timer(2).timeout
	var other: Node
	for node in scene.get_node("Players").get_children():
		if node != p:
			other = node
	while other.net_nickname != "combat_fixture_ready":
		await process_frame
	await create_timer(0.5).timeout
	if role == "client":
		p.rig.global_position = p.global_position + Vector3.UP * 1.62
		p.camera.position = Vector3.ZERO
		p.camera.look_at(other.global_position + Vector3.UP * 1.0)
		p.first_person_weapons.select_slot(1)
		p.first_person_weapons.update_controls(true, false, false, false)
		for i in 3:
			p.first_person_weapons.request_fire()
			p.first_person_weapons._process(0.35)
			await create_timer(0.35).timeout
		await create_timer(0.6).timeout
		check(other.combat.health == 0, "client raycasts kill remote player")
		check(p.combat.health == 100, "shooter unharmed")
		check(get_nodes_in_group("Ragdolls").size() == 1, "remote corpse visible")
		p.camera.look_at(tony.global_position + Vector3.UP * 1.0)
		p.first_person_weapons.select_slot(0)
		p.first_person_weapons.update_controls(true, false, false, false)
		for i in 4:
			p.first_person_weapons.request_fire()
			p.first_person_weapons._process(0.2)
			await create_timer(0.2).timeout
		await create_timer(0.6).timeout
		check(tony.combat.health == 0, "client raycasts kill Tony")
		check(
			p.first_person_weapons.ammunition.magazines == [26, 12],
			"actual firing consumes both magazines"
		)
		p.first_person_weapons.select_slot(1)
		p.first_person_weapons.update_controls(true, false, false, false)
		p.camera.look_at(Vector3(0, 0, 4))
		p.first_person_weapons.request_fire()
		p.first_person_weapons._process(0.35)
		await create_timer(6).timeout
		check(other.combat.health == 100 and other.combat.life == 1, "remote respawn replicated")
		check(
			tony.combat.health == tony.combat.max_health and tony.combat.life == 1,
			"Tony respawn replicated"
		)
	else:
		await create_timer(1.7).timeout
		check(p.combat.health == 0, "host receives lethal damage")
		check(not p.first_person_weapons.active, "host weapons disabled on death")
		check(
			get_nodes_in_group("Ragdolls").any(
				func(corpse): return corpse.global_position.distance_to(p.global_position) < 0.1
			),
			"host corpse visible",
		)
		await create_timer(1.4).timeout
		check(tony.combat.health == 0, "host sees Tony death")
		await create_timer(6).timeout
		check(p.combat.health == 100 and p.combat.life == 1, "host respawn")
		check(
			tony.combat.health == tony.combat.max_health and tony.combat.life == 1,
			"host Tony respawn"
		)
	print(
		"BLOOD_TOTAL ",
		role,
		" ",
		p.combat._shown_impact if role == "client" else other.combat._shown_impact
	)
	check(
		(p.combat._shown_impact if role == "client" else other.combat._shown_impact) == 7,
		"seven confirmed blood events received on this peer"
	)
	check(
		(p.combat._shown_surface if role == "client" else other.combat._shown_surface) == 1,
		"surface impact reaches both peers"
	)
	print("NETWORK_TEST_FAILURES=", failures, " role=", role)
	p.net_nickname = "effects_test_done"
	var done_deadline = Time.get_ticks_msec() + 20000
	while (
		is_instance_valid(other)
		and other.net_nickname != "effects_test_done"
		and Time.get_ticks_msec() < done_deadline
	):
		await process_frame
	await create_timer(1).timeout
	Fusion.disconnect_from_photon()
	quit(1 if failures else 0)
