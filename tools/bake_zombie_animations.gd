extends SceneTree
## Retarget Mixamo motion to Tony. Runtime never needs the source FBX skeletons.

const SOURCES = {
	"fall": "res://animations/Fall Flat.fbx",
	"crawl": "res://animations/Zombie Crawl.fbx",
	"attack": "res://animations/Zombie Punching.fbx",
	"scream": "res://animations/Zombie Scream.fbx",
	"feed_intro": "res://animations/Zombie Biting.fbx",
	"feed_loop": "res://animations/Zombie Biting (1).fbx",
	"bite": "res://animations/Zombie Neck Bite.fbx",
}
const OUTPUT = "res://characters/zombie/tony_zombie_animations.res"
const SAMPLE_RATE = 30.0


func _initialize() -> void:
	bake.call_deferred()


func bake() -> void:
	var target = load("res://Tony/Tony.glb").instantiate()
	root.add_child(target)
	var destination: Skeleton3D = target.find_child("Skeleton3D", true, false)
	var library = AnimationLibrary.new()
	for clip in SOURCES:
		var start = 0.65 if clip == "attack" else 0.0
		var end = 1.95 if clip == "attack" else (3.5 if clip == "feed_intro" else -1.0)
		library.add_animation(
			clip,
			preload("res://tools/mixamo_retarget.gd").bake(
				SOURCES[clip], destination, clip in ["crawl", "feed_loop"], start, end
			)
		)
	_blend_tail(library.get_animation("fall"), library.get_animation("crawl"), 0.25)
	_blend_tail(library.get_animation("attack"), library.get_animation("attack"), 0.12)
	_blend_tail(library.get_animation("feed_intro"), library.get_animation("feed_loop"), 0.2)
	# Preserve the prone pelvis, spine and legs while the arms perform the gesture.
	for clip in ["scream", "attack", "bite", "feed_intro", "feed_loop"]:
		library.add_animation(
			"crawl_" + clip,
			_prone_gesture(library.get_animation("crawl"), library.get_animation(clip))
		)
	assert(ResourceSaver.save(library, OUTPUT) == OK)
	for clip in library.get_animation_list():
		print("BAKED_ZOMBIE ", clip, " ", library.get_animation(clip).length)
	target.free()
	quit()


func _prone_gesture(crawl: Animation, gesture: Animation) -> Animation:
	var result = Animation.new()
	result.length = gesture.length
	result.loop_mode = gesture.loop_mode
	for track in crawl.get_track_count():
		var path = crawl.track_get_path(track)
		var bone = String(path.get_subname(0))
		var use_gesture = bone.begins_with("Left") or bone.begins_with("Right")
		use_gesture = (
			(use_gesture and ("Arm" in bone or "Hand" in bone or "Shoulder" in bone))
			or bone in ["Neck", "Head"]
		)
		var source = gesture if use_gesture else crawl
		var source_track = source.find_track(path, crawl.track_get_type(track))
		source.copy_track(source_track, result)
		if use_gesture:
			continue
		var destination_track = result.get_track_count() - 1
		var value = source.track_get_key_value(source_track, 0)
		for key in range(result.track_get_key_count(destination_track) - 1, -1, -1):
			result.track_remove_key(destination_track, key)
		result.track_insert_key(destination_track, 0.0, value)
		result.track_insert_key(destination_track, result.length, value)
	return result


func _blend_tail(clip: Animation, next: Animation, seconds: float) -> void:
	# End at the next action's first pose rather than snapping across the cut.
	for track in clip.get_track_count():
		var next_track = next.find_track(clip.track_get_path(track), clip.track_get_type(track))
		var target = next.track_get_key_value(next_track, 0)
		for key in clip.track_get_key_count(track):
			var time = clip.track_get_key_time(track, key)
			var weight = smoothstep(clip.length - seconds, clip.length, time)
			if weight <= 0.0:
				continue
			var value = clip.track_get_key_value(track, key)
			clip.track_set_key_value(
				track,
				key,
				value.slerp(target, weight) if value is Quaternion else value.lerp(target, weight)
			)
