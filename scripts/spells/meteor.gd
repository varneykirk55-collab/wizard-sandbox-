extends Node3D
## SPELL 5 - METEOR: a huge burning rock falls from the sky with a long,
## visible approach, then a catastrophic impact with ejecta and fragments.

const FALL_TIME := 3.3
const BLAST_RADIUS := 24.0

var _target := Vector3.ZERO
var _start := Vector3.ZERO
var _t := 0.0
var _hit := false
var _body: Node3D
var _rock: MeshInstance3D
var _trail_fire: GPUParticles3D
var _trail_smoke: GPUParticles3D
var _light: OmniLight3D
var _ground_light: OmniLight3D
var _frags: Array = []


func start(target: Vector3) -> void:
	_target = Vector3(target.x, 0.0, target.z)
	var az := randf() * TAU
	_start = _target + Vector3(cos(az) * 150.0, 240.0, sin(az) * 150.0)
	look_at_from_position(_start, _target, Vector3.UP)

	_body = Node3D.new()
	add_child(_body)
	_rock = FX.mesh_node(FX.sphere, FX.shader_mat("rock", {"seed": randf() * 20.0}))
	_rock.scale = Vector3.ONE * 3.2
	_body.add_child(_rock)
	var shell: MeshInstance3D = FX.mesh_node(FX.sphere, FX.shader_mat("fireball", {"progress": 0.1, "energy": 8.0, "seed": randf() * 30.0}))
	shell.scale = Vector3(4.6, 4.6, 8.5)
	shell.position = Vector3(0.0, 0.0, 2.5)
	_body.add_child(shell)
	var halo: MeshInstance3D = FX.mesh_node(FX.sphere, FX.shader_mat("glow_shell", {"color": Color(1.0, 0.55, 0.15), "energy": 4.0, "power": 2.0, "center": 1.0}))
	halo.scale = Vector3.ONE * 8.0
	_body.add_child(halo)
	_light = FX.light(Color(1.0, 0.6, 0.25), 30.0, 110.0)
	_body.add_child(_light)

	_trail_fire = FX.particles({"mat": "fire", "amount": 130, "life": 0.9, "radius": 2.5, "vel": Vector2(0.0, 4.0), "scale": Vector2(5.0, 9.0), "curve": [[0.0, 1.0], [1.0, 0.15]], "colors": [Color(1.0, 0.95, 0.7, 1.0), Color(1.0, 0.45, 0.08, 0.9), Color(0.4, 0.04, 0.0, 0.0)], "aabb": 600.0})
	add_child(_trail_fire)
	_trail_smoke = FX.particles({"mat": "smoke", "amount": 110, "life": 3.2, "radius": 2.5, "vel": Vector2(0.0, 3.0), "scale": Vector2(6.0, 12.0), "spin": 30.0, "curve": [[0.0, 0.5], [1.0, 1.0]], "colors": [Color(1.0, 0.5, 0.2, 0.6), Color(0.25, 0.18, 0.15, 0.6), Color(0.1, 0.1, 0.1, 0.0)], "offsets": [0.0, 0.2, 1.0], "aabb": 600.0})
	add_child(_trail_smoke)

	# Light that grows on the ground where it is going to land.
	_ground_light = FX.light(Color(1.0, 0.5, 0.2), 0.0, 40.0)
	_ground_light.top_level = true
	add_child(_ground_light)
	_ground_light.global_position = _target + Vector3.UP * 3.0

	# Smaller fragments that break off and land around the main impact.
	for i in 5:
		var f := Node3D.new()
		f.top_level = true
		add_child(f)
		var fm: MeshInstance3D = FX.mesh_node(FX.sphere, FX.shader_mat("fireball", {"progress": 0.1, "energy": 8.0, "seed": randf() * 30.0}))
		fm.scale = Vector3.ONE * randf_range(0.9, 1.5)
		f.add_child(fm)
		var ft: GPUParticles3D = FX.particles({"mat": "fire", "amount": 30, "life": 0.6, "radius": 0.6, "vel": Vector2(0.0, 2.0), "scale": Vector2(1.5, 3.0), "curve": [[0.0, 1.0], [1.0, 0.1]], "colors": [Color(1.0, 0.9, 0.6, 1.0), Color(1.0, 0.4, 0.05, 0.0)], "aabb": 600.0})
		f.add_child(ft)
		var ang := randf() * TAU
		var rad := randf_range(8.0, 17.0)
		var fend := _target + Vector3(cos(ang) * rad, 0.0, sin(ang) * rad)
		var fstart := _start + Vector3(randf_range(-30.0, 30.0), randf_range(-10.0, 25.0), randf_range(-30.0, 30.0))
		f.global_position = fstart
		_frags.append({"node": f, "trail": ft, "mesh": fm, "start": fstart, "end": fend, "delay": randf_range(0.15, 0.7), "done": false})

	AudioManager.play_at("whistle", _target + Vector3.UP * 20.0, 4.0, 1.0, 70.0)


func _physics_process(delta: float) -> void:
	_t += delta
	DM.touch_area(_target, BLAST_RADIUS + 4.0)
	if not _hit:
		var k := _t / FALL_TIME
		if k >= 1.0:
			_impact()
		else:
			global_position = _start.lerp(_target, k)
			_rock.rotate_x(delta * 1.3)
			_rock.rotate_y(delta * 0.7)
			_ground_light.light_energy = k * k * 22.0
			if k > 0.7:
				FX.shake_hold(_target, 0.45 * (k - 0.7) / 0.3, 80.0)
	var all_done := _hit
	for fr in _frags:
		if fr["done"]:
			continue
		all_done = false
		var d: float = fr["delay"]
		var fk := (_t - d) / FALL_TIME
		var node: Node3D = fr["node"]
		var fs: Vector3 = fr["start"]
		var fe: Vector3 = fr["end"]
		if fk >= 1.0:
			fr["done"] = true
			var fmesh: MeshInstance3D = fr["mesh"]
			var ftrail: GPUParticles3D = fr["trail"]
			fmesh.visible = false
			ftrail.emitting = false
			FX.explosion(fe, 0.4, 0)
			DM.explode(fe, 6.0, 260.0, 16.0, 0.5, true)
			AudioManager.play_at("small_boom", fe, 2.0, 1.0, 30.0)
		else:
			node.global_position = fs.lerp(fe, maxf(fk, 0.0))
	if all_done and _t > FALL_TIME + 4.0:
		queue_free()


func _impact() -> void:
	_hit = true
	global_position = _target
	_body.visible = false
	_ground_light.visible = false
	_trail_fire.emitting = false
	_trail_smoke.emitting = false

	FX.explosion(_target, 2.3, 0)
	FX.emit("dust_wall", _target + Vector3.UP * 1.0, 2.0)
	FX.scorch(_target, 16.0)
	DM.explode(_target, BLAST_RADIUS, 900.0, 38.0, 0.55, true)

	# Physical ejecta thrown out of the crater.
	for i in 14:
		var ang := randf() * TAU
		var out := Vector3(cos(ang), 0.0, sin(ang))
		var dim := Vector3(randf_range(0.5, 1.4), randf_range(0.4, 1.0), randf_range(0.5, 1.4))
		var xf := Transform3D(Basis(Vector3.UP, randf() * TAU), _target + out * randf_range(1.0, 4.0) + Vector3.UP * 1.0)
		var vel := out * randf_range(8.0, 24.0) + Vector3.UP * randf_range(12.0, 30.0)
		DM.spawn_debris(dim, "rock", xf, 1.4, vel)

	AudioManager.play_at("impact_big", _target, 9.0, 1.0, 90.0)
	AudioManager.play_at("explosion", _target, 5.0, 0.6, 70.0)
	FX.after(0.25, AudioManager.play_at.bind("rumble", _target, 5.0, 0.8, 70.0))
	FX.after(0.5, AudioManager.play_at.bind("debris", _target, 2.0, 0.8, 40.0))
	FX.after(1.2, AudioManager.play_at.bind("debris", _target, 0.0, 1.0, 40.0))
	FX.shake(_target, 1.5, 170.0)
	FX.screen_flash(_target, 0.9, 200.0)
