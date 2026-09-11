@tool
extends EditorInspectorPlugin
## Keep property keys stable so saved profiles remain compatible.
const LABELS = {
	"display_name": "Название оружия",
	"enabled": "Эффект включён",
	"spring_enabled": "Пружинная инерция",
	"spring_mass": "Масса оружия",
	"spring_stiffness": "Жёсткость возврата",
	"spring_damping": "Вязкость и затухание",
	"lag_seconds": "Сила отставания",
	"response_speed": "Скорость отклика",
	"return_speed": "Скорость возврата",
	"max_angle_degrees": "Предел отклонения",
	"position_gain": "Сила смещения",
	"max_offset": "Предел смещения",
	"roll_ratio": "Боковой наклон",
	"aim_multiplier": "Инерция через прицел",
	"pattern_enabled": "Покачивание включено",
	"base_amplitude_degrees": "Амплитуда по осям",
	"base_frequency_hz": "Базовая частота",
	"frequency_ratio": "Соотношение частот осей",
	"phase_degrees": "Сдвиг фазы",
	"pattern_aim_multiplier": "Покачивание через прицел",
	"context_response": "Плавность смены состояния",
	"crouch_amplitude_multiplier": "Амплитуда в приседе",
	"prone_amplitude_multiplier": "Амплитуда лёжа",
	"moving_amplitude_multiplier": "Амплитуда в движении",
	"moving_speed_multiplier": "Частота в движении",
	"focus_amplitude_multiplier": "Амплитуда при фокусировке",
	"focus_speed_multiplier": "Частота при фокусировке",
}


func _can_handle(object: Object) -> bool:
	return object.get_script() == preload("res://addons/weapon_sway/sway_profile.gd")


func _parse_end(object: Object) -> void:
	_translate.call_deferred(EditorInterface.get_inspector(), object)


func _translate(node: Node, object: Object) -> void:
	if not is_instance_valid(node) or not is_instance_valid(object):
		return
	if node is EditorProperty and node.get_edited_object() == object:
		var property = String(node.get_edited_property())
		if LABELS.has(property):
			node.label = LABELS[property]
	for child in node.get_children():
		_translate(child, object)
