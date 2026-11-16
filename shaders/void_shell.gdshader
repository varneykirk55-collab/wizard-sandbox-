// Oblivion boundary: violet energy filaments crawling over a sphere.
shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled;

uniform float phase = 0.0;
uniform float energy = 2.0;
uniform vec3 color_a : source_color = vec3(0.5, 0.18, 1.0);
uniform vec3 color_b : source_color = vec3(0.85, 0.3, 1.0);

varying vec3 lpos;

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
	lpos = VERTEX;
	float n = vnoise(VERTEX * 3.0 + vec3(0.0, phase * 0.5, 0.0));
	VERTEX += NORMAL * (n - 0.5) * 0.05;
}

void fragment() {
	float n = fbm3(lpos * 2.6 + vec3(phase * 0.35, -phase * 0.5, phase * 0.2));
	float ridge = 1.0 - abs(n * 2.0 - 1.0);
	ridge = pow(clamp(ridge, 0.0, 1.0), 6.0);
	float f = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(1.0 - f, 1.5);
	vec3 col = mix(color_a, color_b, n) + vec3(1.0, 1.0, 1.0) * pow(ridge, 3.0) * 0.5;
	ALBEDO = col * energy;
	ALPHA = clamp(ridge * (0.25 + rim), 0.0, 1.0);
}
