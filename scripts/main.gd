extends Node3D
## Startup scene script: builds lighting, ground, village, player and HUD.

var player
var hud


func _ready() -> void:
	add_to_group("main")
	_build_environment()
	_build_ground()
	var village = load("res://scripts/world/village_builder.gd").new()
	village.name = "Village"
	add_child(village)
	village.build()
	player = load("res://scripts/player/player.gd").new()
	player.name = "Player"
	add_child(player)
	player.global_position = Vector3(0.0, 0.3, 31.0)
	hud = load("res://scripts/ui/hud.gd").new()
	hud.player = player
	add_child(hud)
	FX.player = player
	FX.hud = hud
	DM.player = player
	hud.toast("Unleash everything.")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset_world"):
		reset_world()


## R / controller Y: immediate full-world reset.
func reset_world() -> void:
	player.caster.release()
	FX.clear()
	DM.reset_all()
	AudioManager.play_ui("chime", -6.0, 1.2)
	hud.toast("World restored")


func _build_environment() -> void:
	# Enchanted night: indigo sky with stars, cool moonlight, purple mist.
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.015, 0.02, 0.09)
	sky_mat.sky_horizon_color = Color(0.2, 0.11, 0.36)
	sky_mat.ground_bottom_color = Color(0.01, 0.01, 0.03)
	sky_mat.ground_horizon_color = Color(0.14, 0.08, 0.26)
	sky_mat.sun_angle_max = 4.0
	sky_mat.sky_cover = _star_texture()
	sky_mat.sky_cover_modulate = Color(1, 1, 1, 1)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.29, 0.6)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 1.0
	env.glow_bloom = 0.1
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.fog_enabled = true
	env.fog_light_color = Color(0.13, 0.09, 0.27)
	env.fog_density = 0.005
	env.fog_sky_affect = 0.25
	env.fog_height = 2.5
	env.fog_height_density = 0.04
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.2
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# The moon hangs behind the village, rim-lighting the silhouettes.
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-35.0, -160.0, 0.0)
	moon.light_color = Color(0.56, 0.64, 1.0)
	moon.light_energy = 0.7
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 130.0
	add_child(moon)
	# Drifting magical motes over the village.
	var motes: GPUParticles3D = FX.particles({"mat": "magic", "amount": 140, "life": 7.0, "radius": 30.0, "vel": Vector2(0.1, 0.5), "grav": Vector3(0.0, 0.05, 0.0), "scale": Vector2(0.1, 0.26), "curve": [[0.0, 0.0], [0.3, 1.0], [0.7, 1.0], [1.0, 0.0]], "colors": [Color(0.3, 0.95, 1.0, 0.0), Color(0.3, 0.95, 1.0, 0.8), Color(0.7, 0.4, 1.0, 0.8), Color(0.7, 0.4, 1.0, 0.0)]})
	motes.position = Vector3(0.0, 5.0, -4.0)
	add_child(motes)


func _star_texture() -> ImageTexture:
	var img := Image.create(1024, 512, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 1))
	for i in 1400:
		var x := randi_range(1, 1022)
		var y := randi_range(1, 250)
		var b := randf_range(0.35, 1.0)
		var c := Color(b * randf_range(0.8, 1.0), b * randf_range(0.8, 1.0), b, 1.0)
		img.set_pixel(x, y, c)
		if b > 0.9:
			img.set_pixel(x + 1, y, c)
			img.set_pixel(x, y + 1, c)
	return ImageTexture.create_from_image(img)


func _build_ground() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(600.0, 4.0, 600.0)
	col.shape = shape
	col.position = Vector3(0.0, -2.0, 0.0)
	body.add_child(col)
	add_child(body)

	var grass := _ground_mat(Color(0.13, 0.27, 0.23), 0.08, false)
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(600.0, 600.0)
	mi.mesh = pm
	mi.material_override = grass
	add_child(mi)

	# Cobblestone plaza and road in from the spawn point (visual only).
	var dirt := _ground_mat(Color(0.42, 0.4, 0.55), 0.45, true)
	var plaza := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 12.5
	cm.bottom_radius = 12.5
	cm.height = 0.04
	cm.radial_segments = 40
	plaza.mesh = cm
	plaza.material_override = dirt
	plaza.position = Vector3(0.0, 0.02, 0.0)
	plaza.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(plaza)
	var road := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(6.0, 0.04, 34.0)
	road.mesh = bm
	road.material_override = dirt
	road.position = Vector3(0.0, 0.015, 22.0)
	road.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(road)

	# Distant hills for a readable horizon.
	var hill_mat := StandardMaterial3D.new()
	hill_mat.albedo_color = Color(0.07, 0.06, 0.15)
	hill_mat.roughness = 1.0
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	for i in 9:
		var a := float(i) / 9.0 * TAU + 0.3
		var hill := MeshInstance3D.new()
		hill.mesh = sm
		hill.material_override = hill_mat
		var dist := 190.0 + float(i % 3) * 35.0
		hill.position = Vector3(cos(a) * dist, -6.0, sin(a) * dist)
		hill.scale = Vector3(70.0 + float(i % 4) * 14.0, 22.0 + float(i % 3) * 9.0, 60.0)
		hill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(hill)


func _ground_mat(color: Color, uv: float, cobble: bool) -> StandardMaterial3D:
	var n := FastNoiseLite.new()
	n.frequency = 0.05 if cobble else 0.02
	n.fractal_octaves = 2 if cobble else 5
	if cobble:
		n.noise_type = FastNoiseLite.TYPE_CELLULAR
		n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 1.0])
	ramp.colors = PackedColorArray([Color(0.6, 0.6, 0.6), Color(1, 1, 1)])
	var tex := NoiseTexture2D.new()
	tex.width = 512
	tex.height = 512
	tex.seamless = true
	tex.noise = n
	tex.color_ramp = ramp
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.albedo_texture = tex
	m.roughness = 0.8 if cobble else 1.0
	if cobble:
		var ntex := NoiseTexture2D.new()
		ntex.width = 512
		ntex.height = 512
		ntex.seamless = true
		ntex.noise = n
		ntex.as_normal_map = true
		ntex.bump_strength = 10.0
		m.normal_enabled = true
		m.normal_texture = ntex
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * uv
	return m
