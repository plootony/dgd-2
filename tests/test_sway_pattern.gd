extends SceneTree

const Motion = preload("res://addons/weapon_sway/sway_motion.gd")
const Profile = preload("res://addons/weapon_sway/sway_profile.gd")


func _initialize() -> void:
	var profile = Profile.new()
	assert(Motion.modifiers(profile, Motion.Stance.STANDING, false, false) == Vector2.ONE)
	assert(Motion.modifiers(profile, Motion.Stance.CROUCHED, false, false) == Vector2(0.5, 1))
	assert(Motion.modifiers(profile, Motion.Stance.PRONE, false, false) == Vector2(0.3, 1))
	assert(
		Motion.modifiers(profile, Motion.Stance.CROUCHED, true, true).is_equal_approx(
			Vector2(0.23, 0.6)
		)
	)
	var motion = Motion.new()
	var result = motion.step(profile, Vector2.ZERO, 1.0, 1.0)
	var expected = (
		Vector2(deg_to_rad(0.3) * sin(TAU * 0.2 + PI / 2), deg_to_rad(0.2) * sin(TAU * 0.4))
		* (1.0 - exp(-profile.context_response))
	)
	assert(is_equal_approx(result.basis.get_euler().y, expected.x))
	assert(is_equal_approx(result.basis.get_euler().x, expected.y))
	var before = motion._phase
	motion.step(profile, Vector2.ZERO, 0.016, 1, Motion.Stance.CROUCHED, true, true)
	assert(motion._phase > before and motion._phase - before < 0.03)
	assert(simulate(30).is_equal_approx(simulate(144)))
	motion.reset()
	assert(motion._phase == 0 and motion._pattern_weight == 0)
	print("SWAY_PATTERN_PASSED: formula, stance/movement/focus, continuous phase, FPS, reset")
	quit()


func simulate(fps: int) -> Transform3D:
	var motion = Motion.new()
	var profile = Profile.new()
	var result = Transform3D.IDENTITY
	for i in fps:
		result = motion.step(
			profile, Vector2.ZERO, 1.0 / fps, 1.0, Motion.Stance.CROUCHED, true, true
		)
	return result
