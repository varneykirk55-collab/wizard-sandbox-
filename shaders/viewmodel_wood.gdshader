// Carved staff wood. UV.y runs butt -> head, UV.x runs around the shaft.
// head_glow picks up the crystal pulse near the crown (high UV.y).
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx, shadows_disabled;

uniform vec4 wood_color : source_color = vec4(0.36, 0.18, 0.08, 1.0);
uniform vec4 dark_color : source_color = vec4(0.12, 0.05, 0.02, 1.0);
uniform vec4 worn_color : source_color = vec4(0.52, 0.30, 0.14, 1.0);
uniform float head_glow = 0.2;

void fragment() {
	float along = UV.y;
	float around = UV.x;
	float grain = sin(along * 70.0 + around * 14.0) * 0.5 + 0.5;
	float fine = sin(along * 180.0 + sin(around * TAU) * 2.0) * 0.5 + 0.5;
	float bands = smoothstep(0.42, 0.58, sin(along * 16.0) * 0.5 + 0.5);
	vec3 col = mix(dark_color.rgb, wood_color.rgb, grain);
	col = mix(col, worn_color.rgb, bands * 0.28 + fine * 0.08);
	col *= COLOR.rgb;
	ALBEDO = col;
	ROUGHNESS = mix(0.78, 0.55, bands);
	METALLIC = 0.0;
	SPECULAR = 0.28;
	float crown = smoothstep(0.62, 1.0, along);
	EMISSION = vec3(0.85, 0.08, 0.10) * head_glow * crown;
}
