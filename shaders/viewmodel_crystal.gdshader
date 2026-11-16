// Faceted red crystal. `intensity` is driven by the idle breath and cast kick.
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx, shadows_disabled;

uniform vec4 gem_color : source_color = vec4(0.62, 0.015, 0.04, 1.0);
uniform vec4 hot_color : source_color = vec4(1.0, 0.12, 0.14, 1.0);
uniform float intensity = 1.0;

void fragment() {
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fres = pow(1.0 - ndv, 1.7);
	float core = pow(ndv, 0.8);
	vec3 col = mix(gem_color.rgb, hot_color.rgb, core * 0.35);
	// Stay in a red range after ACES. High multipliers blow the gem out to white.
	ALBEDO = col * 0.85;
	EMISSION = col * intensity * (0.65 + fres * 0.4);
	ROUGHNESS = mix(0.16, 0.04, core);
	METALLIC = 0.0;
	SPECULAR = 0.95;
}
