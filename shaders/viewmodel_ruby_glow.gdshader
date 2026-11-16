// Soft red halo. Mix blend, not additive: additive glow plus the white moon
// composites to pink. Alpha carries a ruby color over whatever is behind.
shader_type spatial;
render_mode unshaded, blend_mix, cull_back, depth_draw_never, shadows_disabled;

uniform vec3 color : source_color = vec3(0.62, 0.015, 0.05);
uniform float energy = 0.41;
uniform float power = 2.0;

void fragment() {
	float f = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float g = pow(1.0 - f, power);
	ALBEDO = color;
	ALPHA = clamp(g * energy, 0.0, 0.26);
}
