shader_type canvas_item;
render_mode unshaded;
// Only the outside of the whole character mask. Overlapping outfit surfaces
// do not produce their own black edges. The rectangle is bounded to the guard.
uniform sampler2D silhouette_tex : filter_linear, repeat_disable;
uniform vec2 radius_uv = vec2(.00115,.00205);

float coverage(vec2 p) {
	return texture(silhouette_tex, p).a;
}
void fragment() {
	vec2 p = SCREEN_UV;
	float inside = coverage(p);
	vec2 dx = vec2(radius_uv.x, 0.0);
	vec2 dy = vec2(0.0, radius_uv.y);
	vec2 diagon = radius_uv * .7071;
	float edge = max(max(coverage(p+dx), coverage(p-dx)), max(coverage(p+dy), coverage(p-dy)));
	edge = max(edge, max(max(coverage(p+diagon), coverage(p-diagon)),
		max(coverage(p+vec2(diagon.x,-diagon.y)),coverage(p+vec2(-diagon.x,diagon.y)))));
	COLOR = vec4(0.0,0.0,0.0,smoothstep(.10,.80,edge)*(1.0-smoothstep(.12,.50,inside)));
}
