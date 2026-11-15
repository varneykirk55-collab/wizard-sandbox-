extends CanvasLayer
## Reticle, spell bar, input hints (keyboard or controller), screen flash and
## the pause menu with volume / sensitivity controls. Fully controller-navigable.

var player

var _info: Array = []
var _current := 0
var _slot_styles: Array = []
var _slot_names: Array = []
var _reticle: Control
var _hint: Label
var _stats: Label
var _toast: Label
var _flash: ColorRect
var _pause: Control
var _resume: Button
var _toast_t := 0.0
var _stat_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_info = player.caster.info
	_build_game_ui()
	_build_pause_menu()
	player.caster.spell_changed.connect(_on_spell_changed)
	InputSetup.device_changed.connect(_on_device_changed)
	_on_device_changed(InputSetup.using_gamepad)
	_on_spell_changed(0)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()
	elif get_tree().paused and event is InputEventJoypadButton:
		if event.pressed and event.button_index == JOY_BUTTON_B:
			_set_paused(false)
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _flash.color.a > 0.0:
		_flash.color.a = move_toward(_flash.color.a, 0.0, delta * 2.2)
	if _toast_t > 0.0:
		_toast_t -= delta
		_toast.modulate.a = clampf(_toast_t, 0.0, 1.0)
	_stat_t -= delta
	if _stat_t <= 0.0:
		_stat_t = 0.25
		_stats.text = "Debris %d   FPS %d" % [DM.debris.size(), int(Engine.get_frames_per_second())]


## Brilliant full-screen flash (explosions).
func flash(amount: float) -> void:
	_flash.color.a = maxf(_flash.color.a, clampf(amount, 0.0, 0.85))


func toast(text: String) -> void:
	_toast.text = text
	_toast_t = 2.5
	_toast.modulate.a = 1.0


# ---------------------------------------------------------------------------
# In-game HUD
# ---------------------------------------------------------------------------

func _label(text: String, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l


func _build_game_ui() -> void:
	_flash = ColorRect.new()
	_flash.color = Color(1.0, 0.95, 0.85, 0.0)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)

	_reticle = Control.new()
	_reticle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reticle.draw.connect(_draw_reticle)
	add_child(_reticle)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 18)
	add_child(margin)

	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(col)

	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(top)
	_hint = _label("", 15)
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint.modulate = Color(1, 1, 1, 0.85)
	top.add_child(_hint)
	_stats = _label("", 14)
	_stats.modulate = Color(1, 1, 1, 0.7)
	top.add_child(_stats)

	_toast = _label("", 28)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.modulate.a = 0.0
	col.add_child(_toast)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(spacer)

	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_constant_override("separation", 10)
	col.add_child(bar)
	for i in _info.size():
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(158, 58)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(8)
		sb.set_border_width_all(2)
		sb.set_content_margin_all(8)
		panel.add_theme_stylebox_override("panel", sb)
		var v := VBoxContainer.new()
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		panel.add_child(v)
		var num := _label(str(i + 1), 13)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num.modulate = Color(1, 1, 1, 0.7)
		v.add_child(num)
		var spell_name: String = _info[i]["name"]
		var nm := _label(spell_name, 16)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(nm)
		bar.add_child(panel)
		_slot_styles.append(sb)
		_slot_names.append(nm)


func _draw_reticle() -> void:
	var c: Vector2 = _reticle.size * 0.5
	var col: Color = _info[_current]["color"]
	var ring := Color(col.r, col.g, col.b, 0.9)
	_reticle.draw_arc(c, 11.0, 0.0, TAU, 40, ring, 2.0, true)
	_reticle.draw_circle(c, 2.0, Color(1, 1, 1, 0.95))
	for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		var dv: Vector2 = d
		_reticle.draw_line(c + dv * 15.0, c + dv * 21.0, ring, 2.0, true)


func _on_spell_changed(index: int) -> void:
	_current = index
	for i in _slot_styles.size():
		var sb: StyleBoxFlat = _slot_styles[i]
		var col: Color = _info[i]["color"]
		var nm: Label = _slot_names[i]
		if i == index:
			sb.bg_color = Color(col.r * 0.35, col.g * 0.35, col.b * 0.35, 0.85)
			sb.border_color = col
			nm.modulate = Color(1, 1, 1, 1)
		else:
			sb.bg_color = Color(0.05, 0.05, 0.08, 0.55)
			sb.border_color = Color(1, 1, 1, 0.15)
			nm.modulate = Color(1, 1, 1, 0.55)
	_reticle.queue_redraw()


func _on_device_changed(gamepad: bool) -> void:
	if gamepad:
		_hint.text = "L-Stick move   R-Stick look   L3 / B sprint   A jump\nLB / RB spell   RT cast (hold: Thunder, Inferno)   Y reset   Start pause"
	else:
		_hint.text = "WASD move   Shift sprint   Space jump   1-5 / wheel spell\nLeft click cast (hold: Thunder, Inferno)   R reset   Esc pause"


# ---------------------------------------------------------------------------
# Pause menu
# ---------------------------------------------------------------------------

func _build_pause_menu() -> void:
	_pause = Control.new()
	_pause.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause.visible = false
	add_child(_pause)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(480, 0)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 24)
	panel.add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	margin.add_child(v)

	var title := _label("PAUSED", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)

	_resume = _button(v, "Resume")
	_resume.pressed.connect(_set_paused.bind(false))

	_slider(v, "Master volume", 0.0, 1.0, AudioManager.get_volume("Master")).value_changed.connect(_on_volume.bind("Master"))
	_slider(v, "Effects volume", 0.0, 1.0, AudioManager.get_volume("SFX")).value_changed.connect(_on_volume.bind("SFX"))
	_slider(v, "Ambience volume", 0.0, 1.0, AudioManager.get_volume("Ambience")).value_changed.connect(_on_volume.bind("Ambience"))
	_slider(v, "Mouse sensitivity", 0.2, 3.0, 1.0).value_changed.connect(_on_mouse_sens)
	_slider(v, "Stick sensitivity", 0.3, 3.0, 1.0).value_changed.connect(_on_pad_sens)

	var invert := CheckButton.new()
	invert.text = "Invert stick Y"
	invert.toggled.connect(_on_invert)
	v.add_child(invert)
	var rumble := CheckButton.new()
	rumble.text = "Controller vibration"
	rumble.button_pressed = true
	rumble.toggled.connect(_on_rumble)
	v.add_child(rumble)

	_button(v, "Reset world").pressed.connect(_on_reset)
	_button(v, "Quit").pressed.connect(_on_quit)


func _button(parent: Control, text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 40)
	parent.add_child(b)
	return b


func _slider(parent: Control, text: String, lo: float, hi: float, value: float) -> HSlider:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(180, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.05
	s.value = value
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.custom_minimum_size = Vector2(220, 24)
	row.add_child(s)
	return s


func _set_paused(p: bool) -> void:
	get_tree().paused = p
	_pause.visible = p
	if p:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_resume.grab_focus()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_volume(value: float, bus: String) -> void:
	AudioManager.set_volume(bus, value)


func _on_mouse_sens(value: float) -> void:
	InputSetup.mouse_sens = 0.0022 * value


func _on_pad_sens(value: float) -> void:
	InputSetup.pad_sens = 3.2 * value


func _on_invert(on: bool) -> void:
	InputSetup.invert_y = on


func _on_rumble(on: bool) -> void:
	InputSetup.rumble_enabled = on


func _on_reset() -> void:
	_set_paused(false)
	get_tree().call_group("main", "reset_world")


func _on_quit() -> void:
	get_tree().quit()
