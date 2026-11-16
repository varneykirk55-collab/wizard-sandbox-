extends CharacterBody3D
## First-person wizard: WASD / left stick movement, mouse / right stick look,
## sprint, jump, aim ray and camera shake.
## Levitation lives in flight.gd; this script keeps ground movement, aiming and spells.
##
## VIEWMODEL (visual only — see scripts/player/viewmodel.gd)
## Before: this script built primitive hands and a spell-colored palm orb, and
## bobbed them in `_process`.
## After: a Viewmodel child draws the hands and staff. Movement, look, camera
## shake, aim, input, flight and `_physics_process` stay here. `_orb` is a
## Marker3D on the camera; the viewmodel moves it onto the casting hand so
## `caster.press(_orb.global_position, ...)` still launches from the hand.
## The viewmodel locks its overlay camera to `cam` and derives bob from
## `velocity` and `is_on_floor()`, so flight does not move the world camera.

const WALK := 6.5
const SPRINT := 12.0
const JUMP := 6.8
const GRAVITY := 19.0
const EYE := 1.65

const _FlightScript := preload("res://scripts/player/flight.gd")

var cam: Camera3D
var caster
var aim_point := Vector3.ZERO
var ground_point := Vector3.ZERO
var aim_normal := Vector3.UP

var _pitch := 0.0
var _trauma := 0.0
var _shake_t := 0.0
var _sprint_toggle := false
## Cast-origin anchor in camera space. The viewmodel writes this; do not bob it here.
var _orb: Node3D
var _marker: Decal
var _flight
var _hover_loop: AudioStreamPlayer3D


func _ready() -> void:
	_flight = _FlightScript.new()
	_flight.started.connect(_on_flight_started)
	_flight.ended.connect(_on_flight_ended)
	collision_layer = 4
	collision_mask = 3
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	col.shape = cap
	col.position = Vector3(0.0, 0.9, 0.0)
	add_child(col)

	cam = Camera3D.new()
	cam.position = Vector3(0.0, EYE, 0.0)
	cam.fov = 80.0
	cam.near = 0.05
	cam.far = 700.0
	add_child(cam)
	cam.current = true

	_build_viewmodel()

	_marker = Decal.new()
	_marker.texture_emission = FX.tex_ring
	_marker.texture_albedo = FX.tex_ring
	_marker.albedo_mix = 0.0
	_marker.emission_energy = 2.5
	_marker.size = Vector3(5.0, 8.0, 5.0)
	_marker.top_level = true
	_marker.visible = false
	add_child(_marker)

	caster = load("res://scripts/spells/spell_caster.gd").new()
	add_child(caster)
	caster.spell_changed.connect(_on_spell_changed)
	caster.cast.connect(_on_cast)
	_on_spell_changed(0)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Hands are built above and are not involved in flight.
	_hover_loop = AudioStreamPlayer3D.new()
	_hover_loop.bus = "SFX"
	_hover_loop.stream = AudioManager.streams["hover"]
	_hover_loop.volume_db = -26.0
	_hover_loop.unit_size = 14.0
	_hover_loop.max_db = 0.0
	add_child(_hover_loop)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * InputSetup.mouse_sens)
		_pitch = clampf(_pitch - event.relative.y * InputSetup.mouse_sens, -1.5, 1.5)
	for i in 5:
		if event.is_action_pressed("spell_%d" % (i + 1)):
			caster.select(i)
	if event.is_action_pressed("spell_next"):
		caster.select(caster.current + 1)
	if event.is_action_pressed("spell_prev"):
		caster.select(caster.current - 1)
	# L3 toggles ground sprint. In the air the same click is hold-to-fly-faster, not a latch.
	if event.is_action_pressed("sprint_toggle") and not _flight.active:
		_sprint_toggle = not _sprint_toggle


func _process(delta: float) -> void:
	# Right-stick look with a squared response curve.
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	var mag := look.length()
	if mag > 0.0:
		var curved := look * mag
		var inv := -1.0 if InputSetup.invert_y else 1.0
		rotate_y(-curved.x * InputSetup.pad_sens * delta)
		_pitch = clampf(_pitch - curved.y * InputSetup.pad_sens * 0.7 * inv * delta, -1.5, 1.5)

	# Camera shake.
	_trauma = maxf(0.0, _trauma - delta * 1.3)
	var s := minf(_trauma * _trauma, 1.6)
	_shake_t += delta * 38.0
	cam.rotation = Vector3(_pitch + sin(_shake_t * 1.3) * 0.035 * s, sin(_shake_t * 1.7 + 1.0) * 0.03 * s, sin(_shake_t * 2.3 + 2.0) * 0.04 * s)
	cam.position = Vector3(sin(_shake_t * 2.1) * 0.1 * s, EYE + sin(_shake_t * 2.9 + 0.5) * 0.1 * s, 0.0)

	# Hands, staff, walk bob and cast gestures live on the Viewmodel child.
	# It follows `cam` (including flight). This camera is not moved for the hands.
	# Ground target ring for the area spells.
	if _marker.visible:
		_marker.global_position = aim_point if caster.current == 1 or caster.current == 2 else ground_point
		_marker.rotation.y += delta * 1.5


func _physics_process(delta: float) -> void:
	var inp := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if inp.length() < 0.2:
		_sprint_toggle = false
	var dir := global_transform.basis * Vector3(inp.x, 0.0, inp.y)
	# Flight owns velocity while airborne-and-held. Otherwise this is the original walk / jump.
	if not _flight.physics_step(self, delta, dir, _flight_wish()):
		var speed := SPRINT if (Input.is_action_pressed("sprint") or _sprint_toggle) else WALK
		var accel := 60.0 if is_on_floor() else 18.0
		accel = _flight.soften_ground_accel(accel)
		velocity.x = move_toward(velocity.x, dir.x * speed, accel * delta)
		velocity.z = move_toward(velocity.z, dir.z * speed, accel * delta)
		if _flight.suppress_gravity:
			_flight.suppress_gravity = false
		elif not is_on_floor():
			velocity.y -= GRAVITY * delta
		if is_on_floor() and Input.is_action_just_pressed("jump"):
			velocity.y = JUMP
	move_and_slide()
	_flight.after_slide(self)
	if global_position.y < -30.0:
		_flight.force_ground(self)
		global_position = Vector3(0.0, 1.0, 31.0)
		velocity = Vector3.ZERO

	_update_aim()
	if Input.is_action_just_pressed("cast"):
		caster.press(_orb.global_position, aim_point, ground_point, aim_normal)
	elif Input.is_action_pressed("cast"):
		caster.hold(delta, aim_point, ground_point)
	if Input.is_action_just_released("cast"):
		caster.release()


func _update_aim() -> void:
	var from := cam.global_position
	var dirv := -cam.global_transform.basis.z
	var q := PhysicsRayQueryParameters3D.create(from, from + dirv * 400.0, 11)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		aim_point = from + dirv * 150.0
		aim_normal = -dirv
		if dirv.y < -0.02:
			var t := minf(from.y / -dirv.y, 250.0)
			ground_point = from + dirv * t
		else:
			ground_point = from + dirv * 120.0
		ground_point.y = 0.0
	else:
		aim_point = hit["position"]
		aim_normal = hit["normal"]
		ground_point = Vector3(aim_point.x, 0.0, aim_point.z)


func add_trauma(v: float) -> void:
	_trauma = minf(1.6, _trauma + v)


func hold_trauma(v: float) -> void:
	_trauma = maxf(_trauma, minf(v, 1.0))


func _on_spell_changed(i: int) -> void:
	var c: Color = caster.info[i]["color"]
	_marker.modulate = c
	_marker.visible = i != 0
	var sizes := [5.0, 5.0, 8.0, 7.0, 16.0]
	var sz: float = sizes[i]
	_marker.size = Vector3(sz, 8.0, sz)


func _on_cast(_i: int) -> void:
	AudioManager.play_ui("cast", -9.0, 0.9 + 0.1 * caster.current)
	InputSetup.rumble(0.25, 0.1, 0.08)


func is_flying() -> bool:
	return _flight != null and _flight.active


func _flight_wish() -> Dictionary:
	return {
		"jump_down": Input.is_action_pressed("jump"),
		# B is still ground sprint. In the air the same button is descend.
		# Ctrl is read directly because modifier keys are unreliable as an action alone.
		"descend": Input.is_action_pressed("descend") or Input.is_key_pressed(KEY_CTRL),
		"boost": Input.is_action_pressed("fly_boost"),
	}


func _on_flight_started() -> void:
	AudioManager.play_at("lift", global_position, -16.0, 1.02, 12.0)
	if _hover_loop != null and not _hover_loop.playing:
		_hover_loop.play()


func _on_flight_ended() -> void:
	if _hover_loop != null:
		_hover_loop.stop()


func _build_viewmodel() -> void:
	_orb = Marker3D.new()
	_orb.name = "CastOrigin"
	_orb.position = Vector3(0.22, -0.22, -0.62)
	cam.add_child(_orb)
	var vm = load("res://scripts/player/viewmodel.gd").new()
	vm.name = "Viewmodel"
	add_child(vm)
	vm.bind(self)
