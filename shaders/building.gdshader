shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Фасады зданий: сетка окон по мировым координатам, ночью часть окон горит.
// COLOR — цвет фасада, UV2.x — сид здания.
#include "res://shaders/noise.gdshaderinc"

uniform float night = 0.0;
uniform vec3 roof_color : source_color = vec3(0.25, 0.25, 0.26);

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 base = COLOR.rgb;
	float seed = UV2.x;
	if (wnrm.y > 0.6) {
		ALBEDO = roof_color * (0.85 + 0.3 * n_noise(wpos.xz * 0.5));
		ROUGHNESS = 0.9;
	} else {
		float u = abs(wnrm.x) > abs(wnrm.z) ? wpos.z : wpos.x;
		float v = wpos.y;
		vec2 cell = vec2(u / 3.2, (v - 0.6) / 3.3);
		vec2 f = fract(cell);
		vec2 id = floor(cell);
		float win = step(0.2, f.x) * step(f.x, 0.8) * step(0.28, f.y) * step(f.y, 0.85) * step(0.0, id.y);
		float h = n_hash(id + seed * 17.0);
		vec3 glass = vec3(0.07, 0.09, 0.12) + vec3(0.1, 0.12, 0.14) * h;
		vec3 col = base * (0.9 + 0.2 * n_noise(wpos.xz * 0.3 + wpos.y * 0.2));
		col = mix(col, glass, win);
		// межэтажные пояски
		col *= 1.0 - (1.0 - smoothstep(0.0, 0.06, f.y)) * 0.25;
		ALBEDO = col;
		ROUGHNESS = mix(0.85, 0.15, win);
		METALLIC = win * 0.3;
		float lit = step(0.62, h) * win * night;
		EMISSION = vec3(1.0, 0.82, 0.55) * lit * (1.2 + 1.5 * n_hash(id * 3.1));
	}
}
