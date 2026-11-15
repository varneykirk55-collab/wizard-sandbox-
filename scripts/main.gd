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
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.09, 0.15, 0.36)
	sky_mat.sky_horizon_color = Color(0.9, 0.52, 0.34)
	sky_mat.ground_bottom_color = Color(0.05, 0.05, 0.07)
	sky_mat.ground_horizon_color = Color(0.7, 0.42, 0.3)
	sky_mat.sun_angle_max = 25.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.12
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.fog_enabled = true
	env.fog_light_color = Color(0.62, 0.46, 0.4)
	env.fog_density = 0.0035
	env.fog_sun_scatter = 0.3
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.12
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-32.0, -37.0, 0.0)
	sun.light_color = Color(1.0, 0.82, 0.64)
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 130.0
	add_child(sun)


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

	var grass := _ground_mat(Color(0.3, 0.42, 0.2), 0.08)
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(600.0, 600.0)
	mi.mesh = pm
	mi.material_override = grass
	add_child(mi)

	# Dirt plaza and the road in from the spawn point (visual only).
	var dirt := _ground_mat(Color(0.5, 0.41, 0.3), 0.25)
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
	hill_mat.albedo_color = Color(0.16, 0.24, 0.16)
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


func _ground_mat(color: Color, uv: float) -> StandardMaterial3D:
	var n := FastNoiseLite.new()
	n.frequency = 0.02
	n.fractal_octaves = 5
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
	m.roughness = 1.0
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * uv
	return m
