@tool
extends EditorPlugin

const Profile = preload("res://addons/weapon_sway/sway_profile.gd")
const Presets = preload("res://addons/weapon_sway/inertia_presets.gd")
const DIRECTORY_SETTING = "weapon_sway/profile_directory"
var _dock: VBoxContainer
var _choice: OptionButton
var _dialog: EditorFileDialog
var _reset: Button
var _preset_choice: OptionButton
var _apply_preset: Button
var _paths: Array[String] = []
var _russian_inspector = preload("res://addons/weapon_sway/russian_inspector.gd").new()


func _enter_tree() -> void:
	add_inspector_plugin(_russian_inspector)
	if not ProjectSettings.has_setting(DIRECTORY_SETTING):
		ProjectSettings.set_setting(DIRECTORY_SETTING, "res://weapon_sway_profiles")
	_dock = VBoxContainer.new()
	_dock.name = "Инерция оружия"
	var label = Label.new()
	label.text = "Профиль оружия"
	_dock.add_child(label)
	_choice = OptionButton.new()
	_choice.item_selected.connect(_select)
	_dock.add_child(_choice)
	var preset_label = Label.new()
	preset_label.text = "Пресет инерции"
	_dock.add_child(preset_label)
	_preset_choice = OptionButton.new()
	for preset_name in Presets.NAMES:
		_preset_choice.add_item(preset_name)
	_preset_choice.select(5)
	_dock.add_child(_preset_choice)
	_apply_preset = Button.new()
	_apply_preset.text = "Применить пресет к оружию"
	_apply_preset.tooltip_text = "Меняет инерцию выбранного профиля. Ctrl+Z — отмена, Ctrl+S — сохранение."
	_apply_preset.disabled = true
	_apply_preset.pressed.connect(_apply_selected_preset)
	_dock.add_child(_apply_preset)
	var refresh = Button.new()
	refresh.text = "Обновить список"
	refresh.pressed.connect(_refresh)
	_dock.add_child(refresh)
	var create = Button.new()
	create.text = "Создать профиль…"
	create.pressed.connect(_create)
	_dock.add_child(create)
	_reset = Button.new()
	_reset.text = "Сбросить по умолчанию"
	_reset.tooltip_text = "Вернуть стандартные параметры инерции оружия. Имя профиля сохранится. Можно отменить через Ctrl+Z; сохраните результат Ctrl+S."
	_reset.disabled = true
	_reset.pressed.connect(_reset_selected)
	_dock.add_child(_reset)
	var help = Label.new()
	help.text = "Выберите оружие и измените\nпараметры в инспекторе.\nСохраните ресурс: Ctrl+S."
	_dock.add_child(help)
	_dialog = EditorFileDialog.new()
	_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	_dialog.add_filter("*.tres", "Sway profile")
	_dialog.file_selected.connect(_save_new)
	_dock.add_child(_dialog)
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)
	_refresh()


func _exit_tree() -> void:
	remove_inspector_plugin(_russian_inspector)
	remove_control_from_docks(_dock)
	_dock.queue_free()


func _refresh() -> void:
	_reset.disabled = true
	_apply_preset.disabled = true
	_paths.clear()
	_choice.clear()
	var directory = String(ProjectSettings.get_setting(DIRECTORY_SETTING))
	if not DirAccess.dir_exists_absolute(directory):
		_choice.disabled = true
		return
	for file in DirAccess.get_files_at(directory):
		if file.ends_with(".tres"):
			var path = directory.path_join(file)
			var profile = load(path)
			if profile is Profile:
				_paths.append(path)
				_choice.add_item(profile.display_name + " — " + file)
	_choice.disabled = _paths.is_empty()
	_choice.select(-1)


func _select(index: int) -> void:
	_reset.disabled = index < 0 or index >= _paths.size()
	_apply_preset.disabled = _reset.disabled
	if index >= 0 and index < _paths.size():
		EditorInterface.edit_resource(load(_paths[index]))


func _reset_selected() -> void:
	var defaults = Profile.new()
	var values = {}
	for property in defaults.get_property_list():
		if not (
			property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE
			and property.usage & PROPERTY_USAGE_EDITOR
		):
			continue
		if property.name == "display_name":
			continue
		values[property.name] = defaults.get(property.name)
	_apply_values(values, "Сбросить инерцию оружия по умолчанию")


func _apply_selected_preset() -> void:
	_apply_values(Presets.values(_preset_choice.selected), "Применить пресет инерции")


func _apply_values(values: Dictionary, title: String) -> void:
	var index = _choice.selected
	if index < 0 or index >= _paths.size() or values.is_empty():
		return
	var profile = load(_paths[index]) as Profile
	var history = get_undo_redo()
	history.create_action(title, UndoRedo.MERGE_DISABLE, profile)
	for property in values:
		history.add_do_property(profile, property, values[property])
		history.add_undo_property(profile, property, profile.get(property))
	history.add_do_method(profile, "emit_changed")
	history.add_undo_method(profile, "emit_changed")
	history.commit_action()
	EditorInterface.edit_resource(profile)


func _create() -> void:
	var directory = String(ProjectSettings.get_setting(DIRECTORY_SETTING))
	DirAccess.make_dir_recursive_absolute(directory)
	_dialog.current_path = directory.path_join("new_weapon.tres")
	_dialog.popup_centered_ratio(0.6)


func _save_new(path: String) -> void:
	var profile = Profile.new()
	profile.display_name = path.get_file().get_basename()
	if ResourceSaver.save(profile, path) != OK:
		push_error("Could not save weapon sway profile: " + path)
		return
	var filesystem = EditorInterface.get_resource_filesystem()
	if not filesystem.is_scanning():
		filesystem.scan()
	_refresh()
	EditorInterface.edit_resource(profile)
