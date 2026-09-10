extends Node3D
## A short, bone-following viewmodel flash. No external textures are required.
var _skeleton: Skeleton3D
var _bone: int
var _offset: Transform3D
var _remaining: float = 0.0
var _star: MeshInstance3D
var _light: OmniLight3D


func configure(model: Node3D, definition: Resource) -> void:
	_skeleton = model.get_node(definition.muzzle_skeleton)
	_bone = _skeleton.find_bone(definition.muzzle_bone)
	_skeleton.add_child(self)
	_offset = (
		_skeleton.get_bone_global_pose(_bone).affine_inverse()
		* _skeleton.global_transform.affine_inverse()
		* model.global_transform
		* Transform3D(Basis.IDENTITY, definition.muzzle_position)
	)
	_star = MeshInstance3D.new()
	var quad = QuadMesh.new()
	quad.size = Vector2(0.16, 0.16)
	_star.mesh = quad
	var shader = Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
void fragment() {
 vec2 p = UV * 2.0 - 1.0;
 float r = length(p);
 float a = atan(p.y, p.x);
 float edge = 0.35 + 0.45 * pow(abs(cos(a * 3.0)), 6.0);
 float flame = 1.0 - smoothstep(edge * 0.35, edge, r);
 float core = 1.0 - smoothstep(0.0, 0.22, r);
 ALBEDO = mix(vec3(1.0, 0.22, 0.015), vec3(1.0, 0.95, 0.6), core);
 ALPHA = flame;
}"""
	var material = ShaderMaterial.new()
	material.shader = shader
	_star.material_override = material
	_star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_star)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.55, 0.12)
	_light.light_energy = 2.5
	_light.omni_range = 1.2
	add_child(_light)
	hide()


func trigger() -> void:
	_remaining = 0.055
	_star.rotation.z = randf() * TAU
	_star.scale = Vector3.ONE * randf_range(0.8, 1.2)
	show()
	follow_bone()


func follow_bone() -> void:
	transform = _skeleton.get_bone_global_pose(_bone) * _offset


func clear() -> void:
	_remaining = 0.0
	hide()


func _process(delta: float) -> void:
	_remaining = maxf(0.0, _remaining - delta)
	visible = _remaining > 0.0
	if visible:
		follow_bone()
