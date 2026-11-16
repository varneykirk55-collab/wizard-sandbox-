extends RefCounted
## Enchanted village expansion. Builds three districts inside the existing
## tree line and perimeter, using the same structure / piece / decor path as
## the original village (breakable sections, support collapse, 180 s rebuild).
##
## Residential lanes sit on the east and west flanks of the plaza.
## The marketplace flanks the south approach road.
## The wizard-tower court fills the open corners inside the north wall.

const GOLD := Color(1.0, 0.72, 0.3)
const CYAN := Color(0.3, 0.95, 1.0)
const VIOLET := Color(0.7, 0.4, 1.0)
const TEAL := Color(0.25, 1.0, 0.75)

var host: Node3D
var _path_mat: StandardMaterial3D
var _path_meshes: Dictionary = {}


func run(builder: Node3D) -> void:
	host = builder
	_residential()
	_marketplace()
	_tower_court()
	_vegetation()
	_lay_paths()
	if OS.get_environment("VILLAGE_AUDIT") == "1" or OS.get_environment("VILLAGE_CAPTURE") == "1":
		var report := Node.new()
		report.name = "VillageAudit"
		report.set_script(load("res://scripts/tools/village_audit.gd"))
		host.add_child(report)


# ---------------------------------------------------------------------------
# Districts
# ---------------------------------------------------------------------------

func _residential() -> void:
	# Cottages face inward. Footprints stay south of the side walls (those end
	# near z=-9.5) and clear of the fences on x=±22, z=-3..3.
	_cottage(Vector3(-25.4, 0, -6.2), PI * 0.5, 4.6, 4.4, 3.0, "plaster", "roof_red", CYAN)
	_cottage(Vector3(-26.2, 0, 7.6), PI * 0.5, 6.0, 4.6, 3.15, "plaster_warm", "thatch", TEAL)
	_cottage(Vector3(25.4, 0, -6.2), -PI * 0.5, 4.6, 4.4, 3.0, "plaster_warm", "roof_slate", VIOLET)
	_cottage(Vector3(26.2, 0, 7.6), -PI * 0.5, 6.0, 4.6, 3.15, "plaster", "roof_red", CYAN)
	_garden_wall(Vector3(-28.4, 0, 12.15), 0.0, 5.4, 1.15, false, TEAL)
	_garden_wall(Vector3(28.4, 0, 12.15), 0.0, 5.4, 1.15, false, VIOLET)
	_lantern_post(Vector3(-21.15, 0, -7.7))
	_lantern_post(Vector3(-21.35, 0, 4.9))
	_lantern_post(Vector3(21.15, 0, -7.7))
	_lantern_post(Vector3(21.35, 0, 5.1))
	_cluster(Vector3(-29.4, 0, 1.55), 0.5, "crystal_teal", TEAL)
	_cluster(Vector3(29.2, 0, -1.3), -0.4, "crystal_violet", VIOLET)


func _marketplace() -> void:
	_shop(Vector3(-17.4, 0, 20.8), PI * 0.5, "plaster", "cloth_violet", VIOLET)
	_shop(Vector3(18.6, 0, 21.2), -PI * 0.5, "plaster_warm", "cloth_teal", TEAL)
	# Front pair faces arriving players. Inner stalls face the road.
	host._stall(Vector3(-14.2, 0, 15.8), 0.05, "cloth_violet", "MarketStall")
	host._stall(Vector3(-12.0, 0, 20.4), PI * 0.5, "cloth_teal", "MarketStall")
	host._stall(Vector3(-12.0, 0, 24.3), PI * 0.5, "cloth_red", "MarketStall")
	host._stall(Vector3(13.6, 0, 17.85), -0.08, "cloth_teal", "MarketStall")
	host._stall(Vector3(13.2, 0, 21.0), -PI * 0.5, "cloth_violet", "MarketStall")
	host._stall(Vector3(13.2, 0, 24.6), -PI * 0.5, "cloth_blue", "MarketStall")
	_arch(Vector3(-11.2, 0, 13.15), 0.0, 3.05, 3.35, VIOLET)
	_arch(Vector3(11.2, 0, 13.15), 0.0, 3.05, 3.35, TEAL)
	_cluster(Vector3(-16.9, 0, 25.85), 0.7, "crystal_violet", VIOLET)
	_cluster(Vector3(17.0, 0, 26.15), -0.5, "crystal_cyan", CYAN)


func _tower_court() -> void:
	_spire(Vector3(-18.6, 0, -27.0), 0.35, CYAN, 2)
	_spire(Vector3(18.8, 0, -27.0), -0.45, VIOLET, 3)
	_workshop(Vector3(-21.0, 0, -19.0), PI * 0.5, "crystal_cyan", CYAN)
	_workshop(Vector3(21.2, 0, -19.2), -PI * 0.5, "crystal_violet", VIOLET)
	_arch(Vector3(0.0, 0, -23.7), 0.0, 3.35, 3.65, CYAN)
	_garden_wall(Vector3(-23.9, 0, -27.9), PI * 0.5, 4.5, 1.65, true, CYAN)
	_garden_wall(Vector3(24.1, 0, -27.9), -PI * 0.5, 4.5, 1.65, true, VIOLET)
	_cluster(Vector3(-14.3, 0, -29.45), 0.4, "crystal_cyan", CYAN)
	_cluster(Vector3(14.5, 0, -29.45), -0.2, "crystal_teal", TEAL)
	_lantern_post(Vector3(-3.65, 0, -26.3))
	_lantern_post(Vector3(3.65, 0, -26.3))


func _vegetation() -> void:
	_shrub(Vector3(-30.4, 0, -6.5), 1.0, 0.4)
	_shrub(Vector3(-31.0, 0, 14.2), 0.85, 1.2)
	_shrub(Vector3(32.8, 0, -12.6), 1.05, 0.8)
	_shrub(Vector3(31.2, 0, 14.0), 0.9, 2.1)
	_shrub(Vector3(-20.2, 0, 26.6), 0.8, 0.3)
	_shrub(Vector3(21.8, 0, 26.7), 0.85, 1.7)
	_shrub(Vector3(-27.6, 0, -30.4), 1.05, 0.6)
	_shrub(Vector3(27.8, 0, -30.2), 1.0, 2.4)
	host._tree(Vector3(-33.4, 0, 1.2))
	host._tree(Vector3(33.6, 0, 2.2))
	host._tree(Vector3(-33.0, 0, -22.5))
	host._tree(Vector3(34.0, 0, -21.5))


func _lay_paths() -> void:
	# Lanes in front of the cottage doors, split so they don't run through the
	# existing fences at x=±22, z=-3..3.
	_path(Vector3(1.25, 0.03, 5.5), Vector3(-22.05, 0.02, -6.55))
	_path(Vector3(1.25, 0.03, 6.2), Vector3(-22.25, 0.02, 7.35))
	_path(Vector3(1.25, 0.03, 5.5), Vector3(22.05, 0.02, -6.55))
	_path(Vector3(1.25, 0.03, 6.2), Vector3(22.25, 0.02, 7.55))
	_path(Vector3(8.4, 0.03, 1.15), Vector3(-19.4, 0.02, -10.25))
	_path(Vector3(8.4, 0.03, 1.15), Vector3(19.4, 0.02, -10.25))
	# Market paving, kept off the colonnades (x≈±5.5) and the centre road.
	_path(Vector3(11.2, 0.03, 12.8), Vector3(-13.7, 0.02, 20.15))
	_path(Vector3(11.4, 0.03, 12.6), Vector3(14.7, 0.02, 20.5))
	# Processional from the great tower to the gate, plus branches to the spires
	# that stay north of the back houses.
	_path(Vector3(2.5, 0.03, 10.4), Vector3(0.0, 0.02, -24.55))
	_path_between(Vector3(-1.7, 0.03, -28.05), Vector3(-15.2, 0.03, -27.15), 1.45)
	_path_between(Vector3(1.7, 0.03, -28.05), Vector3(15.3, 0.03, -27.15), 1.45)


# ---------------------------------------------------------------------------
# Buildings
# ---------------------------------------------------------------------------

func _cottage(pos: Vector3, yaw: float, w: float, d: float, h: float, wall_mat: String, roof_mat: String, tint: Color) -> void:
	var s = host._new_structure("Cottage", pos, yaw)
	var post := 0.38
	var thick := 0.32
	var hx := w * 0.5
	var hz := d * 0.5
	_posts(s, w, d, h, post, "timber", 160.0)
	var rows := 3
	var rh := h / float(rows)
	_facade(s, Vector3(-hx + post, 0.0, hz - post * 0.5), Vector3.RIGHT, w - post * 2.0, rows, rh, thick, wall_mat, "stone_dark", 1, 110.0, 1.85, 2, 2)
	_facade(s, Vector3(-hx + post, 0.0, -hz + post * 0.5), Vector3.RIGHT, w - post * 2.0, rows, rh, thick, wall_mat, "stone_dark", 1, 110.0, 1.85, 0, 2)
	_facade(s, Vector3(-hx + post * 0.5, 0.0, -hz + post), Vector3.BACK, d - post * 2.0, rows, rh, thick, wall_mat, "stone_dark", 1, 110.0, 1.7, 0, 2)
	_facade(s, Vector3(hx - post * 0.5, 0.0, -hz + post), Vector3.BACK, d - post * 2.0, rows, rh, thick, wall_mat, "stone_dark", 1, 110.0, 1.7, 0, 2)
	_ring_beams(s, w, d, h, post)
	s.add_box(Vector3(w - 1.15, 0.1, d - 1.15), Vector3(0.0, 0.05, 0.0), Basis.IDENTITY, "wood", 40.0)
	var ridge := _curved_gable(s, w, d, h, roof_mat, wall_mat, 62.0)
	var ch := ridge + 0.28
	var cx := hx - 0.58
	var cz := -hz * 0.42
	var n := 3
	for k in n:
		s.add_box(Vector3(0.52, ch / float(n) * 0.95, 0.52), Vector3(cx, (k + 0.5) * ch / float(n), cz), Basis.IDENTITY, "stone_dark", 120.0)
	_dress_openings(s)
	var length := w - post * 2.0
	var cols := maxi(1, int(roundf(length / 1.85)))
	var cw := length / float(cols)
	var door_x := -hx + post + (int(cols / 2.0) + 0.5) * cw
	s.decorate("lantern", Vector3(door_x - cw * 0.15, minf(h - 0.35, 2.45), hz + 0.1), Basis.IDENTITY, GOLD, true)
	s.decorate("rune", Vector3(door_x, h * 0.72, hz + 0.04), Basis.IDENTITY, tint)
	if DM.structures.size() % 2 == 0:
		s.decorate("sign", Vector3(door_x - cw, minf(h - 0.2, 2.55), hz + 0.02), Basis.IDENTITY, tint)
	for sx in [-1.0, 1.0]:
		s.decorate("finial", Vector3(sx * (hx - 0.08), ridge + 0.02, 0.0), Basis.IDENTITY, GOLD)
	# Yard crystal sits behind the cottage, off the doorway.
	s.decorate("crystal", Vector3(-hx * 0.15, 0.0, -(hz + 0.4)), Basis.from_scale(Vector3.ONE * 0.65), tint, false)
	s.decorate("crystal", Vector3(cx, ch + 0.02, cz), Basis.from_scale(Vector3.ONE * 0.45), tint, false)
	s.build()


func _shop(pos: Vector3, yaw: float, wall_mat: String, awning: String, tint: Color) -> void:
	var s = host._new_structure("Shop", pos, yaw)
	var w := 5.2
	var d := 4.0
	var h := 2.75
	var post := 0.36
	var thick := 0.3
	var hx := w * 0.5
	var hz := d * 0.5
	_posts(s, w, d, h, post, "timber", 100.0)
	var rows := 3
	var rh := h / float(rows)
	_facade(s, Vector3(-hx + post, 0.0, -hz + post * 0.5), Vector3.RIGHT, w - post * 2.0, rows, rh, thick, wall_mat, "stone", 1, 90.0, 1.6, 0, 2)
	_facade(s, Vector3(-hx + post * 0.5, 0.0, -hz + post), Vector3.BACK, d - post * 2.0, rows, rh, thick, wall_mat, "stone", 1, 90.0, 1.5, 0, 2)
	_facade(s, Vector3(hx - post * 0.5, 0.0, -hz + post), Vector3.BACK, d - post * 2.0, rows, rh, thick, wall_mat, "stone", 1, 90.0, 1.5, 0, 2)
	var fw := w - post * 2.0
	# Counter on the left, open doorway on the right, lintel across the front.
	s.add_box(Vector3(fw * 0.58, 1.02, thick), Vector3(-fw * 0.2, 0.51, hz - thick * 0.5), Basis.IDENTITY, "wood", 55.0)
	s.add_box(Vector3(fw, 0.28, post), Vector3(0.0, h - 0.16, hz - post * 0.5), Basis.IDENTITY, "timber", 70.0)
	s.add_cyl(0.2, 0.5, Vector3(-0.85, 1.28, hz - 0.05), "crystal_cyan", 16.0, true, 0.45)
	s.add_box(Vector3(w * 0.5, 0.07, 1.45), Vector3(-w * 0.22, h - 0.02, hz + 0.28), Basis(Vector3.RIGHT, -0.22), awning, 32.0)
	s.add_box(Vector3(w * 0.5, 0.07, 1.45), Vector3(w * 0.22, h - 0.02, hz + 0.28), Basis(Vector3.RIGHT, -0.22), awning, 32.0)
	_shed_roof(s, w + 0.4, -hz - 0.2, h + 1.2, hz + 0.05, h + 0.08, "roof_slate", 50.0)
	var top := h + 1.35
	for k in 4:
		s.add_box(Vector3(0.4, top / 4.0 * 0.94, 0.4), Vector3(hx * 0.45, (k + 0.5) * top / 4.0, -hz * 0.4), Basis.IDENTITY, "stone_dark", 60.0)
	s.add_box(Vector3(w - 1.0, 0.1, d - 1.0), Vector3(0.0, 0.05, -0.15), Basis.IDENTITY, "wood", 35.0)
	_dress_openings(s)
	s.decorate("lantern", Vector3(0.7, h - 0.25, hz + 0.08), Basis.IDENTITY, GOLD, true)
	s.decorate("sign", Vector3(-0.95, h - 0.05, hz + 0.06), Basis.IDENTITY, tint)
	s.decorate("rune", Vector3(0.15, h * 0.62, hz + 0.02), Basis.IDENTITY, tint)
	s.decorate("crystal", Vector3(hx * 0.45, top + 0.05, -hz * 0.4), Basis.from_scale(Vector3.ONE * 0.45), tint, false)
	s.decorate("finial", Vector3(0.0, h + 1.28, -hz * 0.15), Basis.IDENTITY, GOLD)
	s.build()


func _workshop(pos: Vector3, yaw: float, crystal_mat: String, tint: Color) -> void:
	var s = host._new_structure("Workshop", pos, yaw)
	var w := 6.4
	var d := 4.8
	var post := 0.4
	var thick := 0.32
	var hf := 2.6
	var hb := 3.9
	var hx := w * 0.5
	var hz := d * 0.5
	for sx in [-1.0, 1.0]:
		s.add_box(Vector3(post, hb, post), Vector3(sx * (hx - post * 0.5), hb * 0.5, -(hz - post * 0.5)), Basis.IDENTITY, "timber", 150.0)
		s.add_box(Vector3(post, hf, post), Vector3(sx * (hx - post * 0.5), hf * 0.5, hz - post * 0.5), Basis.IDENTITY, "timber", 120.0)
	_facade(s, Vector3(-hx + post, 0.0, -hz + post * 0.5), Vector3.RIGHT, w - post * 2.0, 3, hb / 3.0, thick, "stone", "stone_dark", 1, 130.0, 1.9, 0, 2)
	# Stepped side walls follow the saltbox slope.
	var segs := 3
	var seg_d := (d - post * 2.0) / float(segs)
	for i in segs:
		var hh := lerpf(hb, hf, (float(i) + 0.5) / float(segs))
		var srows := 2
		var srh := hh / float(srows)
		var zc := -hz + post + (float(i) + 0.5) * seg_d
		for r in srows:
			var mat := "stone_dark" if r == 0 else "plaster"
			if r == srows - 1 and i == 1:
				s.marks.append({"pos": Vector3(-hx + thick * 0.5, (r + 0.5) * srh, zc), "along_x": false, "w": seg_d, "h": srh})
				s.marks.append({"pos": Vector3(hx - thick * 0.5, (r + 0.5) * srh, zc), "along_x": false, "w": seg_d, "h": srh})
				continue
			s.add_box(Vector3(thick, srh * 0.96, seg_d * 0.96), Vector3(-hx + thick * 0.5, (r + 0.5) * srh, zc), Basis.IDENTITY, mat, 110.0)
			s.add_box(Vector3(thick, srh * 0.96, seg_d * 0.96), Vector3(hx - thick * 0.5, (r + 0.5) * srh, zc), Basis.IDENTITY, mat, 110.0)
	var fw := w - post * 2.0
	s.add_box(Vector3(fw * 0.56, 1.05, thick), Vector3(-fw * 0.2, 0.525, hz - thick * 0.45), Basis.IDENTITY, "wood", 55.0)
	s.add_box(Vector3(fw, 0.3, post), Vector3(0.0, hf - 0.16, hz - post * 0.45), Basis.IDENTITY, "timber", 80.0)
	s.add_box(Vector3(1.5, 0.72, 0.55), Vector3(-1.15, 0.36, 0.15), Basis.IDENTITY, "wood", 35.0)
	s.add_box(Vector3(0.85, 0.55, 0.85), Vector3(1.25, 0.28, -0.35), Basis(Vector3.UP, 0.4), "barrel", 30.0)
	_shed_roof(s, w + 0.7, -hz - 0.35, hb + 0.12, hz + 0.15, hf + 0.05, "roof_slate", 58.0)
	# Exterior furnace, grounded, with a glowing charge.
	var fx := -hx + 0.2
	var fz := -hz - 0.55
	for k in 5:
		s.add_box(Vector3(0.72, 0.68, 0.72), Vector3(fx, 0.34 + float(k) * 0.68, fz), Basis.IDENTITY, "stone_dark", 140.0)
	s.add_cyl(0.34, 0.7, Vector3(fx, 3.7, fz), crystal_mat, 22.0, true, 0.45)
	s.add_box(Vector3(0.16, 0.85, 0.16), Vector3(fx + 0.22, 3.35, fz + 0.12), Basis(Vector3.FORWARD, 0.4), crystal_mat, 16.0, 0.45)
	s.add_box(Vector3(w - 1.2, 0.1, d - 1.3), Vector3(0.0, 0.05, 0.1), Basis.IDENTITY, "wood", 35.0)
	_dress_openings(s)
	s.decorate("lantern", Vector3(fw * 0.22, hf - 0.2, hz + 0.12), Basis.IDENTITY, GOLD, true)
	s.decorate("rune", Vector3(fx, 1.7, fz - 0.42), Basis.IDENTITY, tint)
	s.decorate("crystal", Vector3(fx, 3.85, fz), Basis.from_scale(Vector3.ONE * 0.75), tint, false)
	s.decorate("sign", Vector3(-1.3, hf - 0.15, hz + 0.05), Basis.IDENTITY, tint)
	s.build()


func _spire(pos: Vector3, yaw: float, tint: Color, shaft_rings: int) -> void:
	var s = host._new_structure("Spire", pos, yaw)
	var y := 0.0
	var n := 6
	_ring(s, y, 2.05, n, 1.2, 0.58, "stone_dark", false, 190.0)
	y += 1.2
	s.add_cyl(3.15, 0.18, Vector3(0.0, y + 0.06, 0.0), "wood", 80.0)
	for r in shaft_rings:
		var mat := "stone_light" if r % 2 == 0 else "plaster"
		_ring(s, y, 1.62, n, 1.05, 0.48, mat, r % 2 == 1, 150.0)
		y += 1.05
	s.add_cyl(2.7, 0.16, Vector3(0.0, y + 0.04, 0.0), "wood", 70.0)
	_ring(s, y, 1.88, n, 0.62, 0.52, "stone_dark", true, 160.0)
	y += 0.62
	for i in range(0, n, 2):
		var a := float(i) * TAU / float(n)
		s.add_box(Vector3(0.62, 0.48, 0.5), Vector3(cos(a) * 1.9, y + 0.24, sin(a) * 1.9), Basis(Vector3.UP, PI * 0.5 - a), "stone", 110.0)
	var apex := 2.35
	_cone_roof(s, y, 1.45, apex, n, "roof_slate", 55.0)
	var mid_y := 1.2 + 1.05
	for i in 3:
		var a2 := float(i) * TAU / 3.0
		var wb := Basis(Vector3.UP, PI * 0.5 - a2)
		s.decorate("window", Vector3(cos(a2) * 1.88, mid_y, sin(a2) * 1.88), wb * Basis.from_scale(Vector3(0.42, 0.85, 1.0)), GOLD)
	for i in 2:
		var ra := float(i) * PI + 0.5
		var rb := Basis(Vector3.UP, PI * 0.5 - ra)
		s.decorate("rune", Vector3(cos(ra) * 2.12, 0.85, sin(ra) * 2.12), rb * Basis.from_scale(Vector3.ONE * 1.25), tint)
	s.decorate("crystal", Vector3(0.0, y + apex - 0.15, 0.0), Basis.from_scale(Vector3.ONE * 1.25), tint, false)
	s.decorate("lantern", Vector3(0.25, 1.85, 2.35), Basis.IDENTITY, GOLD, true)
	s.decorate("finial", Vector3(0.0, y + apex + 0.15, 0.0), Basis.IDENTITY, GOLD)
	s.build()


func _arch(pos: Vector3, yaw: float, span: float, height: float, tint: Color) -> void:
	var s = host._new_structure("Arch", pos, yaw)
	var pw := 0.82
	var cx := span * 0.5 + pw * 0.5
	var rows := 3
	var rh := height / float(rows)
	for sx in [-1.0, 1.0]:
		for k in rows:
			var mat := "stone_dark" if k == 0 else "stone"
			s.add_box(Vector3(pw, rh * 0.97, pw), Vector3(float(sx) * cx, rh * (float(k) + 0.5), 0.0), Basis.IDENTITY, mat, 170.0)
		s.decorate("rune", Vector3(float(sx) * cx, height * 0.55, pw * 0.58), Basis.from_scale(Vector3.ONE * 1.2), tint)
	var ly := height + 0.2
	var reach := cx + pw * 0.45
	s.add_box(Vector3(reach, 0.42, pw * 0.92), Vector3(-reach * 0.5 + 0.08, ly, 0.0), Basis.IDENTITY, "stone", 140.0)
	s.add_box(Vector3(reach, 0.42, pw * 0.92), Vector3(reach * 0.5 - 0.08, ly, 0.0), Basis.IDENTITY, "stone", 140.0)
	s.add_box(Vector3(0.7, 0.5, pw), Vector3(0.0, ly + 0.4, 0.0), Basis.IDENTITY, "stone_light", 100.0)
	for sx in [-1.0, 1.0]:
		s.add_box(Vector3(span * 0.4, 0.26, pw * 0.82), Vector3(float(sx) * span * 0.24, ly + 0.12, 0.0), Basis(Vector3.BACK, float(sx) * 0.42), "stone", 90.0)
	s.decorate("crystal", Vector3(0.0, ly + 0.72, 0.0), Basis.from_scale(Vector3.ONE * 0.65), tint, false)
	s.build()


func _garden_wall(pos: Vector3, yaw: float, length: float, h: float, merlons: bool, tint: Color) -> void:
	var s = host._new_structure("GardenWall", pos, yaw)
	var rows := maxi(2, int(roundf(h / 0.72)))
	var rh := h / float(rows)
	var cols := maxi(2, int(roundf(length / 1.5)))
	var cw := length / float(cols)
	var x0 := -length * 0.5
	for r in rows:
		for c in cols:
			var mat := "stone_dark" if r == 0 else "stone"
			s.add_box(Vector3(cw * 0.97, rh * 0.96, 0.58), Vector3(x0 + (float(c) + 0.5) * cw, (float(r) + 0.5) * rh, 0.0), Basis.IDENTITY, mat, 140.0)
	if merlons:
		for c in cols:
			if c % 2 == 0:
				s.add_box(Vector3(cw * 0.7, 0.4, 0.58), Vector3(x0 + (float(c) + 0.5) * cw, h + 0.2, 0.0), Basis.IDENTITY, "stone_dark", 90.0)
	s.decorate("rune", Vector3(-length * 0.22, h * 0.55, 0.36), Basis.IDENTITY, tint)
	s.decorate("rune", Vector3(length * 0.22, h * 0.55, 0.36), Basis.IDENTITY, tint)
	s.build()


func _cluster(pos: Vector3, yaw: float, mat_name: String, tint: Color) -> void:
	var s = host._new_structure("Cluster", pos, yaw)
	s.add_box(Vector3(1.25, 0.42, 0.95), Vector3(0.0, 0.18, 0.0), Basis.IDENTITY, "stone_dark", 80.0)
	s.add_box(Vector3(0.7, 0.5, 0.55), Vector3(0.42, 0.32, 0.22), Basis(Vector3.UP, 0.7), "stone", 60.0)
	s.add_box(Vector3(0.48, 0.32, 0.42), Vector3(-0.38, 0.2, -0.18), Basis(Vector3.UP, -0.5), "rock", 45.0)
	s.add_cyl(0.28, 1.15, Vector3(0.02, 0.78, 0.02), mat_name, 26.0, true, 0.45)
	s.add_cyl(0.2, 0.82, Vector3(0.32, 0.62, -0.12), mat_name, 20.0, true, 0.45)
	s.add_cyl(0.16, 0.64, Vector3(-0.28, 0.48, 0.16), mat_name, 18.0, true, 0.45)
	s.add_box(Vector3(0.14, 0.72, 0.14), Vector3(0.12, 0.5, 0.28), Basis(Vector3.RIGHT, 0.4), mat_name, 16.0, 0.45)
	s.decorate("crystal", Vector3(-0.2, 0.35, -0.22), Basis.from_scale(Vector3.ONE * 0.5), tint, false)
	s.build()


func _lantern_post(pos: Vector3) -> void:
	var s = host._new_structure("Lantern", pos, 0.0)
	s.add_box(Vector3(0.2, 2.05, 0.2), Vector3(0.0, 1.025, 0.0), Basis.IDENTITY, "timber", 40.0)
	s.add_box(Vector3(0.36, 0.14, 0.36), Vector3(0.0, 2.1, 0.0), Basis.IDENTITY, "stone_dark", 30.0)
	# Decor lantern hangs toward +Z and down; shift so the lamp sits on the cap.
	s.decorate("lantern", Vector3(0.0, 2.55, -0.42), Basis.IDENTITY, GOLD, true)
	s.build()


func _shrub(pos: Vector3, scale: float, yaw: float) -> void:
	var s = host._new_structure("Shrub", pos, yaw)
	s.add_cyl(1.45 * scale, 0.85 * scale, Vector3(0.0, 0.42 * scale, 0.0), "leaf", 32.0, true)
	s.add_cyl(0.85 * scale, 0.65 * scale, Vector3(0.18 * scale, 0.62 * scale, 0.08 * scale), "leaf", 24.0, true)
	s.build()


# ---------------------------------------------------------------------------
# Shared building blocks
# ---------------------------------------------------------------------------

func _posts(s, w: float, d: float, h: float, post: float, mat: String, hp: float) -> void:
	var hx := w * 0.5
	var hz := d * 0.5
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			s.add_box(Vector3(post, h, post), Vector3(float(sx) * (hx - post * 0.5), h * 0.5, float(sz) * (hz - post * 0.5)), Basis.IDENTITY, mat, hp)


func _ring_beams(s, w: float, d: float, h: float, post: float) -> void:
	var y := h - 0.02
	var bh := 0.26
	s.add_box(Vector3(w - post, bh, 0.22), Vector3(0.0, y, d * 0.5 - post * 0.45), Basis.IDENTITY, "timber", 70.0)
	s.add_box(Vector3(w - post, bh, 0.22), Vector3(0.0, y, -(d * 0.5 - post * 0.45)), Basis.IDENTITY, "timber", 70.0)
	s.add_box(Vector3(0.22, bh, d - post), Vector3(-(w * 0.5 - post * 0.7), y, 0.0), Basis.IDENTITY, "timber", 70.0)
	s.add_box(Vector3(0.22, bh, d - post), Vector3(w * 0.5 - post * 0.7, y, 0.0), Basis.IDENTITY, "timber", 70.0)


## Wall run. Door clears the lower rows of the centre column. The top row of
## every other column becomes a window mark. The lowest `base_rows` use stone.
func _facade(s, start: Vector3, dir: Vector3, length: float, rows: int, rh: float, thick: float, mat: String, base_mat: String, base_rows: int, hp: float, col_w: float, door_rows: int, window_row: int) -> void:
	var cols := maxi(1, int(roundf(length / col_w)))
	var cw := length / float(cols)
	var door_col := int(float(cols) / 2.0)
	var along_x := absf(dir.x) > 0.5
	for r in rows:
		for c in cols:
			var ctr := start + dir * ((float(c) + 0.5) * cw) + Vector3(0.0, (float(r) + 0.5) * rh, 0.0)
			if door_rows > 0 and c == door_col and r < door_rows:
				continue
			if window_row >= 0 and r == window_row and c != door_col:
				s.marks.append({"pos": ctr, "along_x": along_x, "w": cw * 0.92, "h": rh * 0.82})
				continue
			var use := base_mat if r < base_rows else mat
			var dimv := Vector3(cw * 0.97, rh * 0.96, thick) if along_x else Vector3(thick, rh * 0.96, cw * 0.97)
			s.add_box(dimv, ctr, Basis.IDENTITY, use, hp)


func _curved_gable(s, w: float, d: float, h: float, mat: String, wall_mat: String, hp: float) -> float:
	var hx := w * 0.5
	var hz := d * 0.5
	var over := 0.62
	var profile := [Vector2(0.16, 1.58), Vector2(hz * 0.52, 0.74), Vector2(hz * 0.98, 0.16), Vector2(hz + over, 0.4)]
	var cols := 2
	var cw := w / float(cols)
	var th := 0.18
	for sgn in [-1.0, 1.0]:
		for b in profile.size() - 1:
			var p0: Vector2 = profile[b]
			var p1: Vector2 = profile[b + 1]
			var seg := Vector3(0.0, p1.y - p0.y, (p1.x - p0.x) * float(sgn))
			var slope := seg.length()
			var u := seg / slope
			var ya := u.cross(Vector3.RIGHT).normalized()
			if ya.y < 0.0:
				ya = -ya
			var bas := Basis(Vector3.RIGHT, ya, u)
			var mid := Vector3(0.0, h + (p0.y + p1.y) * 0.5, float(sgn) * (p0.x + p1.x) * 0.5)
			for c in cols:
				var ctr := mid + Vector3(-hx + (float(c) + 0.5) * cw, 0.0, 0.0) + ya * (th * 0.35)
				s.add_box(Vector3(cw * 0.99, th, slope * 1.18), ctr, bas, mat, hp)
	var rise: float = profile[0].y
	for sx in [-1.0, 1.0]:
		for k in 2:
			var span := d * (0.8 - float(k) * 0.32)
			var yy := h + (float(k) + 0.5) * rise / 2.0
			s.add_box(Vector3(0.3, rise / 2.0 * 0.95, maxf(span, 0.4)), Vector3(float(sx) * (hx - 0.16), yy, 0.0), Basis.IDENTITY, wall_mat, hp * 0.8)
	return h + rise


func _shed_roof(s, w: float, z_back: float, y_back: float, z_front: float, y_front: float, mat: String, hp: float) -> void:
	var cols := 2
	var cw := (w + 0.3) / float(cols)
	var z_mid := lerpf(z_back, z_front, 0.58)
	var y_mid := lerpf(y_back, y_front, 0.55)
	var samples := [Vector2(z_back, y_back), Vector2(z_mid, y_mid), Vector2(z_front, y_front), Vector2(z_front + 0.5, y_front + 0.26)]
	var th := 0.16
	for b in samples.size() - 1:
		var p0: Vector2 = samples[b]
		var p1: Vector2 = samples[b + 1]
		var seg := Vector3(0.0, p1.y - p0.y, p1.x - p0.x)
		var slope := seg.length()
		var u := seg / slope
		var ya := u.cross(Vector3.RIGHT).normalized()
		if ya.y < 0.0:
			ya = -ya
		var bas := Basis(Vector3.RIGHT, ya, u)
		var mid := Vector3(0.0, (p0.y + p1.y) * 0.5, (p0.x + p1.x) * 0.5)
		for c in cols:
			var ctr := mid + Vector3(-(w + 0.3) * 0.5 + (float(c) + 0.5) * cw, 0.0, 0.0) + ya * (th * 0.35)
			s.add_box(Vector3(cw * 0.98, th, slope * 1.16), ctr, bas, mat, hp)


func _cone_roof(s, y: float, rim: float, apex_h: float, sides: int, mat: String, hp: float) -> void:
	for i in sides:
		var a := (float(i) + 0.5) * TAU / float(sides)
		var outward := Vector3(cos(a), 0.0, sin(a))
		var tdir := Vector3(-sin(a), 0.0, cos(a))
		var p0 := outward * rim + Vector3(0.0, y, 0.0)
		var v := Vector3(0.0, y + apex_h, 0.0) - p0
		var slope := v.length()
		var u := v / slope
		var ya := u.cross(tdir).normalized()
		if ya.y < 0.0:
			ya = -ya
		var bas := Basis(tdir, ya, u)
		for j in 2:
			var k := (float(j) + 0.5) * 0.5
			var width := 2.0 * rim * (1.0 - float(j) * 0.46) * tan(PI / float(sides)) * 1.08
			s.add_box(Vector3(width, 0.14, slope * 0.56), p0 + u * (slope * k), bas, mat, hp)


func _ring(s, y: float, radius: float, n: int, h: float, thick: float, mat: String, offset: bool, hp: float) -> void:
	host._ring(s, y, radius, n, h, thick, mat, offset, hp)


func _dress_openings(s) -> void:
	for m in s.marks:
		var mp: Vector3 = m["pos"]
		var ax: bool = m["along_x"]
		var wb := Basis.IDENTITY if ax else Basis(Vector3.UP, PI * 0.5)
		s.decorate("window", mp, wb * Basis.from_scale(Vector3(m["w"], m["h"], 1.0)), GOLD)


# ---------------------------------------------------------------------------
# Ground dressing (visual only, not rigid bodies)
# ---------------------------------------------------------------------------

func _path(size: Vector3, pos: Vector3, yaw: float = 0.0) -> void:
	_ensure_path_mat()
	var key := "%.2f_%.2f_%.2f" % [size.x, size.y, size.z]
	if not _path_meshes.has(key):
		var bm := BoxMesh.new()
		bm.size = size
		_path_meshes[key] = bm
	var mi := MeshInstance3D.new()
	mi.mesh = _path_meshes[key]
	mi.material_override = _path_mat
	mi.position = pos
	mi.rotation.y = yaw
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(mi)


func _path_between(a: Vector3, b: Vector3, width: float) -> void:
	var flat := Vector3(b.x - a.x, 0.0, b.z - a.z)
	var length := flat.length()
	if length < 0.2:
		return
	var mid := (a + b) * 0.5
	mid.y = maxf(a.y, b.y)
	_path(Vector3(width, 0.03, length), mid, atan2(flat.x, flat.z))


func _ensure_path_mat() -> void:
	if _path_mat != null:
		return
	var n := FastNoiseLite.new()
	n.seed = 11
	n.noise_type = FastNoiseLite.TYPE_CELLULAR
	n.frequency = 0.42
	n.fractal_octaves = 2
	n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	var tex := NoiseTexture2D.new()
	tex.width = 128
	tex.height = 128
	tex.seamless = true
	tex.noise = n
	_path_mat = StandardMaterial3D.new()
	_path_mat.albedo_color = Color(0.4, 0.38, 0.52)
	_path_mat.albedo_texture = tex
	_path_mat.roughness = 0.9
	_path_mat.uv1_triplanar = true
	_path_mat.uv1_scale = Vector3(0.62, 0.62, 0.62)
