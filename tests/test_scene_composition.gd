extends SceneTree
## Actors must work without a particular current_scene or a Main.local_player field.


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var world = Node3D.new()
	root.add_child(world)
	var corpses = Node3D.new()
	world.add_child(corpses)
	var player = load("res://characters/player/player.tscn").instantiate()
	player.offline = true
	player.corpse_parent = corpses
	world.add_child(player)
	var tony = load("res://characters/tony/tony.tscn").instantiate()
	tony.corpse_parent = corpses
	world.add_child(tony)
	assert(current_scene == null)
	assert(player.combat.actor == player and tony.combat.actor == tony)
	assert(player.has_method("rpc_combat_state") and tony.has_method("rpc_combat_state"))
	player.combat.apply_damage(100, Vector3.FORWARD)
	tony.combat.apply_damage(tony.combat.max_health, Vector3.BACK)
	await physics_frame
	await physics_frame
	assert(corpses.get_child_count() == 2)
	assert(not player.visual.visible and not tony.visual.visible)
	world.queue_free()
	await process_frame
	assert(get_nodes_in_group("Ragdolls").is_empty())
	change_scene_to_file("res://game/main.tscn")
	await scene_changed
	var game = current_scene
	game.ui.offline_button.pressed.emit()
	await process_frame
	player = game.local_player
	assert(is_instance_valid(player) and not game.ui.panel.visible)
	assert(player.corpse_parent == game.get_node("Corpses"))
	# The headless display driver does not capture the mouse.
	if DisplayServer.get_name() != "headless":
		await create_timer(0.4).timeout
		Input.action_press("move_forward")
		await create_timer(0.5).timeout
		assert(Vector2(player.velocity.x, player.velocity.z).length() > 2.8)
		Input.action_press("run")
		await create_timer(0.5).timeout
		assert(Vector2(player.velocity.x, player.velocity.z).length() > 5.8)
		Input.action_release("run")
		Input.action_press("crouch")
		await create_timer(0.3).timeout
		assert(player.net_crouched and is_equal_approx(player.collider.shape.height, 1.1))
		Input.action_release("crouch")
		Input.action_release("move_forward")
	game._show_menu(true)
	assert(not player.input_enabled)
	game.ui.resume_requested.emit()
	assert(player.input_enabled and not game.ui.panel.visible)
	game.ui.graphics_requested.emit()
	assert(game.graphics_settings.visible)
	print("SCENE_COMPOSITION_PASSED display=", DisplayServer.get_name())
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/dgd-refactor/composition.png")
	quit()
