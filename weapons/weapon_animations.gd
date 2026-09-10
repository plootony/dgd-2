extends RefCounted
## Converts imported animation tracks to a common viewmodel clip library.


static func build_library(player: AnimationPlayer, definition: Resource) -> void:
	var library = AnimationLibrary.new()
	if not definition.clip_frames.is_empty():
		var combined = Animation.new()
		for clip in player.get_animation_list():
			if clip == "RESET":
				continue
			var source = player.get_animation(clip)
			combined.length = maxf(combined.length, source.length)
			for track in source.get_track_count():
				source.copy_track(track, combined)
		for clip in definition.clip_frames:
			var frames: Vector2 = definition.clip_frames[clip]
			library.add_animation(
				clip,
				_slice(combined, frames.x / definition.source_fps, frames.y / definition.source_fps)
			)
	else:
		for clip in player.get_animation_list():
			for name in definition.clip_suffixes:
				if clip.ends_with(definition.clip_suffixes[name]):
					library.add_animation(name, player.get_animation(clip).duplicate())
		library.add_animation("aim", _slice(library.get_animation("idle"), 0.0, 0.0))
	player.add_animation_library("viewmodel", library)


static func _slice(source: Animation, start: float, end: float) -> Animation:
	var result = Animation.new()
	result.length = maxf(end - start, 0.001)
	for track in source.get_track_count():
		var type = source.track_get_type(track)
		if (
			type
			not in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]
		):
			continue
		source.copy_track(track, result)
		var dest = result.get_track_count() - 1
		for key in range(result.track_get_key_count(dest) - 1, -1, -1):
			result.track_remove_key(dest, key)
		result.track_insert_key(dest, 0.0, _track_value(source, track, start))
		for key in source.track_get_key_count(track):
			var time = source.track_get_key_time(track, key)
			if time > start and time < end:
				result.track_insert_key(
					dest,
					time - start,
					source.track_get_key_value(track, key),
					source.track_get_key_transition(track, key)
				)
		result.track_insert_key(dest, result.length, _track_value(source, track, end))
	return result


static func _track_value(animation: Animation, track: int, time: float) -> Variant:
	match animation.track_get_type(track):
		Animation.TYPE_POSITION_3D:
			return animation.position_track_interpolate(track, time)
		Animation.TYPE_ROTATION_3D:
			return animation.rotation_track_interpolate(track, time)
		Animation.TYPE_SCALE_3D:
			return animation.scale_track_interpolate(track, time)
	return null
