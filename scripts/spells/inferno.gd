extends Node3D
## SPELL 4 - INFERNO: a fire tornado that grows for as long as the cast is held,
## drags debris into its column and tears nearby buildings apart.

const GROW_TIME := 11.0
const LINGER := 3.5
const FADE_TIME := 2.5

var growth := 0.0
var _held := true
var _linger := LINGER
var _fade := 1.0
var _target := Vector3.ZERO
var _phase := 0.0
var _tick := false
var _fire_t := 0.0
var _scorch_t := 0.0
var _layers: Array = []
var _mats: Array = []
var _heat: MeshInstance3D
var _heat_mat: ShaderMaterial
var _flames: GPUParticles3D
var _embers: GPUParticles3D
var _smoke: GPUParticles3D
var _light: OmniLight3D
var _loop: AudioStreamPlayer3D
var _radius := 1.1
var _height := 5.0


func start(pos: Vector3) -> void:
	global_position = Vector3(pos.x, 0.0, pos.z)
	_target = global_position
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.height = 1.0
	cyl.radial_segments = 40
	cyl.rings = 18
	cyl.cap_top = false
	cyl.cap_bottom = false
	for i in 3:
		var m: ShaderMaterial = FX.shader_mat("tornado", {"seed": randf() * 20.0, "twist": 2.5 + i * 1.5, "flare": 1.5 + i * 0.25})
		var mi: MeshInstance3D = FX.mesh_node(cyl, m)
		mi.custom_aabb = AABB(Vector3(-3.0, -0.6, -3.0), Vector3(6.0, 1.2, 6.0))
		add_child(mi)
		_layers.append(mi)
		_mats.append(m)
	_heat_mat = FX.shader_mat("heat", {"strength": 0.012})
	_heat = FX.mesh_node(FX.sphere, _heat_mat)
	add_child(_heat)

	var fire_cols := [Color(1.0, 0.95, 0.6, 0.0), Color(1.0, 0.75, 0.3, 1.0), Color(1.0, 0.35, 0.05, 0.8), Color(0.4, 0.03, 0.0, 0.0)]
	_flames = FX.particles({"mat": "fire", "amount": 110, "life": 1.4, "shape": "ring", "radius": 1.0, "ring_inner": 0.3, "ring_h": 0.4, "spread": 20.0, "vel": Vector2(3.0, 6.0), "grav": Vector3(0.0, 3.0, 0.0), "tang": Vector2(5.0, 9.0), "radial": Vector2(-2.5, -1.0), "scale": Vector2(0.9, 1.8), "curve": [[0.0, 0.3], [0.3, 1.0], [1.0, 0.3]], "colors": fire_cols, "offsets": [0.0, 0.12, 0.55, 1.0], "aabb": 80.0})
	add_child(_flames)
	_embers = FX.particles({"mat": "spark", "amount": 70, "life": 2.6, "radius": 1.2, "spread": 60.0, "vel": Vector2(3.0, 8.0), "grav": Vector3(0.0, 2.0, 0.0), "tang": Vector2(3.0, 6.0), "scale": Vector2(0.08, 0.2), "colors": [Color(1.0, 0.8, 0.4, 1.0), Color(1.0, 0.3, 0.05, 1.0), Color(0.5, 0.0, 0.0, 0.0)], "aabb": 90.0})
	add_child(_embers)
	_smoke = FX.particles({"mat": "smoke", "amount": 40, "life": 3.5, "radius": 1.0, "spread": 40.0, "vel": Vector2(2.0, 5.0), "grav": Vector3(0.0, 1.0, 0.0), "scale": Vector2(2.5, 5.0), "spin": 30.0, "curve": [[0.0, 0.3], [1.0, 1.0]], "colors": [Color(0.6, 0.3, 0.1, 0.0), Color(0.2, 0.15, 0.13, 0.55), Color(0.1, 0.1, 0.1, 0.0)], "offsets": [0.0, 0.2, 1.0], "aabb": 90.0})
	add_child(_smoke)

	_light = FX.light(Color(1.0, 0.5, 0.15), 5.0, 16.0)
	add_child(_light)
	_loop = AudioManager.make_loop("tornado_loop", self, -6.0, 22.0)
	AudioManager.play_at("cast", global_position, 0.0, 0.8, 20.0)
	_apply_visuals()


## Called every frame while the cast is held; the tornado drifts toward the aim point.
func sustain(target: Vector3) -> void:
	_target = Vector3(target.x, 0.0, target.z)


func release() -> void:
	_held = false


func _physics_process(delta: float) -> void:
	_phase += delta * (1.5 + 3.0 * growth)
	if _held:
		growth = minf(1.0, growth + delta / GROW_TIME)
		var to := _target - global_position
		to.y = 0.0
		var dist := to.length()
		if dist > 0.4:
			global_position += to / dist * minf(dist, (3.0 + growth * 3.5) * delta)
	else:
		# Released: wander, linger briefly, then burn out.
		global_position += Vector3(cos(_phase * 0.3), 0.0, sin(_phase * 0.37)) * delta * 1.5
		_linger -= delta
		if _linger <= 0.0:
			if _fade >= 1.0:
				_flames.emitting = false
				_embers.emitting = false
			_fade -= delta / FADE_TIME
			if _fade <= 0.35:
				_smoke.emitting = false
			if _fade <= 0.0:
				queue_free()
				return

	var g := growth * growth * 0.4 + growth * 0.6
	_radius = lerpf(1.1, 6.5, g) * lerpf(0.35, 1.0, _fade)
	_height = lerpf(5.0, 30.0, g) * lerpf(0.6, 1.0, _fade)
	_apply_visuals()

	_tick = not _tick
	if _tick:
		DM.attract(global_position + Vector3.UP, _radius * 2.6 + 3.0, 8.0, 9.0 + 16.0 * g, 6.0 + 10.0 * g, (30.0 + 170.0 * g) * _fade, delta * 2.0, 0.0, _radius * 0.9, _height)

	# Fire and scorched earth left along its path.
	_fire_t -= delta
	if _fire_t <= 0.0 and _fade >= 1.0:
		_fire_t = 0.7
		var off := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * _radius
		FX.emit("linger_fire", global_position + off + Vector3.UP * 0.3, 0.6 + g)
	_scorch_t -= delta
	if _scorch_t <= 0.0 and _fade >= 1.0:
		_scorch_t = 1.6
		FX.scorch(global_position, _radius * 1.3 + 1.0)
	if g > 0.5:
		FX.shake_hold(global_position, 0.3 * g * _fade, 45.0)


func _apply_visuals() -> void:
	var g := growth * growth * 0.4 + growth * 0.6
	var mults := [0.6, 1.0, 1.35]
	for i in _layers.size():
		var mi: MeshInstance3D = _layers[i]
		var mult: float = mults[i]
		mi.scale = Vector3(_radius * mult, _height, _radius * mult)
		mi.position = Vector3(0.0, _height * 0.5, 0.0)
		var m: ShaderMaterial = _mats[i]
		m.set_shader_parameter("phase", _phase * (1.0 + i * 0.3))
		m.set_shader_parameter("intensity", (0.55 + 0.45 * g) * _fade)
	_heat.scale = Vector3(_radius * 2.4, _height * 0.6, _radius * 2.4)
	_heat.position = Vector3(0.0, _height * 0.5, 0.0)
	_heat_mat.set_shader_parameter("phase", _phase)
	_heat_mat.set_shader_parameter("strength", (0.008 + 0.012 * g) * _fade)
	_flames.scale = Vector3.ONE * _radius
	_embers.scale = Vector3.ONE * _radius
	_smoke.scale = Vector3.ONE * _radius * 0.8
	_smoke.position = Vector3(0.0, _height * 0.8, 0.0)
	_light.position = Vector3(0.0, _height * 0.35, 0.0)
	_light.light_energy = (5.0 + 11.0 * g) * _fade * (0.85 + 0.15 * sin(_phase * 7.0))
	_light.omni_range = 16.0 + 40.0 * g
	_loop.volume_db = lerpf(-8.0, 5.0, g) + linear_to_db(maxf(_fade, 0.05))
	_loop.pitch_scale = 0.7 + 0.5 * g
	_loop.unit_size = 20.0 + 25.0 * g
