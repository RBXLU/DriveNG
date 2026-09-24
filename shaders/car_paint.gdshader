shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Автомобильная краска: металлик с блёстками, лак, царапины, грунт и
// «мятый металл» (фасетированные нормали) в местах деформации.
// UV2.x — накопленное повреждение вершины (0..1), COLOR — швы панелей.

uniform vec4 paint_color : source_color = vec4(0.7, 0.05, 0.05, 1.0);
uniform float metallic_amount : hint_range(0.0, 1.0) = 0.45;
uniform float base_roughness : hint_range(0.0, 1.0) = 0.28;
uniform float flake_amount : hint_range(0.0, 1.0) = 0.35;
uniform float dirt : hint_range(0.0, 1.0) = 0.0;
uniform float clearcoat_amount : hint_range(0.0, 1.0) = 1.0;

varying float v_dmg;
varying vec3 v_obj;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash13(i);
	float n100 = hash13(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash13(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash13(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash13(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash13(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash13(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash13(i + vec3(1.0, 1.0, 1.0));
	return mix(mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y),
			mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y), f.z);
}

void vertex() {
	v_dmg = UV2.x;
	v_obj = VERTEX;
}

void fragment() {
	float dmg = clamp(v_dmg, 0.0, 1.0);
	float n1 = vnoise(v_obj * 9.0);
	float n2 = vnoise(v_obj * vec3(60.0, 8.0, 60.0));
	float n3 = vnoise(v_obj * 31.0);

	vec3 base = paint_color.rgb * COLOR.rgb;
	// тусклая, облупившаяся краска в зоне вмятины
	float scuff = smoothstep(0.15, 0.55, dmg + (n1 - 0.5) * 0.5);
	// голый металл — по длинным «царапинам»
	float scratch = smoothstep(0.62, 0.8, dmg * 0.9 + (n2 - 0.5) * 0.7 + (n3 - 0.5) * 0.25);
	vec3 primer = vec3(0.32, 0.31, 0.29);
	vec3 metal = vec3(0.62, 0.63, 0.65) * (0.75 + 0.5 * n3);
	vec3 col = mix(base, mix(base * 0.6, primer, 0.35), scuff * 0.7);
	col = mix(col, metal, scratch);
	// грязь снизу
	float dirt_mask = dirt * smoothstep(0.75, 0.15, v_obj.y) * (0.55 + 0.45 * n1);
	col = mix(col, vec3(0.19, 0.16, 0.12), dirt_mask);
	ALBEDO = col;

	float flake = step(0.9, hash13(floor(v_obj * 420.0))) * flake_amount * (1.0 - scuff);
	METALLIC = mix(metallic_amount + flake * 0.3, 0.95, scratch);
	ROUGHNESS = clamp(mix(base_roughness - flake * 0.12, 0.62, max(scuff * 0.8, dirt_mask)), 0.04, 1.0);
	ROUGHNESS = mix(ROUGHNESS, 0.35, scratch);
	SPECULAR = 0.55;
	CLEARCOAT = clearcoat_amount * (1.0 - scuff) * (1.0 - dirt_mask);
	CLEARCOAT_ROUGHNESS = 0.08;

	// Мятый металл: в повреждённых местах используем нормаль грани
	vec3 fn = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	if (dot(fn, VERTEX) > 0.0) {
		fn = -fn;
	}
	float facet = smoothstep(0.08, 0.4, dmg);
	NORMAL = normalize(mix(NORMAL, fn, facet));
}
