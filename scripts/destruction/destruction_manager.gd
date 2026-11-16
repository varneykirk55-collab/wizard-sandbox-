extends Node
## Central destruction service (autoload "DM"). Every spell goes through the
## same three calls:
##   explode()  - radial damage + outward push (Cataclysm, Thunder, Meteor, well detonation)
##   attract()  - sustained pull / swirl / lift + damage over time (Gravity Well, Inferno)
##   touch_area() - marks structures as "in use" so they are not restored mid-spell

const RESTORE_TIME := 180.0
const MAX_DEBRIS := 650
const DEBRIS_LIFE := 75.0

var now := 0.0
var structures: Array = []
var debris: Array = []
var debris_root: Node3D
var player = null
var materials: Dictionary = {}
var _piece_script: Script
var _mesh_cache: Dictionary = {}
var _shape_cache: Dictionary = {}
var _clean_t := 0.0
var _tick_t := 0.0


func _ready() -> void:
	_piece_script = load("res://scripts/destruction/piece.gd")
	debris_root = Node3D.new()
	debris_root.name = "Debris"
	add_child(debris_root)
	_build_materials()


func _physics_process(delta: float) -> void:
	now += delta
	_clean_t += delta
	_tick_t += delta
	if _clean_t >= 0.5:
		_clean_t = 0.0
		_cleanup()
	if _tick_t >= 1.0:
		_tick_t = 0.0
		for st in structures:
			st.tick()


# ---------------------------------------------------------------------------
# Piece factory
# ---------------------------------------------------------------------------

func new_piece(dim: Vector3, kind: int, mat_name: String, hp: float, density: float):
	var p = _piece_script.new()
	p.setup(dim, kind, mat_name, hp, density)
	return p


func spawn_debris(dim: Vector3, mat_name: String, xform: Transform3D, density: float, vel: Vector3) -> void:
	var d := dim.snapped(Vector3.ONE * 0.05)
	d = Vector3(maxf(d.x, 0.1), maxf(d.y, 0.1), maxf(d.z, 0.1))
	var p = _piece_script.new()
	p.setup(d, 0, mat_name, 40.0, density)
	debris_root.add_child(p)
	p.global_transform = xform
	p.is_loose = true
	p.collision_layer = 8
	p.freeze = false
	p.loose_time = now
	p.linear_velocity = vel
	p.angular_velocity = Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * 8.0
	debris.append(p)


func piece_mesh(dim: Vector3, kind: int) -> Mesh:
	var key := "%d_%.2f_%.2f_%.2f" % [kind, dim.x, dim.y, dim.z]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var m: Mesh
	if kind == 0:
		var b := BoxMesh.new()
		b.size = dim
		m = b
	else:
		var c := CylinderMesh.new()
		c.bottom_radius = dim.x * 0.5
		c.top_radius = dim.x * 0.5 if kind == 1 else 0.02
		c.height = dim.y
		c.radial_segments = 14
		c.rings = 1
		m = c
	_mesh_cache[key] = m
	return m


func piece_shape(dim: Vector3, kind: int) -> Shape3D:
	var key := "%d_%.2f_%.2f_%.2f" % [kind, dim.x, dim.y, dim.z]
	if _shape_cache.has(key):
		return _shape_cache[key]
	var s: Shape3D
	if kind == 0:
		var b := BoxShape3D.new()
		b.size = dim
		s = b
	else:
		var c := CylinderShape3D.new()
		c.radius = dim.x * (0.5 if kind == 1 else 0.3)
		c.height = dim.y
		s = c
	_shape_cache[key] = s
	return s


func material(mat_name: String) -> Material:
	if materials.has(mat_name):
		return materials[mat_name]
	return materials["stone"]


# ---------------------------------------------------------------------------
# Debris bookkeeping
# ---------------------------------------------------------------------------

func register_debris(p) -> void:
	p.loose_time = now
	debris.append(p)


func unregister_debris(p) -> void:
	debris.erase(p)


func can_fragment() -> bool:
	return debris.size() < MAX_DEBRIS - 40


func _cleanup() -> void:
	var over := debris.size() - MAX_DEBRIS
	var i := 0
	while i < debris.size():
		var p = debris[i]
		if not is_instance_valid(p) or p.is_consumed:
			debris.remove_at(i)
			continue
		if over > 0 or (now - p.loose_time > DEBRIS_LIFE and p.sleeping):
			p.vanish()
			debris.remove_at(i)
			over -= 1
			continue
		i += 1


func reset_all() -> void:
	for c in debris_root.get_children():
		c.queue_free()
	debris.clear()
	for st in structures:
		st.build()


# ---------------------------------------------------------------------------
# Shared spell interface
# ---------------------------------------------------------------------------

## Radial blast. Returns how many intact pieces were broken loose.
func explode(pos: Vector3, radius: float, damage: float, push: float, lift: float = 0.35, shatter: bool = true) -> int:
	var broken := 0
	var loose_snapshot: Array = debris.duplicate()
	for st in structures:
		var sc: Vector3 = st.center
		if pos.distance_to(sc) > radius + st.radius:
			continue
		st.touch()
		for p in st.pieces:
			if not is_instance_valid(p) or p.is_consumed or p.is_loose:
				continue
			broken += _blast(p, pos, radius, damage, push, lift, shatter)
	for p in loose_snapshot:
		if is_instance_valid(p) and not p.is_consumed:
			_blast(p, pos, radius, damage, push, lift, shatter)
	return broken


func _blast(p, pos: Vector3, radius: float, damage: float, push: float, lift: float, shatter: bool) -> int:
	var d: Vector3 = p.global_position - pos
	var dist := d.length()
	if dist > radius:
		return 0
	var f := 1.0 - dist / radius
	f = f * f * 0.6 + f * 0.4
	var dir := d / maxf(dist, 0.05)
	dir.y += lift
	dir = dir.normalized()
	var was_loose: bool = p.is_loose
	p.apply_damage(damage * f, dir * push * f * randf_range(0.7, 1.25), shatter)
	if not was_loose and p.is_loose:
		return 1
	return 0


## Sustained force field. With orbit_radius == 0 it is a point attractor that
## can swallow debris (consume_radius). With orbit_radius > 0 it is a vertical
## vortex column of the given height that spins debris around its axis.
## Call at ~30 Hz with the accumulated dt. Returns the number of consumed pieces.
func attract(pos: Vector3, radius: float, pull: float, swirl: float, lift: float, dps: float, dt: float, consume_radius: float = 0.0, orbit_radius: float = 0.0, height: float = 0.0) -> int:
	var consumed := 0
	var r2 := radius * radius
	var column := orbit_radius > 0.0
	for st in structures:
		var sc: Vector3 = st.center
		if Vector2(sc.x - pos.x, sc.z - pos.z).length() > radius + st.radius:
			continue
		st.touch()
		if st.loose_count >= st.total:
			continue
		for p in st.pieces:
			if not is_instance_valid(p) or p.is_loose:
				continue
			var pp: Vector3 = p.global_position
			var d := pos - pp
			if column:
				if pp.y > pos.y + height:
					continue
				d.y = 0.0
			var d2 := d.length_squared()
			if d2 > r2:
				continue
			var f := 1.0 - sqrt(d2) / radius
			p.apply_damage(dps * (0.2 + f) * dt * randf_range(0.4, 1.6), d.normalized() * 1.5, false)
	for i in range(debris.size() - 1, -1, -1):
		var q = debris[i]
		if not is_instance_valid(q) or q.is_consumed:
			debris.remove_at(i)
			continue
		var qp: Vector3 = q.global_position
		var vel: Vector3 = q.linear_velocity
		var to := pos - qp
		var acc := Vector3.ZERO
		if column:
			if qp.y > pos.y + height + 2.0:
				continue
			var h := Vector3(to.x, 0.0, to.z)
			var hd := h.length()
			if hd > radius:
				continue
			var hn := h / maxf(hd, 0.05)
			var tang := Vector3(-hn.z, 0.0, hn.x)
			var fc := 1.0 - hd / radius
			var climb := clampf(1.0 - (qp.y - pos.y) / maxf(height, 1.0), -0.3, 1.0)
			var want := tang * swirl + hn * clampf((hd - orbit_radius) * 1.6, -5.0, pull) + Vector3.UP * lift * climb
			acc = (want - vel) * 3.0 * (0.35 + fc)
			acc.y += 6.0
		else:
			var dist := to.length()
			if dist > radius:
				continue
			if consume_radius > 0.0 and dist < consume_radius:
				q.consume(pos)
				consumed += 1
				continue
			var dirn := to / maxf(dist, 0.05)
			var fw := 1.0 - dist / radius
			var tang2 := Vector3(-dirn.z, 0.0, dirn.x)
			acc = dirn * pull * (0.5 + 1.6 * fw) + tang2 * swirl * (0.4 + fw) - vel * 1.1
			acc.y += 9.8 * (0.5 + 0.5 * fw)
		q.sleeping = false
		q.apply_central_impulse(acc * q.mass * dt)
	return consumed


## Keeps nearby structures from auto-restoring (e.g. while a meteor is inbound).
func touch_area(pos: Vector3, radius: float) -> void:
	for st in structures:
		var sc: Vector3 = st.center
		if pos.distance_to(sc) <= radius + st.radius:
			st.touch()


## Intact pieces near `pos`, spread apart - used for chain lightning.
func nearest_intact(pos: Vector3, radius: float, count: int, min_sep: float = 3.5) -> Array:
	var cands: Array = []
	for st in structures:
		var sc: Vector3 = st.center
		if pos.distance_to(sc) > radius + st.radius:
			continue
		for p in st.pieces:
			if not is_instance_valid(p) or p.is_loose:
				continue
			var pp: Vector3 = p.global_position
			var d := pos.distance_to(pp)
			if d > min_sep and d < radius:
				cands.append([d, pp])
	cands.sort_custom(_by_dist)
	var out: Array = []
	for c in cands:
		var cp: Vector3 = c[1]
		var ok := true
		for o in out:
			var op: Vector3 = o
			if op.distance_to(cp) < min_sep:
				ok = false
				break
		if ok:
			out.append(cp)
			if out.size() >= count:
				break
	return out


func _by_dist(a, b) -> bool:
	return a[0] < b[0]


# ---------------------------------------------------------------------------
# Materials (procedural, no external textures)
# ---------------------------------------------------------------------------

func _build_materials() -> void:
	materials["stone"] = _mat(Color(0.52, 0.5, 0.62), 0.92, 0.8, true, 0.05)
	materials["stone_dark"] = _mat(Color(0.3, 0.29, 0.42), 0.95, 0.8, true, 0.05)
	materials["stone_light"] = _mat(Color(0.7, 0.68, 0.8), 0.9, 0.8, true, 0.06)
	materials["rock"] = _mat(Color(0.2, 0.17, 0.15), 1.0, 0.6, true, 0.04)
	materials["plaster"] = _mat(Color(0.82, 0.78, 0.88), 0.85, 0.5, false, 0.02)
	materials["plaster_warm"] = _mat(Color(0.86, 0.7, 0.64), 0.85, 0.5, false, 0.02)
	materials["timber"] = _mat(Color(0.22, 0.14, 0.15), 0.8, 1.2, false, 0.03)
	materials["wood"] = _mat(Color(0.5, 0.34, 0.27), 0.75, 1.2, false, 0.03)
	materials["barrel"] = _mat(Color(0.4, 0.24, 0.21), 0.7, 1.4, false, 0.04)
	materials["roof_red"] = _mat(Color(0.56, 0.16, 0.42), 0.8, 1.6, true, 0.08)
	materials["roof_slate"] = _mat(Color(0.16, 0.3, 0.58), 0.6, 1.6, true, 0.08)
	materials["thatch"] = _mat(Color(0.26, 0.5, 0.5), 1.0, 2.0, false, 0.06)
	materials["cloth_red"] = _mat(Color(0.78, 0.15, 0.42), 0.9, 1.0, false, 0.02)
	materials["cloth_blue"] = _mat(Color(0.2, 0.36, 0.88), 0.9, 1.0, false, 0.02)
	materials["cloth_violet"] = _mat(Color(0.52, 0.28, 0.78), 0.88, 1.0, false, 0.02)
	materials["cloth_teal"] = _mat(Color(0.12, 0.55, 0.58), 0.88, 1.0, false, 0.02)
	materials["leaf"] = _mat(Color(0.1, 0.36, 0.34), 0.95, 1.0, false, 0.07)
	materials["crystal_cyan"] = _crystal_mat(Color(0.3, 0.95, 1.0))
	materials["crystal_violet"] = _crystal_mat(Color(0.7, 0.4, 1.0))
	materials["crystal_teal"] = _crystal_mat(Color(0.25, 1.0, 0.75))


func _crystal_mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color.r * 0.42, color.g * 0.42, color.b * 0.42)
	m.roughness = 0.28
	m.metallic = 0.08
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 2.3
	return m


func _mat(color: Color, rough: float, uv: float, cellular: bool, freq: float) -> StandardMaterial3D:
	var n := FastNoiseLite.new()
	n.seed = randi()
	n.noise_type = FastNoiseLite.TYPE_CELLULAR if cellular else FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_octaves = 4
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 1.0])
	ramp.colors = PackedColorArray([Color(0.55, 0.55, 0.55), Color(1, 1, 1)])
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.noise = n
	tex.color_ramp = ramp
	var ntex := NoiseTexture2D.new()
	ntex.width = 256
	ntex.height = 256
	ntex.seamless = true
	ntex.noise = n
	ntex.as_normal_map = true
	ntex.bump_strength = 5.0
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.albedo_texture = tex
	m.normal_enabled = true
	m.normal_texture = ntex
	m.normal_scale = 0.8
	m.roughness = rough
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * uv
	return m
