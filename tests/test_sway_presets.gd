extends SceneTree
const Presets = preload("res://addons/weapon_sway/inertia_presets.gd")
const Profile = preload("res://addons/weapon_sway/sway_profile.gd")
const Motion = preload("res://addons/weapon_sway/sway_motion.gd")


func _initialize() -> void:
	assert(Presets.NAMES.size() == 10 and Presets.SETTINGS.size() == 10)
	for i in 10:
		var profile = Profile.new()
		for key in Presets.values(i):
			profile.set(key, Presets.values(i)[key])
		profile.pattern_enabled = false
		assert(simulate(profile, 30).is_equal_approx(simulate(profile, 144)))
		var motion = Motion.new()
		motion.step(profile, Vector2(0, -0.01), 1.0 / 120)
		var before = motion._angle.y
		motion.step(profile, Vector2.ZERO, 1.0 / 120)
		assert(motion._angle.y > before, "Weapon must keep moving after a short camera impulse")
		motion.step(profile, Vector2.ZERO, 10.0)
		assert(motion._angle.length() < 0.00001 and motion._velocity.length() < 0.00001)
		motion.step(profile, Vector2(100, -100), 0.2)
		assert(motion._angle.length() <= deg_to_rad(profile.max_angle_degrees) + 0.000001)
		motion.reset()
		assert(motion._angle == Vector2.ZERO and motion._velocity == Vector2.ZERO)
		print("PRESET_PASS ", Presets.NAMES[i])
	print("SWAY_PRESETS_PASSED")
	quit()


func simulate(profile: Resource, fps: int) -> Transform3D:
	var motion = Motion.new()
	var result = Transform3D.IDENTITY
	for frame in fps:
		result = motion.step(profile, Vector2(0, -0.2 / fps), 1.0 / fps)
	return result
