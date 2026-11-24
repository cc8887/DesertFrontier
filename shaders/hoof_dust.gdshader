shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;
uniform float opacity = 0.0;
uniform float seed = 0.0;
uniform float drift = 0.0;
uniform vec3 pigment = vec3(0.75,0.56,0.35);
float hash21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * .1031);
	p3 += dot(p3,p3.yzx+33.33);
	return fract((p3.x+p3.y)*p3.z);
}
float noise2(vec2 p) {
	vec2 c = floor(p), f = fract(p);
	f = f*f*(3.-2.*f);
	return mix(mix(hash21(c),hash21(c+vec2(1.,0.)),f.x),mix(hash21(c+vec2(0.,1.)),hash21(c+vec2(1.,1.)),f.x),f.y);
}
void fragment() {
	vec2 q = UV*2.-1.;
	float field = noise2(q*vec2(3.1,2.2)+vec2(seed-drift*.45,seed*.2));
	float grit = noise2(q*vec2(8.3,5.)+vec2(seed+4.,seed*1.4));
	float shape = length(q*vec2(.88,1.16));
	float veil = 1.-smoothstep(.17,.93,shape+.43*(field-.5));
	ALBEDO = pigment * (.87+.23*grit);
	ALPHA = opacity*veil*smoothstep(.20,.71,field*.77+grit*.23);
}
