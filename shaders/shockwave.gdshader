// Expanding refractive shock shell (screen-space distortion at the rim).
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform float strength = 0.07;
uniform float fade = 1.0;
uniform vec3 tint : source_color = vec3(1.0, 0.8, 0.6);

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(1.0 - facing, 2.5);
	float band = rim * smoothstep(0.0, 0.15, facing);
	vec2 dir = normalize(NORMAL.xy + vec2(0.0001, 0.0001));
	vec2 off = vec2(dir.x, -dir.y) * band * strength * fade;
	vec3 scr = texture(screen_tex, SCREEN_UV + off).rgb;
	ALBEDO = scr + tint * band * fade * 0.6;
	ALPHA = clamp(band * 4.0, 0.0, 1.0) * fade;
}
