// Тонированное стекло. broken = 1 — «паутина» трещин (разбитое стекло).
uniform vec4 tint : source_color = vec4(0.04, 0.055, 0.07, 1.0);
uniform float broken : hint_range(0.0, 1.0) = 0.0;

varying vec3 v_obj;

vec2 hash22(vec2 p) {
	vec3 a = fract(vec3(p.xyx) * vec3(0.1031, 0.103, 0.0973));
	a += dot(a, a.yzx + 33.33);
	return fract((a.xx + a.yz) * a.zy);
}

// расстояние до границы ячейки Вороного — трещины
float cracks(vec2 uv) {
	vec2 i = floor(uv);
	vec2 f = fract(uv);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = hash22(i + g);
			float d = length(g + o - f);
			if (d < d1) {
				d2 = d1;
				d1 = d;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return d2 - d1;
}

void vertex() {
	v_obj = VERTEX;
}

// col — цвет, rough — шероховатость, line — трещины (0..1)
void glass_shade(out vec3 col, out float rough, out float line) {
	col = tint.rgb;
	rough = 0.04;
	line = 0.0;
	if (broken > 0.5) {
		vec2 uv = v_obj.xy * 7.0 + v_obj.zz * 5.0;
		float c = cracks(uv);
		float c2 = cracks(uv * 3.1 + 7.0);
		line = 1.0 - smoothstep(0.0, 0.06, min(c, c2 + 0.02));
		col = mix(col * 1.6, vec3(0.75, 0.78, 0.8), line * 0.8);
		rough = mix(0.25, 0.6, line);
	}
}
