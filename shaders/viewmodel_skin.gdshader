// Stylized skin for the first-person hands. Vertex color:
//   R = crease darkening, G = rosy mix, B = roughness bias.
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx, shadows_disabled;

uniform vec4 skin_color : source_color = vec4(0.74, 0.48, 0.38, 1.0);
uniform vec4 shade_color : source_color = vec4(0.48, 0.26, 0.24, 1.0);

void fragment() {
	float crease = clamp(COLOR.r, 0.0, 1.0);
	float rosy = clamp(COLOR.g, 0.0, 1.0);
	float rough_b = clamp(COLOR.b, 0.0, 1.0);
	vec3 col = mix(shade_color.rgb, skin_color.rgb, rosy);
	ALBEDO = col * mix(0.78, 1.0, crease);
	ROUGHNESS = clamp(mix(0.58, 0.38, rough_b), 0.2, 0.9);
	METALLIC = 0.0;
	SPECULAR = 0.32;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.6);
	EMISSION = vec3(0.35, 0.16, 0.14) * rim * 0.08;
}
