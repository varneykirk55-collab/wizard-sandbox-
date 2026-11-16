// Dark carved wood. UV.y runs butt -> head, UV.x runs around the shaft.
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx, shadows_disabled;

uniform vec4 wood_color : source_color = vec4(0.20, 0.09, 0.035, 1.0);
uniform vec4 dark_color : source_color = vec4(0.05, 0.02, 0.012, 1.0);
uniform vec4 worn_color : source_color = vec4(0.34, 0.16, 0.07, 1.0);
uniform float head_glow = 0.15;

void fragment() {
	float along = UV.y;
	float around = UV.x;
	float rings = sin(along * 52.0 + around * 11.0);
	float grain = smoothstep(-0.15, 0.9, rings);
	float pores = sin(along * 140.0 + sin(around * TAU) * 3.0);
	float ridge = pow(abs(sin(around * TAU * 2.0 + along * 22.0)), 5.0);
	vec3 col = mix(dark_color.rgb, wood_color.rgb, grain);
	col = mix(col, dark_color.rgb * 0.65, smoothstep(0.15, 0.95, pores) * 0.4);
	col = mix(col, worn_color.rgb, ridge * 0.42);
	col *= COLOR.rgb;
	ALBEDO = col;
	ROUGHNESS = mix(0.84, 0.58, ridge);
	METALLIC = 0.0;
	SPECULAR = 0.22;
	NORMAL = normalize(NORMAL + vec3(rings, 0.0, pores) * 0.18);
	float crown = smoothstep(0.72, 1.0, along);
	EMISSION = vec3(0.42, 0.015, 0.03) * head_glow * crown;
}
