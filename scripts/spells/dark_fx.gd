extends Node
## Shared resources for the two dark spells (Black Fire, Oblivion): materials,
## particle looks, synthesized sounds and a few composite effects. One instance
## lives under the spell caster. Everything here is additive: the original
## five spells, their presets and their sounds are not touched.

const CRIMSON := Color(1.0, 0.1, 0.08)
const VIOLET := Color(0.58, 0.28, 1.0)

var black_mat: StandardMaterial3D      # absolute black, unshaded
var char_mat: StandardMaterial3D       # charred surface with ember veins
var dissolve_mat: StandardMaterial3D   # glowing fragment being erased
var void_shader: Shader

var _field = null
var _field_script: Script


func _ready() -> void:
	_field_script = load("res://scripts/spells/black_fire_field.gd")
	void_shader = load("res://shaders/void_shell.gdshader")

	black_mat = StandardMaterial3D.new()
	black_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	black_mat.albedo_color = Color(0, 0, 0)

	var veins := FastNoiseLite.new()
	veins.noise_type = FastNoiseLite.TYPE_CELLULAR
	veins.frequency = 0.06
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1), Color(0.05, 0.05, 0.05), Color(0, 0, 0)])
	var vt := NoiseTexture2D.new()
	vt.width = 256
	vt.height = 256
	vt.seamless = true
	vt.noise = veins
	vt.color_ramp = ramp
	char_mat = StandardMaterial3D.new()
	char_mat.albedo_color = Color(0.03, 0.022, 0.025)
	char_mat.roughness = 1.0
	char_mat.emission_enabled = true
	char_mat.emission = Color(1.0, 0.08, 0.04)
	char_mat.emission_energy_multiplier = 1.6
	char_mat.emission_texture = vt
	char_mat.uv1_triplanar = true
	char_mat.uv1_scale = Vector3.ONE * 0.9

	dissolve_mat = StandardMaterial3D.new()
	dissolve_mat.albedo_color = Color(0.25, 0.1, 0.5)
	dissolve_mat.emission_enabled = true
	dissolve_mat.emission = Color(0.62, 0.32, 1.0)
	dissolve_mat.emission_energy_multiplier = 3.5

	_register_particles()
	if not AudioManager.streams.has("bf_ignite"):
		_make_sounds()


## The single burn manager. Lives under FX.spell_root, so a world reset removes
## every fire together with the other spell nodes.
func field():
	if not is_instance_valid(_field) or _field.is_queued_for_deletion():
		_field = _field_script.new()
		_field.dark = self
		FX.spell_root.add_child(_field)
	return _field


# ---------------------------------------------------------------------------
# Composite effects
# ---------------------------------------------------------------------------

## Turbulent fireball in custom colours (same shader as the original spells).
func fireball(pos: Vector3, radius: float, dur: float, hot: Color, mid: Color, cool: Color) -> void:
	var mat: ShaderMaterial = FX.shader_mat("fireball", {"seed": randf() * 50.0, "progress": 0.0, "energy": 7.0, "color_hot": hot, "color_mid": mid, "color_cool": cool})
	var mi: MeshInstance3D = FX.mesh_node(FX.sphere, mat)
	FX.fx_root.add_child(mi)
	mi.global_position = pos
	mi.scale = Vector3.ONE * radius * 0.12
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * radius, dur).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "shader_parameter/progress", 1.0, dur)
	tw.chain().tween_callback(mi.queue_free)


## Sphere of pure black that swells and fades: the heart of a Black Fire blast.
func black_flash(pos: Vector3, radius: float, dur: float) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0, 0, 0, 0.95)
	var mi: MeshInstance3D = FX.mesh_node(FX.sphere, mat)
	FX.fx_root.add_child(mi)
	mi.global_position = pos
	mi.scale = Vector3.ONE * radius * 0.2
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * radius, dur).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color", Color(0, 0, 0, 0.0), dur).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(mi.queue_free)


## Expanding energy ring at any height and tilt.
func ring(pos: Vector3, radius: float, dur: float, tint: Color, tilt: Vector3) -> void:
	var mat: ShaderMaterial = FX.shader_mat("ground_ring", {"progress": 0.0, "tint": tint, "energy": 4.5})
	var mi: MeshInstance3D = FX.mesh_node(FX.plane, mat)
	FX.fx_root.add_child(mi)
	mi.global_position = pos
	mi.rotation = tilt
	mi.scale = Vector3.ONE * 0.5
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * radius, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "shader_parameter/progress", 1.0, dur)
	tw.chain().tween_callback(mi.queue_free)


## Ground scar with a glow that cools over a few seconds.
func scar(pos: Vector3, radius: float, glow: Color, fade: float) -> void:
	var d := Decal.new()
	d.texture_albedo = FX.tex_scorch
	d.texture_emission = FX.tex_blob
	d.emission_energy = 3.0
	d.modulate = glow
	d.size = Vector3(radius * 2.0, 4.0, radius * 2.0)
	d.upper_fade = 0.5
	d.lower_fade = 0.5
	FX.fx_root.add_child(d)
	d.global_position = Vector3(pos.x, 0.0, pos.z)
	var tw := d.create_tween()
	tw.tween_property(d, "emission_energy", 0.0, fade)
	tw.tween_interval(20.0)
	tw.tween_callback(d.queue_free)


# ---------------------------------------------------------------------------
# Particle looks
# ---------------------------------------------------------------------------

## Black flame sprite: opaque black body, ragged luminous crimson edge.
func _flame_tex() -> ImageTexture:
	var n := FastNoiseLite.new()
	n.frequency = 0.05
	n.fractal_octaves = 3
	var s := 96
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	for y in s:
		for x in s:
			var dx := (float(x) - s * 0.5) / (s * 0.5)
			var dy := (float(y) - s * 0.5) / (s * 0.5)
			var nv := n.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			var edge := sqrt(dx * dx + dy * dy) + (nv - 0.5) * 0.4
			var a := 1.0 - smoothstep(0.72, 0.98, edge)
			var rim := smoothstep(0.34, 0.74, edge)
			img.set_pixel(x, y, Color(rim, rim * 0.1 + rim * rim * 0.12, rim * 0.06, a))
	return ImageTexture.create_from_image(img)


func _register_particles() -> void:
	FX.register_draw_mat("blackfire", _flame_tex(), false, Color(3.2, 3.2, 3.2), false)
	var fade := [Color(1, 1, 1, 0.0), Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.0)]
	var fade_off := [0.0, 0.12, 0.6, 1.0]
	var grow := [[0.0, 0.35], [0.3, 1.0], [1.0, 0.35]]
	var puff := [[0.0, 0.35], [0.4, 0.9], [1.0, 1.0]]
	var red := [Color(1.0, 0.3, 0.12, 1.0), Color(0.95, 0.05, 0.05, 1.0), Color(0.3, 0.0, 0.0, 0.0)]
	var soot := [Color(0.02, 0.0, 0.01, 0.0), Color(0.03, 0.01, 0.02, 0.8), Color(0.08, 0.02, 0.04, 0.5), Color(0.05, 0.03, 0.05, 0.0)]
	FX.register_preset("bf_burst", {"mat": "blackfire", "amount": 14, "life": 0.8, "explosive": 0.9, "radius": 0.6, "vel": Vector2(1.5, 5.0), "grav": Vector3(0, 3, 0), "damp": Vector2(2, 4), "scale": Vector2(1.2, 2.4), "curve": grow, "spin": 60.0, "colors": fade, "offsets": fade_off})
	FX.register_preset("bf_blast", {"mat": "blackfire", "amount": 60, "life": 1.6, "explosive": 0.95, "radius": 2.0, "vel": Vector2(5, 18), "grav": Vector3(0, 2, 0), "damp": Vector2(5, 10), "scale": Vector2(3.0, 6.5), "curve": grow, "spin": 50.0, "colors": fade, "offsets": fade_off})
	FX.register_preset("bf_ground", {"mat": "blackfire", "secondary": true, "dur": 4.5, "amount": 14, "life": 0.9, "radius": 1.2, "spread": 15.0, "vel": Vector2(1.0, 3.0), "grav": Vector3(0, 2.5, 0), "scale": Vector2(1.2, 2.4), "curve": grow, "spin": 40.0, "colors": fade, "offsets": fade_off})
	FX.register_preset("bf_embers", {"mat": "spark", "secondary": true, "amount": 40, "life": 2.2, "explosive": 0.9, "radius": 0.8, "spread": 70.0, "vel": Vector2(3, 11), "grav": Vector3(0, -5, 0), "scale": Vector2(0.1, 0.28), "colors": red})
	FX.register_preset("bf_smoke", {"mat": "smoke", "secondary": true, "amount": 10, "life": 3.5, "explosive": 0.3, "radius": 0.8, "spread": 20.0, "vel": Vector2(1.5, 3.5), "grav": Vector3(0, 0.8, 0), "scale": Vector2(2.5, 5.0), "curve": puff, "spin": 25.0, "colors": soot, "offsets": [0.0, 0.15, 0.6, 1.0]})
	FX.register_preset("bf_ash", {"mat": "smoke", "secondary": true, "amount": 8, "life": 1.4, "explosive": 0.9, "radius": 0.4, "spread": 60.0, "vel": Vector2(0.5, 2.0), "scale": Vector2(0.6, 1.4), "curve": puff, "colors": [Color(0.05, 0.02, 0.03, 0.8), Color(0.05, 0.03, 0.04, 0.0)]})
	# Oblivion
	FX.register_preset("void_ash", {"mat": "magic", "secondary": true, "amount": 12, "life": 0.9, "explosive": 0.9, "radius": 0.5, "vel": Vector2(0.5, 2.5), "damp": Vector2(1, 2), "scale": Vector2(0.12, 0.4), "colors": [Color(0.85, 0.6, 1.0, 1.0), Color(0.5, 0.2, 1.0, 0.9), Color(0.2, 0.0, 0.5, 0.0)]})
	FX.register_preset("void_burst", {"mat": "magic", "amount": 70, "life": 1.6, "explosive": 0.95, "radius": 3.0, "vel": Vector2(14, 40), "damp": Vector2(6, 12), "scale": Vector2(3, 7), "curve": grow, "colors": [Color(0.95, 0.85, 1.0, 1.0), Color(0.45, 0.15, 0.9, 0.8), Color(0.1, 0.0, 0.3, 0.0)]})
	FX.register_preset("void_after", {"mat": "magic", "dur": 5.0, "amount": 30, "life": 2.5, "radius": 9.0, "vel": Vector2(0.2, 1.2), "scale": Vector2(0.2, 0.6), "curve": [[0.0, 0.0], [0.3, 1.0], [1.0, 0.0]], "colors": [Color(0.6, 0.3, 1.0, 0.0), Color(0.6, 0.3, 1.0, 0.9), Color(0.3, 0.1, 0.8, 0.0)]})


# ---------------------------------------------------------------------------
# Sounds (synthesized once at startup, stored beside the existing ones)
# ---------------------------------------------------------------------------

func _make_sounds() -> void:
	var s: Dictionary = AudioManager.streams
	s["bf_ignite"] = AudioManager._make(_gen_ignite(0.8))
	s["bf_crackle"] = AudioManager._make(_gen_crackle(2.5), true)
	s["bf_charge"] = AudioManager._make(_gen_charge(2.0), true)
	s["void_form"] = AudioManager._make(_gen_void_form(1.6))
	s["void_hum"] = AudioManager._make(_gen_void_hum(3.0), true)
	s["void_dis"] = AudioManager._make(_gen_void_dis(0.5))


func _buf(dur: float) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(int(dur * AudioManager.RATE))
	return buf


## Supernatural ignition: a low whoomp with a hissing, spitting tail.
func _gen_ignite(dur: float) -> PackedFloat32Array:
	var buf := _buf(dur)
	var n := buf.size()
	var rate := float(AudioManager.RATE)
	var lp := 0.0
	var phase := 0.0
	var spit := 0.2
	for i in n:
		var t := float(i) / rate
		var k := float(i) / float(n)
		phase += TAU * lerpf(150.0, 46.0, k) / rate
		var w := randf() * 2.0 - 1.0
		lp += (w - lp) * lerpf(0.25, 0.04, k)
		if randf() < 0.003:
			spit = 1.0
		spit = maxf(0.2, spit * 0.995)
		buf[i] = sin(phase) * exp(-t * 7.0) * 0.9 + lp * exp(-t * 5.0) * 1.2 + (w - lp) * 0.22 * spit * exp(-t * 3.0)
	return buf


## Persistent crackle and sizzle (loop).
func _gen_crackle(dur: float) -> PackedFloat32Array:
	var buf := _buf(dur)
	var n := buf.size()
	var lp := 0.0
	var low := 0.0
	var env := 0.0
	for i in n:
		if randf() < 0.004:
			env = randf_range(0.5, 1.0)
		env *= 0.992
		var w := randf() * 2.0 - 1.0
		lp += (w - lp) * 0.35
		low += (w - low) * 0.01
		buf[i] = (w - lp) * env * 0.9 + (w - lp) * 0.05 + low * 1.5
	return buf


## Charging growl (loop); the spell raises its pitch as the orb grows.
func _gen_charge(dur: float) -> PackedFloat32Array:
	var buf := _buf(dur)
	var n := buf.size()
	var rate := float(AudioManager.RATE)
	var lp := 0.0
	var env := 0.0
	for i in n:
		var t := float(i) / rate
		if randf() < 0.002:
			env = 1.0
		env *= 0.994
		var w := randf() * 2.0 - 1.0
		lp += (w - lp) * 0.05
		var growl := sin(TAU * 62.0 * t) + 0.6 * sin(TAU * 93.0 * t + 2.0 * sin(TAU * 3.0 * t))
		var trem := 0.65 + 0.35 * sin(TAU * 11.0 * t)
		buf[i] = growl * trem * 0.5 + lp * 1.4 + (w - lp) * env * 0.35
	return buf


## Ominous swell as the void forms.
func _gen_void_form(dur: float) -> PackedFloat32Array:
	var buf := _buf(dur)
	var n := buf.size()
	var rate := float(AudioManager.RATE)
	var lp := 0.0
	for i in n:
		var t := float(i) / rate
		var k := float(i) / float(n)
		var env := pow(sin(PI * k), 0.6)
		var w := randf() * 2.0 - 1.0
		lp += (w - lp) * 0.03
		var tone := sin(TAU * 40.0 * t) + 0.7 * sin(TAU * 60.5 * t) + 0.35 * sin(TAU * 81.0 * t + 1.5 * sin(TAU * 0.9 * t))
		buf[i] = (tone * 0.5 + lp * k * 2.0) * env
	return buf


## Deep expanding hum (loop).
func _gen_void_hum(dur: float) -> PackedFloat32Array:
	var buf := _buf(dur)
	var n := buf.size()
	var rate := float(AudioManager.RATE)
	var lp := 0.0
	for i in n:
		var t := float(i) / rate
		var w := randf() * 2.0 - 1.0
		lp += (w - lp) * 0.025
		var hum := sin(TAU * 36.0 * t) + 0.7 * sin(TAU * 54.3 * t) + 0.4 * sin(TAU * 72.6 * t + 2.0 * sin(TAU * 0.5 * t))
		buf[i] = hum * (0.75 + 0.25 * sin(TAU * 1.3 * t)) * 0.5 + lp * 1.2
	return buf


## Disintegration: a spray of glassy pings dissolving into hiss.
func _gen_void_dis(dur: float) -> PackedFloat32Array:
	var buf := _buf(dur)
	var n := buf.size()
	var rate := float(AudioManager.RATE)
	var lp := 0.0
	var phase := 0.0
	var freq := 3000.0
	var env := 1.0
	for i in n:
		var k := float(i) / float(n)
		if i % 500 == 0:
			freq = randf_range(1800.0, 5200.0)
			env = 1.0
		env *= 0.996
		phase += TAU * freq / rate
		var w := randf() * 2.0 - 1.0
		lp += (w - lp) * 0.3
		buf[i] = (sin(phase) * env * 0.5 + (w - lp) * 0.18) * (1.0 - k)
	return buf
