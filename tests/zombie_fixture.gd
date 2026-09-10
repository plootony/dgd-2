extends RefCounted
## Keep the selected zombie active without interference from other arena NPCs.


static func select(game: Node) -> CharacterBody3D:
	var name = "Bogdan" if "--bogdan" in OS.get_cmdline_user_args() else "Tony"
	var selected = game.get_node(name)
	for zombie in game.get_tree().get_nodes_in_group("NPCs"):
		if zombie != selected:
			zombie.set_physics_process(false)
			zombie.collider.set_deferred("disabled", true)
	return selected
