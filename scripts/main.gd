extends Node3D

const PLAYER = preload("res://scenes/player.tscn")
var local_player: NetworkPlayer
var panel: PanelContainer
var status: Label
var hud: Label
var room_input: LineEdit
var name_input: LineEdit
var connect_button: Button
var offline_button: Button
var disconnect_button: Button
var overview: Camera3D
var graphics_settings: ConfirmationDialog
var world_environment: Environment
var sunlight: DirectionalLight3D
var _connecting: bool = false
var _connect_deadline: int = 0
var _error: String = ""
var _ui_elapsed: float = 0.0

func _ready() -> void:
	_setup_input()
	_build_arena()
	_build_ui()
	Fusion.connected_to_photon.connect(_join_room)
	Fusion.room_joined.connect(_room_joined)
	Fusion.connection_failed.connect(_connection_failed)
	Fusion.connection_status_changed.connect(_connection_status_changed)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--room="):
			room_input.text = arg.trim_prefix("--room=")
			connect_online.call_deferred()
		if arg == "--offline": start_offline.call_deferred()

func _setup_input() -> void:
	var keys = {"move_forward":KEY_W,"move_back":KEY_S,"move_left":KEY_A,"move_right":KEY_D,"run":KEY_SHIFT,"crouch":KEY_CTRL,"jump":KEY_SPACE,"view_toggle":KEY_V}
	for action in keys:
		if not InputMap.has_action(action): InputMap.add_action(action)
		if InputMap.action_get_events(action).is_empty():
			var event = InputEventKey.new()
			event.physical_keycode = keys[action]
			InputMap.action_add_event(action,event)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if is_instance_valid(local_player): _show_menu(not panel.visible)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and not panel.visible:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _show_menu(show_menu: bool) -> void:
	panel.visible = show_menu
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if show_menu else Input.MOUSE_MODE_CAPTURED
	if is_instance_valid(local_player): local_player.input_enabled = not show_menu

func connect_online() -> void:
	if _connecting or Fusion.is_in_room(): return
	_clear_players()
	_connecting = true
	_error = ""
	_connect_deadline = Time.get_ticks_msec()+20000
	if Fusion.is_connected_to_photon(): _join_room()
	else: Fusion.connect_to_photon("dgd_"+str(Time.get_unix_time_from_system())+"_"+str(randi()))

func _join_room() -> void:
	if not _connecting: return
	var options = FusionRoomOptions.new()
	options.max_players = 8
	options.custom_properties = {"game_mode":"controller-v1"}
	options.lobby_properties = ["game_mode"]
	# Prefix separates this schema from other examples sharing the same App ID.
	var room = room_input.text.strip_edges()
	if room.is_empty(): room = "test"
	Fusion.join_or_create_room("dgd-controller-v1-"+room,options)

func _room_joined() -> void:
	_connecting = false
	if Fusion.is_master_client(): Fusion.register_current_scene()
	var index = Fusion.get_local_player_id() % 8
	var spawn_position = Vector3((index % 4)*2.5-3.75,0.2,8+(index/4)*2.5)
	var nick = name_input.text.strip_edges().left(24)
	if nick.is_empty(): nick = "Player "+str(Fusion.get_local_player_id())
	var p = $PlayerSpawner.spawn()
	if p == null:
		_error = "Не удалось создать игрока"
		Fusion.disconnect_from_photon()
		return
	local_player = p
	p.net_nickname = nick
	p.respawn(spawn_position)
	_show_menu(false)
	print("ROOM_READY id=",Fusion.get_local_player_id())

func start_offline() -> void:
	if _connecting or Fusion.is_connected_to_photon(): return
	_clear_players()
	var p = PLAYER.instantiate()
	p.offline = true
	p.position = Vector3(0,0.2,8)
	p.net_nickname = "Offline"
	$Players.add_child(p)
	local_player = p
	_show_menu(false)

func disconnect_game() -> void:
	_connecting = false
	if Fusion.get_connection_status() != Fusion.STATUS_DISCONNECTED: Fusion.disconnect_from_photon()
	_clear_players()
	_show_menu(true)

func _clear_players() -> void:
	local_player = null
	for child in $Players.get_children():
		if Fusion.is_in_room() and child.replicator.has_authority(): $PlayerSpawner.despawn(child)
		elif not Fusion.is_in_room() or child.offline: child.queue_free()
	if overview: overview.current = true

func _connection_failed(message: String) -> void:
	_error = message
	_connecting = false
	_show_menu(true)

func _connection_status_changed(value: int) -> void:
	if value == Fusion.STATUS_DISCONNECTED:
		_connecting = false
		_clear_players()
		_show_menu(true)

func _process(delta: float) -> void:
	if _connecting and Time.get_ticks_msec()>_connect_deadline:
		_error = "Время подключения истекло. Проверьте сеть, App ID и регион."
		disconnect_game()
	_ui_elapsed += delta
	if _ui_elapsed<0.25: return
	_ui_elapsed = 0
	var online = Fusion.is_in_room()
	connect_button.disabled = _connecting or online
	offline_button.disabled = _connecting or Fusion.is_connected_to_photon()
	disconnect_button.visible = _connecting or online or is_instance_valid(local_player)
	room_input.editable = not _connecting and not online
	name_input.editable = not _connecting and not online
	status.text = _error if not _error.is_empty() else ("Подключение…" if _connecting else ("В комнате" if online else "Готово"))
	var view = "3-е лицо" if is_instance_valid(local_player) and local_player.third_person else "1-е лицо"
	var mode = "Fusion · %d игроков · RTT %d мс" % [$Players.get_child_count(),roundi(Fusion.get_rtt()*1000)] if online else "Локальный тест"
	hud.text = "DGD / TEST ARENA\n%s  |  %s  |  %d FPS\nWASD — ходьба   Shift — бег   Space — прыжок\nCtrl — присед   V — камера   Esc — меню" % [mode,view,Engine.get_frames_per_second()]

func _build_ui() -> void:
	graphics_settings = preload("res://scripts/graphics_settings.gd").new()
	graphics_settings.environment = world_environment
	graphics_settings.sunlight = sunlight
	add_child(graphics_settings)
	var layer = CanvasLayer.new()
	add_child(layer)
	var network_monitor = preload("res://scripts/network_monitor.gd").new()
	network_monitor.name = "NetworkMonitor"
	layer.add_child(network_monitor)
	hud = Label.new()
	hud.position = Vector2(24,20)
	hud.add_theme_color_override("font_color",Color("e9f2fa"))
	hud.add_theme_color_override("font_shadow_color",Color.BLACK)
	hud.add_theme_constant_override("shadow_offset_x",2)
	hud.add_theme_constant_override("shadow_offset_y",2)
	layer.add_child(hud)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(380,0)
	center.add_child(panel)
	var margin = MarginContainer.new()
	for side in ["left","top","right","bottom"]: margin.add_theme_constant_override("margin_"+side,24)
	panel.add_child(margin)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation",12)
	margin.add_child(box)
	var title = Label.new()
	title.text = "DGD / ПОЛИГОН"
	title.add_theme_font_size_override("font_size",24)
	box.add_child(title)
	name_input = LineEdit.new()
	name_input.placeholder_text = "Имя игрока"
	name_input.max_length = 24
	box.add_child(name_input)
	room_input = LineEdit.new()
	room_input.text = "test"
	room_input.placeholder_text = "Название комнаты"
	room_input.max_length = 40
	box.add_child(room_input)
	connect_button = _button(box,"Подключиться / создать комнату",connect_online)
	offline_button = _button(box,"Локальный тест",start_offline)
	_button(box,"Графика и экран",graphics_settings.open)
	_button(box,"Продолжить",func():
		if is_instance_valid(local_player): _show_menu(false)
	)
	disconnect_button = _button(box,"Отключиться",disconnect_game)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status)
	var cross = Label.new()
	cross.text = "+"
	cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(cross)

func _button(parent: Node, text: String, action: Callable) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size.y = 40
	b.pressed.connect(action)
	parent.add_child(b)
	return b

func _build_arena() -> void:
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
	sun.rotation_degrees = Vector3(-55,-30,0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	add_child(sun)
	overview = Camera3D.new()
	add_child(overview)
	overview.position = Vector3(22,22,26)
	overview.look_at(Vector3.ZERO)
	overview.current = true
	_block("Ground",Vector3(0,-0.5,0),Vector3(40,1,40),Color("344754"))
	for x in [-20,20]: _block("BoundaryX",Vector3(x,3,0),Vector3(1,6,41),Color("607c8b"))
	for z in [-20,20]: _block("BoundaryZ",Vector3(0,3,z),Vector3(41,6,1),Color("607c8b"))
	for i in range(-9,10):
		_block("Grid",Vector3(i*2,0.004,0),Vector3(0.025,0.008,39),Color("48616d"),false)
		_block("Grid",Vector3(0,0.004,i*2),Vector3(39,0.008,0.025),Color("48616d"),false)
	for i in range(5):
		var h = 0.35 + i*0.3
		_block("JumpBlock",Vector3(-9+i*3,h/2,-3),Vector3(2,h,2),Color("dc9945"))
	for i in range(6):
		var h = (i+1)*0.25
		_block("Step",Vector3(-12,h/2,4-i*0.65),Vector3(3,h,0.65),Color("73aba6"))
	_block("Platform",Vector3(-12,0.75,-2),Vector3(3,1.5,3),Color("73aba6"))
	_block("TunnelRoof",Vector3(8,1.45,3),Vector3(4,0.3,5),Color("d7bd85"))
	for x in [5.75,10.25]: _block("TunnelWall",Vector3(x,0.8,3),Vector3(0.5,1.6,5),Color("9d865d"))
	_block("TallBlock",Vector3(9,1.5,-9),Vector3(4,3,4),Color("718aaa"))
	_label("ПРЫЖКИ · 0.35—1.55 м",Vector3(-3,2.7,-4.5))
	_label("ПРИСЕД · ПРОСВЕТ 1.30 м",Vector3(8,2.5,3))
	_label("СТУПЕНИ",Vector3(-12,2.5,2))

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
