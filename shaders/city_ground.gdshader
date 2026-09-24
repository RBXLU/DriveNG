shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Городская земля: сетка улиц с разметкой, стоп-линиями и зебрами — всё
// вычисляется по мировым координатам, один большой полигон на весь город.
#include "res://shaders/noise.gdshaderinc"

uniform float pitch = 110.0;
uniform float road_half = 7.0;
uniform float city_half = 330.0;
uniform vec3 asphalt : source_color = vec3(0.2, 0.2, 0.21);
uniform vec3 grass_a : source_color = vec3(0.22, 0.34, 0.13);
uniform vec3 grass_b : source_color = vec3(0.3, 0.38, 0.15);

varying vec3 wpos;

float band(float v, float w) {
	return 1.0 - smoothstep(w * 0.5 - 0.03, w * 0.5 + 0.03, abs(v));
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	float dist = length(VERTEX);
	float fade = 1.0 - smoothstep(25.0, 120.0, dist);
	float n1 = n_fbm(p * 0.07);
	float n2 = n_noise(p * 3.0);
	vec2 local = mod(p + pitch * 0.5, pitch) - pitch * 0.5;
	vec2 a = abs(local);
	bool inside = max(abs(p.x), abs(p.y)) < city_half + road_half + 0.5;
	vec3 col;
	float m = 0.0;
	if (inside) {
		col = asphalt * (0.85 + 0.3 * n1) * (0.92 + 0.16 * mix(0.5, n2, fade));
		bool road_x = a.x < road_half;   // улица вдоль Z
		bool road_z = a.y < road_half;   // улица вдоль X
		if (road_x && !road_z) {
			m = max(m, band(local.x, 0.14) * step(fract(p.y / 9.0), 0.4));
			// стоп-линия и зебра перед перекрёстком
			float d = a.y - road_half;
			m = max(m, step(d, 1.6) * step(1.0, d) * step(0.0, local.x) * step(local.x, road_half - 0.5));
			m = max(m, step(d, 0.9) * step(0.0, d) * 0.0);
			float zebra = step(abs(d - 5.0), 2.0) * step(fract(local.x / 1.2), 0.5);
			m = max(m, zebra * 0.9);
		} else if (road_z && !road_x) {
			m = max(m, band(local.y, 0.14) * step(fract(p.x / 9.0), 0.4));
			float d = a.x - road_half;
			m = max(m, step(d, 1.6) * step(1.0, d) * step(local.y, 0.0) * step(-road_half + 0.5, local.y));
			float zebra = step(abs(d - 5.0), 2.0) * step(fract(local.y / 1.2), 0.5);
			m = max(m, zebra * 0.9);
		}
		m *= 0.7 + 0.3 * n2;
		col = mix(col, vec3(0.9, 0.9, 0.86), clamp(m, 0.0, 1.0));
	} else {
		col = mix(grass_a, grass_b, smoothstep(0.35, 0.7, n1)) * (0.88 + 0.24 * mix(0.5, n2, fade));
	}
	ALBEDO = col;
	ROUGHNESS = inside ? mix(0.85, 0.6, m) : 0.92;
	SPECULAR = 0.3;
}
