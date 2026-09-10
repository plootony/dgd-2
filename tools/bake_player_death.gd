extends SceneTree


func _initialize():
	bake.call_deferred()


func bake():
	var model = load("res://Bot/Bot.fbx").instantiate()
	root.add_child(model)
	var skeleton = model.find_child("Skeleton3D", true, false)
	var clip = preload("res://tools/mixamo_retarget.gd").bake(
		"res://animations/Standing React Death Forward.fbx",
		skeleton,
		false,
		0.0,
		-1.0,
		"Skeleton3D",
		true
	)
	var library = AnimationLibrary.new()
	library.add_animation("death_forward", clip)
	assert(ResourceSaver.save(library, "res://characters/player/death_animations.res") == OK)
	print("BAKED_PLAYER_DEATH ", clip.length)
	model.free()
	quit()
