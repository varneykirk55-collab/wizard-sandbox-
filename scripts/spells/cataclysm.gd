extends Node3D
## SPELL 1 - CATACLYSM: a fast fireball that detonates like a miniature nuke.

const SPEED := 95.0
const RADIUS := 13.0

var _velocity := Vector3.ZERO
var _life := 0.0
var _done := false
var _visual: Node3D
var _trail: GPUParticles3D
var _smoke: GPUParticles3D
var _loop: AudioStreamPlayer3D


func launch(from: Vector3, target: Vector3) -> void:
	global_position = from
	var dir := target - from
	if dir.length() < 0.1:
		dir = Vector3.FORWARD
	_velocity = dir.normalized() * SPEED

	_visual = Node3D.new()
	add_child(_visual)
	var core: MeshInstance3D = FX.mesh_node(FX.sphere, FX.shader_mat("fireball", {"progress": 0.15, "energy": 9.0, "seed": randf() * 30.0}))
	core.scale = Vector3.ONE * 0.6
	_visual.add_child(core)
	var halo: MeshInstance3D = FX.mesh_node(FX.sphere, FX.shader_mat("glow_shell", {"color": Color(1.0, 0.5, 0.15), "energy": 5.0, "power": 2.0, "center": 1.0}))
	halo.scale = Vector3.ONE * 1.3
	_visual.add_child(halo)
	_visual.add_child(FX.light(Color(1.0, 0.55, 0.2), 7.0, 16.0))

	_trail = FX.particles({"mat": "fire", "amount": 60, "life": 0.45, "radius": 0.3, "vel": Vector2(0.0, 1.5), "scale": Vector2(1.2, 2.4), "curve": [[0.0, 1.0], [1.0, 0.1]], "colors": [Color(1.0, 0.9, 0.6, 1.0), Color(1.0, 0.4, 0.05, 0.8), Color(0.4, 0.05, 0.0, 0.0)], "aabb": 200.0})
	add_child(_trail)
	_smoke = FX.particles({"mat": "smoke", "amount": 30, "life": 1.6, "radius": 0.3, "vel": Vector2(0.0, 1.0), "scale": Vector2(1.5, 3.0), "spin": 40.0, "colors": [Color(0.3, 0.2, 0.15, 0.5), Color(0.12, 0.12, 0.12, 0.0)], "aabb": 250.0})
	add_child(_smoke)

	_loop = AudioManager.make_loop("fire_loop", self, 0.0, 12.0)
	_loop.pitch_scale = 1.7


func _physics_process(delta: float) -> void:
	if _done:
		return
	_life += delta
	var from := global_position
	var to := from + _velocity * delta
	var q := PhysicsRayQueryParameters3D.create(from, to, 11)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		var hp: Vector3 = hit["position"]
		_detonate(hp)
	elif _life > 3.5 or to.y < -0.5:
		_detonate(to)
	else:
		global_position = to


func _detonate(pos: Vector3) -> void:
	_done = true
	global_position = pos
	FX.explosion(pos, 1.0, 0)
	DM.explode(pos, RADIUS, 420.0, 26.0, 0.45, true)
	AudioManager.play_at("explosion", pos, 5.0, 1.0, 45.0)
	AudioManager.play_at("rumble", pos, 0.0, 1.0, 40.0)
	FX.after(0.3, AudioManager.play_at.bind("debris", pos, -2.0, 1.0, 25.0))
	_visual.visible = false
	_trail.emitting = false
	_smoke.emitting = false
	_loop.stop()
	get_tree().create_timer(2.0, false).timeout.connect(queue_free)
