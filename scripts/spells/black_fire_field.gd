extends Node3D
## Black Fire burn manager. Tracks every burning section, damages it on a slow
## tick through the normal piece health (so supports fail and collapse happens
## through the existing support graph), spreads the fire to nearby sections and
## turns burnt-out debris to ash.
##
## Bounded on purpose: a fixed cap on burning sections, a fixed number of new
## ignitions per tick, and a generation limit so one cast burns a neighbourhood
## rather than the whole map. Casting is never refused; when the cap is full a
## new ignition simply waits for a section to burn out.

const MAX_BURNING := 140
const TICK := 0.2
const DPS := 24.0             # health per second on an intact section
const SPREAD_CHANCE := 0.12   # per burning section per tick
const SPREAD_BUDGET := 4      # new ignitions per tick, whole field
const REACH := 1.9            # metres beyond the section's own half-size
const JUMP_REACH := 9.0       # occasional ember jump (reaches adjacent buildings)

var dark

var _burning: Array = []
var _acc := 0.0
var _lights: Array = []
var _loops: Array = []
var _level := 0.0
var _loop_t := 0.0


func _ready() -> void:
	for i in 4:
		var l: OmniLight3D = FX.light(Color(1.0, 0.12, 0.08), 0.0, 11.0)
		add_child(l)
		_lights.append(l)
	for i in 3:
		var lp: AudioStreamPlayer3D = AudioManager.make_loop("bf_crackle", self, -60.0, 16.0)
		lp.pitch_scale = 0.85 + 0.15 * i
		_loops.append(lp)


func burning_count() -> int:
	return _burning.size()


## Sets one section alight. `limit` is how many generations the fire may spread.
func ignite(p, gen: int, limit: int) -> bool:
	if not is_instance_valid(p) or p.is_consumed or p.has_meta("bf"):
		return false
	if _burning.size() >= MAX_BURNING:
		return false
	p.set_meta("bf", true)
	var d: Vector3 = p.dim
	var m := maxf(d.x, maxf(d.y, d.z))
	var sz := clampf(m, 0.7, 1.6)
	var em: GPUParticles3D = FX.particles({"mat": "blackfire", "amount": 7, "life": 0.9, "radius": m * 0.45, "spread": 25.0, "vel": Vector2(0.8, 2.4), "grav": Vector3(0.0, 2.5, 0.0), "scale": Vector2(0.9 * sz, 1.5 * sz), "curve": [[0.0, 0.35], [0.3, 1.0], [1.0, 0.3]], "spin": 50.0, "colors": [Color(1, 1, 1, 0.0), Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.0)], "offsets": [0.0, 0.2, 1.0], "aabb": 30.0})
	p.add_child(em)
	_burning.append({"p": p, "t": 0.0, "loose_t": 0.0, "gen": gen, "limit": limit, "life": randf_range(2.5, 4.5), "charred": false, "reach": m * 0.5 + REACH})
	var pp: Vector3 = p.global_position
	FX.emit("bf_burst", pp, 0.6)
	if p.structure != null:
		p.structure.touch()
	return true


## Ignites up to `max_count` sections within `radius`. With `scatter` the picks
## are random across the area (charged blast); without it the nearest burn first.
func ignite_area(pos: Vector3, radius: float, max_count: int, limit: int, scatter: bool) -> int:
	var cands: Array = []
	for st in DM.structures:
		var sc: Vector3 = st.center
		if pos.distance_to(sc) > radius + st.radius:
			continue
		for p in st.pieces:
			if not is_instance_valid(p) or p.is_consumed or p.has_meta("bf"):
				continue
			var pp: Vector3 = p.global_position
			var dist := pos.distance_to(pp)
			if dist <= radius:
				cands.append([randf() if scatter else dist, p])
	for q in DM.debris:
		if is_instance_valid(q) and not q.is_consumed and q.structure == null and not q.has_meta("bf"):
			var qp: Vector3 = q.global_position
			var qd := pos.distance_to(qp)
			if qd <= radius:
				cands.append([randf() if scatter else qd, q])
	cands.sort_custom(_by_key)
	var count := 0
	for c in cands:
		if count >= max_count:
			break
		if ignite(c[1], 0, limit):
			count += 1
	return count


func _by_key(a, b) -> bool:
	return a[0] < b[0]


func _physics_process(delta: float) -> void:
	_acc += delta
	if _acc < TICK:
		return
	var dt := _acc
	_acc = 0.0
	var budget := SPREAD_BUDGET
	for i in range(_burning.size() - 1, -1, -1):
		var b: Dictionary = _burning[i]
		var p = b["p"]
		if not is_instance_valid(p) or p.is_consumed:
			_burning.remove_at(i)
			continue
		var t: float = b["t"]
		t += dt
		b["t"] = t
		# A burning structure is in use: the 180 s restore waits until the fire is out.
		if p.structure != null:
			p.structure.touch()
		if not b["charred"] and t > 0.8:
			b["charred"] = true
			p.mesh_instance.material_override = dark.char_mat
		var pp: Vector3 = p.global_position
		if p.is_loose:
			var lt: float = b["loose_t"]
			lt += dt
			b["loose_t"] = lt
			var life: float = b["life"]
			if lt > life:
				FX.emit("bf_ash", pp, 1.0)
				p.vanish()
				_burning.remove_at(i)
				continue
		else:
			p.apply_damage(DPS * dt * randf_range(0.5, 1.5), Vector3.ZERO, false)
		var gen: int = b["gen"]
		var limit: int = b["limit"]
		if budget > 0 and t > 0.6 and gen < limit and _burning.size() < MAX_BURNING and randf() < SPREAD_CHANCE:
			var jump := randf() < 0.06
			var reach: float = b["reach"]
			var q = _pick_near(pp, JUMP_REACH if jump else reach)
			if q != null and ignite(q, gen + 1, limit):
				budget -= 1
				if jump:
					FX.emit("bf_embers", pp, 0.8)
	_ambience(dt)


## Random intact, not-yet-burning section within `r` of `pos`.
func _pick_near(pos: Vector3, r: float):
	var pick = null
	var seen := 0
	for st in DM.structures:
		var sc: Vector3 = st.center
		if pos.distance_to(sc) > r + st.radius:
			continue
		if st.loose_count >= st.total:
			continue
		for p in st.pieces:
			if not is_instance_valid(p) or p.is_loose or p.is_consumed or p.has_meta("bf"):
				continue
			var pp: Vector3 = p.global_position
			if pos.distance_to(pp) <= r:
				seen += 1
				if randi() % seen == 0:
					pick = p
	return pick


## Smoke, embers, a few roaming red lights and the crackle bed. All fixed-size.
func _ambience(dt: float) -> void:
	var n := _burning.size()
	var target := clampf(float(n) / 25.0, 0.0, 1.0)
	if n > 0:
		target = maxf(target, 0.15)
	_level = move_toward(_level, target, dt * (1.5 if target > _level else 0.35))
	_loop_t -= dt
	var move_loops := _loop_t <= 0.0
	if move_loops:
		_loop_t = 1.0
	for i in _loops.size():
		var lp: AudioStreamPlayer3D = _loops[i]
		lp.volume_db = linear_to_db(maxf(_level, 0.001)) - 3.0
		if move_loops and n > 0:
			var bp = _burning[randi() % n]["p"]
			if is_instance_valid(bp):
				lp.global_position = bp.global_position
	for i in _lights.size():
		var l: OmniLight3D = _lights[i]
		if n == 0:
			l.light_energy = move_toward(l.light_energy, 0.0, dt * 6.0)
			continue
		var lb = _burning[randi() % n]["p"]
		if is_instance_valid(lb):
			var lpos: Vector3 = lb.global_position
			l.global_position = l.global_position.lerp(lpos + Vector3.UP * 0.8, 0.35)
		l.light_energy = (2.0 + randf() * 1.8) * minf(1.0, float(n) / 6.0)
	if n == 0:
		return
	for i in 2:
		var sp = _burning[randi() % n]["p"]
		if is_instance_valid(sp):
			var spos: Vector3 = sp.global_position
			FX.emit("bf_smoke", spos + Vector3.UP * 0.6, 0.9)
			if randf() < 0.4:
				FX.emit("bf_embers", spos, 0.5)
