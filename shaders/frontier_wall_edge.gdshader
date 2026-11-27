shader_type canvas_item;
render_mode unshaded, blend_disabled;

uniform sampler2D scene_tex : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D wall_tex : repeat_disable, filter_nearest;
uniform sampler2D guard_tex : repeat_disable, filter_nearest;
uniform float edge_radius : hint_range(0.0, 9.0, .1) = 5.2;

const vec2 DIRECTIONS[8] = vec2[8](
	vec2(1,0), vec2(.7071,.7071), vec2(0,1), vec2(-.7071,.7071),
	vec2(-1,0), vec2(-.7071,-.7071), vec2(0,-1), vec2(.7071,-.7071));

// Only borrow pigment across the wall silhouette. No blur on dabs, shadows,
// or edges where both taps are on the same side. Guard mask stays sharp.
vec4 borrow(vec2 p, float own) {
	float other = step(.5,texture(wall_tex,p).r);
	if (other == own || texture(guard_tex,p).a > .08) {
		return vec4(0.0);
	}
	return vec4(texture(scene_tex,p).rgb,1.0);
}
void fragment() {
	vec2 p = SCREEN_UV;
	if (edge_radius < .15 || texture(guard_tex,p).a > .08) {
		discard;
	}
	float own = step(.5,texture(wall_tex,p).r);
	vec2 pixel = SCREEN_PIXEL_SIZE * (edge_radius * .5 * (.72 + .56*texture(wall_tex,p).g));
	vec4 mix_color = vec4(0.0);
	for (int i = 0; i < 8; i++) {
		vec2 off = DIRECTIONS[i] * pixel;
		mix_color += borrow(p+off,own)*.29;
		mix_color += borrow(p+off*2.0,own)*.145;
	}
	if (mix_color.a < .01) {
		discard;
	}
	vec3 c = texture(scene_tex,p).rgb;
	COLOR = vec4(c + (mix_color.rgb-c*mix_color.a)/4.60,1.0);
}
