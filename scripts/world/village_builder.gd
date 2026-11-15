extends Node3D
## Procedurally assembles the destructible village out of pre-fractured sections.

var _structure_script: Script


func build() -> void:
	_structure_script = load("res://scripts/destruction/structure.gd")

	# Houses around the plaza (door faces local +Z).
	_house(Vector3(-14.5, 0, -4), PI * 0.5, 7.0, 3.2, 5.5, "plaster", "roof_red")
	_house(Vector3(14.5, 0, -5), -PI * 0.5, 7.5, 3.2, 5.5, "plaster_warm", "roof_slate")
	_house(Vector3(-17, 0, 10), PI * 0.5 + 0.25, 6.5, 2.4, 5.0, "plaster", "thatch")
	_house(Vector3(17, 0, 11), -PI * 0.5 - 0.25, 6.5, 3.2, 5.0, "stone_light", "roof_red")
	_house(Vector3(-10, 0, -22), 0.08, 8.0, 4.0, 6.0, "plaster_warm", "roof_slate")
	_house(Vector3(10.5, 0, -23), -0.1, 7.0, 3.2, 5.5, "plaster", "roof_red")

	_tower(Vector3(0, 0, -13))
	_well(Vector3(0, 0, 1.5))

	# Perimeter walls with a gate arch at the back.
	_wall(Vector3(-13.5, 0, -31), 0.0, 17.5, 3.2)
	_wall(Vector3(13.5, 0, -31), 0.0, 17.5, 3.2)
	_gate(Vector3(0, 0, -31))
	_wall(Vector3(-26, 0, -17), PI * 0.5, 15.0, 2.4)
	_wall(Vector3(26, 0, -17), PI * 0.5, 15.0, 2.4)

	# Colonnade leading in from the spawn point.
	_colonnade(Vector3(-5.5, 0, 14), 3, 4.5)
	_colonnade(Vector3(5.5, 0, 14), 3, 4.5)

	_stall(Vector3(-5.5, 0, 5.5), 0.5, "cloth_red")
	_stall(Vector3(6, 0, 6.5), -0.6, "cloth_blue")

	_fence(Vector3(-12, 0, 16.5), 0.0, 4)
	_fence(Vector3(-22, 0, 3), PI * 0.5, 3)
	_fence(Vector3(12, 0, 17.5), PI, 4)
	_fence(Vector3(22, 0, 4), PI * 0.5, 3)

	_crates(Vector3(-8.5, 0, -8.5), 0.3)
	_crates(Vector3(8, 0, -10), -0.4)
	_crates(Vector3(3, 0, 9.5), 1.0)
	_barrels(Vector3(-4, 0, -6.5), 5)
	_barrels(Vector3(9.5, 0, 1.5), 4)
	_barrels(Vector3(-10, 0, 4), 3)
	_barrels(Vector3(4.5, 0, -19), 5)

	for tp in [Vector3(-24, 0, 20), Vector3(25, 0, 22), Vector3(-30, 0, -3), Vector3(31, 0, -6), Vector3(-20, 0, -36), Vector3(21, 0, -37), Vector3(-9, 0, 27), Vector3(11, 0, 28)]:
		_tree(tp)


func _new_structure(label: String, pos: Vector3, yaw: float):
	var s = _structure_script.new()
	s.name = "%s_%d" % [label, DM.structures.size()]
	add_child(s)
	s.position = pos
	s.rotation.y = yaw
	DM.structures.append(s)
	return s


# ---------------------------------------------------------------------------
# Building blocks
# ---------------------------------------------------------------------------

func _wall_grid(s, start: Vector3, dir: Vector3, length: float, rows: int, rh: float, thick: float, mat: String, door: bool, windows: bool, hp: float) -> void:
	var cols := maxi(1, int(roundf(length / 1.25)))
	var cw := length / cols
	var door_col := int(cols / 2.0)
	var door_rows := mini(3, rows - 1)
	var along_x := absf(dir.x) > 0.5
	for r in rows:
		for c in cols:
			if door and c == door_col and r < door_rows:
				continue
			if windows and rows >= 4 and r == 2 and c % 2 == 1 and c != door_col:
				continue
			var ctr := start + dir * ((c + 0.5) * cw) + Vector3(0.0, (r + 0.5) * rh, 0.0)
			var dimv := Vector3(cw * 0.995, rh * 0.995, thick) if along_x else Vector3(thick, rh * 0.995, cw * 0.995)
			s.add_box(dimv, ctr, Basis.IDENTITY, "stone" if r == 0 else mat, hp)


func _ring(s, y: float, radius: float, n: int, h: float, thick: float, mat: String, offset: bool, hp: float) -> void:
	var chord := 2.0 * radius * tan(PI / n) * 0.98
	for i in n:
		var a := (float(i) + (0.5 if offset else 0.0)) * TAU / float(n)
		var p := Vector3(cos(a) * radius, y + h * 0.5, sin(a) * radius)
		s.add_box(Vector3(chord, h * 0.995, thick), p, Basis(Vector3.UP, PI * 0.5 - a), mat, hp)


# ---------------------------------------------------------------------------
# Structures
# ---------------------------------------------------------------------------

func _house(pos: Vector3, yaw: float, w: float, h: float, d: float, wall_mat: String, roof_mat: String) -> void:
	var s = _new_structure("House", pos, yaw)
	var t := 0.35
	var post := 0.4
	var rows := maxi(2, int(roundf(h / 0.8)))
	var rh := h / rows
	var hx := w * 0.5
	var hz := d * 0.5
	# Timber corner posts.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			s.add_box(Vector3(post, h, post), Vector3(float(sx) * (hx - post * 0.5), h * 0.5, float(sz) * (hz - post * 0.5)), Basis.IDENTITY, "timber", 200.0)
	# Walls between the posts.
	_wall_grid(s, Vector3(-hx + post, 0.0, hz - post * 0.5), Vector3.RIGHT, w - post * 2.0, rows, rh, t, wall_mat, true, true, 110.0)
	_wall_grid(s, Vector3(-hx + post, 0.0, -hz + post * 0.5), Vector3.RIGHT, w - post * 2.0, rows, rh, t, wall_mat, false, true, 110.0)
	_wall_grid(s, Vector3(-hx + post * 0.5, 0.0, -hz + post), Vector3.BACK, d - post * 2.0, rows, rh, t, wall_mat, false, true, 110.0)
	_wall_grid(s, Vector3(hx - post * 0.5, 0.0, -hz + post), Vector3.BACK, d - post * 2.0, rows, rh, t, wall_mat, false, true, 110.0)
	# Gabled roof: two slopes, two rows of slabs each.
	var rise := d * 0.42
	var over := 0.45
	var half := hz + over
	var drop := rise * over / hz
	var slope := Vector2(half, rise + drop).length()
	var cols := maxi(2, int(roundf(w / 1.8)))
	var cw := w / cols
	var th := 0.18
	for sgn in [-1.0, 1.0]:
		var u := Vector3(0.0, -(rise + drop), float(sgn) * half).normalized()
		var xa := Vector3.RIGHT
		var ya := u.cross(xa).normalized()
		var up := ya if ya.y > 0.0 else -ya
		var bas := Basis(xa, ya, u)
		for j in 2:
			for c in cols:
				var ctr := Vector3(-hx + (c + 0.5) * cw, h + rise, 0.0) + u * (slope * (j + 0.5) * 0.5) + up * (th * 0.5)
				s.add_box(Vector3(cw * 0.995, th, slope * 0.51), ctr, bas, roof_mat, 70.0)
	# Stepped gable ends.
	var steps := 3
	for sx in [-1.0, 1.0]:
		for k in steps:
			var span := d * (1.0 - (k + 0.85) / steps)
			s.add_box(Vector3(t, rise / steps, maxf(span, 0.3)), Vector3(float(sx) * (hx - t * 0.5), h + (k + 0.5) * rise / steps, 0.0), Basis.IDENTITY, wall_mat, 90.0)
	# Chimney on the gable side.
	var ch := h + rise + 0.7
	var n := int(ceilf(ch / 0.9))
	for k in n:
		s.add_box(Vector3(0.7, ch / n * 0.995, 0.7), Vector3(hx + 0.37, (k + 0.5) * ch / n, -hz * 0.3), Basis.IDENTITY, "stone_dark", 150.0)
	s.build()


func _tower(pos: Vector3) -> void:
	var s = _new_structure("Tower", pos, 0.0)
	var y := 0.0
	# Section 1: heavy base.
	for r in 3:
		_ring(s, y, 3.9, 12, 1.1, 0.9, "stone_dark", r % 2 == 1, 220.0)
		y += 1.1
	s.add_cyl(5.8, 0.3, Vector3(0, y + 0.15, 0), "wood", 120.0)
	# Section 2: shaft.
	for r in 6:
		_ring(s, y, 3.3, 12, 1.0, 0.7, "stone", r % 2 == 0, 170.0)
		y += 1.0
	s.add_cyl(5.6, 0.3, Vector3(0, y - 0.7, 0), "wood", 120.0)
	# Section 3: crown with merlons.
	_ring(s, y, 3.7, 12, 0.7, 0.9, "stone_dark", true, 190.0)
	y += 0.7
	for i in range(0, 12, 2):
		var a := float(i) * TAU / 12.0
		s.add_box(Vector3(0.95, 0.8, 0.8), Vector3(cos(a) * 3.75, y + 0.4, sin(a) * 3.75), Basis(Vector3.UP, PI * 0.5 - a), "stone", 140.0)
	# Pointed slate roof built from leaning slabs.
	var rim := 3.15
	var apex_h := 4.4
	for i in 8:
		var a2 := (float(i) + 0.5) * TAU / 8.0
		var o := Vector3(cos(a2), 0.0, sin(a2))
		var tdir := Vector3(-sin(a2), 0.0, cos(a2))
		var p0 := o * rim + Vector3(0.0, y, 0.0)
		var v := Vector3(0.0, y + apex_h, 0.0) - p0
		var slope := v.length()
		var u := v / slope
		var ya := u.cross(tdir).normalized()
		var bas := Basis(tdir, ya, u)
		for j in 2:
			var k := (j + 0.5) * 0.5
			var width := 2.0 * rim * (1.0 - j * 0.5) * tan(PI / 8.0) * 1.08
			s.add_box(Vector3(width, 0.16, slope * 0.5), p0 + u * (slope * k), bas, "roof_slate", 80.0)
	s.build()


func _wall(pos: Vector3, yaw: float, length: float, h: float) -> void:
	var s = _new_structure("Wall", pos, yaw)
	var rows := maxi(2, int(roundf(h / 0.8)))
	var rh := h / rows
	_wall_grid(s, Vector3(-length * 0.5, 0.0, 0.0), Vector3.RIGHT, length, rows, rh, 0.7, "stone", false, false, 170.0)
	var cols := maxi(1, int(roundf(length / 1.25)))
	var cw := length / cols
	for c in cols:
		if c % 2 == 0:
			s.add_box(Vector3(cw * 0.9, 0.6, 0.7), Vector3(-length * 0.5 + (c + 0.5) * cw, h + 0.3, 0.0), Basis.IDENTITY, "stone_dark", 120.0)
	s.build()


func _gate(pos: Vector3) -> void:
	var s = _new_structure("Gate", pos, 0.0)
	for sx in [-1.0, 1.0]:
		for k in 5:
			s.add_box(Vector3(1.3, 0.9, 1.3), Vector3(float(sx) * 3.2, 0.45 + k * 0.9, 0.0), Basis.IDENTITY, "stone_dark", 200.0)
	s.add_box(Vector3(3.9, 0.8, 1.1), Vector3(-1.95, 4.9, 0.0), Basis.IDENTITY, "stone", 160.0)
	s.add_box(Vector3(3.9, 0.8, 1.1), Vector3(1.95, 4.9, 0.0), Basis.IDENTITY, "stone", 160.0)
	s.add_box(Vector3(1.6, 0.7, 1.3), Vector3(0.0, 5.65, 0.0), Basis.IDENTITY, "stone_dark", 160.0)
	s.build()


func _colonnade(pos: Vector3, count: int, spacing: float) -> void:
	var s = _new_structure("Colonnade", pos, 0.0)
	for i in count:
		var z := i * spacing
		s.add_box(Vector3(1.4, 0.4, 1.4), Vector3(0.0, 0.2, z), Basis.IDENTITY, "stone_dark", 180.0)
		for k in 4:
			s.add_cyl(1.0, 1.05, Vector3(0.0, 0.4 + 0.525 + k * 1.05, z), "stone_light", 150.0)
		s.add_box(Vector3(1.3, 0.4, 1.3), Vector3(0.0, 4.8, z), Basis.IDENTITY, "stone", 150.0)
		if i < count - 1:
			s.add_box(Vector3(0.9, 0.6, spacing * 0.995), Vector3(0.0, 5.3, z + spacing * 0.5), Basis.IDENTITY, "stone", 130.0)
	s.build()


func _well(pos: Vector3) -> void:
	var s = _new_structure("Well", pos, 0.0)
	_ring(s, 0.0, 1.3, 8, 0.5, 0.4, "stone", false, 120.0)
	_ring(s, 0.5, 1.3, 8, 0.5, 0.4, "stone_dark", true, 120.0)
	for sx in [-1.0, 1.0]:
		s.add_box(Vector3(0.18, 2.2, 0.18), Vector3(float(sx) * 1.6, 1.1, 0.0), Basis.IDENTITY, "timber", 80.0)
	s.add_box(Vector3(3.6, 0.16, 0.2), Vector3(0.0, 2.28, 0.0), Basis.IDENTITY, "timber", 60.0)
	for sgn in [-1.0, 1.0]:
		s.add_box(Vector3(3.8, 0.08, 1.3), Vector3(0.0, 2.75, float(sgn) * 0.5), Basis(Vector3.RIGHT, float(sgn) * 0.6), "roof_red", 50.0)
	s.build()


func _stall(pos: Vector3, yaw: float, cloth: String) -> void:
	var s = _new_structure("Stall", pos, yaw)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			s.add_box(Vector3(0.15, 2.3, 0.15), Vector3(float(sx) * 1.6, 1.15, float(sz) * 1.0), Basis.IDENTITY, "timber", 60.0)
	s.add_box(Vector3(1.75, 0.08, 2.5), Vector3(-0.88, 2.42, 0.0), Basis(Vector3.BACK, 0.08), cloth, 40.0)
	s.add_box(Vector3(1.75, 0.08, 2.5), Vector3(0.88, 2.42, 0.0), Basis(Vector3.BACK, -0.08), cloth, 40.0)
	s.add_box(Vector3(2.9, 0.9, 0.6), Vector3(0.0, 0.45, 0.55), Basis.IDENTITY, "wood", 60.0)
	s.add_box(Vector3(0.6, 0.6, 0.6), Vector3(-0.8, 1.2, 0.55), Basis.IDENTITY, "wood", 30.0)
	s.add_cyl(0.5, 0.7, Vector3(0.7, 1.25, 0.55), "barrel", 30.0)
	s.build()


func _fence(pos: Vector3, yaw: float, sections: int) -> void:
	var s = _new_structure("Fence", pos, yaw)
	for i in sections + 1:
		s.add_box(Vector3(0.16, 1.2, 0.16), Vector3(i * 2.0, 0.6, 0.0), Basis.IDENTITY, "timber", 50.0)
	for i in sections:
		for ry in [0.45, 0.9]:
			s.add_box(Vector3(1.83, 0.1, 0.07), Vector3(i * 2.0 + 1.0, float(ry), 0.0), Basis.IDENTITY, "wood", 30.0)
	s.build()


func _crates(pos: Vector3, yaw: float) -> void:
	var s = _new_structure("Crates", pos, yaw)
	var c := 0.9
	for i in 3:
		s.add_box(Vector3(c, c, c), Vector3((i - 1) * (c + 0.05), c * 0.5, 0.0), Basis.IDENTITY, "wood", 35.0)
	for i in 2:
		s.add_box(Vector3(c, c, c), Vector3((i - 0.5) * (c + 0.05), c * 1.5 + 0.005, 0.0), Basis.IDENTITY, "wood", 35.0)
	s.add_box(Vector3(c, c, c), Vector3(0.0, c * 2.5 + 0.01, 0.0), Basis.IDENTITY, "wood", 35.0)
	s.add_box(Vector3(0.7, 0.7, 0.7), Vector3(0.3, 0.35, 1.1), Basis(Vector3.UP, 0.5), "wood", 30.0)
	s.build()


func _barrels(pos: Vector3, count: int) -> void:
	var s = _new_structure("Barrels", pos, 0.0)
	for i in count:
		var a := float(i) * 2.4
		var r := 0.5 + 0.38 * sqrt(float(i))
		s.add_cyl(0.75, 1.0, Vector3(cos(a) * r, 0.5, sin(a) * r), "barrel", 30.0)
	s.build()


func _tree(pos: Vector3) -> void:
	var s = _new_structure("Tree", pos, 0.0)
	s.add_cyl(0.55, 2.6, Vector3(0.0, 1.3, 0.0), "timber", 90.0)
	s.add_cyl(3.6, 3.2, Vector3(0.0, 3.9, 0.0), "leaf", 60.0, true)
	s.add_cyl(2.5, 2.8, Vector3(0.0, 5.9, 0.0), "leaf", 50.0, true)
	s.build()
