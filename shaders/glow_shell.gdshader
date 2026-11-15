// Simple additive glow: rim glow (center = 0) or solid core glow (center = 1).
shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled;

uniform vec3 color : source_color = vec3(1.0, 0.6, 0.2);
uniform float energy = 4.0;
uniform float power = 3.0;
uniform float center = 0.0;

void fragment() {
	float f = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float g = mix(pow(1.0 - f, power), pow(f, power), center);
	ALBEDO = color * energy;
	ALPHA = clamp(g, 0.0, 1.0);
}
