extends Node3D
## Builds the test level geometry, environment, lighting and overview camera.

var world_environment: Environment
var sunlight: DirectionalLight3D
var overview: Camera3D


func _ready() -> void:
	var env = WorldEnvironment.new()
	env.environment = Environment.new()
	world_environment = env.environment
	env.environment.background_mode = Environment.BG_SKY
	env.environment.sky = preload("res://environments/arena_sky.tres")
	env.environment.background_color = Color("829eb3")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("b8d1e3")
	env.environment.ambient_light_energy = 0.65
	add_child(env)
	var sun = DirectionalLight3D.new()
	sunlight = sun
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	add_child(sun)
	overview = Camera3D.new()
	add_child(overview)
	overview.position = Vector3(22, 22, 26)
	overview.look_at(Vector3.ZERO)
	overview.current = true
	_block("Ground", Vector3(0, -0.5, 0), Vector3(40, 1, 40), Color("344754"))
	for x in [-20, 20]:
		_block("BoundaryX", Vector3(x, 3, 0), Vector3(1, 6, 41), Color("607c8b"))
	for z in [-20, 20]:
		_block("BoundaryZ", Vector3(0, 3, z), Vector3(41, 6, 1), Color("607c8b"))
	for i in range(-9, 10):
		_block("Grid", Vector3(i * 2, 0.004, 0), Vector3(0.025, 0.008, 39), Color("48616d"), false)
		_block("Grid", Vector3(0, 0.004, i * 2), Vector3(39, 0.008, 0.025), Color("48616d"), false)
	for i in range(5):
		var h = 0.35 + i * 0.3
		_block("JumpBlock", Vector3(-9 + i * 3, h / 2, -3), Vector3(2, h, 2), Color("dc9945"))
	for i in range(6):
		var h = (i + 1) * 0.25
		_block("Step", Vector3(-12, h / 2, 4 - i * 0.65), Vector3(3, h, 0.65), Color("73aba6"))
	_block("Platform", Vector3(-12, 0.75, -2), Vector3(3, 1.5, 3), Color("73aba6"))
	_block("TunnelRoof", Vector3(8, 1.45, 3), Vector3(4, 0.3, 5), Color("d7bd85"))
	for x in [5.75, 10.25]:
		_block("TunnelWall", Vector3(x, 0.8, 3), Vector3(0.5, 1.6, 5), Color("9d865d"))
	_block("TallBlock", Vector3(9, 1.5, -9), Vector3(4, 3, 4), Color("718aaa"))
	_label("ПРЫЖКИ · 0.35—1.55 м", Vector3(-3, 2.7, -4.5))
	_label("ПРИСЕД · ПРОСВЕТ 1.30 м", Vector3(8, 2.5, 3))
	_label("СТУПЕНИ", Vector3(-12, 2.5, 2))
	var navigation_region = NavigationRegion3D.new()
	navigation_region.name = "NavigationRegion3D"
	navigation_region.navigation_mesh = preload("res://world/test_arena_navigation.res")
	add_child(navigation_region)


func _block(label: String, pos: Vector3, size: Vector3, color: Color, solid: bool = true) -> void:
	var node = StaticBody3D.new() if solid else Node3D.new()
	node.name = label
	node.position = pos
	var mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	mesh.material_override = material
	node.add_child(mesh)
	if solid:
		var collision = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		node.add_child(collision)
	add_child(node)


func _label(text: String, pos: Vector3) -> void:
	var label = Label3D.new()
	label.text = text
	label.position = pos
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 40
	label.pixel_size = 0.008
	add_child(label)
