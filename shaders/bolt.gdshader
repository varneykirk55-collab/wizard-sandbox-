// Lightning ribbon: white-hot core with a coloured glow falloff.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec3 color : source_color = vec3(0.55, 0.72, 1.0);
uniform float energy = 12.0;

void fragment() {
	float x = abs(UV.x * 2.0 - 1.0);
	float core = 1.0 - smoothstep(0.0, 0.3, x);
	float glow = pow(1.0 - x, 2.0);
	ALBEDO = (color * glow + vec3(1.0, 1.0, 1.0) * core) * energy;
	ALPHA = clamp(glow + core, 0.0, 1.0);
}
