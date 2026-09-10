extends Node3D
## One pool per player corpse. Wait for the body to settle, then grow on the floor.
var _corpse: Node3D
var _last_focus: Vector3
var _still_time: float = 0.0
var _age: float = 0.0
var _growth: float = 0.0
var _pool: MeshInstance3D


static func attach(corpse: Node3D) -> Node3D:
	var effect = load("res://effects/blood_pool.gd").new()
	effect.name = "BloodPool"
	effect._corpse = corpse
	corpse.add_child(effect)
	effect.add_to_group("BloodPools")
	effect._last_focus = corpse.get_focus_position()
	return effect


func _physics_process(delta: float) -> void:
	_age += delta
	if _pool != null:
		_growth = minf(1.0, _growth + delta / 4.0)
		_pool.scale = Vector3.ONE * lerpf(0.15, 1.0, smoothstep(0.0, 1.0, _growth))
		return
	var focus = _corpse.get_focus_position()
	var speed = focus.distance_to(_last_focus) / maxf(delta, 0.001)
	_last_focus = focus
	_still_time = _still_time + delta if speed < 0.2 else 0.0
	if _age < 1.0 or _still_time < 0.35:
		return
	var ray = PhysicsRayQueryParameters3D.create(
		focus + Vector3.UP * 0.1, focus + Vector3.DOWN * 0.65, 1
	)
	var hit = get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty() or hit.normal.y < 0.65:
		return
	_create_pool(hit.position, hit.normal)


func _create_pool(point: Vector3, normal: Vector3) -> void:
	_pool = MeshInstance3D.new()
	var mesh = QuadMesh.new()
	mesh.size = Vector2(1.15, 1.4)
	_pool.mesh = mesh
	_pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shader = Shader.new()
	shader.code = """shader_type spatial;
render_mode cull_disabled, depth_draw_never;
void fragment() {
 vec2 p = UV * 2.0 - 1.0;
 float a = atan(p.y, p.x);
 float edge = 0.8 + 0.065*sin(a*3.0) + 0.045*cos(a*7.0+1.7) + 0.025*sin(a*11.0);
 float r = length(p);
 ALBEDO = mix(vec3(0.09, 0.001, 0.004), vec3(0.28, 0.004, 0.012), smoothstep(0.0, edge, r));
 ROUGHNESS = 0.38;
 SPECULAR = 0.25;
 ALPHA = (1.0-smoothstep(edge-0.035, edge, r))*0.94;
}"""
	var material = ShaderMaterial.new()
	material.shader = shader
	_pool.material_override = material
	add_child(_pool)
	_pool.global_position = point + normal * 0.009
	_pool.global_basis = Basis.looking_at(-normal, Vector3.FORWARD)
	_pool.scale = Vector3.ONE * 0.15
