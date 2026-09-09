extends ConfirmationDialog
## Local graphics only. Network and physics settings are deliberately independent.
const CONFIG = "user://graphics.cfg"
const ColorMoods = preload("res://scripts/color_moods.gd")
var config_path: String = CONFIG
const RESOLUTIONS = [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1440),Vector2i(3840,2160)]
var settings = {"preset":0,"resolution":2,"mode":0,"vsync":true,"aa":2,"post":true,"mood":0}
var environment: Environment
var sunlight: DirectionalLight3D
var preset: OptionButton
var resolution: OptionButton
var screen_mode: OptionButton
var vsync: CheckBox
var aa: OptionButton
var post: CheckBox
var mood: OptionButton
var description: Label
var confirmation: ConfirmationDialog
var _previous: Dictionary = {}
var _previous_size: Vector2i
var _previous_position: Vector2i
var _previous_mode: int
var _deadline: int = 0
var _display_applied: bool = false

func _ready() -> void:
	title = "Графика и экран"
	ok_button_text = "Применить"
	cancel_button_text = "Закрыть"
	size = Vector2i(570,570)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation",12)
	add_child(box)
	preset = _option(box,"Пресет",["Ultra","Минимальный (разработчик)"])
	resolution = _option(box,"Разрешение",["1280 × 720","1920 × 1080","2560 × 1440 (QHD / 2К)","3840 × 2160"])
	screen_mode = _option(box,"Режим экрана",["Окно","Полный экран без рамки"])
	vsync = CheckBox.new()
	vsync.text = "Вертикальная синхронизация (VSync)"
	box.add_child(vsync)
	aa = _option(box,"Сглаживание",["Выключено","FXAA","MSAA 4× + TAA","MSAA 8× + TAA"])
	post = CheckBox.new()
	post.text = "Постобработка: AO, SSIL, SSR, glow, цветокоррекция"
	box.add_child(post)
	mood = _option(box,"Настроение",ColorMoods.NAMES)
	mood.tooltip_text = "Цветокор, освещение и оттенок тумана. Работает при включённой постобработке."
	description = Label.new()
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(520,105)
	box.add_child(description)
	preset.item_selected.connect(_select_preset)
	confirmed.connect(_apply_requested)
	confirmation = ConfirmationDialog.new()
	confirmation.title = "Сохранить настройки экрана?"
	confirmation.ok_button_text = "Сохранить"
	confirmation.cancel_button_text = "Вернуть"
	add_child(confirmation)
	confirmation.confirmed.connect(_keep)
	confirmation.canceled.connect(_revert)
	_load()
	_sync_controls()
	apply_quality()
	get_tree().root.size_changed.connect(_update_render_scale)
	get_tree().node_added.connect(_node_added)

func _option(parent: Node, label: String, items: Array) -> OptionButton:
	var row = HBoxContainer.new()
	var text = Label.new()
	text.text = label
	text.custom_minimum_size.x = 170
	row.add_child(text)
	var option = OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for item in items: option.add_item(item)
	row.add_child(option)
	parent.add_child(row)
	return option

func open() -> void:
	_sync_controls()
	popup_centered(Vector2i(570,570))

func _select_preset(index: int) -> void:
	aa.select(2 if index==0 else 0)
	post.button_pressed = index==0
	vsync.button_pressed = index==0
	resolution.select(2 if index==0 else 0)
	_describe(index)

func _describe(index: int) -> void:
	description.text = ("Ultra: нативное QHD, тени 4096 / 4 каскада, мягкие тени, AO и непрямой свет высокого качества, отражения, ACES и мягкое свечение." if index==0 else "Минимальный: без теней и дорогих экранных эффектов; облегчённый рендер для нескольких клиентов.") + "\nВ окне — размер окна; без рамки — разрешение 3D, UI нативный.\nИзменение экрана подтверждается за 15 с. Сеть продолжает работать."

func _sync_controls() -> void:
	preset.select(settings.preset)
	resolution.select(settings.resolution)
	screen_mode.select(settings.mode)
	vsync.button_pressed = settings.vsync
	aa.select(settings.aa)
	post.button_pressed = settings.post
	mood.select(settings.mood)
	_describe(settings.preset)

func _apply_requested() -> void:
	_previous = settings.duplicate()
	_previous_size = DisplayServer.window_get_size()
	_previous_position = DisplayServer.window_get_position()
	_previous_mode = DisplayServer.window_get_mode()
	settings = {"preset":preset.selected,"resolution":resolution.selected,"mode":screen_mode.selected,"vsync":vsync.button_pressed,"aa":aa.selected,"post":post.button_pressed,"mood":mood.selected}
	apply_quality()
	var display_changed = settings.resolution != _previous.resolution or settings.mode != _previous.mode or not _display_applied
	if display_changed:
		apply_display()
		_deadline = Time.get_ticks_msec()+15000
		confirmation.popup_centered(Vector2i(420,150))
	else: _save()

func apply_quality() -> void:
	var high: bool = settings.preset==0
	var effects: bool = settings.post
	environment.sky = preload("res://environments/arena_sky.tres") if high else preload("res://environments/arena_sky_minimal.tres")
	var viewport = get_tree().root
	viewport.msaa_3d = [Viewport.MSAA_DISABLED,Viewport.MSAA_DISABLED,Viewport.MSAA_4X,Viewport.MSAA_8X][settings.aa]
	viewport.use_taa = settings.aa>=2
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if settings.aa==1 else Viewport.SCREEN_SPACE_AA_DISABLED
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	viewport.mesh_lod_threshold = 0.5 if high else 4.0
	viewport.anisotropic_filtering_level = 4 if high else 0
	for mesh in get_tree().current_scene.find_children("*","MeshInstance3D",true,false): _filter_mesh(mesh)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if settings.vsync else DisplayServer.VSYNC_DISABLED)
	RenderingServer.directional_shadow_atlas_set_size(4096 if high else 1024,true)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_ULTRA if high else RenderingServer.SHADOW_QUALITY_HARD)
	RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_ULTRA if high else RenderingServer.ENV_SSAO_QUALITY_LOW,not high,0.5,4 if high else 1,50,100)
	RenderingServer.environment_set_ssil_quality(RenderingServer.ENV_SSIL_QUALITY_ULTRA if high else RenderingServer.ENV_SSIL_QUALITY_LOW,not high,0.5,4 if high else 1,50,100)
	sunlight.shadow_enabled = high
	sunlight.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sunlight.directional_shadow_max_distance = 70
	sunlight.light_angular_distance = 0.5 if high else 0
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES if effects else Environment.TONE_MAPPER_LINEAR
	environment.ssao_enabled = effects
	environment.ssao_radius = 1.0
	environment.ssao_intensity = 1.2
	environment.ssil_enabled = effects
	environment.ssil_radius = 5
	environment.ssil_intensity = 0.7
	environment.ssr_enabled = effects
	environment.ssr_max_steps = 128 if high else 32
	environment.glow_enabled = effects
	environment.glow_intensity = 0.35
	environment.glow_hdr_threshold = 1.2
	environment.adjustment_enabled = effects
	environment.adjustment_brightness = 1.0
	environment.adjustment_contrast = 1.03
	environment.adjustment_saturation = 1.04
	environment.volumetric_fog_enabled = high and effects
	environment.volumetric_fog_density = 0.0 # Density comes only from the local arena volume.
	environment.volumetric_fog_length = 50.0
	environment.volumetric_fog_temporal_reprojection_enabled = true
	ColorMoods.apply(environment,sunlight,get_tree().current_scene,settings.mood,effects)
	# No gameplay blur or depth of field.
	_update_render_scale()

func apply_display() -> void:
	_display_applied = true
	if settings.mode==1:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var usable = DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
		var desired: Vector2i = RESOLUTIONS[settings.resolution]
		var factor = minf(1,minf(float(usable.size.x-40)/desired.x,float(usable.size.y-80)/desired.y))
		var window_size = Vector2i(Vector2(desired)*maxf(0.25,factor))
		DisplayServer.window_set_size(window_size)
		DisplayServer.window_set_position(usable.position+(usable.size-window_size)/2)
	_update_render_scale.call_deferred()

func _node_added(node: Node) -> void:
	if node is MeshInstance3D: _filter_mesh.call_deferred(node)

func _filter_mesh(mesh: MeshInstance3D) -> void:
	if not is_instance_valid(mesh) or mesh.mesh==null: return
	for surface in mesh.mesh.get_surface_count():
		var material = mesh.get_active_material(surface)
		if material is BaseMaterial3D:
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC if settings.preset==0 else BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func _update_render_scale() -> void:
	var viewport = get_tree().root
	if _display_applied and settings.mode==1:
		var screen_size = DisplayServer.window_get_size()
		var selected: Vector2i = RESOLUTIONS[settings.resolution]
		viewport.scaling_3d_scale = clampf(float(selected.y)/maxi(1,screen_size.y),0.25,2.0)
	else: viewport.scaling_3d_scale = 1.0

func _process(_delta: float) -> void:
	if _deadline==0: return
	var seconds = maxi(0,int(ceil((_deadline-Time.get_ticks_msec())/1000.0)))
	confirmation.dialog_text = "Сохранить изменения?\nАвтоматический возврат через %d с." % seconds
	if seconds==0: _revert()

func _keep() -> void:
	_deadline = 0
	_save()

func _revert() -> void:
	if _deadline==0: return
	_deadline = 0
	confirmation.hide()
	settings = _previous.duplicate()
	DisplayServer.window_set_mode(_previous_mode)
	if _previous_mode==DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_size(_previous_size)
		DisplayServer.window_set_position(_previous_position)
	apply_quality()
	_sync_controls()

func _save() -> void:
	var config = ConfigFile.new()
	for key in settings: config.set_value("graphics",key,settings[key])
	var error = config.save(config_path)
	if error!=OK: push_warning("Не удалось сохранить графические настройки: "+str(error))

func _load() -> void:
	var config = ConfigFile.new()
	if config.load(config_path)!=OK: return
	for key in settings:
		var value = config.get_value("graphics",key,settings[key])
		if typeof(value)==typeof(settings[key]): settings[key]=value
	settings.preset = clampi(settings.preset,0,1)
	settings.resolution = clampi(settings.resolution,0,RESOLUTIONS.size()-1)
	settings.mode = clampi(settings.mode,0,1)
	settings.aa = clampi(settings.aa,0,3)
	settings.mood = clampi(settings.mood,0,ColorMoods.NAMES.size()-1)
	apply_display.call_deferred()

