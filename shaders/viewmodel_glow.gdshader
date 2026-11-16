// Additive halo used for the crystal bloom and the casting-hand flash.
shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled;

uniform vec3 color : source_color = vec3(1.0, 0.15, 0.12);
uniform float energy = 2.0;
uniform float power = 2.2;

void fragment() {
	float f = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float g = pow(1.0 - f, power);
	ALBEDO = color * energy;
	ALPHA = clamp(g, 0.0, 1.0);
}
