extends CanvasLayer

signal shot_fired(slot: int)
## Local-only viewmodels; this node is never created for remote players.

const WeaponCatalog = preload("res://weapons/weapon_catalog.gd")
const WeaponAnimations = preload("res://weapons/weapon_animations.gd")

var ammunition = preload("res://weapons/ammunition.gd").new()
var _flashes: Array[Node3D] = []
var _ammo_label: Label
var selected_slot: int = 0
var active: bool = false
var _viewport: SubViewport
var _image: TextureRect
var _camera: Camera3D
var _models: Array[Node3D] = []
var _players: Array[AnimationPlayer] = []
var action: StringName = &"idle"
var aim_blend: float = 0.0
var run_blend: float = 0.0
var shots_played: int = 0
var _elapsed: float = 0.0
var _idle_time: float = 0.0
var _run_time: float = 0.0
var _fire_pending: bool = false
var _fire_held: bool = false
var _aim_held: bool = false
var _running: bool = false
var _controls_enabled: bool = false
var _hip: Array[Transform3D] = []
var _aim: Array[Transform3D] = []


func _ready() -> void:
	layer = 0
	_viewport = SubViewport.new()
	_viewport.name = "WeaponViewport"
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	_camera = Camera3D.new()
	_camera.near = 0.01
	_camera.fov = 60.0
	_viewport.add_child(_camera)
	_camera.current = true
	var environment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color.TRANSPARENT
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.85, 0.9, 1.0)
	environment.environment.ambient_light_energy = 0.7
	var sky = Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	environment.environment.sky = sky
	environment.environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	_viewport.add_child(environment)
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -25, 0)
	light.light_energy = 1.2
	_viewport.add_child(light)
	_image = TextureRect.new()
	_image.name = "WeaponImage"
	_image.texture = _viewport.get_texture()
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(_image)
	_image.hide()
	_ammo_label = Label.new()
	_ammo_label.name = "AmmoCounter"
	_ammo_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_ammo_label.offset_left = -450
	_ammo_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_ammo_label.offset_top = -85
	_ammo_label.offset_right = -24
	_ammo_label.offset_bottom = -24
	_ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ammo_label.add_theme_font_size_override("font_size", 24)
	_ammo_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_ammo_label.add_theme_constant_override("shadow_offset_x", 2)
	_ammo_label.add_theme_constant_override("shadow_offset_y", 2)
	_ammo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ammo_label)
	_ammo_label.hide()
	get_viewport().size_changed.connect(_resize)
	_resize()


func _resize() -> void:
	_viewport.size = Vector2i(get_viewport().get_visible_rect().size)


func set_active(value: bool) -> void:
	if active != value:
		_reset_action()
	active = value
	if active and _models.is_empty():
		_load_models()
	_image.visible = active
	_ammo_label.visible = active
	_update_ammo_label()
	_viewport.render_target_update_mode = (
		SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
	)
	for i in _models.size():
		_models[i].visible = active and i == selected_slot
		_models[i].process_mode = (
			Node.PROCESS_MODE_INHERIT
			if active and i == selected_slot
			else Node.PROCESS_MODE_DISABLED
		)


func select_slot(slot: int) -> void:
	if slot < 0 or slot >= WeaponCatalog.DEFINITIONS.size() or slot == selected_slot:
		return
	_reset_action()
	selected_slot = slot
	set_active(active)


func _reset_action() -> void:
	ammunition.cancel_reload()
	for flash in _flashes:
		flash.clear()
	action = &"idle"
	_elapsed = 0.0
	_idle_time = 0.0
	aim_blend = 0.0
	run_blend = 0.0
	_fire_pending = false
	_fire_held = false
	_aim_held = false
	_running = false


func update_controls(enabled: bool, fire_held: bool, aim_held: bool, running: bool) -> void:
	_controls_enabled = enabled and active
	_fire_held = _controls_enabled and fire_held
	_aim_held = _controls_enabled and aim_held
	_running = _controls_enabled and running
	if not _controls_enabled:
		_fire_pending = false


func request_fire() -> void:
	if active and action != &"reload":
		_fire_pending = true


func request_reload() -> void:
	if not active or action == &"reload" or not ammunition.begin_reload(selected_slot):
		return
	action = &"reload"
	_elapsed = 0.0
	_fire_pending = false


func _process(delta: float) -> void:
	if not active or _models.is_empty():
		return
	_elapsed += delta
	_idle_time += delta
	var player = _players[selected_slot]
	var definition = WeaponCatalog.DEFINITIONS[selected_slot]
	if action == &"shoot" and _elapsed >= definition.shot_seconds:
		action = &"idle"
	if action == &"reload" and _elapsed >= player.get_animation("viewmodel/reload").length:
		ammunition.finish_reload()
		action = &"idle"
		_elapsed = 0.0
	if (
		action != &"reload"
		and _controls_enabled
		and (_fire_pending or (definition.automatic and _fire_held))
	):
		if action != &"shoot" and ammunition.consume(selected_slot):
			action = &"shoot"
			_elapsed = 0.0
			shots_played += 1
			shot_fired.emit(selected_slot)
			_flashes[selected_slot].trigger()
		_fire_pending = false
	var wants_aim = _aim_held and action != &"reload"
	var wants_run = _running and not wants_aim and action == &"idle" and not _fire_held
	aim_blend = move_toward(aim_blend, 1.0 if wants_aim else 0.0, delta * 8.0)
	run_blend = move_toward(run_blend, 1.0 if wants_run else 0.0, delta * 6.0)
	var clip: StringName = action
	var time: float = _elapsed
	if action == &"idle":
		clip = &"aim" if aim_blend > 0.001 else &"idle"
		var idle_length = player.get_animation("viewmodel/" + String(clip)).length
		if definition.idle_cycle_seconds > 0.0 and clip == &"idle":
			# Ease back and forth through the short source take; no abrupt loop seam.
			time = idle_length * (0.5 - 0.5 * cos(TAU * _idle_time / definition.idle_cycle_seconds))
		else:
			time = fmod(_idle_time, idle_length)
	elif action == &"shoot":
		time = _elapsed / definition.shot_seconds * player.get_animation("viewmodel/shoot").length
	_sample(player, clip, time)
	var transform = _hip[selected_slot].interpolate_with(_aim[selected_slot], aim_blend)
	_run_time += delta * 15.0
	var bob = Vector3(sin(_run_time) * 0.016, absf(cos(_run_time)) * 0.018, 0.0)
	var run_rotation = Vector3(
		deg_to_rad(definition.run_pitch_degrees),
		deg_to_rad(18),
		deg_to_rad(-8) + sin(_run_time) * 0.035
	)
	# Rotate in camera space: asset origins differ (AK's rest rig is 1.5 m above zero).
	var run_transform = Transform3D(
		Basis.from_euler(run_rotation * run_blend),
		(Vector3(0.01, definition.run_vertical_offset, 0.01) + bob) * run_blend
	)
	transform = run_transform * transform
	_models[selected_slot].transform = transform
	_flashes[selected_slot].follow_bone()
	_update_ammo_label()


func _sample(player: AnimationPlayer, clip: StringName, time: float) -> void:
	var name = "viewmodel/" + String(clip)
	if player.assigned_animation != name:
		player.play(name)
	player.seek(time, true)
	player.pause()


func _load_models() -> void:
	for i in WeaponCatalog.DEFINITIONS.size():
		var definition = WeaponCatalog.DEFINITIONS[i]
		var model = (load(definition.model_path) as PackedScene).instantiate() as Node3D
		model.name = definition.display_name
		model.rotation.y = PI
		model.position = definition.hip_position
		_viewport.add_child(model)
		_models.append(model)
		_hip.append(model.transform)
		var sight_basis = (
			Basis.looking_at(definition.front_sight - definition.rear_sight, Vector3.UP).inverse()
		)
		_aim.append(
			Transform3D(
				sight_basis,
				Vector3(0, 0, -definition.sight_distance) - sight_basis * definition.rear_sight
			)
		)
		for mesh in model.find_children("*", "MeshInstance3D", true, false):
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		_players.append(player)
		WeaponAnimations.build_library(player, definition)
		_sample(player, &"idle", 0.0)
		var flash = preload("res://weapons/muzzle_flash.gd").new()
		flash.configure(model, definition)
		_flashes.append(flash)


func reset_ammunition() -> void:
	_reset_action()
	ammunition.reset()
	_update_ammo_label()


func _update_ammo_label() -> void:
	var status = (
		"  •  ПЕРЕЗАРЯДКА"
		if action == &"reload"
		else (
			"  •  R"
			if ammunition.magazines[selected_slot] == 0 and ammunition.reserves[selected_slot] > 0
			else ""
		)
	)
	_ammo_label.text = (
		"%s\n%d / %d%s"
		% [
			WeaponCatalog.DEFINITIONS[selected_slot].display_name,
			ammunition.magazines[selected_slot],
			ammunition.reserves[selected_slot],
			status
		]
	)
