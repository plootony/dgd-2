extends RefCounted
## Installs default actions without replacing bindings already defined by the project.


static func ensure_defaults() -> void:
	var keys = {
		"move_forward": KEY_W,
		"move_back": KEY_S,
		"move_left": KEY_A,
		"move_right": KEY_D,
		"run": KEY_SHIFT,
		"crouch": KEY_CTRL,
		"jump": KEY_SPACE,
		"view_toggle": KEY_V,
		"weapon_1": KEY_1,
		"weapon_2": KEY_2,
		"reload": KEY_R
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		if InputMap.action_get_events(action).is_empty():
			var event = InputEventKey.new()
			event.physical_keycode = keys[action]
			InputMap.action_add_event(action, event)

	for binding in [["fire", MOUSE_BUTTON_LEFT], ["aim", MOUSE_BUTTON_RIGHT]]:
		if not InputMap.has_action(binding[0]):
			InputMap.add_action(binding[0])
		if InputMap.action_get_events(binding[0]).is_empty():
			var event = InputEventMouseButton.new()
			event.button_index = binding[1]
			InputMap.action_add_event(binding[0], event)
