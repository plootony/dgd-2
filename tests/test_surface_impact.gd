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
	var wall = StaticBody3D.new()
	var collision = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(2, 3, 0.3)
	collision.shape = box
	wall.add_child(collision)
	current_scene.add_child(wall)
	wall.position = Vector3(0, 1.5, 3)
	await physics_frame
	await physics_frame
	var shot = {"origin": Vector3(0, 1, 6), "direction": Vector3.FORWARD, "slot": 0, "life": 0}
	player.combat._resolve_shot(shot)
	var effects = get_nodes_in_group("SurfaceImpacts")
	check(effects.size() == 1, "wall receives an impact")
	check(
		zombie.combat.health == 125 and get_nodes_in_group("BloodImpacts").is_empty(),
		"wall blocks damage and produces no blood"
	)
	var effect = effects[0]
	check(
		effect.global_position.distance_to(Vector3(0, 1, 3.158)) < 0.02,
		"mark sits at raycast contact"
	)
	check(effect._mark.global_basis.z.dot(Vector3.BACK) > 0.99, "mark faces the surface normal")
	player.combat._show_surface(1, Vector3.ZERO, Vector3.UP)
	check(get_nodes_in_group("SurfaceImpacts").size() == 1, "duplicate event ignored")
	shot.direction = Vector3.UP
	player.combat._resolve_shot(shot)
	check(get_nodes_in_group("SurfaceImpacts").size() == 1, "miss produces no impact")
	effect._process(0.5)
	check(not effect._dust.visible, "dust expires quickly")
	effect._process(20)
	await process_frame
	await process_frame
	check(get_nodes_in_group("SurfaceImpacts").is_empty(), "mark expires")
	print("SURFACE_FAILURES=", failures)
	quit(1 if failures else 0)
