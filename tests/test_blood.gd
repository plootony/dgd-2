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
	player.set_physics_process(false)
	zombie.set_physics_process(false)
	player.position = Vector3(0, 0, 6)
	zombie.position = Vector3.ZERO
	await physics_frame
	await physics_frame
	var shot = {"origin": Vector3(0, 1, 6), "direction": Vector3.FORWARD, "slot": 0, "life": 0}
	player.combat._resolve_shot(shot)
	var impacts = get_nodes_in_group("BloodImpacts")
	check(impacts.size() == 1, "confirmed character hit creates one blood effect")
	var impact = impacts[0]
	check(impact._drops.multimesh.instance_count == 16, "impact emits blood droplets")
	check(is_instance_valid(impact._stamp), "nearby floor receives blood splatter")
	player.combat._show_impact(
		1, Vector3.ZERO, Vector3.UP, Vector3.FORWARD, Vector3.ZERO, Vector3.UP
	)
	check(get_nodes_in_group("BloodImpacts").size() == 1, "duplicate hit event is ignored")
	shot.direction = Vector3.UP
	player.combat._resolve_shot(shot)
	check(get_nodes_in_group("BloodImpacts").size() == 1, "miss produces no blood")
	impact._process(0.6)
	check(not impact._drops.visible, "blood droplets expire")
	impact._process(16)
	await process_frame
	await process_frame
	check(get_nodes_in_group("BloodImpacts").is_empty(), "blood splatter cleans up")
	print("BLOOD_FAILURES=", failures)
	quit(1 if failures else 0)
