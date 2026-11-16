extends Node3D
## SPELL 7 - OBLIVION.
## A dark projectile becomes a sphere of nothingness that expands, erases every
## section and loose fragment its boundary touches, then contracts to a point
## and releases a dark-energy shockwave.
##
## It does not pull anything (that is Gravity Well). Sections stay where they
## are and dissolve as the boundary reaches them. Erased sections go through
## piece.break_loose() first, so the structure counts them as destroyed, the
## support graph reacts, and the normal 180 s restore rebuilds them.

const SPEED := 55.0
const FORM_TIME := 0.9
const EXPAND_TIME := 4.5
const HOLD_TIME := 0.4
const COLLAPSE_TIME := 1.1
const POINT_TIME := 0.45
const START_RADIUS := 1.6
const MAX_RADIUS := 15.0
const ERASE_BUDGET := 5        # sections dissolved per tick (30 ticks a second)
const BLAST_RADIUS := 30.0

var dark

var _state := 0                # 0 projectile, 1 forming, 2 expanding, 3 full, 4 collapsing, 5 point, 6 done
var _t := 0.0
var _life := 0.0
var _radius := 0.3
var _velocity := Vector3.ZERO
var _tick := false
var _phase := 0.0
var _ash_i := 0
var _dis_t := 0.0
var _visual: Node3D
var _shell_mat: ShaderMaterial
var _rim_mat: ShaderMaterial
var _lens: MeshInstance3D
var _motes: GPUParticles3D
var _light: OmniLight3D
var _loop: AudioStreamPlayer3D
var _point: MeshInstance3D


func launch(from: Vector3, target: Vector3) -> void:
	global_position = from
	var dir := target - from
	if dir.length() < 0.1:
		dir = Vector3.FORWARD
	_velocity = dir.normalized() * SPEED

	_visual = Node3D.new()
	add_child(_visual)
	var core: MeshInstance3D = FX.mesh_node(FX.sphere, dark.black_mat)
	core.scale = Vector3.ONE * 0.985
	_visual.add_child(core)
	_shell_mat = ShaderMaterial.new()
	_shell_mat.shader = dark.void_shader
	_shell_mat.set_shader_parameter("energy", 2.5)
	_shell_mat.render_priority = 1
	_visual.add_child(FX.mesh_node(FX.sphere, _shell_mat))
	_rim_mat = FX.shader_mat("glow_shell", {"color": dark.VIOLET, "energy": 5.0, "power": 3.0, "center": 0.0})
	_rim_mat.render_priority = 1
	var rim: MeshInstance3D = FX.mesh_node(FX.sphere, _rim_mat)
	rim.scale = Vector3.ONE * 1.03
	_visual.add_child(rim)
	_visual.scale = Vector3.ONE * _radius

	_motes = FX.particles({"mat": "magic", "amount": 60, "life": 1.0, "radius": 1.3, "vel": Vector2(0.0, 0.6), "radial": Vector2(-7.0, -3.0), "scale": Vector2(0.12, 0.4), "curve": [[0.0, 0.2], [0.3, 1.0], [1.0, 0.0]], "colors": [Color(0.4, 0.15, 1.0, 0.0), Color(0.6, 0.3, 1.0, 1.0), Color(0.9, 0.75, 1.0, 0.0)], "aabb": 250.0})
	add_child(_motes)
	_motes.scale = Vector3.ONE * _radius
	_light = FX.light(Color(0.55, 0.28, 1.0), 3.0, 10.0)
	add_child(_light)
	AudioManager.play_at("cast", from, 0.0, 0.55, 16.0)


func _process(delta: float) -> void:
	if _state >= 5:
		return
	# Energy on the boundary moves faster as the void grows and, above all, as it collapses.
	var speed := 2.0
	if _state == 2 or _state == 3:
		speed = 3.5
	elif _state == 4:
		speed = lerpf(4.0, 22.0, clampf(_t / COLLAPSE_TIME, 0.0, 1.0))
	_phase += delta * speed
	_shell_mat.set_shader_parameter("phase", _phase)
	_visual.scale = Vector3.ONE * _radius
	_motes.scale = Vector3.ONE * _radius
	_light.omni_range = _radius * 2.0 + 12.0
	if _lens != null:
		_lens.scale = Vector3.ONE * _radius * 1.22


func _physics_process(delta: float) -> void:
	_t += delta
	match _state:
		0:
			_fly(delta)
		1:
			var k := clampf(_t / FORM_TIME, 0.0, 1.0)
			_radius = lerpf(0.3, START_RADIUS, 1.0 - (1.0 - k) * (1.0 - k))
			if k >= 1.0:
				_state = 2
				_t = 0.0
		2:
			var k2 := clampf(_t / EXPAND_TIME, 0.0, 1.0)
			_radius = lerpf(START_RADIUS, MAX_RADIUS, smoothstep(0.0, 1.0, k2))
			_loop.pitch_scale = lerpf(0.6, 1.0, k2)
			_loop.volume_db = lerpf(-6.0, 4.0, k2)
			_loop.unit_size = lerpf(18.0, 40.0, k2)
			_erase_tick(delta)
			FX.shake_hold(global_position, 0.22 * k2, MAX_RADIUS * 3.0)
			if k2 >= 1.0:
				_state = 3
				_t = 0.0
		3:
			_erase_tick(delta)
			if _t >= HOLD_TIME:
				_state = 4
				_t = 0.0
				AudioManager.play_at("implode", global_position, 5.0, 0.85, 45.0)
		4:
			var k4 := clampf(_t / COLLAPSE_TIME, 0.0, 1.0)
			_radius = lerpf(MAX_RADIUS, 0.25, pow(k4, 2.5))
			_shell_mat.set_shader_parameter("energy", lerpf(2.5, 14.0, k4))
			_rim_mat.set_shader_parameter("energy", lerpf(5.0, 24.0, k4))
			_light.light_energy = lerpf(4.0, 18.0, k4)
			_loop.pitch_scale = lerpf(1.0, 2.6, k4 * k4)
			DM.touch_area(global_position, MAX_RADIUS)
			FX.shake_hold(global_position, 0.3 + 0.3 * k4, MAX_RADIUS * 3.0)
			if k4 >= 1.0:
				_to_point()
		5:
			DM.touch_area(global_position, MAX_RADIUS)
			if _t >= POINT_TIME:
				_detonate()


func _fly(delta: float) -> void:
	_life += delta
	var from := global_position
	var to := from + _velocity * delta
	var q := PhysicsRayQueryParameters3D.create(from, to, 11)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		var hp: Vector3 = hit["position"]
		_form(hp)
	elif _life > 4.0 or to.y < -0.5:
		_form(to)
	else:
		global_position = to


## Phase 1: the projectile becomes a small sphere of nothing.
func _form(pos: Vector3) -> void:
	_state = 1
	_t = 0.0
	global_position = Vector3(pos.x, maxf(pos.y, 0.6), pos.z)
	_lens = FX.mesh_node(FX.sphere, FX.shader_mat("lens", {"strength": 0.07}))
	add_child(_lens)
	_lens.scale = Vector3.ONE * _radius * 1.22
	_light.light_energy = 4.0
	_loop = AudioManager.make_loop("void_hum", self, -6.0, 18.0)
	_loop.pitch_scale = 0.6
	AudioManager.play_at("void_form", global_position, 4.0, 1.0, 35.0)
	FX.emit("void_ash", global_position, 2.0)
	FX.flash_light(global_position, Color(0.55, 0.28, 1.0), 12.0, 18.0, 0.5)


## Phases 2-3: whatever the boundary has reached dissolves, a few sections per tick.
func _erase_tick(delta: float) -> void:
	_dis_t -= delta
	_tick = not _tick
	if not _tick:
		return
	var c := global_position
	var r := _radius
	var budget := ERASE_BUDGET
	for st in DM.structures:
		var sc: Vector3 = st.center
		if c.distance_to(sc) > r + st.radius:
			continue
		st.touch()
		if budget <= 0 or st.loose_count >= st.total:
			continue
		for p in st.pieces:
			if budget <= 0:
				break
			if not is_instance_valid(p) or p.is_loose or p.is_consumed:
				continue
			var pp: Vector3 = p.global_position
			if c.distance_to(pp) < r + 0.3:
				_erase(p)
				budget -= 1
	for i in range(DM.debris.size() - 1, -1, -1):
		if budget <= 0:
			break
		var q = DM.debris[i]
		if not is_instance_valid(q) or q.is_consumed:
			continue
		var qp: Vector3 = q.global_position
		if c.distance_to(qp) < r:
			_erase(q)
			budget -= 1


## One section breaks into a glowing fragment and fades into the void.
func _erase(p) -> void:
	if not p.is_loose:
		p.break_loose()          # registers the loss with its structure and support graph
	p.is_consumed = true
	DM.unregister_debris(p)
	p.collision_layer = 0
	p.collision_mask = 0
	p.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	p.freeze = true
	var pp: Vector3 = p.global_position
	var mesh: MeshInstance3D = p.mesh_instance
	mesh.material_override = dark.dissolve_mat
	var tw: Tween = p.create_tween().set_parallel(true)
	tw.tween_property(mesh, "scale", Vector3.ONE * 0.02, 0.5).set_ease(Tween.EASE_IN)
	tw.tween_property(p, "global_position", pp.lerp(global_position, 0.2) + Vector3.UP * 0.5, 0.5)
	tw.chain().tween_callback(p.queue_free)
	_ash_i += 1
	if _ash_i % 2 == 0:
		FX.emit("void_ash", pp, 1.0)
	if _dis_t <= 0.0:
		_dis_t = 0.12
		AudioManager.play_at("void_dis", pp, -6.0, randf_range(0.7, 1.3), 22.0)


## Phase 4 end: nothing left but a brilliant point and a beat of near-silence.
func _to_point() -> void:
	_state = 5
	_t = 0.0
	_visual.visible = false
	_lens.visible = false
	_motes.emitting = false
	_loop.stop()
	_point = FX.mesh_node(FX.sphere, FX.shader_mat("glow_shell", {"color": Color(0.95, 0.88, 1.0), "energy": 45.0, "power": 1.0, "center": 1.0}))
	_point.scale = Vector3.ONE * 0.45
	add_child(_point)
	_point.create_tween().tween_property(_point, "scale", Vector3.ONE * 0.1, POINT_TIME).set_ease(Tween.EASE_OUT)
	_light.light_color = Color(0.9, 0.8, 1.0)
	_light.light_energy = 30.0
	_light.omni_range = 45.0
	AudioManager.duck_sfx(-30.0, POINT_TIME + 0.1)


## Phase 5: the dark-energy shockwave.
func _detonate() -> void:
	_state = 6
	var pos := global_position
	var violet := Color(0.6, 0.32, 1.0)
	_point.visible = false
	_light.visible = false

	dark.black_flash(pos, 9.0, 0.5)
	dark.fireball(pos, 13.0, 1.1, Color(0.95, 0.85, 1.0), Color(0.45, 0.15, 0.9), Color(0.02, 0.0, 0.06))
	FX.shock_sphere(pos, 75.0, 0.9, violet)
	dark.ring(pos, 62.0, 0.9, violet, Vector3.ZERO)
	dark.ring(pos, 48.0, 1.1, Color(0.85, 0.5, 1.0), Vector3(randf_range(0.5, 1.1), randf() * TAU, 0.0))
	if pos.y < 12.0:
		FX.ground_ring(pos, 65.0, 1.1, violet)
		dark.scar(pos, 12.0, Color(0.5, 0.2, 1.0), 8.0)
	FX.flash_light(pos, violet, 70.0, 90.0, 1.0)
	FX.emit("void_burst", pos, 1.6)
	FX.emit("void_after", pos, 1.0)
	FX.emit("dust_ring", Vector3(pos.x, 0.6, pos.z), 1.8)

	DM.explode(pos, BLAST_RADIUS, 380.0, 36.0, 0.35, true)

	AudioManager.play_at("impact_big", pos, 8.0, 0.75, 90.0)
	AudioManager.play_at("explosion", pos, 5.0, 0.55, 70.0)
	FX.after(0.25, AudioManager.play_at.bind("rumble", pos, 5.0, 0.7, 70.0))
	FX.after(0.6, AudioManager.play_at.bind("debris", pos, 0.0, 0.8, 40.0))
	FX.shake(pos, 1.3, 150.0)
	FX.screen_flash(pos, 0.35, 120.0)
	get_tree().create_timer(1.5, false).timeout.connect(queue_free)
