extends RigidBody3D
## One destructible section: wall chunk, roof slab, tower stone, crate, barrel...
## Intact pieces are frozen (static). When health runs out or their supports are
## gone they become real rigid-body debris.

var structure = null
var max_health := 100.0
var health := 100.0
var dim := Vector3.ONE
var kind := 0            # 0 box, 1 cylinder, 2 cone
var mat_name := "stone"
var density := 1.0
var is_loose := false
var is_consumed := false
var grounded := false
var supporters: Array = []
var dependents: Array = []
var loose_time := 0.0
var mesh_instance: MeshInstance3D
var _fall_pending := false


func setup(p_dim: Vector3, p_kind: int, p_mat: String, p_health: float, p_density: float) -> void:
	dim = p_dim
	kind = p_kind
	mat_name = p_mat
	max_health = p_health
	health = p_health
	density = p_density
	collision_layer = 2
	collision_mask = 11
	var vol := dim.x * dim.y * dim.z
	if kind != 0:
		vol *= 0.7
	mass = maxf(3.0, vol * 600.0 * density)
	mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = DM.piece_mesh(dim, kind)
	mesh_instance.material_override = DM.material(mat_name)
	add_child(mesh_instance)
	var col := CollisionShape3D.new()
	col.shape = DM.piece_shape(dim, kind)
	add_child(col)
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	freeze = true
	can_sleep = true
	angular_damp = 0.4
	linear_damp = 0.05


## Shared damage entry point used by every spell.
## `push` is a velocity change (m/s), so heavy and light pieces react alike.
func apply_damage(amount: float, push: Vector3, shatter: bool = false) -> void:
	if is_consumed:
		return
	if structure != null:
		structure.touch()
	if is_loose:
		sleeping = false
		apply_central_impulse(push * mass)
		if shatter and amount > max_health * 1.5:
			_shatter(push)
		return
	health -= amount
	if health <= 0.0:
		var overkill := -health
		break_loose(push)
		if shatter and overkill > max_health:
			_shatter(push)


func break_loose(push: Vector3 = Vector3.ZERO) -> void:
	if is_loose or is_consumed:
		return
	is_loose = true
	collision_layer = 8
	freeze = false
	sleeping = false
	DM.register_debris(self)
	if push != Vector3.ZERO:
		apply_central_impulse(push * mass)
		var spin := Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5)
		apply_torque_impulse(spin * mass * push.length() * 0.12)
	if structure != null:
		structure.on_piece_loosened(self)


## Called when something this piece rests on has broken away.
func check_support() -> void:
	if is_loose or is_consumed or _fall_pending:
		return
	for s in supporters:
		if is_instance_valid(s) and not s.is_loose:
			return
	_fall_pending = true
	get_tree().create_timer(randf_range(0.05, 0.28), false).timeout.connect(_fall)


func _fall() -> void:
	_fall_pending = false
	if not is_loose and not is_consumed:
		break_loose(Vector3(randf() - 0.5, 0.0, randf() - 0.5) * 0.8)


## Splits a box into up to eight smaller physical fragments.
func _shatter(push: Vector3) -> void:
	if kind != 0 or is_consumed:
		return
	var nx := 2 if dim.x > 0.6 else 1
	var ny := 2 if dim.y > 0.6 else 1
	var nz := 2 if dim.z > 0.6 else 1
	if nx * ny * nz < 2 or not DM.can_fragment():
		return
	var fd := Vector3(dim.x / nx, dim.y / ny, dim.z / nz)
	var b := global_transform.basis
	var o := global_position
	for ix in nx:
		for iy in ny:
			for iz in nz:
				var local := Vector3((ix + 0.5) * fd.x - dim.x * 0.5, (iy + 0.5) * fd.y - dim.y * 0.5, (iz + 0.5) * fd.z - dim.z * 0.5)
				var v := push * randf_range(0.5, 1.2) + Vector3(randf() - 0.5, randf() * 0.6, randf() - 0.5) * 4.0
				DM.spawn_debris(fd * randf_range(0.75, 0.95), mat_name, Transform3D(b, o + b * local), density, v)
	is_consumed = true
	DM.unregister_debris(self)
	queue_free()


## Swallowed by a singularity: shrink while being dragged into the centre.
func consume(center: Vector3, dur: float = 0.35) -> void:
	if is_consumed:
		return
	if not is_loose:
		break_loose()
	is_consumed = true
	DM.unregister_debris(self)
	collision_layer = 0
	collision_mask = 0
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "global_position", center, dur).set_ease(Tween.EASE_IN)
	tw.tween_property(mesh_instance, "scale", Vector3.ONE * 0.02, dur).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(queue_free)


## Debris budget / lifetime cleanup.
func vanish() -> void:
	if is_consumed:
		return
	is_consumed = true
	collision_layer = 0
	collision_mask = 0
	freeze = true
	var tw := create_tween()
	tw.tween_property(mesh_instance, "scale", Vector3.ONE * 0.01, 0.5)
	tw.tween_callback(queue_free)
