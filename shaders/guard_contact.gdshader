shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform bool snow = false;
void fragment() {
	vec2 d = (UV - vec2(0.50, 0.50)) * 2.0;
	ALBEDO = snow ? vec3(0.24, 0.31, 0.36) : vec3(0.39, 0.26, 0.14);
	ALPHA = 0.43 * (1.0 - smoothstep(0.10, 1.0, length(d)));
}
