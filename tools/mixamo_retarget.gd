extends RefCounted
## Shared rest-space Mixamo retargeting for offline animation baking.


static func bake(
	path: String,
	destination: Skeleton3D,
	looping: bool,
	start: float = 0.0,
	end: float = -1.0,
	skeleton_path: String = "Armature/Skeleton3D",
	keep_root_motion: bool = false
) -> Animation:
	var model = load(path).instantiate()
	destination.get_tree().root.add_child(model)
	var source: Skeleton3D = model.find_child("Skeleton3D", true, false)
	var player: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	var clip: StringName = player.get_animation_list()[0]
	var result = Animation.new()
	result.length = (player.get_animation(clip).length if end < 0 else end) - start
	result.loop_mode = Animation.LOOP_LINEAR if looping else Animation.LOOP_NONE
	var mapping = {}
	var tracks = {}
	for bone in destination.get_bone_count():
		var source_bone = source.find_bone(
			"mixamorig1_" + String(destination.get_bone_name(bone)).trim_prefix("mixamorig1_")
		)
		if source_bone < 0:
			continue
		mapping[bone] = source_bone
		tracks[bone] = result.add_track(Animation.TYPE_ROTATION_3D)
		result.track_set_path(
			tracks[bone], NodePath(skeleton_path + ":" + destination.get_bone_name(bone))
		)
	var hips = destination.find_bone("Hips")
	if hips < 0:
		hips = destination.find_bone("mixamorig1_Hips")
	assert(mapping.has(hips))
	var source_hips: int = mapping[hips]
	var ratio = (
		destination.get_bone_global_rest(hips).origin.y
		/ source.get_bone_global_rest(source_hips).origin.y
	)
	var hip_track = result.add_track(Animation.TYPE_POSITION_3D)
	result.track_set_path(
		hip_track, NodePath(skeleton_path + ":" + destination.get_bone_name(hips))
	)
	player.play(clip)
	for sample in ceili(result.length * 30.0) + 1:
		var time = minf(sample / 30.0, result.length)
		player.seek(time + start, true)
		player.advance(0)
		source.force_update_all_bone_transforms()
		var global_bases: Array[Basis] = []
		for bone in destination.get_bone_count():
			var parent = destination.get_bone_parent(bone)
			var parent_basis = global_bases[parent] if parent >= 0 else Basis.IDENTITY
			var basis = parent_basis * destination.get_bone_rest(bone).basis
			if mapping.has(bone):
				var source_bone: int = mapping[bone]
				basis = (
					source.get_bone_global_pose(source_bone).basis
					* source.get_bone_global_rest(source_bone).basis.inverse()
					* destination.get_bone_global_rest(bone).basis
				)
				result.rotation_track_insert_key(
					tracks[bone],
					time,
					(parent_basis.inverse() * basis).orthonormalized().get_rotation_quaternion()
				)
			global_bases.append(basis)
		var position = destination.get_bone_rest(hips).origin
		if keep_root_motion:
			position = source.get_bone_global_pose(source_hips).origin * ratio
		position.y = source.get_bone_global_pose(source_hips).origin.y * ratio
		result.position_track_insert_key(hip_track, time, position)
	model.free()
	return result
