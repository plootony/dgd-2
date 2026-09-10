extends SceneTree
## Rebuild after changing the procedural arena's static collision geometry.


func _initialize() -> void:
	bake.call_deferred()


func bake() -> void:
	var arena = load("res://world/test_arena.gd").new()
	root.add_child(arena)
	var mesh = NavigationMesh.new()
	mesh.agent_radius = 0.4
	mesh.agent_height = 1.9
	mesh.agent_max_climb = 0.3
	mesh.cell_size = 0.2
	mesh.cell_height = 0.1
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask = 1
	var geometry = NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(mesh, geometry, arena)
	NavigationServer3D.bake_from_source_geometry_data(mesh, geometry)
	assert(mesh.get_polygon_count() > 0)
	assert(ResourceSaver.save(mesh, "res://world/test_arena_navigation.res") == OK)
	print("BAKED_NAVIGATION polygons=", mesh.get_polygon_count())
	arena.free()
	quit()
