extends RefCounted
## Kept on the authority: spread growth never trusts the client's shot counter.
var _heat: Dictionary = {}
var rng = RandomNumberGenerator.new()


func _init() -> void:
	rng.randomize()


func reset() -> void:
	_heat.clear()


func spread_direction(direction: Vector3, degrees: float) -> Vector3:
	if degrees <= 0:
		return direction.normalized()
	var radius = sqrt(rng.randf()) * tan(deg_to_rad(minf(degrees, 45.0)))
	var angle = rng.randf() * TAU
	var basis = Basis.looking_at(
		direction, Vector3.RIGHT if absf(direction.y) > 0.99 else Vector3.UP
	)
	return (basis * Vector3(cos(angle) * radius, sin(angle) * radius, -1)).normalized()


func apply(
	slot: int,
	profile: Resource,
	mode: Resource,
	direction: Vector3,
	aim: float,
	crouched: bool,
	moving: bool,
	grounded: bool,
	focused: bool,
	now: float
) -> Vector3:
	var state = _heat.get(slot, {"heat": 0.0, "time": now})
	var heat = maxf(0.0, state.heat - maxf(now - state.time, 0.0) * mode.spread_recovery)
	var degrees = (
		(lerpf(mode.hip_spread, mode.ads_spread, aim) + minf(heat, mode.max_extra_spread))
		* profile.spread_multiplier(crouched, moving, grounded, focused)
	)
	_heat[slot] = {"heat": minf(heat + mode.spread_per_shot, mode.max_extra_spread), "time": now}
	return spread_direction(direction, degrees)
