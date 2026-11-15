// Gravitational lens: bends and swirls the screen behind the singularity.
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform float strength = 0.14;
uniform float phase = 0.0;

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float lens = smoothstep(0.0, 0.9, facing);
	vec2 dir = normalize(NORMAL.xy + vec2(0.0001, 0.0001));
	dir = vec2(dir.x, -dir.y);
	float ang = lens * 1.8;
	float wob = sin(lens * 9.0 + atan(dir.y, dir.x) * 4.0 + phase * 2.0) * 0.25;
	vec2 rdir = vec2(dir.x * cos(ang) - dir.y * sin(ang), dir.x * sin(ang) + dir.y * cos(ang));
	vec2 off = rdir * lens * lens * strength * (1.0 + wob);
	vec3 scr = texture(screen_tex, SCREEN_UV + off).rgb;
	scr *= mix(1.0, 0.2, lens * lens);
	ALBEDO = scr + vec3(0.35, 0.1, 0.8) * pow(lens, 3.0) * 0.3;
	ALPHA = smoothstep(0.0, 0.12, facing);
}
