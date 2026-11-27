shader_type spatial;
render_mode cull_disabled, unshaded;

uniform sampler2D glyph : filter_linear_mipmap, repeat_disable;
uniform float wind_phase = 0.0;
uniform float wind_strength = .5;
uniform float winter = 0.0;
varying vec2 fold;

void vertex() {
	float u = UV.x; // Fixed hoist; amplitude builds toward loose cloth.
	float p = wind_phase*8.0;
	float a = p-u*7.0+UV.y*.93;
	float b = p*1.34-u*11.2-UV.y*1.85;
	float amp = mix(.12,.59,wind_strength);
	float curl = sin(a)*amp + sin(b)*amp*.25;
	VERTEX.z += curl*u;
	VERTEX.y -= u*mix(.68,.20,wind_strength);
	VERTEX.y += u*amp*.7*sin(a-.50)+u*u*amp*.38*sin(b);
	VERTEX.x *= mix(.80,1.0,wind_strength);
	fold = vec2(cos(a)*amp*u,sin(b)*u);
}

void fragment() {
	vec2 p = UV;
	vec3 cloth = mix(vec3(.29,.065,.047),vec3(.53,.132,.090),.54+.30*fold.x+.12*fold.y);
	float sweep = .5+.5*sin(p.y*18.0+p.x*5.1+fold.y*1.2);
	cloth *= mix(.94,1.03,sweep);
	float edge = min(min(p.x,1.0-p.x),min(p.y,1.0-p.y));
	float outer = 1.0-smoothstep(.052,.072,edge);
	float binding = smoothstep(.025,.033,edge)*(1.0-smoothstep(.044,.052,edge));
	cloth = mix(cloth,vec3(.228,.051,.041),outer*.70);
	cloth = mix(cloth,vec3(.67,.40,.20)*(1.0+.19*fold.x),binding*.82);

	// The game camera sees the windward side: hoist u=0 is screen-right.
	float horizontal = FRONT_FACING ? p.x : 1.0-p.x;
	vec2 ink_uv = (vec2(horizontal,p.y)-vec2(.534,.505))/vec2(.60,.72)+.5;
	float ink = 0.0;
	if (all(greaterThanEqual(ink_uv,vec2(0.0))) && all(lessThanEqual(ink_uv,vec2(1.0)))) {
		ink = texture(glyph,ink_uv).a;
	}
	vec3 painted = mix(cloth,vec3(.87,.707,.434)*(1.0+.31*fold.x),ink);
	ALBEDO = painted*mix(vec3(1.0),vec3(.84,.92,1.02),winter);
}
