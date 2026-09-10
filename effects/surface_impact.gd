extends Node3D
## Cosmetic chips, dust and a fading bullet mark on static arena geometry.
const LIFETIME = 20.0
const MAX_EFFECTS = 64
var _age: float = 0.0
var _dust: MultiMeshInstance3D
var _mark: MeshInstance3D
var _positions: Array[Vector3] = []
var _velocities: Array[Vector3] = []
var _material: StandardMaterial3D


static func spawn(container: Node, point: Vector3, normal: Vector3) -> Node3D:
	var effect = load("res://effects/surface_impact.gd").new()
	container.add_child(effect)
	effect.global_position = point + normal * 0.008
	effect.add_to_group("SurfaceImpacts")
	effect._build(normal)
	var effects = container.get_tree().get_nodes_in_group("SurfaceImpacts")
	while effects.size() > MAX_EFFECTS:
		effects.pop_front().queue_free()
	return effect


func _build(normal: Vector3) -> void:
	_dust = MultiMeshInstance3D.new()
	var mesh = QuadMesh.new()
	mesh.size = Vector2.ONE
	_material = StandardMaterial3D.new()
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_material.billboard_keep_scale = true
	_material.albedo_color = Color(0.65, 0.59, 0.49, 0.65)
	var gradient = Gradient.new()
	gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	var texture = GradientTexture2D.new()
	texture.width = 32
	texture.height = 32
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1, 0.5)
	texture.gradient = gradient
	_material.albedo_texture = texture
	mesh.material = _material
	var multi = MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = 10
	_dust.multimesh = multi
	_dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_dust)
	for i in multi.instance_count:
		_positions.append(Vector3.ZERO)
		_velocities.append(
			(
				normal * randf_range(0.4, 1.2)
				+ Vector3(randf_range(-0.4, 0.4), randf_range(0.1, 0.5), randf_range(-0.4, 0.4))
			)
		)
		multi.set_instance_transform(
			i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.025), Vector3.ZERO)
		)
	_mark = MeshInstance3D.new()
	var quad = QuadMesh.new()
	quad.size = Vector2.ONE * 0.13
	_mark.mesh = quad
	_mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shader = Shader.new()
	shader.code = """shader_type spatial;
render_mode cull_disabled, depth_draw_never;
uniform float opacity = 1.0;
void fragment() {
 vec2 p=UV*2.0-1.0;
 float r=length(p);
 float a=atan(p.y,p.x);
 float edge=0.63+0.065*sin(a*7.0)+0.045*cos(a*11.0);
 float core=1.0-smoothstep(0.12,0.36,r);
 ALBEDO=mix(vec3(0.22,0.20,0.17),vec3(0.012),core);
 ROUGHNESS=1.0;
 ALPHA=(1.0-smoothstep(edge-0.12,edge,r))*opacity;
}"""
	var material = ShaderMaterial.new()
	material.shader = shader
	_mark.material_override = material
	add_child(_mark)
	var up = Vector3.RIGHT if absf(normal.dot(Vector3.UP)) > 0.95 else Vector3.UP
	_mark.global_basis = Basis.looking_at(-normal, up) * Basis(Vector3.FORWARD, randf() * TAU)


func _process(delta: float) -> void:
	_age += delta
	if _age < 0.45:
		for i in _positions.size():
			_velocities[i].y -= delta * 1.5
			_positions[i] += _velocities[i] * delta
			_dust.multimesh.set_instance_transform(
				i,
				Transform3D(
					Basis.IDENTITY.scaled(Vector3.ONE * (0.025 + _age * 0.22)), _positions[i]
				)
			)
		_material.albedo_color.a = 0.65 * (1.0 - _age / 0.45)
	else:
		_dust.hide()
	_mark.material_override.set_shader_parameter("opacity", clampf((LIFETIME - _age) / 3.0, 0, 1))
	if _age >= LIFETIME:
		queue_free()
