extends Node3D
## SPELL 6 - BLACK FIRE.
## Tap: a small black flame that ignites whatever it hits.
## Hold: a growing sphere of black fire in the hand; release launches it, it
## explodes and scatters fire across nearby buildings.
## Either way the lasting damage is done by black_fire_field.gd, which burns
## sections through their normal health so buildings fail piece by piece.

const TAP_TIME := 0.22          # released sooner than this = tap
const MAX_CHARGE_TIME := 2.6    # seconds of hold for a full charge

var dark

var _state := 0                 # 0 in hand, 1 flying, 2 done
var _hold_t := 0.0
var _charge := 0.0
var _radius := 0.07
var _velocity := Vector3.ZERO
var _life := 0.0
var _visual: Node3D
var _flames: GPUParticles3D
var _embers: GPUParticles3D
var _light: OmniLight3D
var _loop: AudioStreamPlayer3D


func begin(hand: Vector3) -> void:
	global_position = hand
	_visual = Node3D.new()
	add_child(_visual)
	var core: MeshInstance3D = FX.mesh_node(FX.sphere, dark.black_mat)
	_visual.add_child(core)
	var rim: MeshInstance3D = FX.mesh_node(FX.sphere, FX.shader_mat("glow_shell", {"color": dark.CRIMSON, "energy": 7.0, "power": 2.2, "center": 0.0}))
	rim.scale = Vector3.ONE * 1.14
	_visual.add_child(rim)
	var fade := [Color(1, 1, 1, 0.0), Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.0)]
	_flames = FX.particles({"mat": "blackfire", "amount": 26, "life": 0.5, "radius": 1.0, "vel": Vector2(0.3, 1.2), "grav": Vector3(0.0, 1.0, 0.0), "tang": Vector2(3.0, 6.0), "scale": Vector2(0.7, 1.3), "curve": [[0.0, 0.4], [0.3, 1.0], [1.0, 0.2]], "spin": 80.0, "colors": fade, "offsets": [0.0, 0.2, 1.0], "aabb": 250.0})
	add_child(_flames)
	_embers = FX.particles({"mat": "spark", "amount": 20, "life": 0.7, "radius": 1.1, "vel": Vector2(0.5, 2.0), "grav": Vector3(0.0, 1.0, 0.0), "tang": Vector2(2.0, 5.0), "scale": Vector2(0.05, 0.12), "colors": [Color(1.0, 0.3, 0.12, 1.0), Color(0.9, 0.05, 0.05, 0.0)], "aabb": 250.0})
	add_child(_embers)
	_light = FX.light(Color(1.0, 0.12, 0.08), 1.5, 4.0)
	add_child(_light)
	_apply_size()


## Called every physics frame while the cast button stays down.
func charging(delta: float, hand: Vector3) -> void:
	if _state != 0:
		return
	_hold_t += delta
	global_position = hand
	if _hold_t <= TAP_TIME:
		return
	if _loop == null:
		_loop = AudioManager.make_loop("bf_charge", self, -10.0, 10.0)
	_charge = clampf((_hold_t - TAP_TIME) / MAX_CHARGE_TIME, 0.0, 1.0)
	# Grows fast at first, then swells and shudders toward the cap.
	var wobble := 1.0 + 0.06 * _charge * sin(_hold_t * 40.0)
	_radius = lerpf(0.07, 0.36, sqrt(_charge)) * wobble
	_apply_size()
	_light.light_energy = lerpf(1.5, 7.0, _charge) * (0.85 + 0.15 * sin(_hold_t * 31.0))
	_light.omni_range = lerpf(4.0, 13.0, _charge)
	_loop.pitch_scale = lerpf(0.7, 1.9, _charge)
	_loop.volume_db = lerpf(-10.0, 2.0, _charge)
	FX.shake_hold(global_position, 0.28 * _charge, 6.0)


## Button released: launch as a tap flame or as the charged sphere.
func fire(hand: Vector3, aim: Vector3) -> void:
	if _state != 0:
		return
	_state = 1
	global_position = hand
	var dir := aim - hand
	if dir.length() < 0.1:
		dir = Vector3.FORWARD
	dir = dir.normalized()
	if _loop != null:
		_loop.stop()
	if _hold_t <= TAP_TIME:
		_charge = 0.0
		_radius = 0.16
		_velocity = dir * 75.0
		AudioManager.play_at("bf_ignite", hand, -8.0, 1.7, 10.0)
	else:
		_velocity = dir * 58.0
		var tw := create_tween()
		tw.tween_method(_set_radius, _radius, lerpf(0.5, 2.0, _charge), 0.18)
		AudioManager.play_at("bf_ignite", hand, 0.0, 0.75, 16.0)
		AudioManager.play_at("cast", hand, 0.0, 0.5, 16.0)
		_light.light_energy = 8.0
		_light.omni_range = lerpf(10.0, 22.0, _charge)
	_apply_size()


func _set_radius(r: float) -> void:
	_radius = r
	_apply_size()


func _apply_size() -> void:
	_visual.scale = Vector3.ONE * _radius
	_flames.scale = Vector3.ONE * _radius
	_embers.scale = Vector3.ONE * _radius


func _physics_process(delta: float) -> void:
	if _state != 1:
		return
	_life += delta
	var from := global_position
	var to := from + _velocity * delta
	var q := PhysicsRayQueryParameters3D.create(from, to, 11)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		var hp: Vector3 = hit["position"]
		_impact(hp)
	elif _life > 4.0 or to.y < -0.5:
		_impact(to)
	else:
		global_position = to


func _impact(pos: Vector3) -> void:
	_state = 2
	global_position = pos
	var field = dark.field()
	if _charge <= 0.0:
		_tap_impact(pos, field)
	else:
		_charged_impact(pos, field)
	_visual.visible = false
	_light.visible = false
	_flames.emitting = false
	_embers.emitting = false
	get_tree().create_timer(2.0, false).timeout.connect(queue_free)


func _tap_impact(pos: Vector3, field) -> void:
	DM.explode(pos, 2.2, 35.0, 3.0, 0.3, false)
	var lit: int = field.ignite_area(pos, 2.4, 3, 12, false)
	FX.emit("bf_burst", pos, 1.0)
	FX.emit("bf_embers", pos, 0.6)
	FX.flash_light(pos, Color(1.0, 0.12, 0.08), 9.0, 10.0, 0.4)
	if lit == 0:
		# Nothing to burn here: the flame gutters on the ground for a few seconds.
		FX.emit("bf_ground", Vector3(pos.x, maxf(pos.y, 0.3), pos.z), 0.8)
	AudioManager.play_at("bf_ignite", pos, 0.0, randf_range(1.0, 1.3), 18.0)


func _charged_impact(pos: Vector3, field) -> void:
	var c := _charge
	var reach := lerpf(6.0, 15.0, c)
	var s := lerpf(0.6, 1.6, c)
	# Opening blast: enough to crack things open, not to level them.
	DM.explode(pos, reach, lerpf(130.0, 300.0, c), lerpf(10.0, 20.0, c), 0.4, true)
	# The fire is the real weapon.
	field.ignite_area(pos, reach * 1.15, int(lerpf(12.0, 44.0, c)), int(lerpf(12.0, 22.0, c)), true)

	var up := Vector3.UP * s
	dark.black_flash(pos + up, reach * 0.5, 0.55)
	dark.fireball(pos + up, reach * 0.75, 0.9 + 0.3 * s, Color(1.0, 0.35, 0.2), Color(0.75, 0.03, 0.03), Color(0.08, 0.0, 0.0))
	FX.shock_sphere(pos, reach * 2.2, 0.6, Color(1.0, 0.15, 0.1))
	if pos.y < 5.0:
		FX.ground_ring(pos, reach * 2.0, 0.8, Color(1.0, 0.12, 0.08))
		dark.scar(pos, reach * 0.5, Color(1.0, 0.1, 0.05), 9.0)
	FX.flash_light(pos + up, Color(1.0, 0.12, 0.08), 30.0 * s, 35.0 * s, 0.8)
	FX.emit("bf_blast", pos + up, s)
	FX.emit("bf_embers", pos + up, s * 1.6)
	FX.emit("sparks", pos + up, s * 0.7)
	for i in 3:
		var so := Vector3(randf_range(-1.0, 1.0), randf_range(0.5, 2.0), randf_range(-1.0, 1.0)) * reach * 0.3
		FX.emit("bf_smoke", pos + so, s * 1.6)
	for i in 3 + int(4.0 * c):
		var go := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * reach * 0.7
		FX.emit("bf_ground", Vector3(pos.x + go.x, 0.3, pos.z + go.z), 0.8 + 0.5 * c)
	FX.shake(pos, 0.5 + 0.5 * c, 70.0)
	FX.screen_flash(pos, 0.2, 40.0)

	AudioManager.play_at("explosion", pos, 3.0 + 3.0 * c, 0.8, 45.0)
	AudioManager.play_at("bf_ignite", pos, 4.0, 0.6, 35.0)
	AudioManager.play_at("rumble", pos, 0.0, 0.9, 40.0)
	FX.after(0.3, AudioManager.play_at.bind("debris", pos, -2.0, 0.9, 25.0))
