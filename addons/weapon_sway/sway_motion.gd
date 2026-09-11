extends RefCounted
## Feed actual camera pitch/yaw deltas (radians), once per rendered frame.
## Apply the result BEFORE the weapon's base transform in camera space.

const Profile = preload("res://addons/weapon_sway/sway_profile.gd")
enum Stance { STANDING, CROUCHED, PRONE }
var _angle := Vector2.ZERO
var _velocity := Vector2.ZERO
var _phase: float = 0.0
var _amplitude_modifier: float = 1.0
var _speed_modifier: float = 1.0
var _pattern_weight: float = 0.0


func reset() -> void:
	_angle = Vector2.ZERO
	_velocity = Vector2.ZERO
	_phase = 0.0
	_amplitude_modifier = 1.0
	_speed_modifier = 1.0
	_pattern_weight = 0.0


func step(
	profile: Profile,
	look_delta: Vector2,
	delta: float,
	aim: float = 0.0,
	stance: Stance = Stance.STANDING,
	moving: bool = false,
	focused: bool = false
) -> Transform3D:
	if profile == null or not profile.enabled:
		reset()
		return Transform3D.IDENTITY
	if delta <= 0.0:
		return Transform3D.IDENTITY
	var limit = deg_to_rad(maxf(profile.max_angle_degrees, 0.0))
	var target = (-look_delta / delta * maxf(profile.lag_seconds, 0.0)).limit_length(limit)
	if profile.spring_enabled:
		_spring(profile, target, delta)
		if _angle.length() > limit:
			_angle = _angle.limit_length(limit)
			var normal = _angle.normalized()
			_velocity -= normal * maxf(_velocity.dot(normal), 0.0)
	else:
		_velocity = Vector2.ZERO
		var speed = profile.return_speed if look_delta.is_zero_approx() else profile.response_speed
		_angle = _angle.lerp(target, 1.0 - exp(-maxf(speed, 0.0) * delta)).limit_length(limit)
	var angle = _angle * lerpf(1.0, profile.aim_multiplier, clampf(aim, 0.0, 1.0))
	var offset = Vector3(-angle.y, angle.x, 0.0) * profile.position_gain
	offset = offset.limit_length(maxf(profile.max_offset, 0.0))
	return (
		Transform3D(
			Basis.from_euler(Vector3(angle.x, angle.y, angle.y * profile.roll_ratio)), offset
		)
		* _pattern(profile, delta, aim, stance, moving, focused)
	)


func _spring(profile: Profile, target: Vector2, delta: float) -> void:
	# Exact damped-spring solution with a constant target over the frame.
	var mass = maxf(profile.spring_mass, 0.1)
	var omega_squared = maxf(profile.spring_stiffness, 1.0) / mass
	var alpha = maxf(profile.spring_damping, 1.0) / (2.0 * mass)
	var discriminant = alpha * alpha - omega_squared
	var c: float
	var s: float
	if absf(discriminant) < 0.00001:
		c = exp(-alpha * delta)
		s = c * delta
	elif discriminant < 0.0:
		var frequency = sqrt(-discriminant)
		var decay = exp(-alpha * delta)
		c = decay * cos(frequency * delta)
		s = decay * sin(frequency * delta) / frequency
	else:
		var frequency = sqrt(discriminant)
		var fast = exp((-alpha - frequency) * delta)
		var slow = exp((-alpha + frequency) * delta)
		c = (slow + fast) * 0.5
		s = (slow - fast) / (2.0 * frequency)
	var displacement = _angle - target
	_angle = target + displacement * (c + alpha * s) + _velocity * s
	_velocity = _velocity * (c - alpha * s) - displacement * omega_squared * s


static func modifiers(profile: Profile, stance: Stance, moving: bool, focused: bool) -> Vector2:
	var amplitude = 1.0
	if stance == Stance.CROUCHED:
		amplitude = profile.crouch_amplitude_multiplier
	elif stance == Stance.PRONE:
		amplitude = profile.prone_amplitude_multiplier
	var speed = 1.0
	if moving:
		amplitude *= profile.moving_amplitude_multiplier
		speed *= profile.moving_speed_multiplier
	if focused:
		amplitude *= profile.focus_amplitude_multiplier
		speed *= profile.focus_speed_multiplier
	return Vector2(maxf(amplitude, 0.0), maxf(speed, 0.0))


func _pattern(
	profile: Profile, delta: float, aim: float, stance: Stance, moving: bool, focused: bool
) -> Transform3D:
	var targets = modifiers(profile, stance, moving, focused)
	var rate = maxf(profile.context_response, 0.001)
	var decay = exp(-rate * delta)
	# Integrate the smoothed frequency so changing context never resets the curve's phase.
	var phase_time = targets.y * delta + (_speed_modifier - targets.y) * (1.0 - decay) / rate
	_phase += TAU * maxf(profile.base_frequency_hz, 0.0) * phase_time
	_speed_modifier = lerpf(targets.y, _speed_modifier, decay)
	_amplitude_modifier = lerpf(targets.x, _amplitude_modifier, decay)
	_pattern_weight = lerpf(1.0 if profile.pattern_enabled else 0.0, _pattern_weight, decay)
	var magnitude = _amplitude_modifier * _pattern_weight
	magnitude *= lerpf(1.0, profile.pattern_aim_multiplier, clampf(aim, 0.0, 1.0))
	var horizontal = (
		deg_to_rad(profile.base_amplitude_degrees.x)
		* magnitude
		* sin(profile.frequency_ratio.x * _phase + deg_to_rad(profile.phase_degrees))
	)
	var vertical = (
		deg_to_rad(profile.base_amplitude_degrees.y)
		* magnitude
		* sin(profile.frequency_ratio.y * _phase)
	)
	return Transform3D(Basis.from_euler(Vector3(vertical, horizontal, 0)), Vector3.ZERO)
