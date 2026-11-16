extends Node
## Registers every input action at startup (keyboard + mouse + gamepad) and
## tracks which device the player used last so the HUD can show the right prompts.

signal device_changed(gamepad: bool)

var using_gamepad := false
var mouse_sens := 0.0022
var pad_sens := 3.2
var invert_y := false
var rumble_enabled := true


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Movement
	_key("move_forward", KEY_W)
	_key("move_back", KEY_S)
	_key("move_left", KEY_A)
	_key("move_right", KEY_D)
	_axis("move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_axis("move_back", JOY_AXIS_LEFT_Y, 1.0)
	_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	# Look (right stick)
	_axis("look_left", JOY_AXIS_RIGHT_X, -1.0, 0.15)
	_axis("look_right", JOY_AXIS_RIGHT_X, 1.0, 0.15)
	_axis("look_up", JOY_AXIS_RIGHT_Y, -1.0, 0.15)
	_axis("look_down", JOY_AXIS_RIGHT_Y, 1.0, 0.15)
	# Actions
	_key("jump", KEY_SPACE)
	_pad("jump", JOY_BUTTON_A)
	_key("sprint", KEY_SHIFT)
	_pad("sprint", JOY_BUTTON_B)
	_pad("sprint_toggle", JOY_BUTTON_LEFT_STICK)
	# Flight. B stays ground sprint; while levitating the player reads it as descend.
	# Shift stays ground sprint; while levitating it is also the speed boost.
	_key("descend", KEY_CTRL)
	_pad("descend", JOY_BUTTON_B)
	_key("fly_boost", KEY_SHIFT)
	_pad("fly_boost", JOY_BUTTON_LEFT_STICK)
	_mouse("cast", MOUSE_BUTTON_LEFT)
	_axis("cast", JOY_AXIS_TRIGGER_RIGHT, 1.0, 0.35)
	_pad("cast", JOY_BUTTON_X)
	# Spell selection
	_key("spell_1", KEY_1)
	_key("spell_2", KEY_2)
	_key("spell_3", KEY_3)
	_key("spell_4", KEY_4)
	_key("spell_5", KEY_5)
	_mouse("spell_next", MOUSE_BUTTON_WHEEL_DOWN)
	_mouse("spell_prev", MOUSE_BUTTON_WHEEL_UP)
	_pad("spell_next", JOY_BUTTON_RIGHT_SHOULDER)
	_pad("spell_prev", JOY_BUTTON_LEFT_SHOULDER)
	_pad("spell_next", JOY_BUTTON_DPAD_RIGHT)
	_pad("spell_prev", JOY_BUTTON_DPAD_LEFT)
	# System
	_key("reset_world", KEY_R)
	_pad("reset_world", JOY_BUTTON_Y)
	_key("pause", KEY_ESCAPE)
	_pad("pause", JOY_BUTTON_START)


func _ensure(action: String, deadzone: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, deadzone)


func _key(action: String, keycode: Key) -> void:
	_ensure(action, 0.3)
	var ev := InputEventKey.new()
	ev.device = -1
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)


func _mouse(action: String, button: MouseButton) -> void:
	_ensure(action, 0.3)
	var ev := InputEventMouseButton.new()
	ev.device = -1
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func _pad(action: String, button: JoyButton) -> void:
	_ensure(action, 0.3)
	var ev := InputEventJoypadButton.new()
	ev.device = -1
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func _axis(action: String, axis: JoyAxis, value: float, deadzone: float = 0.25) -> void:
	_ensure(action, deadzone)
	var ev := InputEventJoypadMotion.new()
	ev.device = -1
	ev.axis = axis
	ev.axis_value = value
	InputMap.action_add_event(action, ev)


func _input(event: InputEvent) -> void:
	var pad := using_gamepad
	if event is InputEventJoypadButton:
		pad = true
	elif event is InputEventJoypadMotion:
		if absf(event.axis_value) > 0.5:
			pad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		pad = false
	elif event is InputEventMouseMotion:
		if event.relative.length() > 4.0:
			pad = false
	if pad != using_gamepad:
		using_gamepad = pad
		device_changed.emit(pad)


## Controller vibration. Ignored when the player is on mouse and keyboard.
func rumble(weak: float, strong: float, duration: float) -> void:
	if not using_gamepad or not rumble_enabled:
		return
	for id in Input.get_connected_joypads():
		Input.start_joy_vibration(id, clampf(weak, 0.0, 1.0), clampf(strong, 0.0, 1.0), duration)
