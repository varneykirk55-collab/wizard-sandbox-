extends Node
## Reusable magical decorations (autoload "Decor"). Visual only: no collision,
## no health. Each decoration is parented to the mesh of one destructible
## piece, so it rides along when that piece breaks loose, shrinks with it when
## it is consumed, vanishes when it shatters, and is recreated on rebuild.
##
## Kinds: window, lantern, crystal, finial, curl, rune, sign.
## Local frame: origin at the attach point, +Z out of the wall, +Y up.

var _mats: Dictionary = {}
var _meshes: Dictionary = {}


func _ready() -> void:
	_mats["iron"] = _plain(Color(0.08, 0.08, 0.11), 0.6, 0.5, Color(0, 0, 0), 0.0)
	_mats["timber"] = _plain(Color(0.2, 0.13, 0.11), 0.0, 0.85, Color(0, 0, 0), 0.0)
	_mats["gold"] = _plain(Color(0.95, 0.72, 0.28), 0.9, 0.3, Color(0.7, 0.45, 0.12), 0.45)


func attach(piece, kind: String, xform: Transform3D, tint: Color, lit: bool) -> void:
	var root := Node3D.new()
	root.transform = xform
	piece.mesh_instance.add_child(root)
	match kind:
		"window":
			_add(root, _box(0.84, 0.84, 0.07), _glow(tint, 2.6), Vector3.ZERO)
			_add(root, _box(0.07, 0.92, 0.12), _mats["timber"], Vector3.ZERO)
			_add(root, _box(0.92, 0.07, 0.12), _mats["timber"], Vector3.ZERO)
		"lantern":
			_add(root, _box(0.06, 0.06, 0.55), _mats["iron"], Vector3(0.0, 0.0, 0.27))
			_add(root, _box(0.025, 0.2, 0.025), _mats["iron"], Vector3(0.0, -0.12, 0.5))
			_add(root, _cone(0.17, 0.12, 4), _mats["iron"], Vector3(0.0, -0.26, 0.5))
			_add(root, _box(0.2, 0.26, 0.2), _glow(tint, 4.0), Vector3(0.0, -0.45, 0.5))
			if lit:
				_light(root, tint, 1.8, 9.0, Vector3(0.0, -0.45, 0.65))
		"crystal":
			var g := _glow(tint, 3.5)
			_add(root, _cone(0.2, 1.1, 5), g, Vector3(0.0, 0.5, 0.0))
			_add(root, _cone(0.14, 0.75, 5), g, Vector3(0.22, 0.3, 0.05), Vector3(0.0, 0.0, -0.45))
			_add(root, _cone(0.12, 0.6, 5), g, Vector3(-0.18, 0.25, 0.12), Vector3(0.3, 0.0, 0.5))
			if lit:
				_light(root, tint, 1.6, 8.0, Vector3(0.0, 0.8, 0.0))
		"finial":
			_add(root, _sphere(0.11), _mats["gold"], Vector3(0.0, 0.06, 0.0))
			_add(root, _cone(0.09, 0.6, 8), _mats["gold"], Vector3(0.0, 0.4, 0.0))
		"curl":
			_add(root, _cone(0.12, 0.85, 6), _mats["gold"], Vector3(0.0, 0.0, 0.3), Vector3(PI * 0.5, 0.0, 0.0))
		"rune":
			var r := _glow(tint, 3.0)
			_add(root, _torus(0.22, 0.27), r, Vector3.ZERO, Vector3(PI * 0.5, 0.0, 0.0))
			_add(root, _box(0.04, 0.3, 0.03), r, Vector3.ZERO)
			_add(root, _box(0.2, 0.04, 0.03), r, Vector3(0.0, 0.05, 0.0), Vector3(0.0, 0.0, 0.6))
			_add(root, _box(0.2, 0.04, 0.03), r, Vector3(0.0, -0.05, 0.0), Vector3(0.0, 0.0, -0.6))
		"sign":
			_add(root, _box(0.05, 0.05, 1.0), _mats["iron"], Vector3(0.0, 0.0, 0.5))
			_add(root, _box(0.06, 0.5, 0.8), _mats["timber"], Vector3(0.0, -0.38, 0.55))
			_add(root, _box(0.09, 0.26, 0.26), _glow(tint, 3.0), Vector3(0.0, -0.38, 0.55), Vector3(PI * 0.25, 0.0, 0.0))


## A piece carrying decorations has broken loose: its lights go out.
func on_loosened(piece) -> void:
	for l in piece.mesh_instance.find_children("*", "OmniLight3D", true, false):
		var tw: Tween = l.create_tween()
		tw.tween_property(l, "light_energy", 0.0, 0.5)


func _add(root: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)


func _light(root: Node3D, color: Color, energy: float, rng: float, pos: Vector3) -> void:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng
	l.omni_attenuation = 1.5
	l.shadow_enabled = false
	l.position = pos
	root.add_child(l)


func _plain(color: Color, metallic: float, rough: float, emission: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = rough
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = energy
	return m


func _glow(tint: Color, energy: float) -> StandardMaterial3D:
	var key := "glow_%s_%.1f" % [tint.to_html(false), energy]
	if not _mats.has(key):
		_mats[key] = _plain(Color(tint.r * 0.35, tint.g * 0.35, tint.b * 0.35), 0.0, 0.4, tint, energy)
	return _mats[key]


func _box(x: float, y: float, z: float) -> Mesh:
	var key := "b_%.3f_%.3f_%.3f" % [x, y, z]
	if not _meshes.has(key):
		var m := BoxMesh.new()
		m.size = Vector3(x, y, z)
		_meshes[key] = m
	return _meshes[key]


func _cone(radius: float, height: float, segs: int) -> Mesh:
	var key := "c_%.3f_%.3f_%d" % [radius, height, segs]
	if not _meshes.has(key):
		var m := CylinderMesh.new()
		m.top_radius = 0.0
		m.bottom_radius = radius
		m.height = height
		m.radial_segments = segs
		m.rings = 1
		_meshes[key] = m
	return _meshes[key]


func _sphere(radius: float) -> Mesh:
	var key := "s_%.3f" % radius
	if not _meshes.has(key):
		var m := SphereMesh.new()
		m.radius = radius
		m.height = radius * 2.0
		m.radial_segments = 12
		m.rings = 6
		_meshes[key] = m
	return _meshes[key]


func _torus(inner: float, outer: float) -> Mesh:
	var key := "t_%.3f_%.3f" % [inner, outer]
	if not _meshes.has(key):
		var m := TorusMesh.new()
		m.inner_radius = inner
		m.outer_radius = outer
		m.rings = 20
		m.ring_segments = 6
		_meshes[key] = m
	return _meshes[key]
