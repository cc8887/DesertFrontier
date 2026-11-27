shader_type spatial;
render_mode unshaded, cull_disabled;

// Palette is the original material swatch; value bands carry the large forms.
// UVs are laid out in the bind pose, so the paint follows the skin.
uniform vec4 pigment : source_color = vec4(1.0);
uniform float winter : hint_range(0.0, 1.0) = 0.0;
uniform float airborne_sand : hint_range(0.0, 1.0) = 0.59;
uniform float sun_power : hint_range(0.0, 1.0) = 0.68;
uniform float brush_weight : hint_range(0.0, 1.0) = 0.72;
uniform bool ribbon = false;

float pigment_hash(vec2 p) {
	vec3 h = fract(vec3(p.xyx) * .1031);
	h += dot(h, h.yzx + 33.33);
	return fract((h.x + h.y) * h.z);
}
float brush_field(vec2 p) {
	vec2 id = floor(p);
	vec2 f = fract(p);
	f = f*f*(3.0-2.0*f);
	return mix(mix(pigment_hash(id), pigment_hash(id+vec2(1,0)), f.x),
		mix(pigment_hash(id+vec2(0,1)), pigment_hash(id+vec2(1,1)), f.x),f.y);
}
void fragment() {
	vec3 n = normalize(mat3(INV_VIEW_MATRIX) * NORMAL);
	if (!FRONT_FACING) { n = -n; }
	// Same incoming sun direction as the terrain; cold diffuse light in snow.
	vec3 sun_dir = normalize(vec3(-.677, .468, -.568));
	float f = dot(n, sun_dir);
	if (ribbon) { f = mix(.20, abs(f), .75); }
	vec2 p = UV;
	vec2 block_uv = vec2(p.x*13.0 + p.y*4.0, p.y*17.0 - p.x*2.0);
	float block = brush_field(block_uv);
	float stroke = brush_field(vec2(p.x*8.0-p.y*6.0, p.y*35.0+p.x*20.0));
	float drag = smoothstep(.27, .64, stroke) - .46;
	float wobble = (block-.5)*(.16*brush_weight);
	float soft_band = smoothstep(-.26, -.10, f+wobble);
	float light_band = smoothstep(.26, .47, f+wobble);
	vec3 shade = mix(vec3(.69,.63,.64),vec3(.68,.75,.85),winter);
	vec3 mid = mix(vec3(.95,.86,.75),vec3(.86,.92,1.0),winter);
	vec3 highlight = mix(vec3(1.12,1.01,.86),vec3(.97,1.025,1.085),winter);
	float relief = mix(.84,1.0,sun_power) * (1.0-.19*airborne_sand) * mix(1.0,.81,winter);
	vec3 colored_light = mix(mid, mix(mix(shade,mid,soft_band),highlight,light_band), relief);
	vec3 paint = pigment.rgb * colored_light * (1.0+(drag*.16+(block-.5)*.16)*brush_weight);
	vec3 bounce = mix(vec3(.78,.56,.36), vec3(.54,.65,.73), winter);
	float reflected = mix(.12,.08,winter)*(.55+.45*airborne_sand);
	paint = mix(paint,bounce,reflected);
	if (ribbon) {
		// Thin black selvage, independent of which side faces the camera.
		float edge = min(p.x, 1.0-p.x);
		paint *= mix(.035, 1.0, smoothstep(.018,.058,edge));
	}
	ALBEDO = clamp(paint,vec3(0.0),vec3(1.0));
}
