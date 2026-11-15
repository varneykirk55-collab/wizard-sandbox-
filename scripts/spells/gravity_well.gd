extends Node3D
## SPELL 3 - GRAVITY WELL: a singularity that strips buildings apart piece by
## piece, swallows the debris, collapses to a brilliant point and detonates.

const DURATION := 7.0
const RADIUS := 17.0
const COLLAPSE_TIME := 0.5

var _t := 0.0
var _state := 0          # 0 pulling, 1 collapsed point, 2 done
var _state_t := 0.0
var _tick := false
var _phase := 0.0
var _implode_played := false
var _visual: Node3D
var _lens_mat: ShaderMaterial
var _disc_mats: Array = []
var _rim_mat: ShaderMaterial
var _light: OmniLight3D
var _swirl: GPUParticles3D
var _loop: AudioStreamPlayer3D
var _point: MeshInstance3D


func start(pos: Vector3) -> void:
	global_position = pos
	_visual = Node3D.new()
	add_child(_visual)

	var black := StandardMaterial3D.new()
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	black.albedo_color = Color(0, 0, 0)
	var core: MeshInstance3D = FX.mesh_node(FX.sphere, black)
	core.scale = Vector3.ONE * 0.55
	_visual.add_child(core)

	_rim_mat = FX.shader_mat("glow_shell", {"color": Color(0.7, 0.35, 1.0), "energy": 6.0, "power": 2.5, "center": 0.0})
	var rim: MeshInstance3D = FX.mesh_node(FX.sphere, _rim_mat)
	rim.scale = Vector3.ONE * 0.62
	_visual.add_child(rim)

	_lens_mat = FX.shader_mat("lens", {"strength": 0.14})
	var lens: MeshInstance3D = FX.mesh_node(FX.sphere, _lens_mat)
	lens.scale = Vector3.ONE * 2.3
	_visual.add_child(lens)

	var tilts := [Vector3(0.3, 0.0, 0.15), Vector3(-0.45, 1.0, -0.3)]
	for i in 2:
		var dm: ShaderMaterial = FX.shader_mat("vortex_disc", {"energy": 3.0})
		var disc: MeshInstance3D = FX.mesh_node(FX.plane, dm)
		disc.scale = Vector3.ONE * (2.8 - i * 0.6)
		disc.rotation = tilts[i]
		_visual.add_child(disc)
		_disc_mats.append(dm)

	_light = FX.light(Color(0.65, 0.35, 1.0), 6.0, 24.0)
	add_child(_light)

	_swirl = FX.particles({"mat": "magic", "amount": 70, "life": 1.1, "shape": "ring", "radius": 9.0, "ring_inner": 0.6, "ring_h": 3.0, "vel": Vector2(0.0, 0.5), "grav": Vector3(0.0, -0.5, 0.0), "radial": Vector2(-22.0, -14.0), "tang": Vector2(8.0, 14.0), "scale": Vector2(0.3, 0.9), "curve": [[0.0, 0.2], [0.3, 1.0], [1.0, 0.0]], "colors": [Color(0.5, 0.2, 1.0, 0.0), Color(0.7, 0.45, 1.0, 1.0), Color(1.0, 1.0, 1.0, 1.0)], "aabb": 40.0})
	add_child(_swirl)

	_loop = AudioManager.make_loop("vortex_loop", self, 2.0, 22.0)
	AudioManager.play_at("cast", pos, 0.0, 0.6, 20.0)
	_visual.scale = Vector3.ONE * 0.2
	create_tween().tween_property(_visual, "scale", Vector3.ONE * 3.2, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if _state != 0:
		return
	var k := clampf(_t / DURATION, 0.0, 1.0)
	# Rotation and energy intensify as it shrinks.
	_phase += delta * lerpf(2.5, 16.0, k * k)
	_lens_mat.set_shader_parameter("phase", _phase)
	_lens_mat.set_shader_parameter("strength", lerpf(0.14, 0.22, k))
	for i in _disc_mats.size():
		var dm: ShaderMaterial = _disc_mats[i]
		dm.set_shader_parameter("phase", _phase * (1.0 + i * 0.4))
		dm.set_shader_parameter("energy", lerpf(3.0, 11.0, k))
	_rim_mat.set_shader_parameter("energy", lerpf(6.0, 20.0, k))
	_light.light_energy = lerpf(6.0, 16.0, k) * (0.9 + 0.1 * sin(_phase * 3.0))
	if _t > 0.4:
		_visual.scale = Vector3.ONE * lerpf(3.2, 0.35, k * k)
	_loop.pitch_scale = lerpf(0.8, 2.6, k * k)


func _physics_process(delta: float) -> void:
	_t += delta
	if _state == 0:
		var k := clampf(_t / DURATION, 0.0, 1.0)
		_tick = not _tick
		if _tick:
			DM.attract(global_position, RADIUS, lerpf(38.0, 85.0, k), lerpf(10.0, 28.0, k), 0.0, lerpf(45.0, 170.0, k), delta * 2.0, lerpf(2.2, 1.2, k))
		if not _implode_played and _t >= DURATION - 0.95:
			_implode_played = true
			AudioManager.play_at("implode", global_position, 4.0, 1.0, 30.0)
		if k >= 1.0:
			_collapse()
	elif _state == 1:
		_state_t += delta
		DM.touch_area(global_position, RADIUS)
		if _state_t >= COLLAPSE_TIME:
			_detonate()


## Everything is gone: a tiny brilliant point and a beat of near-silence.
func _collapse() -> void:
	_state = 1
	_swirl.emitting = false
	_loop.stop()
	_visual.visible = false
	DM.attract(global_position, 5.0, 120.0, 0.0, 0.0, 0.0, 0.03, 5.0)
	_point = FX.mesh_node(FX.sphere, FX.shader_mat("glow_shell", {"color": Color(1.0, 0.95, 1.0), "energy": 40.0, "power": 1.0, "center": 1.0}))
	_point.scale = Vector3.ONE * 0.5
	add_child(_point)
	var tw := _point.create_tween()
	tw.tween_property(_point, "scale", Vector3.ONE * 0.12, COLLAPSE_TIME).set_ease(Tween.EASE_OUT)
	_light.light_energy = 30.0
	_light.light_color = Color(1.0, 0.95, 1.0)
	_light.omni_range = 40.0
	AudioManager.duck_sfx(-30.0, COLLAPSE_TIME + 0.1)


func _detonate() -> void:
	_state = 2
	var pos := global_position
	_point.visible = false
	_light.visible = false
	FX.explosion(pos, 1.5, 1)
	DM.explode(pos, 21.0, 520.0, 34.0, 0.3, true)
	AudioManager.play_at("explosion", pos, 6.0, 0.7, 55.0)
	AudioManager.play_at("rumble", pos, 3.0, 0.9, 50.0)
	FX.after(0.35, AudioManager.play_at.bind("debris", pos, 0.0, 0.9, 30.0))
	get_tree().create_timer(1.0, false).timeout.connect(queue_free)
