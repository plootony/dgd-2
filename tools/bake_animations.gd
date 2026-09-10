## Run with Godot --headless --path . --script tools/bake_animations.gd
## Rest-space rotation retarget; preserves Bot limb lengths and removes horizontal root motion.
extends SceneTree


func _initialize() -> void:
	call_deferred("bake")


func bake() -> void:
	var bogdan = "--bogdan" in OS.get_cmdline_user_args()
	var tony = "--tony" in OS.get_cmdline_user_args() or bogdan
	var bone_prefix = "" if tony else "mixamorig1_"
	var skeleton_path = "Armature/Skeleton3D:" if tony else "Skeleton3D:"
	var source = (
		load("res://Animation Library[Standard]/Godot/AnimationLibrary_Godot_Standard.glb")
		. instantiate()
	)
	var target_path = "res://Tony/Tony.glb" if tony else "res://Bot/Bot.fbx"
	if bogdan:
		target_path = "res://characters/bogdan/Bogdan.glb"
	var target = load(target_path).instantiate()
	root.add_child(source)
	root.add_child(target)
	var src: Skeleton3D = source.find_child("Skeleton3D", true, false)
	var dst: Skeleton3D = target.find_child("Skeleton3D", true, false)
	var player: AnimationPlayer = source.find_child("AnimationPlayer", true, false)
	var names = {
		"DEF-hips": "Hips",
		"DEF-spine.001": "Spine",
		"DEF-spine.002": "Spine1",
		"DEF-spine.003": "Spine2",
		"DEF-neck": "Neck",
		"DEF-head": "Head"
	}
	for side in ["L", "R"]:
		var prefix = "Left" if side == "L" else "Right"
		for pair in [
			["shoulder", "Shoulder"],
			["upper_arm", "Arm"],
			["forearm", "ForeArm"],
			["hand", "Hand"],
			["thigh", "UpLeg"],
			["shin", "Leg"],
			["foot", "Foot"],
			["toe", "ToeBase"]
		]:
			names["DEF-" + pair[0] + "." + side] = prefix + pair[1]
		for pair in [
			["f_index", "Index"],
			["f_middle", "Middle"],
			["f_ring", "Ring"],
			["f_pinky", "Pinky"],
			["thumb", "Thumb"]
		]:
			for i in range(1, 4):
				names["DEF-%s.0%d.%s" % [pair[0], i, side]] = prefix + "Hand" + pair[1] + str(i)
	var mapping = {}
	for name in names:
		var a = src.find_bone(name)
		var b = dst.find_bone(bone_prefix + names[name])
		assert(a >= 0 and b >= 0, "Bone mapping missing: " + name)
		mapping[b] = a
	player.play("A_TPose")
	player.seek(0, true)
	player.advance(0)
	src.force_update_all_bone_transforms()
	var reference = []
	for i in src.get_bone_count():
		reference.append(src.get_bone_global_pose(i))
	var hips: int = dst.find_bone(bone_prefix + "Hips")
	var src_hips: int = mapping[hips]
	var ratio: float = dst.get_bone_global_rest(hips).origin.y / reference[src_hips].origin.y
	var library = AnimationLibrary.new()
	for clip in [
		"Idle",
		"Walk",
		"Jog_Fwd",
		"Sprint",
		"Jump",
		"Jump_Start",
		"Jump_Land",
		"Crouch_Idle",
		"Crouch_Fwd"
	]:
		assert(player.has_animation(clip), "Missing animation: " + clip)
		var original = player.get_animation(clip)
		var animation = Animation.new()
		animation.length = original.length
		animation.loop_mode = (
			Animation.LOOP_NONE if clip.begins_with("Jump") else Animation.LOOP_LINEAR
		)
		var tracks = {}
		for b in mapping:
			var tr = animation.add_track(Animation.TYPE_ROTATION_3D)
			animation.track_set_path(tr, NodePath(skeleton_path + dst.get_bone_name(b)))
			tracks[b] = tr
		var hip_track = animation.add_track(Animation.TYPE_POSITION_3D)
		animation.track_set_path(hip_track, NodePath(skeleton_path + dst.get_bone_name(hips)))
		player.play(clip)
		for sample in range(int(ceil(original.length * 30)) + 1):
			var time = minf(sample / 30.0, original.length)
			player.seek(time, true)
			player.advance(0)
			src.force_update_all_bone_transforms()
			var globals = []
			for b in dst.get_bone_count():
				var parent = dst.get_bone_parent(b)
				var parent_basis: Basis = globals[parent] if parent >= 0 else Basis.IDENTITY
				var global_basis = parent_basis * dst.get_bone_rest(b).basis
				if mapping.has(b):
					var s: int = mapping[b]
					global_basis = (
						src.get_bone_global_pose(s).basis
						* reference[s].basis.inverse()
						* dst.get_bone_global_rest(b).basis
					)
					var rotation = (
						(parent_basis.inverse() * global_basis)
						. orthonormalized()
						. get_rotation_quaternion()
					)
					animation.rotation_track_insert_key(tracks[b], time, rotation)
				globals.append(global_basis)
			var hip_pos = dst.get_bone_rest(hips).origin
			hip_pos.y += (
				(src.get_bone_global_pose(src_hips).origin.y - reference[src_hips].origin.y) * ratio
			)
			animation.position_track_insert_key(hip_track, time, hip_pos)
		library.add_animation(clip, animation)
		print("BAKED ", clip, " ", animation.length, "s")
	DirAccess.make_dir_recursive_absolute("res://animations")
	var output = (
		"res://animations/tony_locomotion.res" if tony else "res://animations/bot_locomotion.res"
	)
	if bogdan:
		output = "res://characters/bogdan/locomotion.res"
	assert(ResourceSaver.save(library, output) == OK)
	source.free()
	target.free()
	quit()
