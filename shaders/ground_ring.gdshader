// Flat expanding ground shock ring (drawn on a 2x2 plane that is scaled up).
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform float progress = 0.0;
uniform float energy = 3.0;
uniform vec3 tint : source_color = vec3(1.0, 0.7, 0.4);

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float w = mix(0.14, 0.04, progress);
	float ring = smoothstep(0.9 - w, 0.9, r) * (1.0 - smoothstep(0.9, 0.96, r));
	ALBEDO = tint * energy;
	ALPHA = clamp(ring * (1.0 - progress), 0.0, 1.0);
}
