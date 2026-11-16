extends Node3D
## A building assembled from destructible pieces. Keeps the blueprint (specs)
## so it can be rebuilt, links pieces into a support graph for secondary
## collapse, and restores itself 180 s after it was first damaged.

var specs: Array = []
var decor: Array = []     # decorations riding on pieces (see Decor autoload)
var marks: Array = []     # builder notes, e.g. window openings
var pieces: Array = []
var total := 0
var loose_count := 0
var damaged_at := 0.0
var last_touch := -100.0
var center := Vector3.ZERO
var radius := 1.0


func add_box(dim: Vector3, pos: Vector3, bas: Basis = Basis.IDENTITY, mat: String = "stone", hp: float = 100.0, density: float = 1.0) -> void:
	specs.append({"dim": dim, "kind": 0, "mat": mat, "hp": hp, "density": density, "xform": Transform3D(bas, pos)})


func add_cyl(diameter: float, height: float, pos: Vector3, mat: String = "stone", hp: float = 100.0, cone: bool = false, density: float = 1.0) -> void:
	specs.append({"dim": Vector3(diameter, height, diameter), "kind": 2 if cone else 1, "mat": mat, "hp": hp, "density": density, "xform": Transform3D(Basis.IDENTITY, pos)})


## Attaches a decoration to whichever piece is closest to `pos` (structure
## space). Call after the pieces it should ride on have been added.
func decorate(kind: String, pos: Vector3, bas: Basis = Basis.IDENTITY, tint: Color = Color(1, 1, 1), lit: bool = false) -> void:
	var best := -1
	var best_d := 1.0e9
	for i in specs.size():
		var xf: Transform3D = specs[i]["xform"]
		var d: Vector3 = specs[i]["dim"]
		var lp := xf.affine_inverse() * pos
		var h := d * 0.5
		var cl := Vector3(clampf(lp.x, -h.x, h.x), clampf(lp.y, -h.y, h.y), clampf(lp.z, -h.z, h.z))
		var dist := lp.distance_to(cl)
		if dist < best_d:
			best_d = dist
			best = i
	if best < 0:
		return
	var pxf: Transform3D = specs[best]["xform"]
	decor.append({"piece": best, "kind": kind, "xform": pxf.affine_inverse() * Transform3D(bas, pos), "tint": tint, "lit": lit})


## (Re)creates every piece from the blueprint.
func build() -> void:
	for p in pieces:
		if is_instance_valid(p):
			DM.unregister_debris(p)
			p.queue_free()
	pieces.clear()
	loose_count = 0
	total = specs.size()
	var aabbs: Array = []
	var bounds := AABB()
	for i in specs.size():
		var s: Dictionary = specs[i]
		var d: Vector3 = s["dim"]
		var xf: Transform3D = s["xform"]
		var p = DM.new_piece(d, s["kind"], s["mat"], s["hp"], s["density"])
		p.structure = self
		add_child(p)
		p.transform = xf
		pieces.append(p)
		var box: AABB = xf * AABB(-d * 0.5, d)
		aabbs.append(box)
		if i == 0:
			bounds = box
		else:
			bounds = bounds.merge(box)
	_link_supports(aabbs)
	for dc in decor:
		Decor.attach(pieces[dc["piece"]], dc["kind"], dc["xform"], dc["tint"], dc["lit"])
	center = global_transform * bounds.get_center()
	radius = bounds.size.length() * 0.5


func _link_supports(aabbs: Array) -> void:
	var n := pieces.size()
	for i in n:
		var b: AABB = aabbs[i]
		var pi = pieces[i]
		pi.grounded = b.position.y < 0.2
		if pi.grounded:
			continue
		var bc := b.get_center()
		for j in n:
			if i == j:
				continue
			var a: AABB = aabbs[j]
			if a.get_center().y >= bc.y - 0.1:
				continue
			if b.position.y - a.end.y > 0.3:
				continue
			var ox := minf(a.end.x, b.end.x) - maxf(a.position.x, b.position.x)
			var oz := minf(a.end.z, b.end.z) - maxf(a.position.z, b.position.z)
			if ox > 0.02 and oz > 0.02:
				pi.supporters.append(pieces[j])
				pieces[j].dependents.append(pi)
		if pi.supporters.is_empty():
			# Nothing underneath (lintels, window headers, fence rails):
			# hang on to whatever it touches sideways.
			var grown := b.grow(0.06)
			for j in n:
				if i != j and grown.intersects(aabbs[j]):
					pi.supporters.append(pieces[j])
					pieces[j].dependents.append(pi)


func touch() -> void:
	last_touch = DM.now


func on_piece_loosened(piece) -> void:
	if loose_count == 0:
		damaged_at = DM.now
	loose_count += 1
	last_touch = DM.now
	Decor.on_loosened(piece)
	for d in piece.dependents:
		if is_instance_valid(d) and not d.is_loose:
			d.check_support()


## Called about once a second by the destruction manager.
func tick() -> void:
	if loose_count == 0:
		return
	if DM.now - damaged_at < DM.RESTORE_TIME:
		return
	# Never restore while a spell is still working on this structure.
	if DM.now - last_touch < 4.0:
		return
	if DM.player != null:
		var pp: Vector3 = DM.player.global_position
		if pp.distance_to(center) < radius + 1.5:
			return
	build()
	FX.emit("restore_sparkle", center, maxf(1.0, radius * 0.3))
	AudioManager.play_at("chime", center, -4.0, 1.0, 20.0)
