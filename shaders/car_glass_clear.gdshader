shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, specular_schlick_ggx;

// Полупрозрачное стекло с френелем: сквозь него виден салон
#include "res://shaders/car_glass_common.gdshaderinc"

uniform float opacity : hint_range(0.0, 1.0) = 0.6;

void fragment() {
	vec3 col;
	float rough;
	float line;
	glass_shade(col, rough, line);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = col;
	METALLIC = 0.1;
	ROUGHNESS = rough;
	SPECULAR = 0.9;
	ALPHA = clamp(opacity + fres * 0.5 + line * 0.6 + broken * 0.15, 0.0, 1.0);
}
