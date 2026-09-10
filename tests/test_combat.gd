extends SceneTree
var failures = 0


func check(value: bool, label: String):
	print("PASS " if value else "FAIL ", label)
	if not value:
		failures += 1


func _initialize():
	run.call_deferred()


func run():
	change_scene_to_file("res://game/main.tscn")
	await scene_changed
	current_scene.start_offline()
	var player = current_scene.local_player
	var tony = current_scene.get_node("Tony")
	player.set_physics_process(false)
	tony.set_physics_process(false)
	player.global_position = Vector3(0, 0, 6)
	tony.global_position = Vector3(0, 0, 0)
	await physics_frame
	await physics_frame
	var shot = {"origin": Vector3(0, 1, 6), "direction": Vector3.FORWARD, "slot": 0, "life": 0}
	player.combat._resolve_shot(shot)
	check(tony.combat.health == tony.combat.max_health - 34, "raycast hits Tony; shooter excluded")
	player.combat._resolve_shot(shot)
	player.combat._resolve_shot(shot)
	await physics_frame
	await physics_frame
	player.combat._resolve_shot(shot)
	await physics_frame
	check(tony.combat.is_dead(), "lethal rifle damage kills Tony")
	check(
		not tony.get_node("Visual").visible and tony.get_node("CollisionShape3D").disabled,
		"dead actor invisible and noncolliding"
	)
	check(get_nodes_in_group("Ragdolls").size() == 1, "one corpse created")
	var corpse = get_nodes_in_group("Ragdolls")[0]
	check(corpse.bodies.size() == 15, "15 physical bones")
	for bone in corpse.bodies:
		check(
			bone.get_bone_id() >= 0 and bone.is_simulating_physics(),
			"bound active bone " + bone.name
		)
	var hips: PhysicalBone3D = corpse.bodies[0]
	var before = hips.global_position
	for i in 180:
		await physics_frame
	print("HIPS ", before, " -> ", hips.global_position)
	check(
		hips.global_position.y < before.y - 0.3 and hips.global_position.y > -0.3,
		"ragdoll falls and collides with floor"
	)
	# Walls occlude hits.
	var wall = StaticBody3D.new()
	var collision = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(2, 3, 0.3)
	collision.shape = box
	wall.add_child(collision)
	current_scene.add_child(wall)
	wall.position = Vector3(0, 1.5, 3)
	tony.combat._dead_time = 5.0
	await physics_frame
	await physics_frame
	tony.global_position = Vector3(0, 0, 0)
	await physics_frame
	player.combat._resolve_shot(shot)
	check(tony.combat.health == tony.combat.max_health, "wall blocks damage")
	wall.queue_free()
	await physics_frame
	# Player death and respawn also restore local weapons and collision.
	player.third_person = false
	player._update_view()
	player.combat.apply_damage(100, Vector3.BACK, 5.0, player.combat.DamageSource.PLAYER)
	await physics_frame
	check(
		player.combat.is_dead() and not player.first_person_weapons.active,
		"player death disables weapons"
	)
	check(get_nodes_in_group("Ragdolls").size() == 2, "player mannequin ragdoll created")
	player.combat._dead_time = 5.0
	await physics_frame
	await physics_frame
	check(
		(
			player.combat.health == 100
			and player.first_person_weapons.active
			and not player.collider.disabled
		),
		"respawn restores health, weapons and capsule"
	)
	check(get_nodes_in_group("Ragdolls").size() == 2, "corpses persist after respawn")

	# Exercise the real weapon signal -> shot queue -> physics raycast against a player.
	tony.position = Vector3(10, 0, 0)
	var remote = load("res://characters/player/player.tscn").instantiate()
	remote.set_script(load("res://tests/fixtures/remote_combat_fixture.gd"))
	current_scene.get_node("Players").add_child(remote)
	remote.global_position = Vector3.ZERO
	player.set_process(false)
	player.global_position = Vector3(0, 0, 6)
	player.rig.global_position = Vector3(0, 1.62, 6)
	player.rig.look_at(Vector3(0, 1, 0))
	player.camera.transform = Transform3D.IDENTITY
	var weapons = player.first_person_weapons
	weapons.set_process(false)
	weapons.select_slot(1)
	weapons.update_controls(true, false, false, false)
	await physics_frame
	weapons.request_fire()
	weapons._process(0.01)
	await physics_frame
	await physics_frame
	check(
		remote.combat.health == 60,
		"pistol animation signal queues a raycast that damages another player"
	)
	var count = weapons.shots_played
	weapons.request_reload()
	weapons.request_fire()
	weapons._process(0.01)
	check(weapons.shots_played == count, "reload does not emit a damaging shot")
	player.third_person = true
	player.fire_weapon(0)
	check(player.combat._shots.is_empty(), "third-person fire is disabled")
	player.third_person = false
	player.combat._next_fire = 0
	player.combat._queue_shot(100, player.combat.life, 0, Vector3(100, 100, 100), Vector3.FORWARD)
	player.combat._queue_shot(
		101, player.combat.life - 1, 0, player.camera.global_position, Vector3.FORWARD
	)
	check(player.combat._shots.is_empty(), "invalid origin and previous-life shots rejected")
	var state: Vector3 = player.combat.net_state
	player.combat.net_state = Vector3(0, 0, state.z - 1)
	check(
		player.combat.health == 100 and player.combat.life == 1,
		"stale network snapshots cannot undo respawn"
	)
	for body in get_nodes_in_group("Ragdolls"):
		body._age = 20.0
	await physics_frame
	await physics_frame
	check(get_nodes_in_group("Ragdolls").is_empty(), "expired corpses are removed")
	print("COMBAT_TEST_FAILURES=", failures)
	quit(1 if failures else 0)
