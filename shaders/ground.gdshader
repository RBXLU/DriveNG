shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Процедурная земля в мировых координатах: трава/грунт/бетон, пятна, мелкая
// детализация, затухающая с расстоянием (без мерцания). COLOR.r — скалы, COLOR.g — грунт.
#include "res://shaders/noise.gdshaderinc"

uniform vec3 color_a : source_color = vec3(0.23, 0.36, 0.13);
uniform vec3 color_b : source_color = vec3(0.32, 0.4, 0.16);
uniform vec3 color_c : source_color = vec3(0.35, 0.3, 0.2);
uniform vec3 rock_color : source_color = vec3(0.42, 0.4, 0.37);
uniform vec3 dirt_color : source_color = vec3(0.4, 0.33, 0.24);
uniform float scale = 0.035;
uniform float rough = 0.92;
uniform float use_vertex_color = 0.0;
uniform float tiles = 0.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	float dist = length(VERTEX);
	float detail_fade = 1.0 - smoothstep(30.0, 140.0, dist);
	float n1 = n_fbm(p * scale);
	float n2 = n_noise(p * scale * 9.0);
	float n3 = n_noise(p * 1.7);
	vec3 col = mix(color_a, color_b, smoothstep(0.35, 0.7, n1));
	col = mix(col, color_c, smoothstep(0.62, 0.9, n2) * 0.55);
	col *= 0.88 + 0.24 * mix(0.5, n3, detail_fade);
	if (use_vertex_color > 0.5) {
		vec3 rc = rock_color * (0.75 + 0.5 * n2);
		col = mix(col, rc, clamp(COLOR.r, 0.0, 1.0));
		col = mix(col, dirt_color * (0.85 + 0.3 * n3), clamp(COLOR.g, 0.0, 1.0));
	}
	if (tiles > 0.0) {
		// бетонные плиты со швами
		vec2 g = abs(fract(p / tiles) - 0.5);
		float seam = smoothstep(0.492, 0.498, max(g.x, g.y));
		col *= 1.0 - seam * 0.35 * (1.0 - smoothstep(40.0, 120.0, dist));
		col *= 0.93 + 0.14 * n_hash(floor(p / tiles));
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.3;
}
