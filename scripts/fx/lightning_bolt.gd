extends MeshInstance3D
## Jagged, branching, flickering lightning bolt built from camera-facing ribbons.
## Geometry is regenerated many times per second so the arcs writhe.

var from := Vector3.ZERO
var to := Vector3.ZERO
var width := 0.6
var branches := 3
var life := 0.32
var jag := 0.16

var _t := 0.0
var _regen := 0.0
var _im: ImmediateMesh


func _ready() -> void:
	_im = ImmediateMesh.new()
	mesh = _im
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(Vector3(-500, -100, -500), Vector3(1000, 600, 1000))
	_build()


func _process(delta: float) -> void:
	_t += delta
	_regen -= delta
	if _t >= life:
		queue_free()
		return
	if _regen <= 0.0:
		_regen = 0.045
		_build()


func _build() -> void:
	_im.clear_surfaces()
	var cam := get_viewport().get_camera_3d()
	var cam_pos := Vector3(0.0, 2.0, 0.0)
	if cam != null:
		cam_pos = cam.global_position
	var w := width * (1.0 - pow(_t / life, 2.0))
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	_strand(from, to, w, branches, cam_pos, 0)
	_im.surface_end()


func _strand(a: Vector3, b: Vector3, w: float, n_branch: int, cam_pos: Vector3, depth: int) -> void:
	var pts := _jagged(a, b, 5 if depth == 0 else 3)
	for i in pts.size() - 1:
		_quad(pts[i], pts[i + 1], w, cam_pos)
	if depth >= 2 or pts.size() < 4:
		return
	var dir := (b - a).normalized()
	var length := a.distance_to(b)
	for k in n_branch:
		var idx := randi_range(1, pts.size() - 2)
		var start: Vector3 = pts[idx]
		var rnd := Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5).normalized()
		var bdir := (dir + rnd * 0.9).normalized()
		var blen := length * randf_range(0.12, 0.3)
		_strand(start, start + bdir * blen, w * 0.5, 1 if depth == 0 else 0, cam_pos, depth + 1)


func _jagged(a: Vector3, b: Vector3, iterations: int) -> PackedVector3Array:
	var pts := PackedVector3Array([a, b])
	var disp := a.distance_to(b) * jag
	for it in iterations:
		var next := PackedVector3Array()
		for i in pts.size() - 1:
			var p0: Vector3 = pts[i]
			var p1: Vector3 = pts[i + 1]
			var mid := (p0 + p1) * 0.5 + Vector3(randf() - 0.5, (randf() - 0.5) * 0.4, randf() - 0.5) * disp
			next.append(p0)
			next.append(mid)
		next.append(pts[pts.size() - 1])
		pts = next
		disp *= 0.5
	return pts


func _quad(p0: Vector3, p1: Vector3, w: float, cam_pos: Vector3) -> void:
	var d := p1 - p0
	var side := d.cross(cam_pos - p0).normalized() * w
	if side.length_squared() < 0.000001:
		side = Vector3.RIGHT * w
	# Slight overlap along the strand hides the joints.
	var a := p0 - d * 0.08
	var b := p1 + d * 0.08
	_vert(a - side, Vector2(0.0, 0.0))
	_vert(a + side, Vector2(1.0, 0.0))
	_vert(b + side, Vector2(1.0, 1.0))
	_vert(a - side, Vector2(0.0, 0.0))
	_vert(b + side, Vector2(1.0, 1.0))
	_vert(b - side, Vector2(0.0, 1.0))


func _vert(p: Vector3, uv: Vector2) -> void:
	_im.surface_set_uv(uv)
	_im.surface_add_vertex(p)
