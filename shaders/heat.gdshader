// Heat-haze distortion volume.
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform float strength = 0.012;
uniform float phase = 0.0;

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float m = smoothstep(0.0, 0.5, facing);
	vec2 wob = vec2(sin(FRAGCOORD.y * 0.05 + phase * 6.0), cos(FRAGCOORD.x * 0.04 + phase * 5.0));
	ALBEDO = texture(screen_tex, SCREEN_UV + wob * strength * m).rgb;
	ALPHA = m;
}
