// Opaque ruby. Unshaded so lights cannot blow the facets out to white.
// Output is linear. A cap near 0.50 lands around sRGB 190, softer than a
// clipped 255 disk, and stays red.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_opaque;

uniform vec4 ruby : source_color = vec4(0.22, 0.0, 0.02, 1.0);
uniform vec4 core_color : source_color = vec4(0.55, 0.02, 0.035, 1.0);
uniform float intensity = 1.0;

void fragment() {
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fres = pow(1.0 - ndv, 1.5);
	float heart = pow(ndv, 1.2);
	vec3 col = mix(ruby.rgb, core_color.rgb, heart);
	col = mix(col, vec3(0.48, 0.015, 0.03), fres * 0.28);
	float kick = clamp(intensity, 0.55, 1.45);
	vec3 ruby_out = min(col, vec3(0.42, 0.022, 0.032));
	// Idle sits under the cap. A cast raises it by about a quarter, still red.
	ruby_out *= mix(1.0, 1.28, clamp((kick - 0.75) / 0.7, 0.0, 1.0));
	ALBEDO = ruby_out;
	EMISSION = ruby_out * 0.05;
}
