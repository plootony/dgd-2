extends Node3D
## Short droplets and a flat splatter on a confirmed static surface, with bounded lifetime/count.
const MAX_EFFECTS = 40
const LIFETIME = 15.0
static var _texture: ImageTexture
var _age: float = 0.0
var _drops: MultiMeshInstance3D
var _positions: Array[Vector3] = []
var _velocities: Array[Vector3] = []
var _stamp: MeshInstance3D
var _material: StandardMaterial3D


static func spawn(
	container: Node,
	point: Vector3,
	normal: Vector3,
	direction: Vector3,
	surface_point: Vector3,
	surface_normal: Vector3
) -> Node3D:
	var effect = load("res://effects/blood_impact.gd").new()
	container.add_child(effect)
	effect.global_position = point
	effect.add_to_group("BloodImpacts")
	effect._build(normal, direction, surface_point, surface_normal)
	var effects = container.get_tree().get_nodes_in_group("BloodImpacts")
	while effects.size() > MAX_EFFECTS:
		effects.pop_front().queue_free()
	return effect


func _build(
	normal: Vector3, direction: Vector3, surface_point: Vector3, surface_normal: Vector3
) -> void:
	_drops = MultiMeshInstance3D.new()
	var mesh = SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 6
	mesh.rings = 3
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.5, 0.012, 0.02)
	material.roughness = 0.7
	mesh.material = material
	var multi = MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = 16
	_drops.multimesh = multi
	_drops.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_drops)
	for i in multi.instance_count:
		_positions.append(Vector3.ZERO)
		_velocities.append(
			(
				normal * randf_range(0.4, 1.2)
				+ direction * 0.35
				+ Vector3(randf_range(-0.8, 0.8), randf_range(0.2, 1.2), randf_range(-0.8, 0.8))
			)
		)
		multi.set_instance_transform(
			i, Transform3D(Basis.IDENTITY.scaled(Vector3(0.016, 0.035, 0.016)), Vector3.ZERO)
		)
	if surface_normal.length_squared() < 0.5:
		return
	_stamp = MeshInstance3D.new()
	var quad = QuadMesh.new()
	quad.size = Vector2.ONE * randf_range(0.28, 0.48)
	_stamp.mesh = quad
	_material = StandardMaterial3D.new()
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.albedo_color = Color(0.32, 0.006, 0.012, 0.85)
	_material.albedo_texture = _get_texture()
	_material.roughness = 0.95
	_stamp.material_override = _material
	_stamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_stamp)
	var up = Vector3.RIGHT if absf(surface_normal.dot(Vector3.UP)) > 0.95 else Vector3.UP
	_stamp.global_basis = (
		Basis.looking_at(-surface_normal, up) * Basis(Vector3.FORWARD, randf() * TAU)
	)
	_stamp.global_position = surface_point + surface_normal * 0.008


static func _get_texture() -> ImageTexture:
	if _texture != null:
		return _texture
	var image = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var random = RandomNumberGenerator.new()
	random.seed = 81473
	for drop in 36:
		var center = (
			Vector2(64, 64)
			if drop == 0
			else Vector2(random.randf_range(15, 113), random.randf_range(15, 113))
		)
		var radius = 23.0 if drop == 0 else random.randf_range(1.5, 10.0)
		for y in range(maxi(0, int(center.y - radius - 2)), mini(128, int(center.y + radius + 3))):
			for x in range(
				maxi(0, int(center.x - radius - 2)), mini(128, int(center.x + radius + 3))
			):
				var offset = Vector2(x, y) - center
				var edge = radius * (0.87 + 0.13 * sin(offset.angle() * 7.0 + drop))
				var alpha = clampf(edge - offset.length(), 0, 1)
				if alpha > image.get_pixel(x, y).a:
					image.set_pixel(x, y, Color(1, 1, 1, alpha))
	_texture = ImageTexture.create_from_image(image)
	return _texture


func _process(delta: float) -> void:
	_age += delta
	if _age < 0.55:
		for i in _positions.size():
			_velocities[i].y -= delta * 5.0
			_positions[i] += _velocities[i] * delta
			var scale = maxf(0, 1.0 - _age / 0.55)
			_drops.multimesh.set_instance_transform(
				i,
				Transform3D(
					Basis.IDENTITY.scaled(Vector3(0.016, 0.035, 0.016) * scale), _positions[i]
				)
			)
	else:
		_drops.hide()
	if _material != null:
		_material.albedo_color.a = 0.85 * clampf((LIFETIME - _age) / 3.0, 0, 1)
	if _age >= LIFETIME or (_stamp == null and _age >= 0.55):
		queue_free()
