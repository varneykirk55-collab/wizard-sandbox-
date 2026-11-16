extends RefCounted
## Procedural meshes for the first-person hands and staff.
## Tubes are smooth and low-poly; the crystal is flat-faceted.
## Winding is corrected so Godot's clockwise front faces point outward.

static func finger_segment(length: float, r0: float, r1: float, rounded_tip: bool) -> ArrayMesh:
	var path := PackedVector3Array()
	var radii := PackedFloat32Array()
	var colors: Array = []
	var steps := 5
	for i in steps:
		var t := float(i) / float(steps - 1)
		path.append(Vector3(0.0, 0.0, -length * t))
		var belly := 1.0 + 0.10 * sin(t * PI)
		radii.append(lerpf(r0, r1, t) * belly)
		var crease := lerpf(0.55, 1.0, smoothstep(0.0, 0.4, t))
		var rosy := 0.5 + 0.4 * sin(t * PI)
		colors.append(Color(crease, rosy, lerpf(0.2, 0.6, t)))
	if rounded_tip:
		var tip_r := r1
		for k in 3:
			var a := float(k + 1) / 4.0 * (PI * 0.5)
			path.append(Vector3(0.0, 0.0, -length - sin(a) * tip_r * 1.15))
			radii.append(cos(a) * tip_r * 0.96)
			colors.append(Color(1.0, 0.72, 0.55))
	return _tube(path, radii, 8, 0.15, 0.86, colors, false)


static func palm() -> ArrayMesh:
	var path := PackedVector3Array()
	var rx := PackedFloat32Array()
	var ry := PackedFloat32Array()
	var specs := [
		[0.018, 0.027, 0.023],
		[-0.006, 0.032, 0.020],
		[-0.030, 0.042, 0.017],
		[-0.052, 0.047, 0.015],
		[-0.074, 0.044, 0.014],
	]
	for spec in specs:
		path.append(Vector3(0.0, 0.004, float(spec[0])))
		rx.append(float(spec[1]))
		ry.append(float(spec[2]))
	return _ellipse_loft(path, rx, ry, 12)


static func sleeve() -> ArrayMesh:
	var path := PackedVector3Array()
	var radii := PackedFloat32Array()
	var colors: Array = []
	var steps := 8
	for i in steps:
		var t := float(i) / float(steps - 1)
		var z := lerpf(0.02, 0.40, t)
		path.append(Vector3(0.012 * t, -0.045 * t * t, z))
		# Modest bell. A wide cone reads as a megaphone, not a sleeve.
		radii.append(lerpf(0.034, 0.062, smoothstep(0.0, 1.0, t)))
		colors.append(Color(1, 1, 1, 1))
	return _tube(path, radii, 10, 0.4, 0.92, colors, false)


static func band(length: float, radius: float, flare: float) -> ArrayMesh:
	var path := PackedVector3Array()
	var radii := PackedFloat32Array()
	var colors: Array = []
	var steps := 4
	for i in steps:
		var t := float(i) / float(steps - 1)
		path.append(Vector3(0.0, 0.0, t * length))
		radii.append(radius * (1.0 + flare * sin(t * PI)))
		colors.append(Color(1, 1, 1, 1))
	return _tube(path, radii, 12, 0.0, 1.0, colors, true)


static func wrist() -> ArrayMesh:
	var path := PackedVector3Array()
	var radii := PackedFloat32Array()
	var colors: Array = []
	for i in 4:
		var t := float(i) / 3.0
		path.append(Vector3(0.0, 0.0, t * 0.05))
		radii.append(lerpf(0.030, 0.026, t))
		colors.append(Color(0.85, 0.7, 0.35))
	return _tube(path, radii, 10, 0.2, 0.94, colors, false)


static func shaft() -> ArrayMesh:
	var built := _shaft_samples(40)
	var colors: Array = []
	for i in built["path"].size():
		var t := float(i) / float(built["path"].size() - 1)
		# Slightly lighter on the raised bands, warmer toward the crown.
		var tint := lerpf(0.92, 1.05, smoothstep(0.7, 1.0, t))
		colors.append(Color(tint, tint * 0.96, tint * 0.9))
	return _tube(built["path"], built["radii"], 10, 8.0, 0.62, colors, true)


static func leather_wrap() -> ArrayMesh:
	return _span_tube(0.60, 0.76, 0.009, 8, 0.2)


static func crown_ring() -> ArrayMesh:
	return _span_tube(0.875, 0.915, 0.007, 8, 0.0)


static func prongs() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var crystal := Vector3(0.58, 0.02, 0.0)
	# Angle 0 is +Y (toward the camera). Leave that side open so the gem reads.
	var angles: Array[float] = [1.15, 2.2, 3.3, 4.4, 5.4]
	var touch: Array[bool] = [false, true, true, false, true]
	for i in angles.size():
		var ang := float(angles[i])
		var dir := Vector3(0.0, cos(ang), sin(ang))
		var gap := 0.058 if bool(touch[i]) else 0.078
		var start := _shaft_center(0.9) + dir * _shaft_radius(0.9)
		var c1 := start + Vector3(0.06, 0.0, 0.0) + dir * 0.07
		var c2 := crystal + Vector3(-0.04, 0.0, 0.0) + dir * (gap + 0.03)
		var tip := crystal + dir * gap + Vector3(-0.01, 0.0, 0.0)
		_branch(st, start, c1, c2, tip, 0.016, 0.006, Color(0.72, 0.5, 0.36))
		if i == 2 or i == 4:
			var mid := _bezier(start, c1, c2, tip, 0.5)
			var fork_dir := Vector3(0.0, cos(ang + 0.45), sin(ang + 0.45))
			var f1 := mid + fork_dir * 0.03 + Vector3(0.02, 0.0, 0.0)
			var ftip := mid + fork_dir * 0.055 + Vector3(0.05, 0.0, 0.0)
			_branch(st, mid, f1, ftip, ftip + fork_dir * 0.01, 0.008, 0.0035, Color(0.62, 0.4, 0.3))
	st.index()
	return st.commit()


static func crystal(length: float, radius: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := 6
	var along: Array[float] = [-0.50, -0.30, -0.06, 0.16, 0.50]
	var rads: Array[float] = [0.0, 0.58, 1.0, 0.62, 0.0]
	var rings: Array = []
	for i in along.size():
		var ring := PackedVector3Array()
		var r := rads[i] * radius
		var x := along[i] * length
		if r < 0.0008:
			ring.append(Vector3(x, 0.0, 0.0))
		else:
			for s in sides:
				var a := float(s) / float(sides) * TAU + 0.18
				var wob := 1.0 + 0.035 * sin(float(s) * 1.7 + float(i))
				ring.append(Vector3(x, cos(a) * r * wob, sin(a) * r * wob * 0.9))
		rings.append(ring)
	for i in rings.size() - 1:
		var a: PackedVector3Array = rings[i]
		var b: PackedVector3Array = rings[i + 1]
		if a.size() == 1:
			for s in b.size():
				_facet(st, a[0], b[s], b[(s + 1) % b.size()])
		elif b.size() == 1:
			for s in a.size():
				_facet(st, a[s], b[0], a[(s + 1) % a.size()])
		else:
			for s in a.size():
				var s2 := (s + 1) % a.size()
				_facet(st, a[s], b[s], b[s2])
				_facet(st, a[s], b[s2], a[s2])
	st.index()
	return st.commit()


static func _span_tube(t0: float, t1: float, extra: float, steps: int, twist: float) -> ArrayMesh:
	var path := PackedVector3Array()
	var radii := PackedFloat32Array()
	var colors: Array = []
	for i in steps:
		var u := float(i) / float(steps - 1)
		var t := lerpf(t0, t1, u)
		path.append(_shaft_center(t))
		radii.append(_shaft_radius(t) + extra)
		colors.append(Color(1, 1, 1, 1))
	return _tube(path, radii, 10, twist, 0.9, colors, false)


static func _shaft_samples(steps: int) -> Dictionary:
	var path := PackedVector3Array()
	var radii := PackedFloat32Array()
	for i in steps:
		var t := float(i) / float(steps - 1)
		path.append(_shaft_center(t))
		radii.append(_shaft_radius(t))
	return {"path": path, "radii": radii}


static func _shaft_center(t: float) -> Vector3:
	var x := lerpf(-1.05, 0.50, t)
	var sp := t * TAU * 3.1
	var amp := 0.022 * smoothstep(0.05, 0.28, t) * (1.0 - 0.55 * smoothstep(0.82, 0.97, t))
	return Vector3(x, sin(sp) * amp + sin(t * TAU * 1.4) * 0.006, cos(sp * 0.9) * amp * 0.8)


static func _shaft_radius(t: float) -> float:
	var r := 0.017
	r += 0.0032 * sin(t * TAU * 2.0 + 0.5)
	r += 0.0018 * sin(t * TAU * 5.0)
	if t < 0.055:
		r += 0.008 * (1.0 - t / 0.055)
	for c in [0.2, 0.38, 0.72]:
		var d := absf(t - c)
		if d < 0.011:
			r += 0.0055 * (1.0 - d / 0.011)
		elif d < 0.02:
			r -= 0.0024 * (1.0 - (d - 0.011) / 0.009)
	if t > 0.84:
		r += 0.011 * smoothstep(0.84, 0.97, t)
	return maxf(r, 0.01)


static func _branch(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, r0: float, r1: float, tint: Color) -> void:
	var path := PackedVector3Array()
	var radii := PackedFloat32Array()
	var colors: Array = []
	var steps := 8
	for i in steps:
		var t := float(i) / float(steps - 1)
		path.append(_bezier(p0, p1, p2, p3, t))
		radii.append(lerpf(r0, r1, t) * (1.0 + 0.08 * sin(t * PI)))
		colors.append(tint)
	_append_tube(st, path, radii, 6, 1.4, 0.8, colors, false)


static func _bezier(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var u := 1.0 - t
	return p0 * (u * u * u) + p1 * (3.0 * u * u * t) + p2 * (3.0 * u * t * t) + p3 * (t * t * t)


static func _ellipse_loft(path: PackedVector3Array, rx: PackedFloat32Array, ry: PackedFloat32Array, sides: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var frames := _frames(path)
	var rings: Array = []
	var norms: Array = []
	var cols: Array = []
	for i in path.size():
		var ring := PackedVector3Array()
		var nrm := PackedVector3Array()
		var col := PackedColorArray()
		var b: Basis = frames[i]
		for s in sides:
			var a := float(s) / float(sides) * TAU
			var local := Vector3(cos(a) * rx[i], sin(a) * ry[i], 0.0)
			var offset: Vector3 = b * local
			ring.append(path[i] + offset)
			var n := offset.normalized()
			if offset.length() < 0.0001:
				n = b.x
			nrm.append(n)
			# R crease, G rosy, B roughness. The back of the hand (+local Y) is lighter.
			var back := clampf(sin(a) * 0.5 + 0.5, 0.0, 1.0)
			col.append(Color(lerpf(0.7, 1.0, back), lerpf(0.45, 0.85, back), 0.4))
		rings.append(ring)
		norms.append(nrm)
		cols.append(col)
	_stitch(st, rings, norms, cols)
	_cap_fan(st, rings[0], norms[0], cols[0], path[0], -(frames[0] as Basis).z)
	_cap_fan(st, rings[rings.size() - 1], norms[norms.size() - 1], cols[cols.size() - 1], path[path.size() - 1], (frames[frames.size() - 1] as Basis).z)
	st.index()
	return st.commit()


static func _tube(path: PackedVector3Array, radii: PackedFloat32Array, sides: int, twist: float, ellipse: float, colors: Array, cap: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_append_tube(st, path, radii, sides, twist, ellipse, colors, cap)
	st.index()
	return st.commit()


static func _append_tube(st: SurfaceTool, path: PackedVector3Array, radii: PackedFloat32Array, sides: int, twist: float, ellipse: float, colors: Array, cap: bool) -> void:
	if path.size() < 2:
		return
	var frames := _frames(path)
	var rings: Array = []
	var norms: Array = []
	var cols: Array = []
	for i in path.size():
		var ring := PackedVector3Array()
		var nrm := PackedVector3Array()
		var col := PackedColorArray()
		var b: Basis = frames[i]
		var twist_a := twist * float(i) / float(path.size() - 1)
		var tint: Color = colors[mini(i, colors.size() - 1)]
		for s in sides:
			var a := float(s) / float(sides) * TAU + twist_a
			var local := Vector3(cos(a) * radii[i], sin(a) * radii[i] * ellipse, 0.0)
			var offset: Vector3 = b * local
			ring.append(path[i] + offset)
			var n := offset.normalized()
			if offset.length() < 0.0001:
				n = b.x
			nrm.append(n)
			col.append(tint)
		rings.append(ring)
		norms.append(nrm)
		cols.append(col)
	_stitch(st, rings, norms, cols)
	if cap:
		_cap_fan(st, rings[0], norms[0], cols[0], path[0], -(frames[0] as Basis).z)
		var last := path.size() - 1
		_cap_fan(st, rings[last], norms[last], cols[last], path[last], (frames[last] as Basis).z)


static func _stitch(st: SurfaceTool, rings: Array, norms: Array, cols: Array) -> void:
	var count := rings.size()
	var sides := (rings[0] as PackedVector3Array).size()
	for i in count - 1:
		var v0 := float(i) / float(count - 1)
		var v1 := float(i + 1) / float(count - 1)
		var r0: PackedVector3Array = rings[i]
		var r1: PackedVector3Array = rings[i + 1]
		var n0: PackedVector3Array = norms[i]
		var n1: PackedVector3Array = norms[i + 1]
		var c0: PackedColorArray = cols[i]
		var c1: PackedColorArray = cols[i + 1]
		for s in sides:
			var s2 := (s + 1) % sides
			var u0 := float(s) / float(sides)
			var u1 := float(s + 1) / float(sides)
			_tri(st, r0[s], n0[s], Vector2(u0, v0), c0[s], r0[s2], n0[s2], Vector2(u1, v0), c0[s2], r1[s2], n1[s2], Vector2(u1, v1), c1[s2])
			_tri(st, r0[s], n0[s], Vector2(u0, v0), c0[s], r1[s2], n1[s2], Vector2(u1, v1), c1[s2], r1[s], n1[s], Vector2(u0, v1), c1[s])


static func _cap_fan(st: SurfaceTool, ring: PackedVector3Array, norms: PackedVector3Array, cols: PackedColorArray, center: Vector3, normal: Vector3) -> void:
	var n := normal.normalized()
	for s in ring.size():
		var s2 := (s + 1) % ring.size()
		_tri(st, center, n, Vector2(0.5, 0.0), cols[s], ring[s], n, Vector2(0.0, 1.0), cols[s], ring[s2], n, Vector2(1.0, 1.0), cols[s2])


static func _frames(path: PackedVector3Array) -> Array:
	var tangents: Array = []
	for i in path.size():
		var t := Vector3.FORWARD
		if i == 0:
			t = path[1] - path[0]
		elif i == path.size() - 1:
			t = path[i] - path[i - 1]
		else:
			t = path[i + 1] - path[i - 1]
		if t.length() < 0.00001:
			t = Vector3.FORWARD
		tangents.append(t.normalized())
	var frames: Array = []
	var hint := Vector3.UP
	if absf((tangents[0] as Vector3).dot(hint)) > 0.9:
		hint = Vector3.FORWARD
	var binormal := (tangents[0] as Vector3).cross(hint).normalized()
	var normal := binormal.cross(tangents[0] as Vector3).normalized()
	frames.append(Basis(binormal, normal, tangents[0]))
	for i in range(1, path.size()):
		var prev_t: Vector3 = tangents[i - 1]
		var tan: Vector3 = tangents[i]
		var axis := prev_t.cross(tan)
		var prev: Basis = frames[i - 1]
		var bn: Vector3 = prev.x
		var nn: Vector3 = prev.y
		if axis.length() > 0.00001:
			var rot := Basis(axis.normalized(), acos(clampf(prev_t.dot(tan), -1.0, 1.0)))
			bn = rot * bn
			nn = rot * nn
		bn = tan.cross(nn).normalized()
		if bn.length() < 0.5:
			bn = prev.x
		nn = bn.cross(tan).normalized()
		frames.append(Basis(bn, nn, tan))
	return frames


static func _tri(st: SurfaceTool, a: Vector3, na: Vector3, ua: Vector2, ca: Color, b: Vector3, nb: Vector3, ub: Vector2, cb: Color, c: Vector3, nc: Vector3, uc: Vector2, cc: Color) -> void:
	var want := na + nb + nc
	if (b - a).cross(c - a).dot(want) > 0.0:
		_corner(st, a, na, ua, ca)
		_corner(st, c, nc, uc, cc)
		_corner(st, b, nb, ub, cb)
	else:
		_corner(st, a, na, ua, ca)
		_corner(st, b, nb, ub, cb)
		_corner(st, c, nc, uc, cc)


static func _facet(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var mid := (a + b + c) / 3.0
	var rh := (b - a).cross(c - a)
	if rh.length() < 0.0000001:
		return
	if rh.dot(mid) > 0.0:
		var swap := b
		b = c
		c = swap
		rh = -rh
	var n := rh.normalized()
	if n.dot(mid) < 0.0:
		n = -n
	_corner(st, a, n, Vector2(0.2, 0.2), Color(1, 1, 1))
	_corner(st, b, n, Vector2(0.8, 0.2), Color(1, 1, 1))
	_corner(st, c, n, Vector2(0.5, 0.9), Color(1, 1, 1))


static func _corner(st: SurfaceTool, p: Vector3, n: Vector3, uv: Vector2, color: Color) -> void:
	st.set_normal(n)
	st.set_uv(uv)
	st.set_color(color)
	st.add_vertex(p)
