extends CanvasLayer
## Menu and HUD presentation; game/session actions are requested through signals.

signal connect_requested
signal offline_requested
signal graphics_requested
signal resume_requested
signal disconnect_requested

var panel: PanelContainer
var status: Label
var hud: Label
var crosshair: Label
var room_input: LineEdit
var name_input: LineEdit
var connect_button: Button
var offline_button: Button
var disconnect_button: Button


func _ready() -> void:
	var network_monitor = preload("res://ui/network/network_monitor.gd").new()
	network_monitor.name = "NetworkMonitor"
	add_child(network_monitor)
	hud = Label.new()
	hud.position = Vector2(24, 20)
	hud.add_theme_color_override("font_color", Color("e9f2fa"))
	hud.add_theme_color_override("font_shadow_color", Color.BLACK)
	hud.add_theme_constant_override("shadow_offset_x", 2)
	hud.add_theme_constant_override("shadow_offset_y", 2)
	add_child(hud)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(380, 0)
	center.add_child(panel)
	var margin = MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	var title = Label.new()
	title.text = "DGD / ПОЛИГОН"
	title.add_theme_font_size_override("font_size", 24)
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
	connect_button = _button(box, "Подключиться / создать комнату", connect_requested.emit)
	offline_button = _button(box, "Локальный тест", offline_requested.emit)
	_button(box, "Графика и экран", graphics_requested.emit)
	_button(box, "Продолжить", resume_requested.emit)
	disconnect_button = _button(box, "Отключиться", disconnect_requested.emit)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status)
	var cross = Label.new()
	crosshair = cross
	cross.text = "+"
	cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cross)


func _button(parent: Node, text: String, action: Callable) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size.y = 40
	b.pressed.connect(action)
	parent.add_child(b)
	return b


func update_crosshair(local_player: NetworkPlayer) -> void:
	if crosshair != null:
		crosshair.visible = (
			not (is_instance_valid(local_player) and local_player.combat.is_dead())
			and not (
				is_instance_valid(local_player)
				and local_player.first_person_weapons != null
				and local_player.first_person_weapons.active
				and local_player.first_person_weapons.aim_blend > 0.5
			)
		)


func refresh(
	local_player: NetworkPlayer,
	online: bool,
	connected: bool,
	connecting: bool,
	error: String,
	player_count: int,
	rtt: float
) -> void:
	connect_button.disabled = connecting or online
	offline_button.disabled = connecting or connected
	disconnect_button.visible = connecting or online or is_instance_valid(local_player)
	room_input.editable = not connecting and not online
	name_input.editable = not connecting and not online
	status.text = (
		error
		if not error.is_empty()
		else ("Подключение…" if connecting else ("В комнате" if online else "Готово"))
	)
	var view = (
		"3-е лицо" if is_instance_valid(local_player) and local_player.third_person else "1-е лицо"
	)
	var mode = (
		"Fusion · %d игроков · RTT %d мс" % [player_count, roundi(rtt * 1000)]
		if online
		else "Локальный тест"
	)
	hud.text = (
		"DGD / TEST ARENA\n%s  |  %s  |  %d FPS\nWASD — ходьба   Shift — бег   Space — прыжок\nCtrl — присед   V — камера   Esc — меню\n1 — AK74U   2 — Beretta (от первого лица)\nЛКМ — огонь   ПКМ — прицел   R — перезарядка"
		% [mode, view, Engine.get_frames_per_second()]
	)

	if is_instance_valid(local_player):
		hud.text += (
			"\n"
			+ (
				"Вы погибли. Возрождение через 5 секунд…"
				if local_player.combat.is_dead()
				else "Здоровье: %d / 100" % local_player.combat.health
			)
		)
