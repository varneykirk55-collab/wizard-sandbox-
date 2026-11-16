extends Node3D
## Headless checks for levitation. Drives Input actions, so it validates the
## shared jump / descend / boost actions rather than a physical gamepad.
## Run: godot --headless --audio-driver Dummy --path . res://scenes/flight_test.tscn

var player
var _phase := "settle"
var _phase_t := 0.0
var _floor_t := 0.0
var _rose := 0.0
var _base_y := 0.0
var _hover_y := 0.0
var _peak_speed := 0.0
var _entry_t := -1.0
var _left_ground := false
var _cam_ok := true
var _casts := 0
var _spell_i := 0
var _spell_base := 0
var _spell_phase := 0
var _min_y := 1000.0
var _ceiling: StaticBody3D
var _wall: StaticBody3D
var _platform: StaticBody3D
var _near_state := 0
var _retap_state := 0
var _dead := false


func _ready() -> void:
	_build_ground()
	player = load("res://scripts/player/player.gd").new()
	player.name = "Player"
	player.position = Vector3(0.0, 0.6, 0.0)
	add_child(player)
	FX.player = player
	DM.player = player
	player.caster.cast.connect(func(_i): _casts += 1)
	_verify_bindings()
	_probe_ctrl()


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_phase_t += delta
	_min_y = minf(_min_y, player.global_position.y)
	if _min_y < -0.5:
		_fail("fell through the floor (y=%.3f)" % _min_y)
		return
	if _cam_ok and player.is_flying() and player._trauma < 0.001:
		var cam_pos: Vector3 = player.cam.position
		if cam_pos.distance_to(Vector3(0.0, player.EYE, 0.0)) > 0.002:
			_cam_ok = false
			_fail("camera offset during flight %s" % cam_pos)
			return
	match _phase:
		"settle":
			_settle()
		"ground":
			_ground()
		"tap":
			_tap()
		"hold":
			_hold()
		"ascend":
			_ascend()
		"hover":
			_hover()
		"boost":
			_boost()
		"coast":
			_coast()
		"stop":
			_stop()
		"descend":
			_descend()
		"retap":
			_retap()
		"rehold":
			_rehold()
		"latch":
			_latch()
		"near":
			_near()
		"ceiling":
			_ceiling_phase()
		"wall":
			_wall_phase()
		"platform":
			_platform_phase()
		"spells":
			_spells()
		_:
			_fail("unknown phase %s" % _phase)


func _verify_bindings() -> void:
	if not _has_key("descend", KEY_CTRL):
		_fail("descend is missing Ctrl")
	if not _has_button("descend", JOY_BUTTON_B):
		_fail("descend is missing joypad B")
	if not _has_key("fly_boost", KEY_SHIFT):
		_fail("fly_boost is missing Shift")
	if not _has_button("fly_boost", JOY_BUTTON_LEFT_STICK):
		_fail("fly_boost is missing left stick click")
	if not _has_key("jump", KEY_SPACE) or not _has_button("jump", JOY_BUTTON_A):
		_fail("jump bindings changed")
	if not _has_button("sprint", JOY_BUTTON_B) or not _has_key("sprint", KEY_SHIFT):
		_fail("ground sprint bindings changed")
	var names := ["CATACLYSM", "THUNDER GOD", "GRAVITY WELL", "INFERNO", "METEOR", "BLACK FIRE", "OBLIVION"]
	for i in names.size():
		if player.caster.info[i]["name"] != names[i]:
			_fail("spell name changed at %d" % i)


func _settle() -> void:
	if player.is_flying():
		_fail("entered flight while settling")
		return
	if player.is_on_floor():
		_floor_t += get_physics_process_delta_time()
	else:
		_floor_t = 0.0
	if _floor_t > 0.25:
		_goto("ground")
	elif _phase_t > 3.0:
		_fail("never settled on the floor")


func _ground() -> void:
	if _phase_t < 0.45:
		_press("move_forward")
		if player.is_flying():
			_fail("ground move entered flight")
			return
	elif _phase_t < 0.55:
		_release("move_forward")
	elif _phase_t < 1.05:
		_press("move_forward")
		_press("sprint")
	else:
		var speed := Vector2(player.velocity.x, player.velocity.z).length()
		_release("move_forward")
		_release("sprint")
		if player.is_flying():
			_fail("ground sprint entered flight")
			return
		if speed < 10.0:
			_fail("ground sprint too slow (%.2f)" % speed)
			return
		if player.global_position.z > -1.0:
			_fail("ground move did not travel forward (z=%.2f)" % player.global_position.z)
			return
		_goto("tap")


func _tap() -> void:
	if _phase_t == get_physics_process_delta_time() or _phase_t < 0.02:
		if not Input.is_action_pressed("jump"):
			_base_y = player.global_position.y
			_rose = _base_y
			_press("jump")
	if Input.is_action_pressed("jump") and _phase_t >= 0.06:
		_release("jump")
	_rose = maxf(_rose, player.global_position.y)
	if not player.is_on_floor():
		_left_ground = true
	if player.is_flying():
		_fail("tap jump entered flight after %.3fs" % _phase_t)
		return
	if not Input.is_action_pressed("jump") and _phase_t > 0.4 and player.is_on_floor() and _left_ground:
		if _rose - _base_y < 0.55:
			_fail("tap jump barely left the ground (rise %.2f)" % (_rose - _base_y))
			return
		if _rose - _base_y > 2.4:
			_fail("tap jump rose like flight (rise %.2f)" % (_rose - _base_y))
			return
		_goto("hold")
	elif _phase_t > 3.0:
		_fail("tap jump did not land (rise %.2f floor %s)" % [_rose - _base_y, player.is_on_floor()])


func _hold() -> void:
	if not Input.is_action_pressed("jump"):
		if not player.is_on_floor():
			_fail("hold test left the floor before the press")
			return
		_press("jump")
		_entry_t = -1.0
	if player.is_flying():
		if _entry_t < 0.0:
			_entry_t = _phase_t
			if _entry_t < 0.15:
				_fail("flight started too early (%.3fs)" % _entry_t)
				return
		_goto("ascend")
		return
	if _phase_t > 0.08 and _phase_t < 0.12 and player.is_flying():
		_fail("flying before the hold threshold")
		return
	if _phase_t > 0.55:
		_fail("hold did not enter flight (held %.2fs on_floor=%s)" % [_phase_t, player.is_on_floor()])


func _ascend() -> void:
	_press("jump")
	if not player.is_flying():
		_fail("left flight while ascend was held")
		return
	if _phase_t > 0.35:
		if player.velocity.y < 4.0:
			_fail("ascend speed low (vy=%.2f)" % player.velocity.y)
			return
		_release("jump")
		_goto("hover")


func _hover() -> void:
	_release("jump")
	_release("descend")
	if not player.is_flying():
		_fail("hover cancelled flight")
		return
	if absf(player.velocity.y) < 0.001 and _phase_t > 0.15 and _hover_y == 0.0:
		_hover_y = player.global_position.y
	if _hover_y != 0.0 and _phase_t > 0.2:
		var age := _phase_t - 0.2
		if age > 0.85:
			if absf(player.global_position.y - _hover_y) > 0.03:
				_fail("hover drifted (dy=%.4f)" % (player.global_position.y - _hover_y))
				return
			if absf(player.velocity.y) > 0.001:
				_fail("hover vertical speed %.4f" % player.velocity.y)
				return
			_goto("boost")
	elif _phase_t > 2.0:
		_fail("never reached a stable hover (vy=%.3f)" % player.velocity.y)


func _boost() -> void:
	_press("move_forward")
	_press("fly_boost")
	if not player.is_flying():
		_fail("boost cancelled flight")
		return
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	_peak_speed = maxf(_peak_speed, speed)
	if _phase_t > 1.2:
		if _peak_speed < 15.0:
			_fail("boost too slow (%.2f)" % _peak_speed)
			return
		_release("fly_boost")
		_goto("coast")


func _coast() -> void:
	_press("move_forward")
	_release("fly_boost")
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	if _phase_t > 0.12 and speed < 2.0:
		_fail("releasing boost hard-stopped (speed %.2f)" % speed)
		return
	if _phase_t > 0.7:
		if speed > 10.5:
			_fail("did not settle toward cruise (%.2f)" % speed)
			return
		if speed < 6.0:
			_fail("cruise too slow (%.2f)" % speed)
			return
		_release("move_forward")
		_peak_speed = speed
		_goto("stop")


func _stop() -> void:
	_release("move_forward")
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	if _phase_t < 0.08 and speed < 0.4:
		_fail("releasing the stick hard-stopped")
		return
	if _phase_t > 0.7:
		if speed > 0.4:
			_fail("did not finish decelerating (%.2f)" % speed)
			return
		_press("jump")
		_goto("descend")


func _descend() -> void:
	# Climb first so landing is a real descent, not a hover into the dirt.
	if _phase_t < 0.35:
		_press("jump")
		_release("descend")
		return
	_release("jump")
	_press("descend")
	if _phase_t > 0.45 and player.is_flying() == false and player.is_on_floor():
		if player.global_position.y > 0.35 or player.global_position.y < -0.05:
			_fail("landed at a bad height y=%.3f" % player.global_position.y)
			return
		# Descend is still held. That must not launch flight again.
		_goto("retap", false)
		return
	if _phase_t > 4.0:
		_fail("descend did not land (y=%.2f flying=%s floor=%s)" % [player.global_position.y, player.is_flying(), player.is_on_floor()])


func _retap() -> void:
	# 0: descend is still held from the landing. Must stay walking.
	# 1: stand with everything released. Must not sink or take off.
	# 2: a short tap, which must be a jump and not flight.
	if _retap_state == 0:
		_press("descend")
		if player.is_flying():
			_fail("re-entered flight while descend was still held")
			return
		if not player.is_on_floor():
			_fail("left the floor on the landing frame")
			return
		if _phase_t > 0.2:
			_release("descend")
			_retap_state = 1
			_phase_t = 0.0
		return
	if _retap_state == 1:
		_release_all()
		if player.is_flying():
			_fail("took off with no ascend held")
			return
		if _phase_t > 0.4:
			if not player.is_on_floor():
				_fail("lost the floor after landing")
				return
			if player.global_position.y < -0.02 or player.global_position.y > 0.2:
				_fail("height wrong after landing y=%.3f" % player.global_position.y)
				return
			_retap_state = 2
			_phase_t = 0.0
			_left_ground = false
			_base_y = player.global_position.y
			_rose = _base_y
			_press("jump")
		return
	if _phase_t >= 0.07:
		_release("jump")
	_rose = maxf(_rose, player.global_position.y)
	if not player.is_on_floor():
		_left_ground = true
	if player.is_flying():
		_fail("second tap entered flight")
		return
	if not Input.is_action_pressed("jump") and _left_ground and player.is_on_floor() and _phase_t > 0.45:
		if _rose - _base_y < 0.5:
			_fail("second tap did not jump (rise %.2f)" % (_rose - _base_y))
			return
		_goto("rehold")
	elif _phase_t > 2.5:
		_fail("second tap did not land")


func _rehold() -> void:
	if not player.is_on_floor() and not Input.is_action_pressed("jump") and _phase_t < 0.05:
		return
	if not Input.is_action_pressed("jump"):
		if not player.is_on_floor():
			_fail("rehold started in the air")
			return
		_press("jump")
	if player.is_flying():
		_goto("latch")
		return
	if _phase_t > 0.6:
		_fail("fresh hold after landing did not fly")


func _latch() -> void:
	if _phase_t < 0.05:
		_press("jump")
		if player.is_flying():
			player._flight.force_ground(player)
		return
	_press("jump")
	if player.is_flying():
		_fail("flight restarted from the same held press")
		return
	if _phase_t > 0.4:
		_release("jump")
		_near_state = 0
		_goto("near")


func _near() -> void:
	# 0: fresh hold until flying. 1: release and park just above the ground. 2: stay there.
	if _near_state == 0:
		_release("descend")
		if not player.is_flying():
			if player.is_on_floor():
				_press("jump")
			elif _phase_t > 2.5:
				_fail("near-ground setup never left the fall")
			return
		_release("jump")
		_near_state = 1
		return
	if _near_state == 1:
		_release_all()
		if Input.is_action_pressed("jump"):
			return
		player.velocity = Vector3.ZERO
		player.global_position = Vector3(0.0, 0.22, 0.0)
		_near_state = 2
		_phase_t = 0.0
		return
	_release("jump")
	_release("descend")
	_press("move_right")
	if not player.is_flying():
		_fail("hover near terrain cancelled flight")
		return
	if _phase_t > 0.85:
		if absf(player.global_position.y - 0.22) > 0.08:
			_fail("near-ground hover moved vertically to %.3f" % player.global_position.y)
			return
		_release("move_right")
		_goto("ceiling")


func _ceiling_phase() -> void:
	if _ceiling == null:
		_release_all()
		_ceiling = _static_box(Vector3(0.0, 4.2, -8.0), Vector3(6.0, 0.6, 6.0), 1)
		player.velocity = Vector3.ZERO
		player.global_position = Vector3(0.0, 1.2, -8.0)
		if not player.is_flying():
			_fail("lost flight before the ceiling")
			return
	_press("jump")
	var top: float = player.global_position.y + 1.8
	if top > 3.95:
		_fail("passed through the ceiling (top %.2f)" % top)
		return
	if _phase_t > 0.7:
		if not player.is_flying():
			_fail("ceiling contact cancelled flight")
			return
		_release("jump")
		_goto("wall")


func _wall_phase() -> void:
	if _wall == null:
		_release_all()
		_wall = _static_box(Vector3(4.5, 1.5, -8.0), Vector3(0.6, 4.0, 6.0), 1)
		player.velocity = Vector3.ZERO
		player.global_position = Vector3(0.5, 1.6, -8.0)
	_press("move_right")
	if player.global_position.x > 4.5 - 0.35:
		_fail("passed through the wall (x=%.2f)" % player.global_position.x)
		return
	if _phase_t > 0.8:
		if not player.is_flying():
			_fail("wall contact cancelled flight")
			return
		if player.global_position.x < 2.0:
			_fail("did not reach the wall (x=%.2f)" % player.global_position.x)
			return
		_release("move_right")
		_goto("platform")


func _platform_phase() -> void:
	if _platform == null:
		_release_all()
		# Layer 2 is intact structure, which the player already collides with.
		_platform = _static_box(Vector3(0.0, 2.5, 24.0), Vector3(6.0, 1.0, 6.0), 2)
		player.velocity = Vector3.ZERO
		player.global_position = Vector3(0.0, 6.0, 24.0)
		if not player.is_flying():
			_fail("lost flight before the platform")
			return
	_release("jump")
	_press("descend")
	if not player.is_flying() and player.is_on_floor():
		if absf(player.global_position.y - 3.0) > 0.25:
			_fail("platform landing height y=%.2f" % player.global_position.y)
			return
		if absf(player.global_position.z - 24.0) > 2.0:
			_fail("slid off the platform")
			return
		_release("descend")
		# Take off again for the spell checks.
		_goto("spells")
		return
	if _phase_t > 3.0:
		_fail("did not land on the platform (y=%.2f flying=%s)" % [player.global_position.y, player.is_flying()])


func _spells() -> void:
	if _spell_phase == 0:
		if not player.is_flying():
			if player.is_on_floor():
				_press("jump")
			if _phase_t > 1.5:
				_fail("could not fly for spell checks")
			return
		_release("jump")
		_spell_phase = 1
		_phase_t = 0.0
		_spell_i = 0
		_spell_base = _casts
		player.caster.select(0)
		return
	var window := 0.4
	var index := int(_phase_t / window)
	if index >= player.caster.info.size():
		_release("cast")
		if _casts <= _spell_base:
			_fail("spell %d did not cast while flying" % _spell_i)
			return
		if not player.is_flying():
			_fail("spell %d cancelled flight" % _spell_i)
			return
		print("  spell %d cast ok" % _spell_i)
		print("FLIGHT TEST PASSED")
		print("  min_y=%.3f  casts=%d" % [_min_y, _casts])
		get_tree().quit(0)
		return
	if index != _spell_i:
		_release("cast")
		if _casts <= _spell_base:
			_fail("spell %d did not cast while flying" % _spell_i)
			return
		if not player.is_flying():
			_fail("spell %d cancelled flight" % _spell_i)
			return
		print("  spell %d cast ok" % _spell_i)
		_spell_i = index
		_spell_base = _casts
		player.caster.select(_spell_i)
		return
	if not Input.is_action_pressed("cast"):
		_press("cast")


func _goto(next: String, release := true) -> void:
	if release:
		_release_all()
	print("phase %s -> %s  y=%.2f vy=%.2f flying=%s floor=%s t=%.2f" % [_phase, next, player.global_position.y, player.velocity.y, player.is_flying(), player.is_on_floor(), _phase_t])
	_phase = next
	_phase_t = 0.0
	_hover_y = 0.0


func _press(action: String) -> void:
	if not Input.is_action_pressed(action):
		Input.action_press(action)


func _release(action: String) -> void:
	if Input.is_action_pressed(action):
		Input.action_release(action)


func _release_all() -> void:
	for action in ["jump", "descend", "fly_boost", "move_forward", "move_back", "move_left", "move_right", "cast", "sprint", "sprint_toggle"]:
		_release(action)


func _fail(msg: String) -> void:
	if _dead:
		return
	_dead = true
	print("FLIGHT TEST FAIL [%s] %s" % [_phase, msg])
	if player:
		print("  pos=%s vel=%s flying=%s floor=%s" % [player.global_position, player.velocity, player.is_flying(), player.is_on_floor()])
	get_tree().quit(1)


func _probe_ctrl() -> void:
	var ev := InputEventKey.new()
	ev.device = -1
	ev.physical_keycode = KEY_CTRL
	ev.keycode = KEY_CTRL
	ev.pressed = true
	Input.parse_input_event(ev)
	Input.flush_buffered_events()
	var action_down := Input.is_action_pressed("descend")
	var key_down := Input.is_key_pressed(KEY_CTRL)
	var up := ev.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	Input.flush_buffered_events()
	print("ctrl probe action=%s key=%s" % [action_down, key_down])
	if not action_down and not key_down:
		_fail("Ctrl did not register as descend")


func _has_key(action: String, keycode: Key) -> bool:
	for e in InputMap.action_get_events(action):
		if e is InputEventKey and (e.physical_keycode == keycode or e.keycode == keycode):
			return true
	return false


func _has_button(action: String, button: JoyButton) -> bool:
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadButton and e.button_index == button:
			return true
	return false


func _build_ground() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(400.0, 4.0, 400.0)
	col.shape = shape
	col.position = Vector3(0.0, -2.0, 0.0)
	body.add_child(col)
	add_child(body)


func _static_box(center: Vector3, size: Vector3, layer: int) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	body.position = center
	add_child(body)
	return body
