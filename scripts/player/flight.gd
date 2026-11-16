extends RefCounted
## Magical levitation. The player controller stays in charge of walking, jumping,
## aiming and spells; this only owns the airborne hold-to-fly transition, the
## hover / ascend / descend velocity, and when a deliberate descent becomes a landing.
##
## No mana, stamina, duration or cooldown. Vertical speed is driven to an exact
## target (zero while hovering) so altitude does not drift.

const HOLD_THRESHOLD := 0.17
const ASCEND_SPEED := 7.5
const DESCEND_SPEED := 9.0
const VERT_ACCEL := 20.0
const HOVER_DAMP := 36.0
const FLY_SPEED := 8.5
const FLY_BOOST := 17.0
const FLY_ACCEL := 20.0
const BLEND_DECAY := 2.2
## Backup probe below the feet. Short on purpose: hovering near terrain never
## runs it, and a descent has to actually reach the surface.
const LAND_PROBE := 0.08

signal started
signal ended

var active := false
## After landing, the jump button must be released before another hold can fly.
var armed := true
## 1 on the landing frame, then decays so ground grip eases back in.
var ground_blend := 0.0
## Skip one gravity step so the landing frame cannot dip the body through the floor.
var suppress_gravity := false

var hold_time := 0.0
var _snap := 0.1
var _try_land := false


func physics_step(body: CharacterBody3D, delta: float, dir: Vector3, wish: Dictionary) -> bool:
	var jump_down := bool(wish.get("jump_down", false))
	if not jump_down:
		armed = true
		hold_time = 0.0
	if active:
		_apply_flight(body, delta, dir, wish)
		return true
	if ground_blend > 0.0:
		ground_blend = maxf(0.0, ground_blend - BLEND_DECAY * delta)
	# Count the hold only once the body has left the floor, so a tap stays a jump.
	if not body.is_on_floor() and jump_down and armed:
		hold_time += delta
		if hold_time >= HOLD_THRESHOLD:
			_activate(body)
			_apply_flight(body, delta, dir, wish)
			return true
	else:
		hold_time = 0.0
	return false


## Ground acceleration the frame after landing. Returns `base` unchanged once the blend finishes.
func soften_ground_accel(base: float) -> float:
	if ground_blend <= 0.0:
		return base
	return lerpf(FLY_ACCEL, base, 1.0 - ground_blend)


func after_slide(body: CharacterBody3D) -> void:
	if not active or not _try_land:
		return
	var limit := cos(body.floor_max_angle)
	for i in body.get_slide_collision_count():
		var col := body.get_slide_collision(i)
		var n := col.get_normal()
		if n.dot(body.up_direction) >= limit:
			var hit_y := col.get_position().y
			if body.global_position.dot(body.up_direction) < hit_y:
				var p := body.global_position
				p += body.up_direction * (hit_y - p.dot(body.up_direction))
				body.global_position = p
			_land(body)
			return
	if _probe_landing(body, limit):
		_land(body)


## Void rescue and any forced return to walking. Requires a fresh hold to fly again.
func force_ground(body: CharacterBody3D) -> void:
	hold_time = 0.0
	ground_blend = 0.0
	suppress_gravity = true
	armed = false
	_try_land = false
	if active:
		body.velocity.y = 0.0
		_deactivate(body)
	else:
		body.motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED


func _apply_flight(body: CharacterBody3D, delta: float, dir: Vector3, wish: Dictionary) -> void:
	var jump_down := bool(wish.get("jump_down", false))
	var descend := bool(wish.get("descend", false))
	var boost := bool(wish.get("boost", false))
	var speed := FLY_BOOST if boost else FLY_SPEED
	var target := dir * speed
	body.velocity.x = move_toward(body.velocity.x, target.x, FLY_ACCEL * delta)
	body.velocity.z = move_toward(body.velocity.z, target.z, FLY_ACCEL * delta)
	# Ascend wins if both are held, so a sprint button still held from takeoff
	# does not cancel the climb. Descend is the button alone.
	var target_y := 0.0
	_try_land = false
	if jump_down:
		target_y = ASCEND_SPEED
	elif descend:
		target_y = -DESCEND_SPEED
		_try_land = true
	var rate := HOVER_DAMP if target_y == 0.0 else VERT_ACCEL
	body.velocity.y = move_toward(body.velocity.y, target_y, rate * delta)
	if target_y == 0.0 and absf(body.velocity.y) < 0.04:
		body.velocity.y = 0.0


func _probe_landing(body: CharacterBody3D, limit: float) -> bool:
	var space := body.get_world_3d().direct_space_state
	if space == null:
		return false
	var from := body.global_position + body.up_direction * 0.2
	var to := body.global_position - body.up_direction * LAND_PROBE
	var q := PhysicsRayQueryParameters3D.create(from, to, body.collision_mask)
	q.exclude = [body.get_rid()]
	q.collide_with_areas = false
	q.hit_from_inside = true
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return false
	var n: Vector3 = hit["normal"]
	if n.dot(body.up_direction) < limit:
		return false
	var p: Vector3 = hit["position"]
	body.global_position += body.up_direction * (p - body.global_position).dot(body.up_direction)
	return true


func _activate(body: CharacterBody3D) -> void:
	_snap = body.floor_snap_length
	body.floor_snap_length = 0.0
	body.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	active = true
	_try_land = false
	started.emit()


func _land(body: CharacterBody3D) -> void:
	_try_land = false
	ground_blend = 1.0
	suppress_gravity = true
	armed = false
	hold_time = 0.0
	body.velocity.y = 0.0
	_deactivate(body)
	# Snap first so the body is flagged on the floor, then put the feet back on
	# the surface. Snap alone can leave the capsule a few centimetres inside.
	body.apply_floor_snap()
	_rest_on_floor(body)
	body.velocity.y = 0.0


func _rest_on_floor(body: CharacterBody3D) -> void:
	var space := body.get_world_3d().direct_space_state
	if space == null:
		return
	var from := body.global_position + body.up_direction * 1.25
	var to := body.global_position - body.up_direction * 1.25
	var q := PhysicsRayQueryParameters3D.create(from, to, body.collision_mask)
	q.exclude = [body.get_rid()]
	q.collide_with_areas = false
	q.hit_from_inside = true
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return
	var n: Vector3 = hit["normal"]
	if n.dot(body.up_direction) < cos(body.floor_max_angle):
		return
	var p: Vector3 = hit["position"]
	var delta := (p - body.global_position).dot(body.up_direction)
	if absf(delta) > 0.4:
		return
	body.global_position += body.up_direction * delta


func _deactivate(body: CharacterBody3D) -> void:
	active = false
	body.motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	body.floor_snap_length = _snap
	ended.emit()
