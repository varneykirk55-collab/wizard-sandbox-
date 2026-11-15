// Fire tornado column. Applied to an open unit cylinder (radius 1, height 1).
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform float phase = 0.0;
uniform float intensity = 1.0;
uniform float twist = 3.0;
uniform float flare = 1.6;
uniform float seed = 0.0;
uniform vec3 color_hot : source_color = vec3(1.0, 0.9, 0.55);
uniform vec3 color_mid : source_color = vec3(1.0, 0.42, 0.04);
uniform vec3 color_cool : source_color = vec3(0.5, 0.05, 0.0);

varying float hgt;
varying float ang;

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

void vertex() {
	hgt = VERTEX.y + 0.5;
	ang = atan(VERTEX.z, VERTEX.x);
	float rad = mix(0.35, flare, pow(hgt, 1.4));
	float n = vnoise(vec3(cos(ang) * 1.5, hgt * 4.0 - phase * 0.8, sin(ang) * 1.5) + vec3(seed, seed, seed));
	rad *= 1.0 + (n - 0.5) * 0.35;
	VERTEX.x = VERTEX.x * rad + sin(hgt * 5.0 + phase * 1.3 + seed) * 0.14 * hgt;
	VERTEX.z = VERTEX.z * rad + cos(hgt * 4.0 + phase + seed) * 0.14 * hgt;
}

void fragment() {
	float a = ang + hgt * twist - phase * 2.0;
	vec3 q = vec3(cos(a) * 2.0, hgt * 5.0 - phase * 1.5, sin(a) * 2.0);
	float n = fbm3(q + vec3(seed, seed, seed));
	float streak = fbm3(vec3(cos(a) * 4.0, hgt * 2.0 - phase * 3.0, sin(a) * 4.0) + vec3(seed * 2.0, 0.0, seed));
	float f = n * 0.7 + streak * 0.6;
	float heat = clamp(f * 1.5 - hgt * 0.45, 0.0, 1.0);
	vec3 col = mix(color_cool, color_mid, smoothstep(0.15, 0.5, heat));
	col = mix(col, color_hot, smoothstep(0.6, 0.95, heat));
	float edge = smoothstep(0.0, 0.08, hgt) * (1.0 - smoothstep(0.75, 1.0, hgt));
	float alpha = smoothstep(0.25, 0.7, f) * edge * intensity;
	ALBEDO = col * (2.0 + 3.0 * intensity);
	ALPHA = clamp(alpha, 0.0, 1.0);
}
