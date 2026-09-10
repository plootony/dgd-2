extends SceneTree

var role = "host"
var failures = 0
var saw_hit = false
var saw_bite = false
var saw_scream = false
var saw_crawl = false
var saw_crawl_attack = false


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--role="):
			role = argument.trim_prefix("--role=")
	run.call_deferred()


func check(value: bool, label: String) -> void:
	print("NET_PASS " if value else "NET_FAIL ", role, " ", label)
	if not value:
		failures += 1


func wait_for_health(actor: Node, health: int, zombie: Node) -> bool:
	var deadline = Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline:
		saw_hit = saw_hit or zombie.net_stagger.z > 0
		saw_bite = saw_bite or zombie._clip == &"zombie/crawl_bite"
		saw_scream = saw_scream or zombie._clip == &"zombie/scream"
		saw_crawl = saw_crawl or zombie.is_crawling()
		saw_crawl_attack = saw_crawl_attack or zombie._clip == &"zombie/crawl_attack"
		if actor.combat.health == health:
			return true
		await process_frame
	return false


func run() -> void:
	change_scene_to_file("res://game/main.tscn")
	await scene_changed
	var game = current_scene
	var zombie = game.get_node("Tony")
	zombie.set_physics_process(false)
	var deadline = Time.get_ticks_msec() + 45000
	while (
		not is_instance_valid(game.local_player) or game.get_node("Players").get_child_count() < 2
	):
		if Time.get_ticks_msec() > deadline:
			print("NET_FAIL connection timeout")
			quit(1)
			return
		await process_frame
	var local = game.local_player
	local.set_physics_process(false)
	local.set_process(false)
	local.respawn(Vector3(0, 0, 3) if role == "host" else Vector3(8, 0, 3))
	local.net_nickname = "zombie_fixture_ready"
	var remote: Node
	for actor in game.get_node("Players").get_children():
		if actor != local:
			remote = actor
	while remote.net_nickname != "zombie_fixture_ready":
		await process_frame
	await create_timer(1).timeout
	var victim = local if role == "host" else remote
	if role == "host":
		zombie.replicator.teleport_3d(Vector3.ZERO, Vector3(0, PI, 0))
	zombie.set_physics_process(true)
	check(await wait_for_health(victim, 80, zombie), "standing zombie damages the nearest player")
	check(saw_scream, "standing scream was visible before damage")
	if role == "host":
		zombie.combat.apply_damage(101, Vector3.ZERO)
	check(await wait_for_health(victim, 60, zombie), "crawling zombie damage is replicated")
	check(saw_hit, "brief flinch is replicated")
	check(await wait_for_health(victim, 40, zombie), "third punch is replicated")
	check(await wait_for_health(victim, 20, zombie), "fourth punch leaves victim vulnerable")
	check(await wait_for_health(victim, 0, zombie), "bite is the killing attack")
	check(saw_bite, "bite animation is replicated")
	check(saw_crawl and saw_crawl_attack, "crawl and prone attack are visible")
	check(is_equal_approx(zombie.collider.rotation.x, PI / 2), "prone hit volume is replicated")
	if role == "client":
		check(local.combat.health == 100, "distant player is unharmed")
	var feed_deadline = Time.get_ticks_msec() + 12000
	while zombie.get_state() != zombie.State.FEED_LOOP and Time.get_ticks_msec() < feed_deadline:
		await process_frame
	check(zombie.get_state() == zombie.State.FEED_LOOP, "feeding animation is replicated")
	check(victim.combat.is_dead(), "victim stays dead during feeding")
	check(victim.combat.respawn_delay > 14.0, "extended death view is replicated")
	check(
		is_instance_valid(victim.last_corpse) and victim.last_corpse.is_in_group("AnimatedCorpses"),
		"zombie death animation is selected on both peers"
	)
	if role == "host":
		zombie.combat.apply_damage(1000, Vector3.ZERO)
	await create_timer(1).timeout
	check(zombie.combat.is_dead(), "zombie can be killed while eating")
	await create_timer(5).timeout
	check(zombie.combat.health == 125, "zombie respawns normally")
	print("ZOMBIE_NETWORK_FAILURES=", failures, " role=", role)
	await create_timer(0.5).timeout
	Fusion.disconnect_from_photon()
	quit(1 if failures else 0)
