shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Асфальт с разметкой. UV.x — метры поперёк дороги от левой кромки, UV.y — метры вдоль.
#include "res://shaders/noise.gdshaderinc"

uniform float road_width = 10.0;
uniform float lanes_per_dir = 1.0;
uniform float lane_width = 3.5;
uniform float median = 0.0;         // половина ширины разделительной зоны
uniform float center_solid = 1.0;   // 1 — сплошная по центру
uniform vec3 line_color : source_color = vec3(0.92, 0.92, 0.88);
uniform vec3 center_color : source_color = vec3(0.95, 0.75, 0.15);
uniform vec3 asphalt : source_color = vec3(0.2, 0.2, 0.205);
uniform float wear = 1.0;

varying vec3 wpos;

float line(float x, float c, float w) {
	return 1.0 - smoothstep(w * 0.5 - 0.02, w * 0.5 + 0.02, abs(x - c));
}

float dashed(float y, float len, float gap) {
	return step(fract(y / (len + gap)), len / (len + gap));
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float x = UV.x;
	float y = UV.y;
	float c = road_width * 0.5;
	float dist = length(VERTEX);
	float fade = 1.0 - smoothstep(25.0, 120.0, dist);
	vec2 wp = wpos.xz;
	float n1 = n_fbm(wp * 0.08);
	float n2 = n_noise(wp * 3.0);
	vec3 col = asphalt * (0.85 + 0.3 * n1) * (0.92 + 0.16 * mix(0.5, n2, fade));
	// накатанные колеи
	float lx = mod(abs(x - c) - median, lane_width);
	float track = smoothstep(0.35, 0.0, abs(lx - lane_width * 0.28)) + smoothstep(0.35, 0.0, abs(lx - lane_width * 0.72));
	col *= 1.0 - track * 0.12 * wear;
	float m = 0.0;
	vec3 mc = line_color;
	float edge = c - median - lanes_per_dir * lane_width;
	// кромки
	m = max(m, line(abs(x - c), c - edge + 0.25, 0.15));
	// центр
	if (median > 0.05) {
		float cm = line(abs(x - c), median + 0.2, 0.15);
		if (cm > 0.0) { mc = center_color; }
		m = max(m, cm);
	} else {
		float cl;
		if (center_solid > 0.5) {
			cl = max(line(x, c - 0.12, 0.1), line(x, c + 0.12, 0.1));
		} else {
			cl = line(x, c, 0.12) * dashed(y, 3.0, 6.0);
		}
		if (cl > 0.0) { mc = center_color; }
		m = max(m, cl);
	}
	// разделители полос
	for (int k = 1; k < 4; k++) {
		if (float(k) >= lanes_per_dir) { break; }
		float off = median + float(k) * lane_width;
		m = max(m, (line(x, c - off, 0.13) + line(x, c + off, 0.13)) * dashed(y, 4.0, 8.0));
	}
	m *= 0.75 + 0.25 * n2;
	col = mix(col, mc, clamp(m, 0.0, 1.0));
	ALBEDO = col;
	ROUGHNESS = mix(0.85, 0.6, m);
	SPECULAR = 0.35;
}
