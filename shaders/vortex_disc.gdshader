// Spiralling accretion disc for the gravity well (drawn on a 2x2 plane).
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform float phase = 0.0;
uniform float energy = 3.0;
uniform vec3 color_a : source_color = vec3(0.55, 0.2, 1.0);
uniform vec3 color_b : source_color = vec3(0.25, 0.6, 1.0);

float h31(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(h31(i + vec3(0.0, 0.0, 0.0)), h31(i + vec3(1.0, 0.0, 0.0)), f.x);
	float b = mix(h31(i + vec3(0.0, 1.0, 0.0)), h31(i + vec3(1.0, 1.0, 0.0)), f.x);
	float c = mix(h31(i + vec3(0.0, 0.0, 1.0)), h31(i + vec3(1.0, 0.0, 1.0)), f.x);
	float d = mix(h31(i + vec3(0.0, 1.0, 1.0)), h31(i + vec3(1.0, 1.0, 1.0)), f.x);
	return mix(mix(a, b, f.y), mix(c, d, f.y), f.z);
}

float fbm3(vec3 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		v += amp * vnoise(p);
		p *= 2.03;
		amp *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float swirl = a + phase + 2.5 / (r + 0.15);
	float arms = sin(swirl * 3.0) * 0.5 + 0.5;
	float n = fbm3(vec3(cos(swirl) * 2.0, sin(swirl) * 2.0, r * 6.0 - phase * 0.5));
	float band = smoothstep(0.16, 0.3, r) * (1.0 - smoothstep(0.55, 1.0, r));
	float v = band * (arms * 0.6 + n * 0.9);
	vec3 col = mix(color_a, color_b, n) + vec3(1.0, 1.0, 1.0) * smoothstep(0.75, 1.0, v);
	ALBEDO = col * energy;
	ALPHA = clamp(v, 0.0, 1.0);
}
