// Molten meteor rock: displaced surface with glowing cracks.
shader_type spatial;

uniform float seed = 0.0;
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
	float n = fbm3(VERTEX * 1.3 + vec3(seed, seed, seed));
	VERTEX += NORMAL * (n - 0.5) * 0.7;
}

void fragment() {
	float n = fbm3(lpos * 2.5 + vec3(seed, seed, seed));
	float crack = 1.0 - smoothstep(0.0, 0.07, abs(n - 0.5));
	ALBEDO = mix(vec3(0.07, 0.05, 0.04), vec3(0.2, 0.15, 0.12), n);
	ROUGHNESS = 0.95;
	EMISSION = vec3(1.0, 0.35, 0.05) * (crack * 9.0 + 0.5);
}
