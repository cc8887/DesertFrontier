shader_type spatial;
render_mode diffuse_lambert, specular_disabled, ambient_light_disabled;

uniform float winter = 0.0;
uniform float sun_power = .68;
// Approximate long dimension of a broad dab in project world units.
uniform float brush_size : hint_range(1.0, 8.0, .1) = 3.9;
uniform float brush_strength : hint_range(0.0, 1.0) = .94;
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
// Overlapping broad, uneven dabs. Quantized hue choices keep the marks legible
// under haze instead of turning a blended noise field into blurry spots.
vec4 paint_dabs(vec2 plane, float seed, float pixel_width) {
	vec2 grid = plane / vec2(brush_size, brush_size * .48);
	grid.x -= grid.y * .44;
	vec2 cell = floor(grid);
	vec3 colored = vec3(0.0);
	float covered = 0.0;
	float edge = clamp(pixel_width * .91, .031, .23);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 id = cell + vec2(float(x), float(y));
			float rnd = hash(vec3(id, seed));
			float rnd2 = hash(vec3(id.yx, seed + 17.7));
			float rnd3 = hash(vec3(id + 8.7, seed - 3.3));
			vec2 d = grid - id - .5 - (vec2(rnd, rnd2)-.5)*.66;
			d.y += d.x * (rnd3-.5) * .67;
			d.x += d.y * (rnd2-.5) * .32;
			vec2 half_size = vec2(mix(.40,.71,rnd2),mix(.24,.53,rnd3));
			vec2 q = abs(d) - half_size + .15;
			float dist = length(max(q,vec2(0.0))) + min(max(q.x,q.y),0.0) - .15;
			// Dry bristles at the edges only. Fade them from small screen footprints.
			float split = sin(d.y*23.0 + rnd*6.28) * sin(d.x*4.8 + 1.9);
			dist += split*.075*(1.0-smoothstep(.04,.20,pixel_width));
			float mask = (1.0-smoothstep(-edge,edge,dist))*mix(.49,.88,rnd3);
			vec3 pigment = mix(vec3(.405,.304,.231),vec3(.79,.617,.424),smoothstep(.19,.86,rnd));
			pigment = mix(pigment,vec3(.61,.443,.326),smoothstep(.53,.81,rnd2)*.82);
			pigment = mix(pigment,vec3(.523,.477,.435),smoothstep(.62,.90,rnd3)*.86);
			colored = mix(colored,pigment,mask);
			covered = mix(covered,1.0,mask);
		}
	}
	return vec4(colored,covered);
}

void fragment() {
	vec3 p = world_pos;
	vec3 n = normalize(mat3(INV_VIEW_MATRIX)*NORMAL);
	float top = smoothstep(.48,.96,n.y);
	// Use the main face axes, not the camera or per-block UV islands.
	bool x_face = abs(n.x) > abs(n.z);
	vec2 local = n.y > .67 ? p.xz : vec2(x_face ? -p.z : p.x, p.y);
	// On the walk, turn the dabs across depth so perspective still shows
	// broad overlapping shapes instead of compressing them into stripes.
	float angle = n.y > .67 ? -.58 : (x_face ? -.20 : .15);
	float sn = sin(angle);
	float cs = cos(angle);
	vec2 plane = mat2(vec2(cs,sn),vec2(-sn,cs)) * local;
	plane.y += .33*sin(plane.x*.43) + .19*sin(plane.x*.87+plane.y*.34);
	float seed = n.y > .67 ? 13.7 : (x_face ? 8.4 : 4.2);
	float px = max(length(dFdx(p)),length(dFdy(p))) / (brush_size*.48);
	float wide = wash(p*vec3(.17,.31,.21));
	vec4 strokes = paint_dabs(plane,seed,px);
	float seam_y = p.y + (wide-.5)*.34 + .10*sin(p.x*.39+p.z*.44);
	float lift = sin(seam_y*3.43 + .28*sin(seam_y*1.11));
	float seams = smoothstep(.77,.96,lift)*(1.0-top)*smoothstep(.29,.59,wide);
	vec3 ground = mix(vec3(.47,.364,.270),vec3(.68,.524,.368),wide);
	vec3 clay = mix(ground,ground*(1.0-strokes.a)+strokes.rgb,brush_strength);
	clay *= 1.0-.12*seams;
	clay *= mix(1.0,1.07,top);
	float paint_value = strokes.a > .01 ? strokes.r/strokes.a : ground.r;
	float deposit = smoothstep(.39,.64,wide*.50+paint_value*.50)*top*winter;
	vec3 snow = mix(vec3(.66,.711,.723),vec3(.87,.882,.859),smoothstep(.46,.73,paint_value));
	clay = mix(clay*mix(vec3(1.0),vec3(.85,.94,1.075),winter),snow,deposit*.92);
	ALBEDO = clay;
	// Painted ambient stays in the shade; only the sunlight is shadowed.
	EMISSION = clay * (mix(.71,.77,winter)+.07*top);
}
void light() {
	float direct = smoothstep(-.03,.57,dot(NORMAL,LIGHT));
	float strength = mix(.14,.26,sun_power)*mix(1.0,.62,winter);
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * direct * ATTENUATION * strength;
}
