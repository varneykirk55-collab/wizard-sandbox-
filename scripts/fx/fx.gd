extends Node
## Effects service (autoload "FX"): pooled GPU particle bursts, shader-driven
## fireballs / shockwaves / rings, flash lights, scorch decals, lightning,
## camera shake and screen flash. Spells compose these building blocks.

const MAX_SCORCH := 40
const BUSY_BURSTS := 90   # above this, "secondary" particle presets are skipped

var fx_root: Node3D
var spell_root: Node3D
var player = null
var hud = null
var epoch := 0
var sphere: SphereMesh
var plane: PlaneMesh
var tex_blob: Texture2D
var tex_smoke: Texture2D
var tex_scorch: Texture2D
var tex_ring: Texture2D

var _pool_root: Node3D
var _shaders: Dictionary = {}
var _draw_mats: Dictionary = {}
var _presets: Dictionary = {}
var _pools: Dictionary = {}
var _active := 0
var _scorches: Array = []
var _bolt_script: Script
var _bolt_mat: ShaderMaterial


func _ready() -> void:
	_pool_root = Node3D.new()
	add_child(_pool_root)
	fx_root = Node3D.new()
	add_child(fx_root)
	spell_root = Node3D.new()
	add_child(spell_root)

	sphere = SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 32
	sphere.rings = 16
	plane = PlaneMesh.new()
	plane.size = Vector2(2.0, 2.0)

	for n in ["fireball", "shockwave", "ground_ring", "bolt", "glow_shell", "lens", "vortex_disc", "tornado", "heat", "rock"]:
		_shaders[n] = load("res://shaders/%s.gdshader" % n)

	tex_blob = _radial_tex([Color(1, 1, 1, 1), Color(1, 1, 1, 0.5), Color(1, 1, 1, 0)], [0.0, 0.35, 1.0])
	tex_scorch = _radial_tex([Color(0.02, 0.015, 0.01, 0.92), Color(0.03, 0.02, 0.015, 0.75), Color(0.05, 0.04, 0.03, 0.0)], [0.0, 0.55, 1.0])
	tex_ring = _radial_tex([Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)], [0.0, 0.7, 0.85, 1.0])
	tex_smoke = _smoke_tex()

	_draw_mats["fire"] = _draw_mat(tex_blob, true, Color(2.2, 2.2, 2.2), false)
	_draw_mats["spark"] = _draw_mat(tex_blob, true, Color(4.0, 4.0, 4.0), false)
	_draw_mats["magic"] = _draw_mat(tex_blob, true, Color(3.0, 3.0, 3.0), false)
	_draw_mats["smoke"] = _draw_mat(tex_smoke, false, Color(1, 1, 1), true)

	_define_presets()
	_bolt_script = load("res://scripts/fx/lightning_bolt.gd")
	_bolt_mat = shader_mat("bolt")


# ---------------------------------------------------------------------------
# Lifetime helpers
# ---------------------------------------------------------------------------

## Runs `c` after `delay` seconds of game time, unless the world was reset.
func after(delay: float, c: Callable) -> void:
	get_tree().create_timer(delay, false).timeout.connect(_run_after.bind(epoch, c))


func _run_after(e: int, c: Callable) -> void:
	if e == epoch and c.is_valid():
		c.call()


## Removes every live effect and spell (used by the world reset).
func clear() -> void:
	epoch += 1
	for c in fx_root.get_children():
		c.queue_free()
	for c in spell_root.get_children():
		c.queue_free()
	_scorches.clear()


# ---------------------------------------------------------------------------
# Resources
# ---------------------------------------------------------------------------

func _radial_tex(colors: Array, offsets: Array) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	g.colors = PackedColorArray(colors)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 128
	t.height = 128
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t


func _smoke_tex() -> ImageTexture:
	var n := FastNoiseLite.new()
	n.frequency = 0.035
	n.fractal_octaves = 3
	var s := 96
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	for y in s:
		for x in s:
			var dx := (float(x) - s * 0.5) / (s * 0.5)
			var dy := (float(y) - s * 0.5) / (s * 0.5)
			var d := sqrt(dx * dx + dy * dy)
			var nv := n.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			var a := clampf((1.0 - d) * 1.6 - (1.0 - nv) * 0.75, 0.0, 1.0)
			a = a * a * (3.0 - 2.0 * a)
			var shade := 0.75 + nv * 0.25
			img.set_pixel(x, y, Color(shade, shade, shade, a))
	return ImageTexture.create_from_image(img)


func _draw_mat(tex: Texture2D, additive: bool, tint: Color, soft: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.albedo_color = tint
	m.albedo_texture = tex
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_receive_shadows = true
	if soft:
		m.proximity_fade_enabled = true
		m.proximity_fade_distance = 1.2
	return m


func shader_mat(shader_name: String, params: Dictionary = {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shaders[shader_name]
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m


func mesh_node(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 4.0
	return mi


func light(color: Color, energy: float, rng: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng
	l.omni_attenuation = 1.2
	l.shadow_enabled = false
	return l


# ---------------------------------------------------------------------------
# Particles
# ---------------------------------------------------------------------------

func _curve(points: Array) -> CurveTexture:
	var c := Curve.new()
	for pt in points:
		c.add_point(Vector2(pt[0], pt[1]))
	var t := CurveTexture.new()
	t.curve = c
	return t


func _ramp(colors: Array, offsets: Array) -> GradientTexture1D:
	var offs: Array = offsets
	if offs.is_empty():
		for i in colors.size():
			offs.append(float(i) / float(maxi(1, colors.size() - 1)))
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offs)
	g.colors = PackedColorArray(colors)
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


func _process_mat(cfg: Dictionary) -> ParticleProcessMaterial:
	var pm := ParticleProcessMaterial.new()
	var shape: String = cfg.get("shape", "sphere")
	var radius: float = cfg.get("radius", 1.0)
	if shape == "ring":
		var inner: float = cfg.get("ring_inner", 0.8)
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
		pm.emission_ring_axis = Vector3.UP
		pm.emission_ring_radius = radius
		pm.emission_ring_inner_radius = radius * inner
		pm.emission_ring_height = cfg.get("ring_h", 0.3)
	elif shape == "point":
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	else:
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = radius
	pm.direction = cfg.get("dir", Vector3.UP)
	pm.spread = cfg.get("spread", 180.0)
	pm.flatness = cfg.get("flat", 0.0)
	var vel: Vector2 = cfg.get("vel", Vector2(1.0, 2.0))
	pm.initial_velocity_min = vel.x
	pm.initial_velocity_max = vel.y
	pm.gravity = cfg.get("grav", Vector3.ZERO)
	var damp: Vector2 = cfg.get("damp", Vector2.ZERO)
	pm.damping_min = damp.x
	pm.damping_max = damp.y
	var sc: Vector2 = cfg.get("scale", Vector2.ONE)
	pm.scale_min = sc.x
	pm.scale_max = sc.y
	if cfg.has("curve"):
		pm.scale_curve = _curve(cfg["curve"])
	if cfg.has("colors"):
		pm.color_ramp = _ramp(cfg["colors"], cfg.get("offsets", []))
	if cfg.has("tang"):
		var tg: Vector2 = cfg["tang"]
		pm.tangential_accel_min = tg.x
		pm.tangential_accel_max = tg.y
	if cfg.has("radial"):
		var rd: Vector2 = cfg["radial"]
		pm.radial_accel_min = rd.x
		pm.radial_accel_max = rd.y
	if cfg.has("spin"):
		var sp: float = cfg["spin"]
		pm.angle_min = 0.0
		pm.angle_max = 360.0
		pm.angular_velocity_min = -sp
		pm.angular_velocity_max = sp
	return pm


func _make_particles(cfg: Dictionary) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.process_material = _process_mat(cfg)
	var q := QuadMesh.new()
	var mat_name: String = cfg.get("mat", "fire")
	q.material = _draw_mats[mat_name]
	p.draw_pass_1 = q
	p.amount = cfg.get("amount", 32)
	p.lifetime = cfg.get("life", 1.0)
	p.explosiveness = cfg.get("explosive", 0.0)
	p.randomness = 0.4
	p.local_coords = cfg.get("local", false)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ab: float = cfg.get("aabb", 90.0)
	p.visibility_aabb = AABB(Vector3(-ab, -ab * 0.5, -ab), Vector3(ab * 2.0, ab * 2.0, ab * 2.0))
	return p


## Continuous emitter for spells to parent to themselves.
func particles(cfg: Dictionary) -> GPUParticles3D:
	var p := _make_particles(cfg)
	p.one_shot = false
	p.emitting = true
	return p


## Pooled burst from a named preset.
func emit(preset: String, pos: Vector3, size: float = 1.0) -> void:
	if not _presets.has(preset):
		return
	var cfg: Dictionary = _presets[preset]
	if cfg.get("secondary", false) and _active > BUSY_BURSTS:
		return
	if not _pools.has(preset):
		_pools[preset] = []
	var pool: Array = _pools[preset]
	var p: GPUParticles3D
	var dur: float = cfg.get("dur", 0.0)
	if pool.is_empty():
		p = _make_particles(cfg)
		p.one_shot = dur <= 0.0
		_pool_root.add_child(p)
	else:
		p = pool.pop_back()
	p.global_position = pos
	p.scale = Vector3.ONE * size
	p.visible = true
	p.restart()
	p.emitting = true
	_active += 1
	if dur > 0.0:
		get_tree().create_timer(dur, false).timeout.connect(_stop.bind(p))
	get_tree().create_timer(dur + p.lifetime + 0.4, false).timeout.connect(_recycle.bind(preset, p))


func _stop(p: GPUParticles3D) -> void:
	if is_instance_valid(p):
		p.emitting = false


func _recycle(preset: String, p: GPUParticles3D) -> void:
	_active = maxi(0, _active - 1)
	if is_instance_valid(p):
		p.emitting = false
		p.visible = false
		_pools[preset].append(p)


func _define_presets() -> void:
	var fire_cols := [Color(1.0, 0.95, 0.7, 1.0), Color(1.0, 0.5, 0.1, 0.9), Color(0.4, 0.05, 0.0, 0.0)]
	var grow := [[0.0, 0.3], [0.25, 1.0], [1.0, 0.45]]
	var puff := [[0.0, 0.35], [0.4, 0.9], [1.0, 1.0]]
	_presets["fire_burst"] = {"mat": "fire", "amount": 48, "life": 1.1, "explosive": 0.92, "radius": 2.5, "vel": Vector2(6, 22), "grav": Vector3(0, 3, 0), "damp": Vector2(6, 12), "scale": Vector2(5, 10), "curve": grow, "colors": fire_cols, "offsets": [0.0, 0.3, 1.0]}
	_presets["arcane_burst"] = {"mat": "magic", "amount": 48, "life": 1.2, "explosive": 0.92, "radius": 2.5, "vel": Vector2(8, 26), "grav": Vector3(0, 1, 0), "damp": Vector2(6, 12), "scale": Vector2(5, 10), "curve": grow, "colors": [Color(1, 1, 1, 1), Color(0.7, 0.4, 1.0, 0.9), Color(0.2, 0.0, 0.5, 0.0)], "offsets": [0.0, 0.3, 1.0]}
	_presets["smoke_burst"] = {"mat": "smoke", "amount": 40, "life": 4.5, "explosive": 0.85, "radius": 3.0, "vel": Vector2(3, 12), "grav": Vector3(0, 1.2, 0), "damp": Vector2(1.5, 3), "scale": Vector2(7, 14), "curve": puff, "spin": 40.0, "colors": [Color(1.0, 0.6, 0.3, 0.0), Color(0.35, 0.22, 0.15, 0.75), Color(0.12, 0.11, 0.11, 0.6), Color(0.1, 0.1, 0.1, 0.0)], "offsets": [0.0, 0.12, 0.5, 1.0]}
	_presets["smoke_column"] = {"mat": "smoke", "secondary": true, "amount": 36, "life": 5.5, "explosive": 0.4, "radius": 2.0, "spread": 12.0, "vel": Vector2(9, 16), "grav": Vector3(0, 0.5, 0), "damp": Vector2(1, 2), "scale": Vector2(6, 13), "curve": puff, "spin": 30.0, "colors": [Color(1.0, 0.55, 0.2, 0.0), Color(0.3, 0.2, 0.15, 0.7), Color(0.1, 0.1, 0.1, 0.55), Color(0.1, 0.1, 0.1, 0.0)], "offsets": [0.0, 0.1, 0.5, 1.0]}
	_presets["sparks"] = {"mat": "spark", "amount": 90, "life": 1.4, "explosive": 1.0, "radius": 1.0, "vel": Vector2(18, 48), "grav": Vector3(0, -16, 0), "damp": Vector2(1, 2), "scale": Vector2(0.25, 0.6), "colors": [Color(1, 1, 0.9, 1), Color(1.0, 0.55, 0.15, 1.0), Color(1.0, 0.2, 0.0, 0.0)]}
	_presets["embers"] = {"mat": "spark", "secondary": true, "amount": 60, "life": 4.0, "explosive": 0.7, "radius": 4.0, "spread": 70.0, "vel": Vector2(2, 9), "grav": Vector3(0, 1.0, 0), "scale": Vector2(0.15, 0.4), "colors": [Color(1.0, 0.7, 0.3, 1.0), Color(1.0, 0.3, 0.05, 0.9), Color(0.6, 0.05, 0.0, 0.0)]}
	_presets["dust_ring"] = {"mat": "smoke", "amount": 56, "life": 2.6, "explosive": 1.0, "radius": 1.5, "dir": Vector3(1, 0, 0), "flat": 1.0, "vel": Vector2(16, 30), "grav": Vector3(0, 0.6, 0), "damp": Vector2(8, 14), "scale": Vector2(5, 10), "curve": puff, "spin": 30.0, "colors": [Color(0.75, 0.65, 0.5, 0.0), Color(0.6, 0.52, 0.42, 0.55), Color(0.5, 0.45, 0.4, 0.0)], "offsets": [0.0, 0.15, 1.0]}
	_presets["dust_wall"] = {"mat": "smoke", "amount": 80, "life": 5.0, "explosive": 1.0, "radius": 2.0, "dir": Vector3(1, 0, 0), "flat": 1.0, "vel": Vector2(14, 30), "grav": Vector3(0, 0.8, 0), "damp": Vector2(3, 6), "scale": Vector2(10, 20), "curve": puff, "spin": 20.0, "colors": [Color(0.7, 0.6, 0.48, 0.0), Color(0.55, 0.48, 0.4, 0.6), Color(0.4, 0.37, 0.34, 0.0)], "offsets": [0.0, 0.12, 1.0]}
	_presets["small_dust"] = {"mat": "smoke", "secondary": true, "amount": 14, "life": 1.6, "explosive": 1.0, "radius": 0.6, "spread": 80.0, "vel": Vector2(2, 7), "damp": Vector2(2, 4), "scale": Vector2(2, 4), "curve": puff, "colors": [Color(0.6, 0.55, 0.5, 0.0), Color(0.5, 0.46, 0.42, 0.5), Color(0.4, 0.4, 0.4, 0.0)], "offsets": [0.0, 0.15, 1.0]}
	_presets["linger_fire"] = {"mat": "fire", "secondary": true, "dur": 5.0, "amount": 16, "life": 0.9, "radius": 1.2, "spread": 15.0, "vel": Vector2(1.5, 4), "grav": Vector3(0, 2, 0), "scale": Vector2(1.6, 3.2), "curve": grow, "colors": fire_cols, "offsets": [0.0, 0.3, 1.0]}
	_presets["linger_smoke"] = {"mat": "smoke", "secondary": true, "dur": 6.0, "amount": 12, "life": 3.5, "radius": 1.0, "spread": 15.0, "vel": Vector2(2, 4), "scale": Vector2(3, 6), "curve": puff, "spin": 20.0, "colors": [Color(0.2, 0.18, 0.17, 0.0), Color(0.15, 0.14, 0.14, 0.4), Color(0.1, 0.1, 0.1, 0.0)], "offsets": [0.0, 0.2, 1.0]}
	_presets["electric_sparks"] = {"mat": "spark", "amount": 60, "life": 0.7, "explosive": 1.0, "radius": 0.5, "vel": Vector2(10, 34), "grav": Vector3(0, -20, 0), "scale": Vector2(0.2, 0.5), "colors": [Color(1, 1, 1, 1), Color(0.5, 0.75, 1.0, 1.0), Color(0.2, 0.4, 1.0, 0.0)]}
	_presets["electric_flash"] = {"mat": "magic", "amount": 6, "life": 0.25, "explosive": 1.0, "radius": 0.5, "vel": Vector2(0, 2), "scale": Vector2(8, 14), "colors": [Color(0.8, 0.9, 1.0, 1.0), Color(0.4, 0.6, 1.0, 0.0)]}
	_presets["restore_sparkle"] = {"mat": "magic", "amount": 40, "life": 1.5, "explosive": 0.6, "radius": 4.0, "spread": 30.0, "vel": Vector2(1, 4), "scale": Vector2(0.3, 0.8), "colors": [Color(0.7, 1.0, 1.0, 1.0), Color(0.4, 0.8, 1.0, 0.0)]}


# ---------------------------------------------------------------------------
# Composite effects
# ---------------------------------------------------------------------------

func _palette(i: int) -> Array:
	if i == 1:
		return [Color(1.0, 0.95, 1.0), Color(0.65, 0.3, 1.0), Color(0.15, 0.0, 0.4), Color(0.75, 0.5, 1.0)]
	if i == 2:
		return [Color(1.0, 1.0, 1.0), Color(0.45, 0.7, 1.0), Color(0.05, 0.1, 0.5), Color(0.6, 0.8, 1.0)]
	return [Color(1.0, 0.95, 0.7), Color(1.0, 0.45, 0.05), Color(0.35, 0.03, 0.0), Color(1.0, 0.6, 0.25)]


func fireball(pos: Vector3, radius: float, dur: float, palette: int = 0, rise: float = 0.0) -> void:
	var pal := _palette(palette)
	var mat := shader_mat("fireball", {"seed": randf() * 50.0, "progress": 0.0, "energy": 7.0, "color_hot": pal[0], "color_mid": pal[1], "color_cool": pal[2]})
	var mi := mesh_node(sphere, mat)
	fx_root.add_child(mi)
	mi.global_position = pos
	mi.scale = Vector3.ONE * radius * 0.12
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * radius, dur).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "shader_parameter/progress", 1.0, dur)
	if rise != 0.0:
		tw.tween_property(mi, "position:y", pos.y + rise, dur).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(mi.queue_free)


func shock_sphere(pos: Vector3, radius: float, dur: float, tint: Color = Color(1.0, 0.8, 0.6)) -> void:
	var mat := shader_mat("shockwave", {"strength": 0.08, "fade": 1.0, "tint": tint})
	var mi := mesh_node(sphere, mat)
	fx_root.add_child(mi)
	mi.global_position = pos
	mi.scale = Vector3.ONE * 0.5
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * radius, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "shader_parameter/fade", 0.0, dur).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(mi.queue_free)


func ground_ring(pos: Vector3, radius: float, dur: float, tint: Color = Color(1.0, 0.7, 0.4)) -> void:
	var mat := shader_mat("ground_ring", {"progress": 0.0, "tint": tint, "energy": 3.5})
	var mi := mesh_node(plane, mat)
	fx_root.add_child(mi)
	mi.global_position = Vector3(pos.x, 0.18, pos.z)
	mi.scale = Vector3.ONE * 0.5
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * radius, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "shader_parameter/progress", 1.0, dur)
	tw.chain().tween_callback(mi.queue_free)


func flash_light(pos: Vector3, color: Color, energy: float, rng: float, dur: float) -> void:
	var l := light(color, energy, rng)
	fx_root.add_child(l)
	l.global_position = pos
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, dur).set_ease(Tween.EASE_OUT)
	tw.tween_callback(l.queue_free)


## Burnt ground decal with a glowing core that cools down.
func scorch(pos: Vector3, radius: float) -> void:
	var d := Decal.new()
	d.texture_albedo = tex_scorch
	d.texture_emission = tex_blob
	d.emission_energy = 3.0
	d.modulate = Color(1.0, 0.4, 0.1)
	d.size = Vector3(radius * 2.0, 4.0, radius * 2.0)
	d.upper_fade = 0.5
	d.lower_fade = 0.5
	fx_root.add_child(d)
	d.global_position = Vector3(pos.x, 0.0, pos.z)
	d.rotation.y = randf() * TAU
	d.create_tween().tween_property(d, "emission_energy", 0.0, 8.0)
	_scorches.append(d)
	if _scorches.size() > MAX_SCORCH:
		var old = _scorches.pop_front()
		if is_instance_valid(old):
			old.queue_free()


## Big layered detonation. size 1.0 = Cataclysm, ~2.3 = Meteor.
func explosion(pos: Vector3, size: float = 1.0, palette: int = 0) -> void:
	var gpos := Vector3(pos.x, maxf(pos.y, 0.0), pos.z)
	var pal := _palette(palette)
	var near_ground := gpos.y < 7.0 * size
	flash_light(gpos + Vector3.UP * 2.0 * size, pal[3], 55.0 * size, 50.0 * size, 0.8)
	fireball(gpos + Vector3.UP * size, 7.5 * size, 0.9 + 0.3 * size, palette)
	after(0.1, fireball.bind(gpos + Vector3.UP * 4.0 * size, 5.5 * size, 1.5 + 0.3 * size, palette, 6.0 * size))
	shock_sphere(gpos, 28.0 * size, 0.5 + 0.15 * size, pal[3])
	emit("fire_burst" if palette == 0 else "arcane_burst", gpos + Vector3.UP * size, size)
	emit("smoke_burst", gpos + Vector3.UP * 1.5 * size, size)
	emit("sparks", gpos + Vector3.UP * size, size)
	emit("embers", gpos + Vector3.UP * 2.0 * size, size)
	emit("smoke_column", gpos + Vector3.UP * 2.0 * size, size)
	if near_ground:
		ground_ring(gpos, 30.0 * size, 0.7 + 0.2 * size, pal[3])
		emit("dust_ring", Vector3(gpos.x, 0.6, gpos.z), size)
		scorch(gpos, 6.0 * size)
		for i in 3:
			var off := Vector3(randf_range(-4.0, 4.0), 0.3, randf_range(-4.0, 4.0)) * size
			emit("linger_fire", Vector3(gpos.x, 0.0, gpos.z) + off, size)
			emit("linger_smoke", Vector3(gpos.x, 1.0, gpos.z) + off, size)
	shake(gpos, 0.85 * size, 75.0 * size)
	screen_flash(gpos, 0.75 * size, 90.0 * size)


## Smaller blue-white impact used by lightning.
func electric_impact(pos: Vector3, size: float = 1.0) -> void:
	flash_light(pos + Vector3.UP * 1.5, Color(0.65, 0.8, 1.0), 40.0 * size, 32.0 * size, 0.3)
	fireball(pos + Vector3.UP * 0.5, 2.6 * size, 0.35, 2)
	emit("electric_sparks", pos + Vector3.UP * 0.4, size)
	emit("electric_flash", pos + Vector3.UP * 0.8, size)
	emit("small_dust", pos + Vector3.UP * 0.4, size * 1.4)
	if pos.y < 3.0:
		ground_ring(pos, 9.0 * size, 0.35, Color(0.6, 0.8, 1.0))
		scorch(pos, 2.2 * size)
	shake(pos, 0.3 * size, 55.0)
	screen_flash(pos, 0.3 * size, 60.0)


func bolt(from: Vector3, to: Vector3, width: float = 0.6, branches: int = 3, life: float = 0.32) -> void:
	var b = _bolt_script.new()
	b.from = from
	b.to = to
	b.width = width
	b.branches = branches
	b.life = life
	b.material_override = _bolt_mat
	fx_root.add_child(b)


# ---------------------------------------------------------------------------
# Player feedback
# ---------------------------------------------------------------------------

func shake(pos: Vector3, strength: float, radius: float) -> void:
	if player == null:
		return
	var pp: Vector3 = player.global_position
	var f := clampf(1.0 - pp.distance_to(pos) / radius, 0.0, 1.0)
	if f <= 0.0:
		return
	var s := strength * (0.25 + 0.75 * f)
	player.add_trauma(s)
	InputSetup.rumble(s * 0.8, s, 0.2 + 0.35 * minf(strength, 1.5))


## Sustained low rumble (keeps shake at a floor instead of adding to it).
func shake_hold(pos: Vector3, level: float, radius: float) -> void:
	if player == null:
		return
	var pp: Vector3 = player.global_position
	var f := clampf(1.0 - pp.distance_to(pos) / radius, 0.0, 1.0)
	if f > 0.0:
		player.hold_trauma(level * f)
		InputSetup.rumble(level * f * 0.5, level * f * 0.7, 0.1)


func screen_flash(pos: Vector3, strength: float, radius: float) -> void:
	if player == null or hud == null:
		return
	var pp: Vector3 = player.global_position
	var f := clampf(1.0 - pp.distance_to(pos) / radius, 0.0, 1.0)
	if f > 0.0:
		hud.flash(minf(0.85, strength * f))
