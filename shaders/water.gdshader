shader_type spatial;
render_mode specular_schlick_ggx, cull_back;

// Недорогая вода: бегущие нормали из шума, френель за счёт низкой шероховатости.
#include "res://shaders/noise.gdshaderinc"

uniform vec3 deep : source_color = vec3(0.02, 0.09, 0.12);
uniform vec3 shallow : source_color = vec3(0.06, 0.2, 0.22);

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	float t = TIME * 0.4;
	float n1 = n_noise(p * 0.35 + vec2(t, t * 0.6));
	float n2 = n_noise(p * 0.8 - vec2(t * 0.7, t));
	float nx = n_noise(p * 0.35 + vec2(t, t * 0.6) + vec2(0.3, 0.0)) - n1;
	float nz = n_noise(p * 0.35 + vec2(t, t * 0.6) + vec2(0.0, 0.3)) - n1;
	NORMAL_MAP = normalize(vec3(0.5 + nx * 1.5 + (n2 - 0.5) * 0.1, 0.5 + nz * 1.5, 1.0));
	NORMAL_MAP_DEPTH = 1.0;
	ALBEDO = mix(deep, shallow, n2 * 0.5);
	ROUGHNESS = 0.06;
	METALLIC = 0.0;
	SPECULAR = 0.8;
}
