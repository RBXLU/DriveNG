shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx;

// Непрозрачное тонированное стекло (дёшево — для слабых устройств)
#include "res://shaders/car_glass_common.gdshaderinc"

void fragment() {
	vec3 col;
	float rough;
	float line;
	glass_shade(col, rough, line);
	ALBEDO = col;
	METALLIC = 0.1;
	ROUGHNESS = rough;
	SPECULAR = 0.9;
}
