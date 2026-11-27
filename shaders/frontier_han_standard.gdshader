shader_type spatial;
render_mode cull_disabled, unshaded;

uniform sampler2D glyph : filter_linear_mipmap, repeat_disable;
uniform float wind_phase = 0.0;
uniform float wind_strength = .5;
uniform float winter = 0.0;
varying vec2 fold;

void vertex() {
	float v = UV.y; // Top edge pinned to the crossbar.
	float p = wind_phase*7.8;
	float a = p-v*9.6+UV.x*2.1;
	float b = p*1.19-v*14.2-UV.x*3.4;
	float amp = mix(.12,.59,wind_strength);
	float loose = v*v;
	VERTEX.z -= v*amp*(.65+.53*sin(a)+.22*sin(b));
	VERTEX.x += loose*(.095+.32*wind_strength + .16*sin(a-.42));
	VERTEX.y += loose*amp*.34*sin(a+.80);
	fold = vec2(cos(a)*amp*v,sin(b)*v);
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

	// The game camera sees the windward side: u=0 is screen-right.
	float horizontal = FRONT_FACING ? p.x : 1.0-p.x;
	vec2 ink_uv = (vec2(horizontal,p.y)-vec2(.50,.405))/vec2(.78,.395)+.5;
	float ink = 0.0;
	if (all(greaterThanEqual(ink_uv,vec2(0.0))) && all(lessThanEqual(ink_uv,vec2(1.0)))) {
		ink = texture(glyph,ink_uv).a;
	}
	vec3 painted = mix(cloth,vec3(.87,.707,.434)*(1.0+.31*fold.x),ink);
	ALBEDO = painted*mix(vec3(1.0),vec3(.84,.92,1.02),winter);
}
