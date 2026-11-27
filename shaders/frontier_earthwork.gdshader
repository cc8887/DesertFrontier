shader_type spatial;
render_mode diffuse_lambert, specular_disabled, ambient_light_disabled;

uniform float winter = 0.0;
uniform float sun_power = .68;
varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec3 p) {
	p = fract(p * .1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x+p.y)*p.z);
}
float wash(vec3 p) {
	vec3 a = floor(p), f = fract(p);
	f=f*f*(3.0-2.0*f);
	return mix(
		mix(mix(hash(a), hash(a+vec3(1,0,0)), f.x),
			mix(hash(a+vec3(0,1,0)), hash(a+vec3(1,1,0)), f.x),f.y),
		mix(mix(hash(a+vec3(0,0,1)), hash(a+vec3(1,0,1)), f.x),
			mix(hash(a+vec3(0,1,1)), hash(a+vec3(1,1,1)), f.x),f.y), f.z);
}
void fragment() {
	vec3 p = world_pos;
	vec3 n = normalize(mat3(INV_VIEW_MATRIX)*NORMAL);
	float top = smoothstep(.48,.96,n.y);
	float wide = wash(p*vec3(.23,.60,.27));
	float stroke = wash(vec3(p.x*.90+p.y*.44,p.y*2.30+p.z*.711,p.z*.92+p.x*.25));
	float drag = wash(vec3(p.x*1.7+p.y*.82,p.y*6.8-p.x*.24,p.z*1.8+p.y*2.2));
	float weather = wash(p * vec3(.57,.86,.64)+vec3(12.7,1.27,9.7))*.68+stroke*.32;
	float lift = sin((p.y+.11*stroke+.52*wide)*5.05);
	float seams = smoothstep(.74,.97,lift)*(1.0-top)*smoothstep(.26,.66,weather);
	float missing = smoothstep(.50,.80,weather+(wide-.5)*.25)*(1.0-.45*top);
	vec3 clay = mix(vec3(.49,.378,.264),vec3(.71,.555,.376),smoothstep(.10,.94,wide*.63+stroke*.37));
	clay = mix(clay,vec3(.43,.339,.257),missing*mix(.72,.45,top));
	float flakes = wash(vec3(p.x*3.4+p.y*.75,p.y*8.9-p.z*1.65,p.z*4.0+p.x*.77));
	clay *= .95+.12*drag-.135*seams;
	clay = mix(clay,clay*.74,smoothstep(.57,.80,drag)*smoothstep(.53,.79,flakes)*.65);
	clay = mix(clay,clay*1.1,smoothstep(.55,.83,flakes)*smoothstep(.43,.72,stroke));
	float scrape = smoothstep(.62,.80,stroke)*smoothstep(.48,.72,drag);
	clay = mix(clay,vec3(.74,.604,.425),scrape*.26);
	clay = mix(clay, clay*vec3(1.05,1.05,1.06),top*.55);
	float deposit = smoothstep(.33,.71,wide*.55+stroke*.45)*top*winter;
	vec3 snow = mix(vec3(.60,.66,.69),vec3(.84,.866,.864),stroke);
	clay = mix(clay*mix(vec3(1.0),vec3(.84,.93,1.075),winter),snow,deposit*.92);
	ALBEDO = clay;
	// Painted ambient stays in the shade; only the sunlight is shadowed.
	EMISSION = clay * (mix(.71,.77,winter)+.07*top);
}
void light() {
	float direct = smoothstep(-.03,.57,dot(NORMAL,LIGHT));
	float strength = mix(.14,.26,sun_power)*mix(1.0,.62,winter);
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * direct * ATTENUATION * strength;
}
