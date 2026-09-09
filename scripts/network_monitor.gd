extends PanelContainer
## Fusion 3.0.0.2787 exposes byte rates via Performance and native monitor getters.
## No probe RPCs or extra replicated properties are sent by this overlay.
const Graph = preload("res://scripts/network_graph.gd")
const INTERVAL: float = 0.5
const HISTORY: int = 60
var _elapsed: float = 0
var _in_room: bool = false
var _rtt: Array[float] = []
var _sent: Array[float] = []
var _received: Array[float] = []
var _info: Label
var _latency: Label
var _traffic: Label
var _rtt_graph: Control
var _traffic_graph: Control
var latest_sent_bps: float = -1
var latest_received_bps: float = -1
var latest_rtt_ms: float = -1

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -366
	offset_right = -18
	offset_top = 18
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.035,0.055,0.08,0.93)
	style.set_corner_radius_all(8)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	add_theme_stylebox_override("panel",style)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation",7)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var title = _label(box,"СЕТЬ / F3 — скрыть",Color("f1f6fb"))
	title.add_theme_font_size_override("font_size",16)
	_info = _label(box,"",Color("a6bbce"))
	_latency = _label(box,"",Color("e8c677"))
	_rtt_graph = Graph.new()
	_rtt_graph.custom_minimum_size = Vector2(320,58)
	_rtt_graph.colors = [Color("e8c677")]
	_rtt_graph.minimum_max = 50
	_rtt_graph.unit = "мс"
	box.add_child(_rtt_graph)
	_traffic = _label(box,"",Color("d5e3ef"))
	_traffic_graph = Graph.new()
	_traffic_graph.custom_minimum_size = Vector2(320,70)
	_traffic_graph.colors = [Color("68cbaa"),Color("76aaff")]
	_traffic_graph.minimum_max = 1
	_traffic_graph.unit = "КиБ/с"
	box.add_child(_traffic_graph)
	_label(box,"↑ отправка — зелёный   ↓ приём — синий\nИстория 30 с · обновление 0.5 с\nТрафик клиента ↔ Photon Cloud\n1 КиБ = 1024 байта · общий поток",Color("97aabd"))
	_sample()

func _label(parent: Node, text: String, color: Color) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color",color)
	label.add_theme_font_size_override("font_size",13)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F3:
		visible = not visible
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed<INTERVAL: return
	_elapsed = fmod(_elapsed,INTERVAL)
	_sample()

func _read_rate(monitor: StringName, fallback: StringName) -> float:
	var value: float = -1
	if Performance.has_custom_monitor(monitor):
		value = float(Performance.get_custom_monitor(monitor))
	elif Fusion.has_method(fallback):
		value = float(Fusion.call(fallback))
	# An unavailable metric must not look like a measured zero.
	return value if is_finite(value) and value>=0 else -1

func _push(history: Array[float], value: float) -> void:
	history.append(value)
	if history.size()>HISTORY: history.pop_front()

func _sample() -> void:
	var online = Fusion.is_in_room()
	if online != _in_room:
		_rtt.clear()
		_sent.clear()
		_received.clear()
		_in_room = online
	if not online:
		latest_rtt_ms = -1
		latest_sent_bps = -1
		latest_received_bps = -1
		_info.text = "Нет сетевой сессии · регион "+Fusion.get_default_region()
		_latency.text = "RTT до Photon: —"
		_traffic.text = "↑ Отправка: —\n↓ Приём: —"
	else:
		latest_rtt_ms = Fusion.get_rtt()*1000
		latest_sent_bps = _read_rate(&"Fusion/Sent (Bps)",&"_get_monitor_bps_sent")
		latest_received_bps = _read_rate(&"Fusion/Received (Bps)",&"_get_monitor_bps_recv")
		_push(_rtt,latest_rtt_ms)
		var average: float = 0
		for value in _rtt: average += value
		average /= _rtt.size()
		var room = Fusion.get_room()
		_info.text = "Shared · %s · ID %d%s · игроков %d/%d" % [Fusion.get_default_region(),Fusion.get_local_player_id()," / Master" if Fusion.is_master_client() else "",room.get_player_count(),room.get_max_players()]
		_latency.text = "RTT: %.0f мс · сред. %.0f · макс. %.0f" % [latest_rtt_ms,average,_rtt.max()]
		_traffic.text = "↑ Отправка: %s\n↓ Приём: %s" % [_format_rate(latest_sent_bps),_format_rate(latest_received_bps)]
		if latest_sent_bps>=0: _push(_sent,latest_sent_bps/1024)
		else: _sent.clear()
		if latest_received_bps>=0: _push(_received,latest_received_bps/1024)
		else: _received.clear()
	_rtt_graph.series = [_rtt]
	_traffic_graph.series = [_sent,_received]
	_rtt_graph.queue_redraw()
	_traffic_graph.queue_redraw()

func _format_rate(value: float) -> String:
	return "%.2f КиБ/с" % (value/1024) if value>=0 else "недоступно в SDK"

