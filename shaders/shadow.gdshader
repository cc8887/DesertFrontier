shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, fog_disabled;

uniform vec4 capsules[9];
uniform vec3 penumbra[9];
uniform vec4 footprint = vec4(0.0);
uniform vec2 footprint_heading = vec2(0.0, 1.0);
uniform float alpha_factor = 0.0;
uniform float sand_density = 0.59;
uniform bool contact_only = false;
uniform bool snow_mode = false;
varying vec2 ground_xz;
varying float view_depth;

void vertex() {
	ground_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	view_depth = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
}

void fragment() {
	float mask = 0.0;
	if (contact_only) {
		vec2 delta = ground_xz - footprint.xy;
		vec2 side = vec2(footprint_heading.y, -footprint_heading.x);
		vec2 local_p = vec2(dot(delta, side), dot(delta, footprint_heading)) / footprint.zw;
		mask = 1.0 - smoothstep(0.08, 1.0, length(local_p));
		mask *= exp(-view_depth * (0.16 + sand_density * 0.42) / 325.0);
	} else {
		for (int i = 0; i < 9; i++) {
			if (penumbra[i].x > 0.01) {
				vec2 a = capsules[i].xy;
				vec2 ab = capsules[i].zw - a;
				float f = clamp(dot(ground_xz - a, ab) / max(0.0001, dot(ab, ab)), 0.0, 1.0);
				float d = length(ground_xz - (a + ab * f));
				float feather = 1.0 - smoothstep(penumbra[i].x * 0.46, penumbra[i].x + penumbra[i].y, d);
				mask = max(mask, feather * penumbra[i].z);
			}
		}
		mask *= exp(-view_depth * (0.11 + sand_density * 0.47) / 245.0);
	}
	ALBEDO = snow_mode ? vec3(.250,.310,.354) : vec3(0.235, 0.165, 0.145);
	ALPHA = mask * alpha_factor;
}
