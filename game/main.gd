extends Node3D

const SessionConfig = preload("res://network/session_config.gd")
const PLAYER = preload("res://characters/player/player.tscn")
var local_player: NetworkPlayer
var graphics_settings: ConfirmationDialog
var ui: CanvasLayer
var arena: Node3D
var _connecting: bool = false
var _connect_deadline: int = 0
var _error: String = ""
var _ui_elapsed: float = 0.0


func _ready() -> void:
	preload("res://game/input_bindings.gd").ensure_defaults()
	arena = preload("res://world/test_arena.gd").new()
	arena.name = "Arena"
	add_child(arena)
	graphics_settings = preload("res://ui/settings/graphics_settings.gd").new()
	graphics_settings.environment = arena.world_environment
	graphics_settings.sunlight = arena.sunlight
	graphics_settings.scene_root = self
	add_child(graphics_settings)
	ui = preload("res://ui/game_ui.gd").new()
	ui.name = "GameUi"
	add_child(ui)
	ui.connect_requested.connect(connect_online)
	ui.offline_requested.connect(start_offline)
	ui.disconnect_requested.connect(disconnect_game)
	ui.graphics_requested.connect(graphics_settings.open)
	ui.resume_requested.connect(_resume_game)
	$Players.child_entered_tree.connect(_configure_actor)
	for zombie in get_tree().get_nodes_in_group("NPCs"):
		_configure_actor(zombie)
	Fusion.connected_to_photon.connect(_join_room)
	Fusion.room_joined.connect(_room_joined)
	Fusion.connection_failed.connect(_connection_failed)
	Fusion.connection_status_changed.connect(_connection_status_changed)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--room="):
			ui.room_input.text = arg.trim_prefix("--room=")
			connect_online.call_deferred()
		if arg == "--offline":
			start_offline.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if is_instance_valid(local_player):
			_show_menu(not ui.panel.visible)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and not ui.panel.visible:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _show_menu(show_menu: bool) -> void:
	ui.panel.visible = show_menu
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if show_menu else Input.MOUSE_MODE_CAPTURED
	if is_instance_valid(local_player):
		local_player.input_enabled = not show_menu


func connect_online() -> void:
	if _connecting or Fusion.is_in_room():
		return
	_clear_players()
	_connecting = true
	_error = ""
	_connect_deadline = Time.get_ticks_msec() + SessionConfig.CONNECTION_TIMEOUT_MSEC
	if Fusion.is_connected_to_photon():
		_join_room()
	else:
		Fusion.connect_to_photon(
			"dgd_" + str(Time.get_unix_time_from_system()) + "_" + str(randi())
		)


func _join_room() -> void:
	if not _connecting:
		return
	var options = FusionRoomOptions.new()
	options.max_players = SessionConfig.MAX_PLAYERS
	options.custom_properties = {"game_mode": SessionConfig.GAME_MODE}
	options.lobby_properties = ["game_mode"]
	# Prefix separates this schema from other examples sharing the same App ID.
	var room = ui.room_input.text.strip_edges()
	if room.is_empty():
		room = "test"
	Fusion.join_or_create_room(SessionConfig.ROOM_PREFIX + room, options)


func _room_joined() -> void:
	_connecting = false
	if Fusion.is_master_client():
		Fusion.register_current_scene()
	var index = Fusion.get_local_player_id() % SessionConfig.MAX_PLAYERS
	var spawn_position = Vector3((index % 4) * 2.5 - 3.75, 0.2, 8 + (index / 4) * 2.5)
	var nick = ui.name_input.text.strip_edges().left(24)
	if nick.is_empty():
		nick = "Player " + str(Fusion.get_local_player_id())
	var p = $PlayerSpawner.spawn()
	if p == null:
		_error = "Не удалось создать игрока"
		Fusion.disconnect_from_photon()
		return
	local_player = p
	p.net_nickname = nick
	p.respawn(spawn_position)
	_show_menu(false)
	print("ROOM_READY id=", Fusion.get_local_player_id())


func start_offline() -> void:
	if _connecting or Fusion.is_connected_to_photon():
		return
	_clear_players()
	var p = PLAYER.instantiate()
	p.offline = true
	p.position = Vector3(0, 0.2, 8)
	p.net_nickname = "Offline"
	$Players.add_child(p)
	local_player = p
	_show_menu(false)


func disconnect_game() -> void:
	_connecting = false
	if Fusion.get_connection_status() != Fusion.STATUS_DISCONNECTED:
		Fusion.disconnect_from_photon()
	_clear_players()
	_show_menu(true)


func _clear_players() -> void:
	local_player = null
	for child in $Players.get_children():
		if Fusion.is_in_room() and child.replicator.has_authority():
			$PlayerSpawner.despawn(child)
		elif not Fusion.is_in_room() or child.offline:
			child.queue_free()
	if arena.overview:
		arena.overview.current = true


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
	ui.update_crosshair(local_player)
	if _connecting and Time.get_ticks_msec() > _connect_deadline:
		_error = "Время подключения истекло. Проверьте сеть, App ID и регион."
		disconnect_game()
	_ui_elapsed += delta
	if _ui_elapsed < 0.25:
		return
	_ui_elapsed = 0.0
	ui.refresh(
		local_player,
		Fusion.is_in_room(),
		Fusion.is_connected_to_photon(),
		_connecting,
		_error,
		$Players.get_child_count(),
		Fusion.get_rtt()
	)


func _configure_actor(actor: Node) -> void:
	actor.corpse_parent = $Corpses


func _resume_game() -> void:
	if is_instance_valid(local_player):
		_show_menu(false)
