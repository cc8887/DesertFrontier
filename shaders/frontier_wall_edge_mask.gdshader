shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
uniform bool wall = true;
varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
}
void fragment() {
	if (!wall) {
		// Leave the translucent crest of the foreground dunes out of the mask.
		if (UV.y < .025) { discard; }
		ALBEDO = vec3(0.0);
	} else {
		// Subtle mask-width variation, fixed to the wall rather than the pixels.
		float drift = .5+.25*sin(world_pos.x*1.04+world_pos.y*.64)
			+.25*sin(world_pos.y*1.58+world_pos.z*.52);
		ALBEDO = vec3(1.0,drift,0.0);
	}
}
