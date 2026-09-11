extends SceneTree
const Profile = preload("res://addons/weapon_control/weapon_profile.gd")
const Ballistics = preload("res://addons/weapon_control/ballistics.gd")
const Recoil = preload("res://addons/weapon_control/recoil_motion.gd")
var weapons: Node


func _initialize() -> void:
	run.call_deferred()


func step(seconds: float) -> void:
	for i in ceili(seconds * 120):
		weapons._process(1.0 / 120)


func run() -> void:
	weapons = load("res://weapons/first_person_weapons.gd").new()
	root.add_child(weapons)
	weapons.set_active(true)
	weapons.set_process(false)
	weapons.update_controls(true, false, false, false)
	assert(weapons.selected_fire_mode() == 2)
	weapons.cycle_fire_mode()
	assert(weapons.selected_fire_mode() == 0)
	weapons.update_controls(true, true, false, false)
	weapons.request_fire()
	step(0.7)
	assert(weapons.shots_played == 1, "Single mode cannot repeat from held input")
	weapons.cycle_fire_mode()
	weapons.request_fire()
	step(0.7)
	assert(weapons.shots_played == 4, "One trigger starts exactly three burst shots")
	weapons.request_fire()
	weapons.request_reload()
	step(0.3)
	assert(weapons.shots_played == 5 and weapons.action == &"reload")
	weapons.reset_ammunition()
	weapons.update_controls(true, true, false, false)
	weapons.cycle_fire_mode()
	var before = weapons.shots_played
	weapons.request_fire()
	step(0.5)
	assert(weapons.shots_played >= before + 4 and weapons.shots_played <= before + 5)
	weapons.update_controls(true, false, false, false)
	before = weapons.shots_played
	step(0.5)
	assert(weapons.shots_played == before)
	weapons.cycle_fire_mode()
	weapons.cycle_fire_mode()
	weapons.request_fire()
	before = weapons.shots_played
	weapons.select_slot(1)
	weapons.update_controls(true, false, false, false)
	step(0.5)
	assert(weapons.shots_played == before, "Switching weapons cancels a pending burst")
	weapons.cycle_fire_mode()
	assert(weapons.selected_fire_mode() == 0)
	for i in 15:
		weapons.request_fire()
	assert(weapons.shots_played == before + 15)
	var profile = Profile.new()
	var mode = profile.single
	var ballistic = Ballistics.new()
	ballistic.rng.seed = 42
	for i in 1000:
		var direction = ballistic.spread_direction(Vector3.FORWARD, 2.0)
		assert(direction.is_normalized())
		assert(direction.angle_to(Vector3.FORWARD) <= deg_to_rad(2.0) + 0.0001)
	assert(ballistic.spread_direction(Vector3.FORWARD, 0) == Vector3.FORWARD)
	assert(
		(
			profile.spread_multiplier(true, true, true, true)
			< profile.spread_multiplier(false, true, true, false)
		)
	)
	ballistic.apply(0, profile, mode, Vector3.FORWARD, 0, false, false, true, false, 0)
	ballistic.apply(0, profile, mode, Vector3.FORWARD, 0, false, false, true, false, 0)
	assert(is_equal_approx(ballistic._heat[0].heat, mode.spread_per_shot * 2))
	ballistic.apply(0, profile, mode, Vector3.FORWARD, 0, false, false, true, false, 10)
	assert(is_equal_approx(ballistic._heat[0].heat, mode.spread_per_shot))
	var recoil = Recoil.new()
	mode.yaw_random = 0
	mode.yaw_pattern = PackedFloat32Array()
	mode.lateral_drift = 0.2
	var kick = recoil.shot(mode, 1)
	assert(kick.x > 0 and kick.y < 0)
	var transform = recoil.step(mode, 0)
	assert(transform.origin.z > 0 and transform.basis.get_euler().x > 0)
	assert(recoil.step(mode, 10).is_equal_approx(Transform3D.IDENTITY))
	print(
		"WEAPON_CONTROL_PASSED: three modes, burst cancellation, pistol clicks, spread cone/bloom, recoil/drift"
	)
	quit()
