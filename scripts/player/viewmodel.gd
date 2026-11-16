extends CanvasLayer
## First-person wizard hands and staff.
##
## Drawn in an isolated SubViewport and composited over the world, so the
## viewmodel never clips the near plane or into walls, and it stays correct at
## any height, pitch or speed (including flight). The player camera is not moved.
##
## INTEGRATION (scripts/player/player.gd, visual only)
## Before: primitive capsule hands and a spell-colored orb were built and bobbed
## inside player.gd. Casts launched from that orb.
## After: this node owns the meshes, gestures and bob. player.gd still runs
## movement, look, camera shake, aim and casting. The only shared hook is the
## Marker3D `player._orb` (camera child): this script places it on the casting
## hand, and the existing `caster.press(_orb.global_position, ...)` line is
## unchanged. Walk / sprint bob is derived here from `velocity` and
## `is_on_floor()` — movement code is not edited.
##
## Spell hook: connects itself to `caster.cast` and `caster.spell_changed`.
## Each cast plays a hand gesture and kicks the crystal's emission. Thunder and
## Inferno hold their channeling pose while `cast` is held. Audio, rumble,
## timings and spell scripts are untouched.
##
## Screenshot pass (not used in normal play):
##   godot --path . -- --capture /opt/cursor/artifacts

const MeshLib := preload("res://scripts/player/viewmodel_mesh.gd")

# Same speeds player.gd already accelerates toward. Not written back.
const MOVE_WALK := 6.5
const MOVE_SPRINT := 12.0

# Positive curl closes the fist. Flip this one value if fingers close backwards.
const CURL_SIGN := -1.0

const CAST_HOME := Vector3(0.28, -0.16, -0.58)
const STAFF_HOME := Vector3(-0.34, -0.20, -0.56)
# Shoulder sockets below the eyes, so the sleeves come up from the body.
const RIGHT_SHOULDER := Vector3(0.18, -0.58, 0.02)
const LEFT_SHOULDER := Vector3(-0.22, -0.62, 0.04)
const VIEW_LAYER := 2
# Keep the crosshair readable. Normalized radius around the screen center.
const RETICLE_CLEAR := 0.15

var player: CharacterBody3D
var _vm_cam: Camera3D
var _vp: SubViewport
var _rig: Node3D
var _cast_anchor: Node3D
var _staff_anchor: Node3D
var _cast_pivot: Node3D
var _staff_pivot: Node3D
var _staff_model: Node3D
var _cast_fingers: Array = []
var _cast_thumb: Array = []
var _staff_fingers: Array = []
var _staff_thumb: Array = []
var _cast_point: Node3D
var _guard_cast: Array = []
var _guard_staff: Array = []
var _crystal: Node3D
var _crystal_mat: ShaderMaterial
var _wood_mat: ShaderMaterial
var _halo_mat: ShaderMaterial
var _halo2_mat: ShaderMaterial
var _wisp: MeshInstance3D
var _wisp_mat: ShaderMaterial
var _wisp_light: OmniLight3D
var _crystal_light: OmniLight3D
var _motes: GPUParticles3D
var _sparks: GPUParticles3D

var _shown: Pose
var _gesture := ""
var _gesture_t := 0.0
var _gesture_len := 0.0
var _hold := ""
var _gestures := {}
var _time := 0.0
var _bob_phase := 0.0
var _prev_vel := Vector3.ZERO
var _lag := Vector3.ZERO
var _crystal_kick := 0.0
var _spell_flash := 0.0
var _staff_squeeze := 0.0
var _staff_react := 0.0
var _pulse := 0.0
var _spell_color := Color(1.0, 0.5, 0.12)
var _hooked := false
var _aspect := 1.777

var _cap := false
var _cap_dir := ""
var _cap_t := 0.0
var _cap_i := 0
var _cap_events: Array = []
var _shot_queue: Array = []


class Pose:
	var pos := Vector3.ZERO
	var rot := Vector3.ZERO
	var spread := 0.0
	var thumb := Vector2.ZERO
	var curls: Array = []

	func dup() -> Pose:
		var copy := Pose.new()
		copy.pos = pos
		copy.rot = rot
		copy.spread = spread
		copy.thumb = thumb
		for c in curls:
			copy.curls.append(c)
		return copy


func bind(body: CharacterBody3D) -> void:
	player = body
	layer = 5
	_build_viewport()
	_build_materials()
	_build_gestures()
	_build_rig()
	_shown = _pose_idle()
	_apply_cast_pose(_shown)
	_apply_grip()
	_setup_capture()


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	_time += delta
	_sync_view()
	_ensure_hooks()
	_decay(delta)
	if _gesture != "":
		_gesture_t += delta
		if _gesture_t >= _gesture_len:
			_gesture = ""
	if not Input.is_action_pressed("cast"):
		_hold = ""
	_animate(delta)
	_locomotion(delta)
	_keep_reticle_clear()
	_update_cast_origin()
	_update_crystal()
	_update_wisp()
	if _motes:
		var at := _crystal.global_position
		_motes.global_position = at
		_sparks.global_position = at
	if _cap:
		_capture(delta)


# ---------------------------------------------------------------------------
# Viewport. Own world, transparent, composited under the HUD (layer 10).
# ---------------------------------------------------------------------------

func _build_viewport() -> void:
	var container := SubViewportContainer.new()
	container.name = "ViewmodelLayer"
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(container)

	_vp = SubViewport.new()
	_vp.name = "ViewmodelViewport"
	# Isolated world so this environment cannot replace the game sky.
	# The arm rig is parented to the player camera below; its pose is copied
	# onto this camera every frame so the overlay stays locked while flying.
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.handle_input_locally = false
	_vp.gui_disable_input = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.msaa_3d = Viewport.MSAA_2X
	# SubViewportContainer with stretch owns the viewport size. Setting it
	# after the container is attached is ignored and spams a warning.
	_vp.size = _viewport_size()
	container.add_child(_vp)

	var env := Environment.new()
	# BG_CANVAS leaves the clear color transparent. A sky or BG_COLOR would
	# punch an opaque rectangle over the game view.
	env.background_mode = Environment.BG_CANVAS
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.38, 0.52)
	env.ambient_light_energy = 0.7
	# Linear tonemap. ACES was pushing the ruby emission toward white.
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.0
	env.glow_enabled = false
	env.fog_enabled = false
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	_vp.add_child(world_env)

	_vm_cam = Camera3D.new()
	_vm_cam.fov = 80.0
	_vm_cam.near = 0.02
	_vm_cam.far = 4.0
	_vm_cam.current = true
	_vp.add_child(_vm_cam)

	# Match the night scene: cool moon from behind, warm fill on the hands.
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-35.0, -160.0, 0.0)
	moon.light_color = Color(0.62, 0.70, 1.0)
	moon.light_energy = 0.38
	moon.shadow_enabled = false
	moon.light_cull_mask = VIEW_LAYER
	_vm_cam.add_child(moon)
	_omni(Color(1.0, 0.84, 0.7), 0.55, 2.8, Vector3(0.12, 0.02, -0.16))
	_omni(Color(0.5, 0.58, 0.95), 0.28, 2.6, Vector3(-0.35, 0.15, -0.85))


func _omni(color: Color, energy: float, rng: float, pos: Vector3) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = rng
	light.omni_attenuation = 1.15
	light.shadow_enabled = false
	light.light_cull_mask = VIEW_LAYER
	light.light_specular = 0.35
	light.position = pos
	_vm_cam.add_child(light)
	return light


func _sync_view() -> void:
	var sz := _vp.size
	if sz.x < 2:
		sz = _viewport_size()
	_aspect = float(sz.x) / float(maxi(sz.y, 1))
	# Orientation lock. The arms are a child of this camera, so pitch, yaw
	# and flight stay matched without depending on ground height.
	_vm_cam.global_transform = Transform3D(player.cam.global_transform.basis, Vector3.ZERO)
	if absf(player.cam.fov - _vm_cam.fov) > 0.01:
		_vm_cam.fov = player.cam.fov


func _viewport_size() -> Vector2i:
	var sz := Vector2i(get_viewport().size)
	if sz.x < 2 or sz.y < 2:
		return Vector2i(1600, 900)
	return sz


# ---------------------------------------------------------------------------
# Rig
# ---------------------------------------------------------------------------

func _build_materials() -> void:
	_crystal_mat = _mat("res://shaders/viewmodel_crystal.gdshader", {"intensity": 0.75})
	_wood_mat = _mat("res://shaders/viewmodel_wood.gdshader", {"head_glow": 0.16})
	_halo_mat = _mat("res://shaders/viewmodel_ruby_glow.gdshader", {"color": Color(0.55, 0.01, 0.045), "energy": 0.52, "power": 1.7})
	_halo2_mat = _mat("res://shaders/viewmodel_ruby_glow.gdshader", {"color": Color(0.42, 0.0, 0.04), "energy": 0.28, "power": 1.35})
	_wisp_mat = _mat("res://shaders/viewmodel_glow.gdshader", {"color": _spell_color, "energy": 0.0, "power": 1.5})


func _build_rig() -> void:
	_rig = Node3D.new()
	_rig.name = "Arms"
	# Parent under the overlay camera, which is transform-locked to the
	# player camera in _sync_view. A shared world would replace the game sky.
	_vm_cam.add_child(_rig)

	_cast_anchor = Node3D.new()
	_cast_anchor.name = "CastAnchor"
	_cast_anchor.position = CAST_HOME
	_rig.add_child(_cast_anchor)
	var cast_hand := _make_hand(_cast_anchor, 1.0, false)
	_cast_pivot = cast_hand["pivot"]
	_cast_fingers = cast_hand["fingers"]
	_cast_thumb = cast_hand["thumb"]
	_cast_point = cast_hand["cast_point"]
	_guard_cast = cast_hand["tips"]
	_connect_arm(_cast_anchor, 1.0)

	_staff_anchor = Node3D.new()
	_staff_anchor.name = "StaffAnchor"
	_staff_anchor.position = STAFF_HOME
	_rig.add_child(_staff_anchor)
	var staff_hand := _make_hand(_staff_anchor, -1.0, true)
	_staff_pivot = staff_hand["pivot"]
	_staff_fingers = staff_hand["fingers"]
	_staff_thumb = staff_hand["thumb"]
	_guard_staff = staff_hand["tips"]
	_connect_arm(_staff_anchor, -1.0)
	_build_staff(staff_hand["palm"])

	_motes = _make_particles(14, 1.6, 0.08, 0.035, Color(0.55, 0.04, 0.05, 0.45), Vector2(0.012, 0.028))
	_sparks = _make_particles(6, 0.7, 0.05, 0.08, Color(0.7, 0.06, 0.07, 0.5), Vector2(0.006, 0.012))


func _make_hand(anchor: Node3D, side: float, grip: bool) -> Dictionary:
	# Sleeve stays in camera space so casting rotates the hand, not a cone across the view.
	var pivot := Node3D.new()
	pivot.name = "Gesture"
	anchor.add_child(pivot)
	var orient := Node3D.new()
	orient.name = "Orient"
	orient.transform = Transform3D(_hand_basis(side, anchor.position), Vector3.ZERO)
	orient.scale = Vector3.ONE * 1.12
	if grip:
		orient.rotate_object_local(Vector3(1.0, 0.0, 0.0), deg_to_rad(-32.0))
	pivot.add_child(orient)

	var palm := Node3D.new()
	palm.name = "Palm"
	orient.add_child(palm)
	_mesh(MeshLib.palm(), _skin(), palm)

	var lengths := [
		Vector3(0.034, 0.024, 0.022),
		Vector3(0.037, 0.026, 0.023),
		Vector3(0.034, 0.024, 0.021),
		Vector3(0.026, 0.019, 0.017),
	]
	var radii := [
		Vector4(0.011, 0.0094, 0.0082, 0.0070),
		Vector4(0.0115, 0.0098, 0.0084, 0.0072),
		Vector4(0.0106, 0.0092, 0.0080, 0.0068),
		Vector4(0.0088, 0.0076, 0.0066, 0.0056),
	]
	var xs := [0.034, 0.012, -0.012, -0.036]
	var fingers: Array = []
	var tips: Array = []
	for i in 4:
		var joints := _add_finger(palm, Vector3(side * xs[i], 0.012, -0.066), lengths[i], radii[i])
		fingers.append(joints)
		tips.append(joints[2].get_node("Tip"))
	var thumb := _add_thumb(palm, side)
	tips.append(thumb[1].get_node("Tip"))
	var palm_mark := Marker3D.new()
	palm_mark.position = Vector3(0.0, 0.0, -0.04)
	palm.add_child(palm_mark)
	tips.append(palm_mark)
	var cast_point: Node3D = fingers[1][2].get_node("Tip")
	if not grip:
		_wisp = _styled(MeshInstance3D.new(), _sphere(0.045, 10))
		_wisp.material_override = _wisp_mat
		_wisp.position = Vector3(0.0, 0.0, -0.01)
		cast_point.add_child(_wisp)
		_wisp_light = OmniLight3D.new()
		_wisp_light.light_color = _spell_color
		_wisp_light.light_energy = 0.0
		_wisp_light.omni_range = 0.45
		_wisp_light.shadow_enabled = false
		_wisp_light.position = Vector3(0.0, 0.0, -0.01)
		cast_point.add_child(_wisp_light)
	return {"fingers": fingers, "thumb": thumb, "tips": tips, "cast_point": cast_point, "pivot": pivot, "palm": palm}


func _connect_arm(anchor: Node3D, side: float) -> void:
	# Sleeve runs from behind the shoulder (off the bottom of the view, where
	# the body is) to the wrist, so the hand is not a floating piece.
	var shoulder: Vector3 = LEFT_SHOULDER if side < 0.0 else RIGHT_SHOULDER
	var wrist: Vector3 = anchor.position
	var delta := wrist - shoulder
	var back := 0.48
	var sleeve := Node3D.new()
	sleeve.name = "Sleeve"
	sleeve.transform = Transform3D(_aim_basis(delta), shoulder - delta.normalized() * back)
	_rig.add_child(sleeve)
	_mesh(MeshLib.sleeve_span(delta.length() + back), _cloth(), sleeve)
	var reach := delta.length() + back
	var trim := _mesh(MeshLib.band(0.012, 0.040, 0.0), _trim(), sleeve)
	trim.position = Vector3(0.0, 0.0, reach - 0.03)
	var braid := _mesh(MeshLib.band(0.006, 0.043, 0.0), _gold(), sleeve)
	braid.position = Vector3(0.0, 0.0, reach - 0.012)


func _aim_basis(direction: Vector3) -> Basis:
	var z := direction.normalized()
	var x := z.cross(Vector3(0.0, 1.0, 0.2))
	if x.length() < 0.001:
		x = Vector3.RIGHT
	x = x.normalized()
	var y := z.cross(x).normalized()
	return Basis(x, y, z)


func _hand_basis(side: float, wrist: Vector3) -> Basis:
	# +Z runs from the wrist back into the sleeve, so the forearm and the hand meet.
	var shoulder: Vector3 = LEFT_SHOULDER if side < 0.0 else RIGHT_SHOULDER
	var into_sleeve := shoulder - wrist
	if into_sleeve.length() < 0.001:
		into_sleeve = Vector3(0.0, -1.0, 0.2)
	into_sleeve = into_sleeve.normalized()
	if side < 0.0:
		# Up and a little left, held away from the camera so the gem stays a gem.
		var x := Vector3(-0.45, 0.45, -0.45).normalized()
		var z := into_sleeve - x * into_sleeve.dot(x)
		if z.length() < 0.001:
			z = Vector3.DOWN
		z = z.normalized()
		var y := z.cross(x).normalized()
		return Basis(x, y, z)
	var z2 := into_sleeve
	var x2 := Vector3(-0.15, 0.2, -1.0).cross(z2)
	if x2.length() < 0.001:
		x2 = Vector3.RIGHT
	x2 = x2.normalized()
	var y2 := z2.cross(x2).normalized()
	return Basis(x2, y2, z2)


func _add_finger(parent: Node3D, origin: Vector3, lengths: Vector3, radii: Vector4) -> Array:
	var joints: Array = []
	var prev := parent
	var lens := [lengths.x, lengths.y, lengths.z]
	var rs := [radii.x, radii.y, radii.z, radii.w]
	for i in 3:
		var joint := Node3D.new()
		joint.name = "F%d" % i
		joint.position = origin if i == 0 else Vector3(0.0, 0.0, -lens[i - 1])
		prev.add_child(joint)
		var seg := _styled(MeshInstance3D.new(), MeshLib.finger_segment(lens[i], rs[i], rs[i + 1], i == 2))
		seg.material_override = _skin()
		joint.add_child(seg)
		if i == 2:
			var nail := _styled(MeshInstance3D.new(), _sphere(rs[3] * 0.85, 6))
			nail.material_override = _nail()
			nail.position = Vector3(0.0, rs[3] * 0.7, -lens[2] * 0.55)
			nail.scale = Vector3(1.15, 0.42, 1.4)
			joint.add_child(nail)
			var tip := Marker3D.new()
			tip.name = "Tip"
			tip.position = Vector3(0.0, 0.0, -lens[2])
			joint.add_child(tip)
		joints.append(joint)
		prev = joint
	return joints


func _add_thumb(parent: Node3D, side: float) -> Array:
	var root := Node3D.new()
	root.name = "Thumb"
	root.position = Vector3(side * 0.040, -0.006, -0.02)
	parent.add_child(root)
	var a := _styled(MeshInstance3D.new(), MeshLib.finger_segment(0.034, 0.013, 0.011, false))
	a.material_override = _skin()
	root.add_child(a)
	var mid := Node3D.new()
	mid.position = Vector3(0.0, 0.0, -0.032)
	root.add_child(mid)
	var b := _styled(MeshInstance3D.new(), MeshLib.finger_segment(0.026, 0.010, 0.008, true))
	b.material_override = _skin()
	mid.add_child(b)
	var tip := Marker3D.new()
	tip.name = "Tip"
	tip.position = Vector3(0.0, 0.0, -0.026)
	mid.add_child(tip)
	return [root, mid]


func _build_staff(pivot: Node3D) -> void:
	_staff_model = Node3D.new()
	_staff_model.name = "Staff"
	# Slide the haft into the curled fingers. Tuned with the grip pose.
	_staff_model.position = Vector3(0.0, -0.012, -0.05)
	pivot.add_child(_staff_model)
	_mesh(MeshLib.shaft(), _wood_mat, _staff_model)
	_mesh(MeshLib.prongs(), _wood_mat, _staff_model)
	_mesh(MeshLib.leather_wrap(), _leather(), _staff_model)
	_mesh(MeshLib.crown_ring(), _gold(), _staff_model)

	_crystal = Node3D.new()
	_crystal.name = "Crystal"
	_crystal.position = Vector3(0.64, 0.035, 0.0)
	_crystal.rotation_degrees = Vector3(24.0, 12.0, 18.0)
	_staff_model.add_child(_crystal)
	var gem := _styled(MeshInstance3D.new(), MeshLib.crystal(0.20, 0.074))
	gem.material_override = _crystal_mat
	_crystal.add_child(gem)
	var core := _styled(MeshInstance3D.new(), MeshLib.crystal(0.20, 0.074))
	core.material_override = _core_mat()
	core.position = Vector3(0.0, 0.012, 0.0)
	core.scale = Vector3(0.55, 0.55, 0.55)
	_crystal.add_child(core)
	# A tight shell, only slightly larger than the gem. A unit sphere here
	# previously read as a red sun and hid the facets.
	_crystal_light = OmniLight3D.new()
	_crystal_light.light_color = Color(0.85, 0.05, 0.08)
	_crystal_light.light_energy = 0.26
	_crystal_light.light_cull_mask = VIEW_LAYER
	_crystal_light.omni_range = 0.55
	_crystal_light.shadow_enabled = false
	_crystal.add_child(_crystal_light)

	var mid := Marker3D.new()
	mid.name = "ShaftMid"
	mid.position = Vector3(0.32, 0.0, 0.0)
	_staff_model.add_child(mid)
	_guard_staff.append(mid)
	_guard_staff.append(_crystal)


func _mesh(mesh: Mesh, mat: Material, parent: Node3D) -> MeshInstance3D:
	return _styled_mat(MeshInstance3D.new(), mesh, mat, parent)


func _styled(mi: MeshInstance3D, mesh: Mesh) -> MeshInstance3D:
	mi.mesh = mesh
	_finish(mi)
	return mi


func _styled_mat(mi: MeshInstance3D, mesh: Mesh, mat: Material, parent: Node3D) -> MeshInstance3D:
	mi.mesh = mesh
	mi.material_override = mat
	_finish(mi)
	parent.add_child(mi)
	return mi


func _finish(mi: MeshInstance3D) -> void:
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	mi.extra_cull_margin = 1.0
	mi.layers = VIEW_LAYER


func _sphere(radius: float, seg: int) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = seg
	mesh.rings = maxi(4, seg / 2)
	return mesh


# ---------------------------------------------------------------------------
# Materials
# ---------------------------------------------------------------------------

var _skin_mat: ShaderMaterial
var _nail_mat: ShaderMaterial
var _cloth_mat: ShaderMaterial
var _gold_mat: StandardMaterial3D
var _leather_mat: StandardMaterial3D


func _skin() -> Material:
	if _skin_mat == null:
		_skin_mat = _mat("res://shaders/viewmodel_skin.gdshader", {})
	return _skin_mat


func _nail() -> Material:
	if _nail_mat == null:
		_nail_mat = _skin().duplicate() as ShaderMaterial
		_nail_mat.set_shader_parameter("skin_color", Color(0.97, 0.8, 0.76))
		_nail_mat.set_shader_parameter("shade_color", Color(0.78, 0.5, 0.5))
	return _nail_mat


func _cloth() -> Material:
	if _cloth_mat == null:
		_cloth_mat = _mat("res://shaders/viewmodel_cloth.gdshader", {})
	return _cloth_mat


var _trim_mat: StandardMaterial3D
var _core_crystal: ShaderMaterial


func _trim() -> Material:
	if _trim_mat == null:
		_trim_mat = StandardMaterial3D.new()
		_trim_mat.albedo_color = Color(0.035, 0.016, 0.06)
		_trim_mat.roughness = 0.78
	return _trim_mat


func _core_mat() -> ShaderMaterial:
	if _core_crystal == null:
		_core_crystal = _mat("res://shaders/viewmodel_crystal.gdshader", {
			"ruby": Color(0.72, 0.02, 0.06),
			"core_color": Color(1.0, 0.08, 0.12),
			"intensity": 1.01,
		})
	return _core_crystal


func _gold() -> Material:
	if _gold_mat == null:
		_gold_mat = StandardMaterial3D.new()
		_gold_mat.albedo_color = Color(0.86, 0.66, 0.28)
		_gold_mat.metallic = 0.88
		_gold_mat.roughness = 0.32
	return _gold_mat


func _leather() -> Material:
	if _leather_mat == null:
		_leather_mat = StandardMaterial3D.new()
		_leather_mat.albedo_color = Color(0.28, 0.13, 0.07)
		_leather_mat.roughness = 0.72
	return _leather_mat


func _mat(path: String, params: Dictionary) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load(path)
	for key in params:
		mat.set_shader_parameter(key, params[key])
	return mat


func _make_particles(amount: int, life: float, radius: float, speed: float, color: Color, scale: Vector2) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = life
	particles.preprocess = 1.8
	particles.explosiveness = 0.0
	particles.local_coords = true
	particles.visibility_aabb = AABB(Vector3(-0.4, -0.4, -0.4), Vector3(0.8, 0.8, 0.8))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = radius
	pm.direction = Vector3(0.0, 1.0, 0.0)
	pm.spread = 32.0
	pm.initial_velocity_min = speed * 0.4
	pm.initial_velocity_max = speed
	pm.gravity = Vector3(0.0, 0.06, 0.0)
	pm.scale_min = scale.x
	pm.scale_max = scale.y
	pm.color = color
	particles.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(0.45, 0.04, 0.05, 0.55)
	mat.albedo_texture = _blob()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = mat
	particles.draw_pass_1 = quad
	particles.layers = VIEW_LAYER
	_vm_cam.add_child(particles)
	return particles


func _blob() -> Texture2D:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var dx := (float(x) + 0.5) / 32.0 - 0.5
			var dy := (float(y) + 0.5) / 32.0 - 0.5
			var a := clampf(1.0 - sqrt(dx * dx + dy * dy) * 2.0, 0.0, 1.0)
			a = a * a
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


# ---------------------------------------------------------------------------
# Animation
# ---------------------------------------------------------------------------

func _ensure_hooks() -> void:
	if _hooked or player.caster == null:
		return
	player.caster.cast.connect(_on_cast)
	player.caster.spell_changed.connect(_on_spell)
	_hooked = true
	_on_spell(player.caster.current)


func _on_cast(index: int) -> void:
	_crystal_kick = 1.0
	_spell_flash = 1.0
	_staff_squeeze = 1.0
	_staff_react = 1.0
	_pulse = 1.0
	match index:
		0:
			_begin("cataclysm", 0.52)
		1:
			_hold = "thunder"
			_gesture = ""
		2:
			_begin("gravity", 0.58)
		3:
			_hold = "inferno"
			_gesture = ""
		4:
			_begin("meteor", 0.66)


func _on_spell(index: int) -> void:
	_spell_color = player.caster.info[index]["color"]
	if _wisp_mat:
		_wisp_mat.set_shader_parameter("color", Vector3(_spell_color.r, _spell_color.g, _spell_color.b))
	if _wisp_light:
		_wisp_light.light_color = _spell_color
	_crystal_kick = maxf(_crystal_kick, 0.28)


func _begin(name: String, length: float) -> void:
	_gesture = name
	_gesture_t = 0.0
	_gesture_len = length
	_hold = ""


func _decay(delta: float) -> void:
	_crystal_kick = maxf(0.0, _crystal_kick - delta * 2.6)
	_spell_flash = maxf(0.0, _spell_flash - delta * 3.0)
	_staff_squeeze = maxf(0.0, _staff_squeeze - delta * 4.2)
	_staff_react = maxf(0.0, _staff_react - delta * 3.2)
	_pulse = maxf(0.0, _pulse - delta / 0.12)


func _animate(delta: float) -> void:
	var pose := _pose_idle()
	if _gesture != "":
		pose = _sample(_gestures[_gesture], _gesture_t)
	elif _hold == "thunder":
		var snap := sin(clampf(1.0 - _pulse, 0.0, 1.0) * PI)
		pose = _lerp_pose(_pose_thunder(), _pose_thunder_snap(), snap)
	elif _hold == "inferno":
		pose = _pose_inferno()
		pose.rot.z += sin(_time * 5.4) * 13.0
		pose.rot.y += cos(_time * 3.2) * 7.0
		pose.spread += sin(_time * 6.5) * 4.0
	if _gesture == "":
		pose = _idle_motion(pose, 0.4 if _hold != "" else 1.0)
	var sharp := 16.0 if (_gesture != "" or _hold != "") else 7.0
	_damp_pose(pose, sharp, delta)
	_apply_cast_pose(_shown)
	_apply_grip()


func _apply_cast_pose(pose: Pose) -> void:
	if _cast_fingers.is_empty():
		return
	var spread_dir := [-1.0, -0.3, 0.35, 1.0]
	for i in 4:
		var curls: Vector3 = pose.curls[i]
		_set_curl(_cast_fingers[i], curls, pose.spread * spread_dir[i])
	_set_thumb(_cast_thumb, pose.thumb, 1.0)


func _apply_grip() -> void:
	if _staff_fingers.is_empty():
		return
	var grips := [
		Vector3(88, 108, 78),
		Vector3(92, 114, 82),
		Vector3(96, 116, 84),
		Vector3(100, 110, 80),
	]
	var spread_dir := [8.0, 3.0, -3.0, -8.0]
	for i in 4:
		var curls: Vector3 = grips[i]
		curls.x += _staff_squeeze * 8.0
		curls.y += _staff_squeeze * 6.0
		_set_curl(_staff_fingers[i], curls, spread_dir[i])
	_set_thumb(_staff_thumb, Vector2(46.0 + _staff_squeeze * 8.0, 34.0 + _staff_squeeze * 5.0), -1.0)


func _set_curl(joints: Array, curls: Vector3, spread: float) -> void:
	var root: Node3D = joints[0]
	var mid: Node3D = joints[1]
	var tip: Node3D = joints[2]
	root.rotation_degrees = Vector3(CURL_SIGN * curls.x, spread, 0.0)
	mid.rotation_degrees = Vector3(CURL_SIGN * curls.y, 0.0, 0.0)
	tip.rotation_degrees = Vector3(CURL_SIGN * curls.z, 0.0, 0.0)


func _set_thumb(joints: Array, curls: Vector2, side: float) -> void:
	var root: Node3D = joints[0]
	var mid: Node3D = joints[1]
	root.rotation_degrees = Vector3(-42.0 + CURL_SIGN * curls.x, 68.0 * side, 18.0 * side)
	mid.rotation_degrees = Vector3(CURL_SIGN * curls.y, 0.0, 0.0)


func _locomotion(delta: float) -> void:
	var vel: Vector3 = player.velocity
	var horiz := Vector2(vel.x, vel.z).length()
	var grounded := player.is_on_floor()
	# Airborne / flying: keep a softer sway from horizontal speed instead of
	# footstep bob, so the rig never locks stiff and never assumes ground level.
	var step := 1.0 if grounded else (0.55 if horiz > MOVE_WALK else 0.28)
	var moving := clampf(horiz / MOVE_WALK, 0.0, 1.0)
	var sprint := smoothstep(MOVE_WALK + 1.0, MOVE_SPRINT - 1.0, horiz)
	var freq := lerpf(1.55, 2.5, sprint)
	_bob_phase += delta * TAU * freq * moving
	var amp := moving * step
	var sway_x := sin(_bob_phase * 0.5) * lerpf(0.008, 0.016, sprint) * amp
	var sway_y := absf(sin(_bob_phase)) * -1.0 * lerpf(0.010, 0.020, sprint) * amp
	var bob_pitch := cos(_bob_phase) * lerpf(0.6, 1.3, sprint) * amp
	var bob_roll := sin(_bob_phase * 0.5) * lerpf(0.8, 1.8, sprint) * amp
	var accel := (vel - _prev_vel) / maxf(delta, 0.0001)
	_prev_vel = vel
	var cam_basis: Basis = player.cam.global_transform.basis
	var local_accel: Vector3 = cam_basis.inverse() * Vector3(accel.x, 0.0, accel.z)
	var lag_target := Vector3(clampf(-local_accel.x * 0.004, -0.03, 0.03), clampf(-vel.y * 0.0035, -0.02, 0.02), clampf(-local_accel.z * 0.003, -0.02, 0.02))
	_lag = _lag.lerp(lag_target, 1.0 - exp(-6.0 * delta))
	var breathe := sin(_time * 1.35) * 0.0045
	_rig.position = Vector3(sway_x + _lag.x, sway_y + breathe + _lag.y, _lag.z)
	_rig.rotation_degrees = Vector3(bob_pitch, 0.0, bob_roll)
	var hand_y := sin(_bob_phase + 0.5) * lerpf(0.004, 0.008, sprint) * amp
	var staff_y := sin(_bob_phase + 2.0) * lerpf(0.004, 0.008, sprint) * amp
	# Keep translations small so the sleeves stay in the lower corners.
	_cast_anchor.position = CAST_HOME + _shown.pos * 0.35 + Vector3(0.0, hand_y, 0.0)
	_cast_anchor.rotation_degrees = Vector3.ZERO
	_cast_pivot.rotation_degrees = _shown.rot
	_staff_anchor.position = STAFF_HOME + Vector3(0.0, staff_y, 0.0)
	_staff_anchor.rotation_degrees = Vector3.ZERO
	_staff_pivot.rotation_degrees = Vector3(_staff_react * 5.0, sin(_time * 1.1) * 0.8, -_staff_react * 4.0 + sin(_bob_phase) * amp * 1.4)


func _keep_reticle_clear() -> void:
	_push_outside(_cast_anchor, _guard_cast, Vector2(0.6, -0.8))
	_push_outside(_staff_anchor, _guard_staff, Vector2(-0.7, 0.5))


func _push_outside(anchor: Node3D, points: Array, prefer: Vector2) -> void:
	var worst := 0.0
	var push := Vector3.ZERO
	for point in points:
		if point == null or not is_instance_valid(point):
			continue
		var local := _vm_cam.to_local((point as Node3D).global_position)
		var z := maxf(0.2, -local.z)
		var half_h := tan(deg_to_rad(_vm_cam.fov * 0.5)) * z
		var half_w := half_h * _aspect
		var ndc := Vector2(local.x / half_w, local.y / half_h)
		if ndc.length() >= RETICLE_CLEAR:
			continue
		var dir := ndc
		if dir.length() < 0.001:
			dir = prefer.normalized()
		else:
			dir = dir.normalized()
		var target := dir * RETICLE_CLEAR
		var delta := Vector3((target.x - ndc.x) * half_w, (target.y - ndc.y) * half_h, 0.0)
		var penalty := delta.length()
		if penalty > worst:
			worst = penalty
			push = delta
	if worst <= 0.0001:
		return
	var parent := anchor.get_parent() as Node3D
	var world_delta := _vm_cam.global_transform.basis * push
	anchor.position += parent.global_transform.basis.inverse() * world_delta


func _update_cast_origin() -> void:
	if player._orb == null or _cast_point == null:
		return
	var local := _vm_cam.to_local(_cast_point.global_position)
	local.x = clampf(local.x, -0.02, 0.55)
	local.y = minf(local.y, -0.06)
	local.z = minf(local.z, -0.28)
	player._orb.position = local


func _update_crystal() -> void:
	var breathe := 0.68 + 0.09 * sin(_time * 2.1)
	var intensity := breathe + _crystal_kick * 0.64
	_crystal_mat.set_shader_parameter("intensity", intensity)
	if _core_crystal:
		_core_crystal.set_shader_parameter("intensity", 0.86 + _crystal_kick * 0.30)
	_wood_mat.set_shader_parameter("head_glow", 0.135 + _crystal_kick * 0.30)
	_halo_mat.set_shader_parameter("energy", 0.315 + _crystal_kick * 0.15)
	_halo2_mat.set_shader_parameter("energy", 0.165 + _crystal_kick * 0.09)
	_crystal_light.light_energy = 0.165 + _crystal_kick * 0.225
	var s := 1.0 + _crystal_kick * 0.045
	_crystal.scale = Vector3(s, s, s)


func _update_wisp() -> void:
	if _wisp == null:
		return
	var energy := _spell_flash
	if _hold == "thunder":
		energy = maxf(energy, 0.7 + 0.3 * sin(_time * 28.0))
	elif _hold == "inferno":
		energy = maxf(energy, 0.65 + 0.2 * sin(_time * 12.0))
	_wisp_mat.set_shader_parameter("energy", energy * 4.5)
	_wisp.scale = Vector3.ONE * (0.7 + energy * 0.8)
	_wisp.visible = energy > 0.03
	if _wisp_light:
		_wisp_light.light_energy = energy * 1.4


# ---------------------------------------------------------------------------
# Poses. Rotations are degrees in camera space on the casting-hand anchor.
# ---------------------------------------------------------------------------

func _build_gestures() -> void:
	_gestures["cataclysm"] = [
		{"t": 0.0, "pose": _pose_idle()},
		{"t": 0.10, "pose": _p(Vector3(0.02, 0.02, 0.03), Vector3(22, 14, -16), 3.0, Vector2(50, 32), _curls(58, 74, 46))},
		{"t": 0.26, "pose": _p(Vector3(-0.03, 0.05, -0.04), Vector3(-42, -24, 22), 20.0, Vector2(6, 2), _curls(2, 0, 0))},
		{"t": 0.52, "pose": _pose_idle()},
	]
	_gestures["gravity"] = [
		{"t": 0.0, "pose": _pose_idle()},
		{"t": 0.16, "pose": _p(Vector3(0.0, 0.03, 0.0), Vector3(55, 28, -48), 12.0, Vector2(12, 6), _curls(8, 12, 6))},
		{"t": 0.34, "pose": _p(Vector3(0.01, 0.04, 0.0), Vector3(62, 10, -36), 4.0, Vector2(60, 44), _curls(68, 90, 60))},
		{"t": 0.58, "pose": _pose_idle()},
	]
	_gestures["meteor"] = [
		{"t": 0.0, "pose": _pose_idle()},
		{"t": 0.16, "pose": _p(Vector3(0.0, 0.04, 0.01), Vector3(-95, 8, 12), 1.0, Vector2(10, 4), _curls(4, 6, 2))},
		{"t": 0.36, "pose": _p(Vector3(-0.01, 0.01, -0.03), Vector3(34, -8, 6), 0.0, Vector2(18, 10), _curls(6, 8, 4))},
		{"t": 0.66, "pose": _pose_idle()},
	]


func _pose_idle() -> Pose:
	return _p(Vector3.ZERO, Vector3(-48, -22, 16), 16.0, Vector2(14, 8), [
		Vector3(14, 18, 10),
		Vector3(18, 24, 12),
		Vector3(20, 26, 14),
		Vector3(24, 30, 16),
	])


func _pose_thunder() -> Pose:
	return _p(Vector3(-0.02, 0.03, -0.02), Vector3(-72, -6, 16), 22.0, Vector2(6, 2), _curls(0, 2, 0))


func _pose_thunder_snap() -> Pose:
	return _p(Vector3(-0.02, 0.04, -0.03), Vector3(-84, 0, 10), 28.0, Vector2(2, 0), _curls(0, 0, 0))


func _pose_inferno() -> Pose:
	return _p(Vector3(-0.03, 0.02, -0.03), Vector3(-28, -22, 18), 16.0, Vector2(14, 8), _curls(10, 16, 8))


func _curls(a: float, b: float, c: float) -> Array:
	return [Vector3(a, b, c), Vector3(a + 2.0, b + 4.0, c), Vector3(a + 4.0, b + 6.0, c + 2.0), Vector3(a + 8.0, b + 4.0, c + 2.0)]


func _p(pos: Vector3, rot: Vector3, spread: float, thumb: Vector2, curls: Array) -> Pose:
	var pose := Pose.new()
	pose.pos = pos
	pose.rot = rot
	pose.spread = spread
	pose.thumb = thumb
	pose.curls = curls
	return pose


func _sample(keys: Array, t: float) -> Pose:
	if t <= float(keys[0]["t"]):
		return (keys[0]["pose"] as Pose).dup()
	for i in range(keys.size() - 1):
		var a: Dictionary = keys[i]
		var b: Dictionary = keys[i + 1]
		var t0 := float(a["t"])
		var t1 := float(b["t"])
		if t <= t1:
			var u := 0.0 if t1 <= t0 else (t - t0) / (t1 - t0)
			u = u * u * (3.0 - 2.0 * u)
			return _lerp_pose(a["pose"], b["pose"], u)
	return (keys[keys.size() - 1]["pose"] as Pose).dup()


func _lerp_pose(a: Pose, b: Pose, t: float) -> Pose:
	var pose := Pose.new()
	pose.pos = a.pos.lerp(b.pos, t)
	pose.rot = a.rot.lerp(b.rot, t)
	pose.spread = lerpf(a.spread, b.spread, t)
	pose.thumb = a.thumb.lerp(b.thumb, t)
	for i in a.curls.size():
		var ca: Vector3 = a.curls[i]
		var cb: Vector3 = b.curls[i]
		pose.curls.append(ca.lerp(cb, t))
	return pose


func _idle_motion(base: Pose, amount: float) -> Pose:
	var pose := base.dup()
	for i in pose.curls.size():
		var c: Vector3 = pose.curls[i]
		var phase := _time * 1.6 + float(i) * 0.7
		c.x += sin(phase) * 1.6 * amount
		c.y += sin(phase * 1.25) * 2.0 * amount
		pose.curls[i] = c
	pose.thumb.x += sin(_time * 1.15) * 1.4 * amount
	pose.rot.z += sin(_time * 0.85) * 1.6 * amount
	pose.pos.y += sin(_time * 1.4) * 0.003 * amount
	return pose


func _damp_pose(target: Pose, sharp: float, delta: float) -> void:
	var k := 1.0 - exp(-sharp * delta)
	if _shown.curls.is_empty():
		_shown = target.dup()
		return
	_shown.pos = _shown.pos.lerp(target.pos, k)
	_shown.rot = _shown.rot.lerp(target.rot, k)
	_shown.spread = lerpf(_shown.spread, target.spread, k)
	_shown.thumb = _shown.thumb.lerp(target.thumb, k)
	for i in target.curls.size():
		var c: Vector3 = _shown.curls[i]
		var d: Vector3 = target.curls[i]
		_shown.curls[i] = c.lerp(d, k)


# ---------------------------------------------------------------------------
# Optional in-game capture. Enabled only with `-- --capture <dir>`.
# ---------------------------------------------------------------------------

func _setup_capture() -> void:
	var args := OS.get_cmdline_user_args()
	var idx := args.find("--capture")
	if idx < 0:
		return
	_cap = true
	_cap_dir = "/opt/cursor/artifacts"
	if idx + 1 < args.size() and not str(args[idx + 1]).begins_with("--"):
		_cap_dir = str(args[idx + 1])
	DirAccess.make_dir_recursive_absolute(_cap_dir)
	_cap_events = [
		{"t": 2.6, "op": "shot", "name": "idle"},
		{"t": 2.65, "op": "press", "action": "move_forward"},
		{"t": 3.35, "op": "shot", "name": "walk"},
		{"t": 3.4, "op": "press", "action": "sprint"},
		{"t": 4.0, "op": "shot", "name": "sprint"},
		{"t": 4.05, "op": "release", "action": "sprint"},
		{"t": 4.05, "op": "release", "action": "move_forward"},
		{"t": 4.55, "op": "select", "spell": 0},
		{"t": 4.6, "op": "press", "action": "cast"},
		{"t": 4.86, "op": "shot", "name": "cast_cataclysm"},
		{"t": 4.92, "op": "release", "action": "cast"},
		{"t": 5.35, "op": "select", "spell": 1},
		{"t": 5.4, "op": "press", "action": "cast"},
		{"t": 5.78, "op": "shot", "name": "cast_thunder"},
		{"t": 5.84, "op": "release", "action": "cast"},
		{"t": 6.25, "op": "select", "spell": 2},
		{"t": 6.3, "op": "press", "action": "cast"},
		{"t": 6.64, "op": "shot", "name": "cast_gravity"},
		{"t": 6.7, "op": "release", "action": "cast"},
		{"t": 7.15, "op": "select", "spell": 3},
		{"t": 7.2, "op": "press", "action": "cast"},
		{"t": 7.62, "op": "shot", "name": "cast_inferno"},
		{"t": 7.7, "op": "release", "action": "cast"},
		{"t": 8.15, "op": "select", "spell": 4},
		{"t": 8.2, "op": "press", "action": "cast"},
		{"t": 8.56, "op": "shot", "name": "cast_meteor"},
		{"t": 8.64, "op": "release", "action": "cast"},
		{"t": 8.85, "op": "look", "pitch": 0.22, "yaw": -0.55},
		{"t": 9.15, "op": "shot", "name": "crystal_over_moon"},
		{"t": 9.35, "op": "quit"},
	]
	print("VIEWMODEL capture -> ", _cap_dir)


func _capture(delta: float) -> void:
	_cap_t += delta
	while _cap_i < _cap_events.size() and _cap_t >= float(_cap_events[_cap_i]["t"]):
		_cap_run(_cap_events[_cap_i])
		_cap_i += 1
	if _cap_t > 20.0:
		_release_capture_input()
		get_tree().quit()


func _cap_run(ev: Dictionary) -> void:
	match str(ev["op"]):
		"shot":
			_queue_shot(_cap_dir.path_join(str(ev["name"]) + ".png"))
			_log_clearance(str(ev["name"]))
		"press":
			Input.action_press(str(ev["action"]))
		"release":
			Input.action_release(str(ev["action"]))
		"select":
			if player.caster:
				player.caster.select(int(ev["spell"]))
		"look":
			# Capture-only. Aims the sky disk toward the crystal for one proof shot.
			player._pitch = float(ev["pitch"])
			if ev.has("yaw"):
				player.rotation.y = float(ev["yaw"])
		"quit":
			_release_capture_input()
			get_tree().quit()


func _release_capture_input() -> void:
	for action in ["move_forward", "sprint", "cast"]:
		Input.action_release(action)


func _queue_shot(path: String) -> void:
	_shot_queue.append(path)
	if not RenderingServer.frame_post_draw.is_connected(_flush_shots):
		RenderingServer.frame_post_draw.connect(_flush_shots, CONNECT_ONE_SHOT)


func _flush_shots() -> void:
	var img := get_viewport().get_texture().get_image()
	if img == null:
		push_error("VIEWMODEL screenshot failed: viewport image is null")
		_shot_queue.clear()
		return
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	for path in _shot_queue:
		var err := img.save_png(path)
		print("VIEWMODEL shot ", path, " ", err, " ", img.get_width(), "x", img.get_height())
	_shot_queue.clear()


func _log_clearance(label: String) -> void:
	if _crystal == null or _cast_point == null:
		return
	var gem := _ndc(_crystal.global_position)
	var hand := _ndc(_cast_point.global_position)
	print("VIEWMODEL clearance ", label, " crystal ", gem, " hand ", hand)


func _ndc(global_pos: Vector3) -> Vector2:
	var local := _vm_cam.to_local(global_pos)
	var z := maxf(0.2, -local.z)
	var half_h := tan(deg_to_rad(_vm_cam.fov * 0.5)) * z
	var half_w := half_h * _aspect
	return Vector2(local.x / half_w, local.y / half_h)
