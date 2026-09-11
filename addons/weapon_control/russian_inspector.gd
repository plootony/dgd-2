@tool
extends EditorInspectorPlugin
## Translate presentation labels without renaming serialized resource fields.
const LABELS = {
	"display_name": "Название оружия",
	"enabled": "Режим разрешён",
	"default_mode": "Начальный режим",
	"single": "Одиночный огонь",
	"burst": "Стрельба очередями",
	"automatic": "Автоматический огонь",
	"interval": "Интервал выстрелов",
	"unlimited_single_clicks": "Выстрел на каждый клик",
	"burst_count": "Выстрелов в очереди",
	"hip_spread": "Разброс от бедра",
	"ads_spread": "Разброс через прицел",
	"spread_per_shot": "Рост разброса за выстрел",
	"max_extra_spread": "Предел дополнительного разброса",
	"spread_recovery": "Скорость восстановления точности",
	"pitch_kick": "Подброс камеры",
	"yaw_random": "Случайный боковой увод",
	"lateral_drift": "Постоянный боковой увод",
	"yaw_pattern": "Рисунок бокового увода",
	"ads_recoil_multiplier": "Множитель отдачи через прицел",
	"visual_pitch": "Подброс модели оружия",
	"kickback": "Толчок оружия назад",
	"visual_recovery": "Скорость возврата оружия",
	"visual_angle_limit": "Предел наклона оружия",
	"kickback_limit": "Предел смещения назад",
	"crouch_spread": "Разброс в приседе",
	"moving_spread": "Разброс в движении",
	"airborne_spread": "Разброс в воздухе",
	"focused_spread": "Разброс при фокусировке",
	"crouch_recoil": "Отдача в приседе",
	"moving_recoil": "Отдача в движении",
	"focused_recoil": "Отдача при фокусировке",
}


func _can_handle(object: Object) -> bool:
	return (
		object.get_script()
		in [
			preload("res://addons/weapon_control/fire_mode.gd"),
			preload("res://addons/weapon_control/weapon_profile.gd")
		]
	)


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
