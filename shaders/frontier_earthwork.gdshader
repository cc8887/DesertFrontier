shader_type spatial;
render_mode diffuse_lambert, specular_disabled, ambient_light_disabled;

uniform float winter = 0.0;
uniform float sun_power = .68;
// Long brush dimension in world units, not a UV tile size.
uniform float brush_size : hint_range(3.0, 22.0, .1) = 11.0;
uniform float brush_strength : hint_range(0.0, 1.0, .01) = .68;
varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash2(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * .1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

// Continuous pigment field: no stamps, cell rims, or discrete rock colors.
float wash(vec2 p) {
	vec2 cell = floor(p);
	vec2 t = smoothstep(vec2(0.0), vec2(1.0), fract(p));
	return mix(
		mix(hash2(cell),hash2(cell + vec2(1,0)),t.x),
		mix(hash2(cell + vec2(0,1)),hash2(cell + vec2(1,1)),t.x),t.y);
}

float paint(vec2 uv) {
	float drift = wash(uv * .31 + vec2(4.9,7.1));
	vec2 q = uv + vec2(.32,-.62) * (drift - .5);
	float bed = wash(q);
	float pass = wash(q * vec2(.84,1.72) + vec2(13.5,5.9));
	// A broad wash with a few overlapping flat strokes, without outlining their edges.
	float keep = 1.0 - smoothstep(.08,.35,max(length(dFdx(q)),length(dFdy(q))));
	return mix(bed,mix(bed,smoothstep(.24,.79,pass),.36),keep);
}

void fragment() {
	vec3 p = world_pos;
	vec3 n = normalize(mat3(INV_VIEW_MATRIX) * NORMAL);
	float top = smoothstep(.30,.90,n.y);
	// Vertical paint layers follow elevation around corners; the deck uses its
	// own broader swept coat so it doesn't look like a pile of fragments.
	vec2 deck = vec2(p.x+.32*p.z,p.z-.21*p.x);
	float deck_wash = paint(deck/vec2(brush_size*1.25,brush_size*.47));
	float along_x = paint(vec2(p.x,p.y)/vec2(brush_size,brush_size*.23));
	float along_z = paint(vec2(-p.z,p.y)/vec2(brush_size,brush_size*.23));
	float axis = abs(n.x) / max(.001,abs(n.x)+abs(n.z));
	float blend_side = smoothstep(.15,.85,axis);
	float side_wash = mix(along_x,along_z,blend_side);
	float dragged = .5+.5*sin(deck.y*.36 + 1.80*wash(deck/vec2(17.0,7.4)+vec2(2.3,18.4)));
	float glaze = smoothstep(.19,.63,dragged);
	float pigment = mix(side_wash,mix(deck_wash,glaze,.36),top);
	vec3 clay = mix(vec3(.562,.423,.299),vec3(.726,.567,.408),.5+(pigment-.5)*brush_strength);
	clay = mix(clay,clay*vec3(1.01,1.045,1.09),top*glaze*.8);
	// Subtle, broken compaction bands. Avoid dark grout lines or vertical joints.
	float run = wash(p.xz*.093 + vec2(6.1,4.2));
	float h = p.y + (run-.5)*.31;
	float layer = .5+.5*sin(h*3.78+.53*sin(h*1.11));
	float tier = smoothstep(.27,.71,layer)*mix(.32,1.0,smoothstep(.12,.79,run));
	float wall_base = 1.0-smoothstep(-14.0,-4.6,p.y);
	clay *= (1.0 - .095*tier*(1.0-top) - .095*wall_base)*mix(.94,1.035,top);
	// Dust/snow rests on upward-facing surfaces; leave warm earth visible below.
	float powder = wash(p.xz/vec2(7.8,6.9)+vec2(21.2,12.1));
	float deposit = smoothstep(.21,.74,powder*.78+deck_wash*.22) * smoothstep(.52,.94,n.y) * winter;
	vec3 snow = mix(vec3(.70,.73,.735),vec3(.83,.85,.83),smoothstep(.18,.85,powder));
	clay = mix(clay*mix(vec3(1.0),vec3(.87,.94,1.04),winter),snow,deposit*.92);
	ALBEDO = clay;
	// Matte colored base remains lit in shade; retain the real cast shadow.
	EMISSION = clay * (mix(.71,.77,winter)+.055*top);
}

void light() {
	float direct = mix(.18,1.0,smoothstep(-.32,.50,dot(NORMAL,LIGHT)));
	float strength = mix(.14,.26,sun_power)*mix(1.0,.62,winter);
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * direct * ATTENUATION * strength;
}
