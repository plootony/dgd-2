@tool
extends EditorPlugin
const Profile = preload("res://addons/weapon_control/weapon_profile.gd")
var _dock: VBoxContainer
var _weapons: OptionButton
var _modes: OptionButton
var _paths: Array[String] = []
var _profile: Profile
var _russian_inspector = preload("res://addons/weapon_control/russian_inspector.gd").new()


func _enter_tree() -> void:
	add_inspector_plugin(_russian_inspector)
	_dock = VBoxContainer.new()
	_dock.name = "Управление оружием"
	_weapons = OptionButton.new()
	_weapons.item_selected.connect(_select_weapon)
	_dock.add_child(_weapons)
	_modes = OptionButton.new()
	for name in Profile.MODE_NAMES:
		_modes.add_item(name)
	_modes.item_selected.connect(_select_mode)
	_dock.add_child(_modes)
	for item in [
		["Общие настройки оружия", _edit_profile],
		["Настройки режима", _edit_mode],
		["Сохранить профиль", _save],
		["Обновить список", _refresh],
		["Сбросить выбранный режим", _reset_mode]
	]:
		var button = Button.new()
		button.text = item[0]
		button.pressed.connect(item[1])
		_dock.add_child(button)
	var hint = Label.new()
	hint.text = "Параметры — в инспекторе.\nФлажок «Режим разрешён»\nвключает режим стрельбы.\nВ игре: B — сменить режим."
	_dock.add_child(hint)
	add_control_to_dock(DOCK_SLOT_RIGHT_BL, _dock)
	_refresh()


func _exit_tree() -> void:
	remove_inspector_plugin(_russian_inspector)
	remove_control_from_docks(_dock)
	_dock.queue_free()


func _refresh() -> void:
	_profile = null
	_paths.clear()
	_weapons.clear()
	var directory = ProjectSettings.get_setting(
		"weapon_control/profile_directory", "res://weapon_control_profiles"
	)
	if DirAccess.dir_exists_absolute(directory):
		for file in DirAccess.get_files_at(directory):
			if file.ends_with(".tres"):
				var path = String(directory).path_join(file)
				var resource = load(path)
				if resource is Profile:
					_paths.append(path)
					_weapons.add_item(resource.display_name)
	_weapons.select(-1)


func _select_weapon(index: int) -> void:
	_profile = load(_paths[index])
	_modes.select(maxi(_profile.initial_mode(), 0))
	_edit_mode()


func _select_mode(_index: int) -> void:
	_edit_mode()


func _edit_profile() -> void:
	if _profile != null:
		EditorInterface.edit_resource(_profile)


func _edit_mode() -> void:
	if _profile != null:
		EditorInterface.edit_resource(_profile.mode(_modes.selected))


func _save() -> void:
	if _profile != null and ResourceSaver.save(_profile, _profile.resource_path) != OK:
		push_error("Could not save weapon profile")


func _reset_mode() -> void:
	if _profile == null or _profile.mode(_modes.selected) == null:
		return
	var target = _profile.mode(_modes.selected)
	var defaults = Profile.Mode.new()
	var history = get_undo_redo()
	history.create_action("Сбросить настройки режима оружия", UndoRedo.MERGE_DISABLE, _profile)
	for property in defaults.get_property_list():
		if (
			property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE
			and property.usage & PROPERTY_USAGE_EDITOR
		):
			history.add_do_property(target, property.name, defaults.get(property.name))
			history.add_undo_property(target, property.name, target.get(property.name))
	history.add_do_method(target, "emit_changed")
	history.add_undo_method(target, "emit_changed")
	history.commit_action()
	_edit_mode()
