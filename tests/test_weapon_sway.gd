extends SceneTree

const Motion = preload("res://addons/weapon_sway/sway_motion.gd")
const Profile = preload("res://addons/weapon_sway/sway_profile.gd")


func _initialize() -> void:
	run.call_deferred()


func simulate(fps: int) -> Transform3D:
	var motion = Motion.new()
	var profile = Profile.new()
	var result = Transform3D.IDENTITY
	for frame in fps:
		result = motion.step(profile, Vector2(0, -0.4 / fps), 1.0 / fps)
	return result


func run() -> void:
	var profile = Profile.new()
	var motion = Motion.new()
	profile.pattern_enabled = false
	var moved = motion.step(profile, Vector2(0, -0.1), 1.0 / 60)
	assert(moved.origin.x < 0 and moved.basis.get_euler().y > 0)
	var returned = motion.step(profile, Vector2.ZERO, 1.0 / 60)
	assert(returned.origin.length() > 0 and returned.origin.length() < moved.origin.length())
	for i in 120:
		returned = motion.step(profile, Vector2.ZERO, 1.0 / 60)
	assert(returned.origin.length() < 0.000001)
	assert(simulate(30).is_equal_approx(simulate(144)))
	var limited = motion.step(profile, Vector2(100, 100), 1.0)
	assert(limited.origin.length() <= profile.max_offset + 0.000001)
	var angles = limited.basis.get_euler()
	assert(Vector2(angles.x, angles.y).length() <= deg_to_rad(profile.max_angle_degrees) + 0.000001)
	assert(motion.step(profile, Vector2.ONE, 0.016, 1.0).is_equal_approx(Transform3D.IDENTITY))
	profile.enabled = false
	assert(motion.step(profile, Vector2.ONE, 0.016).is_equal_approx(Transform3D.IDENTITY))
	var weapons = load("res://weapons/first_person_weapons.gd").new()
	root.add_child(weapons)
	weapons.set_active(true)
	weapons.set_process(false)
	weapons.update_controls(true, false, false, false)
	weapons.add_look_delta(Vector2(0, -0.05))
	weapons._process(0.016)
	assert(weapons._look_delta == Vector2.ZERO)
	assert(weapons._sway._angle.length() > 0)
	weapons.select_slot(1)
	assert(weapons._sway._angle == Vector2.ZERO)
	weapons.add_look_delta(Vector2.ONE)
	weapons.update_controls(false, false, false, false)
	assert(weapons._look_delta == Vector2.ZERO and weapons._sway._angle == Vector2.ZERO)
	var catalog = load("res://weapons/weapon_catalog.gd")
	assert(catalog.DEFINITIONS[0].sway_profile != catalog.DEFINITIONS[1].sway_profile)
	assert(
		(
			catalog.DEFINITIONS[0].sway_profile.lag_seconds
			!= catalog.DEFINITIONS[1].sway_profile.lag_seconds
		)
	)
	print("WEAPON_SWAY_PASSED: direction, return, FPS, limits, ADS, disable, slot reset, profiles")
	quit()
