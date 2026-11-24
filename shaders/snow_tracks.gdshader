shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, fog_disabled;

uniform float now_time = 0.0;
uniform float snow_density = 0.68;
varying vec4 stamp;
varying float depth;

float print_shape(vec2 p) {
	float spread = mix(0.87, 1.17, smoothstep(0.10, 0.80, p.y));
	vec2 v = vec2(p.x * spread, p.y);
	return length(v) + 0.145 * smoothstep(0.14, 0.89, p.y);
}

void vertex() {
	stamp = COLOR;
	depth = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
}

void fragment() {
	float birth_code = round(stamp.x * 255.0) * 256.0 + round(stamp.y * 255.0);
	float age = now_time - birth_code * (20.0 / 65535.0);
	if (age <= 0.0 || age >= 10.50) { discard; }
	vec2 p = (UV * 2.0 - 1.0) * vec2(1.19, 1.05);
	float small_edges = 0.041 * sin(p.x * 24.0 + p.y * 14.0 + stamp.z * 31.0)
		+ 0.023 * sin(p.x * 45.0 - p.y * 26.0 - stamp.z * 57.0);
	float edge = print_shape(p) + small_edges;
	float core = 1.0 - smoothstep(0.50, 0.82, edge);
	float outer = 1.0 - smoothstep(0.78, 0.98, edge);
	float toe = (outer - core) * smoothstep(-0.45, 0.36, -p.y + p.x * 0.31);
	float heel = (outer - core) * smoothstep(0.0, 0.72, p.y - p.x * 0.15);
	float divot = core * (0.90 - 0.34 * smoothstep(-0.10, 0.70, p.y));
	float wash = (1.0 - smoothstep(1.25 + 1.20 * (1.0 - snow_density), 10.50, age));
	float fresh = smoothstep(0.0, 0.06, age);
	float air = exp(-depth * (0.58 + snow_density * 0.95) / 345.0);
	float stroke = divot * 0.75 + heel * 0.46 + toe * 0.30;
	vec3 dark_ink = vec3(0.37, 0.43, 0.51);
	vec3 pale_rim = vec3(0.76, 0.80, 0.82);
	ALBEDO = mix(dark_ink, pale_rim, toe * 1.44);
	ALPHA = clamp(stroke * wash * fresh * air * (0.62 + 0.15 * stamp.w), 0.0, 0.73);
}
