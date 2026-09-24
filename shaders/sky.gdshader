shader_type sky;
render_mode use_quarter_res_pass;

// Небо: градиент, солнце с ореолом, рассеяние у горизонта, облака, звёзды ночью.
uniform vec3 zenith_color : source_color = vec3(0.18, 0.38, 0.75);
uniform vec3 horizon_color : source_color = vec3(0.62, 0.75, 0.9);
uniform vec3 ground_color : source_color = vec3(0.25, 0.27, 0.28);
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.85);
uniform float sun_disk = 1.0;
uniform float cloud_amount : hint_range(0.0, 1.0) = 0.45;
uniform float clouds_enabled = 1.0;
uniform float stars = 0.0;
uniform vec3 cloud_color : source_color = vec3(1.0, 1.0, 1.0);

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		s += a * noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return s;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float h = d.y;
	vec3 col;
	if (h >= 0.0) {
		col = mix(horizon_color, zenith_color, pow(h, 0.45));
	} else {
		col = mix(horizon_color, ground_color, clamp(pow(-h, 0.4) * 1.3, 0.0, 1.0));
	}
	vec3 sd = normalize(LIGHT0_DIRECTION);
	float sdot = max(dot(d, sd), 0.0);
	// ореол и рассеяние у горизонта в сторону солнца
	float horizon_band = exp(-abs(h) * 6.0);
	col += sun_color * (pow(sdot, 6.0) * 0.25 + pow(sdot, 64.0) * 0.6) * (0.4 + horizon_band);
	col += sun_color * horizon_band * 0.12 * pow(sdot, 2.0);
	// диск
	col += sun_color * smoothstep(0.9994, 0.9997, sdot) * 30.0 * sun_disk;

	// звёзды
	if (stars > 0.0 && h > 0.0) {
		vec2 sp = d.xz / (d.y + 0.3) * 180.0;
		float st = step(0.997, hash(floor(sp)));
		col += vec3(st) * stars * h * (0.6 + 0.4 * sin(TIME * 3.0 + hash(floor(sp)) * 40.0));
	}

	// облака на плоскости
	if (clouds_enabled > 0.5 && h > 0.01) {
		vec2 uv = d.xz / (h + 0.12) * 1.3 + vec2(TIME * 0.006, TIME * 0.002);
		float n = fbm(uv * 1.4);
		float c = smoothstep(1.0 - cloud_amount, 1.0 - cloud_amount + 0.35, n);
		float shade = fbm(uv * 1.4 + sd.xz * 0.12);
		vec3 cc = mix(cloud_color, cloud_color * 0.62, clamp((shade - n) * 3.0 + 0.4, 0.0, 1.0));
		cc += sun_color * pow(sdot, 12.0) * 0.5;
		col = mix(col, cc, c * smoothstep(0.01, 0.2, h) * 0.92);
	}
	COLOR = col;
}
