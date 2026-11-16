// Wizard sleeve. Back faces show a lighter lining so the bell reads as cloth.
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx, shadows_disabled;

uniform vec4 cloth_color : source_color = vec4(0.10, 0.045, 0.22, 1.0);
uniform vec4 lining_color : source_color = vec4(0.20, 0.09, 0.34, 1.0);
uniform vec4 fold_color : source_color = vec4(0.15, 0.07, 0.30, 1.0);

void fragment() {
	float fold = sin(UV.y * 10.0 + UV.x * 3.0) * 0.5 + 0.5;
	fold = smoothstep(0.4, 0.85, fold);
	float hem = smoothstep(0.0, 0.2, UV.y);
	vec3 outer = mix(cloth_color.rgb, fold_color.rgb, fold * 0.22);
	// Darker cuff at the wrist end of the sleeve (low UV.y).
	float cuff = smoothstep(0.28, 0.0, UV.y);
	outer = mix(outer, vec3(0.04, 0.018, 0.07), cuff * 0.45);
	outer *= mix(0.9, 1.0, hem);
	vec3 col = FRONT_FACING ? outer : lining_color.rgb;
	ALBEDO = col * COLOR.rgb;
	ROUGHNESS = FRONT_FACING ? 0.86 : 0.7;
	METALLIC = 0.0;
	SPECULAR = 0.22;
}
