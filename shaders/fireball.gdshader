// Layered turbulent fireball. "progress" 0..1 cools and dissolves it.
shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled;

uniform float progress = 0.0;
uniform float energy = 6.0;
uniform float seed = 0.0;
uniform vec3 color_hot : source_color = vec3(1.0, 0.95, 0.7);
uniform vec3 color_mid : source_color = vec3(1.0, 0.45, 0.05);
uniform vec3 color_cool : source_color = vec3(0.35, 0.03, 0.0);

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
	float n = fbm3(VERTEX * 2.2 + vec3(seed, TIME * 0.6, seed * 1.7));
	VERTEX += NORMAL * (n - 0.4) * 0.35;
}

void fragment() {
	float n = fbm3(lpos * 3.0 + vec3(seed, -TIME * 1.2 - progress * 3.0, seed));
	float fres = pow(clamp(dot(NORMAL, VIEW), 0.0, 1.0), 1.2);
	float heat = clamp(fres * 1.4 + n * 0.9 - progress * 1.5, 0.0, 1.0);
	vec3 col = mix(color_cool, color_mid, smoothstep(0.1, 0.5, heat));
	col = mix(col, color_hot, smoothstep(0.55, 0.95, heat));
	float alpha = smoothstep(0.02, 0.35, heat) * (1.0 - smoothstep(0.7, 1.0, progress));
	ALBEDO = col * energy;
	ALPHA = clamp(alpha, 0.0, 1.0);
}
