extends Node3D
## Reuses the skeletal mesh, samples exact clip time (including backward scrubs),
## and attaches the procedural rider to the posed Spine bone.

const HORSE = "res://assets/horse/western-silhouette.glb"
const MODEL_SCALE := 5.35
const SUN := Vector3(-0.677, 0.468, -0.568)
const CLIP_NAMES: Array[StringName] = [&"Idle", &"Gallop", &"Rear"]
const HIND: Array[StringName] = [&"Hind_Hoof_L", &"Hind_Hoof_R"]
const FEET: Array[StringName] = [&"Hind_Hoof_L", &"Hind_Hoof_R", &"Front_Hoof_L", &"Front_Hoof_R"]
const CASTER: Array[StringName] = [
	&"Hips", &"Chest", &"Chest", &"Neck2", &"Neck2", &"Head",
	&"Hind_Upper_L", &"Hind_Hoof_L", &"Hind_Upper_R", &"Hind_Hoof_R",
	&"Front_Upper_L", &"Front_Hoof_L", &"Front_Upper_R", &"Front_Hoof_R",
]
const PIGMENTS := {
	"Coat": Color("#33241c"), "Hair": Color("#211b17"), "Hoof": Color("#241b15"),
	"Sole": Color("#211914"), "Shoe": Color("#271e19"), "Lash": Color("#191410"),
	"Eye_Brown": Color("#211713"), "Leather": Color("#302219"), "Leather_Dark": Color("#221915"),
	"Steel": Color("#413128"), "Blanket": Color("#50342a"), "Wool": Color("#403129"),
}
const ROBE := Color(0.370, 0.187, 0.101)
const LEATHER := Color(0.251, 0.218, 0.160)
const REIN := Color(0.555, 0.383, 0.209)
const INK := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_always;
uniform vec3 pigment;
uniform float relief = 0.0;
uniform float visibility = 1.0;
const vec3 SUN = vec3(-0.677, 0.468, -0.568);
varying vec3 face_world;
void vertex(){ face_world = MODEL_NORMAL_MATRIX * NORMAL; }
void fragment(){
	// Screen-door fade retains correct depth for the rig as an entire silhouette.
	if (visibility < 0.999) {
		float grain = fract(sin(dot(floor(FRAGCOORD.xy), vec2(12.9898, 78.233))) * 43758.5453);
		if (grain > visibility) discard;
	}
	float face = smoothstep(-0.19, 0.87, dot(normalize(face_world), normalize(SUN)));
	vec3 facing = pigment * vec3(1.58, 1.32, 1.12) + vec3(0.020, 0.011, 0.005);
	vec3 shade = pigment * vec3(0.70, 0.76, 0.88);
	ALBEDO = mix(pigment, mix(shade, facing, face), relief);
}
"""

var rig: Node3D
var skeleton: Skeleton3D
var animations: Array[Animation] = []
var track_maps: Array[Dictionary] = []
var bones: Dictionary = {}
var idle_hind := Vector3.ZERO
var seat := Vector3(0.0, 9.84, -0.58)
var materials: Dictionary = {}
var material_shader: Shader
var rider_parts: Array[MeshInstance3D] = []
var segment_shapes: SphereMesh
var native_ok := false


func _ready() -> void:
	material_shader = Shader.new()
	material_shader.code = INK
	segment_shapes = SphereMesh.new()
	segment_shapes.radial_segments = 10
	segment_shapes.rings = 6
	segment_shapes.radius = 1.0
	segment_shapes.height = 2.0

	if ResourceLoader.exists(HORSE):
		var horse_scene := load(HORSE) as PackedScene
		if horse_scene != null:
			rig = horse_scene.instantiate() as Node3D
			if rig != null:
				add_child(rig)
				rig.scale = Vector3.ONE * MODEL_SCALE
				skeleton = rig.find_child("Skeleton3D", true, false) as Skeleton3D
				var player := rig.find_child("AnimationPlayer", true, false) as AnimationPlayer
				if skeleton != null and player != null and _prepare_clips(player):
					player.active = false
					for mesh in rig.find_children("*", "MeshInstance3D", true, false):
						_ink_mesh(mesh as MeshInstance3D)
					native_ok = true
					_sample_skeleton(Vector3.ZERO, 0.0, 0.0)
					idle_hind = (_bone(HIND[0]) + _bone(HIND[1])) * 0.5
	if not native_ok:
		if rig != null:
			rig.hide()
		push_warning("Western Horse assets unavailable; using the procedural rider and horse.")
		for i in 7:
			_make_segment(Color("#38281d"))
	for i in 17:
		_make_segment(LEATHER if (i in [1, 2, 3, 6, 7, 12, 13]) else REIN if i in [10, 16] else ROBE)
	update_pose(0.0, 0.59, 0.72, 565.0, 1.0)


func _prepare_clips(player: AnimationPlayer) -> bool:
	for i in skeleton.get_bone_count():
		bones[skeleton.get_bone_name(i)] = i
	for key in FEET:
		if not bones.has(key):
			return false
	for key in CASTER:
		if not bones.has(key):
			return false
	if not bones.has(&"Spine"):
		return false
	for key in CLIP_NAMES:
		if not player.has_animation(key):
			return false
		var clip := player.get_animation(key)
		animations.push_back(clip)
		var tracks := {}
		for index in clip.get_track_count():
			var track_type := clip.track_get_type(index)
			if not track_type in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]:
				continue
			var path := clip.track_get_path(index)
			if path.get_subname_count() != 1:
				continue
			var bone_name := path.get_subname(0)
			if bones.has(bone_name):
				tracks[Vector2i(bones[bone_name], track_type)] = index
		track_maps.push_back(tracks)
	return true


func _ink_mesh(mesh: MeshInstance3D) -> void:
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.extra_cull_margin = 12.0
	for index in mesh.mesh.get_surface_count():
		var mat := mesh.get_active_material(index)
		var name_ := "" if mat == null else mat.resource_name
		mesh.set_surface_override_material(index, _ink(PIGMENTS.get(name_, PIGMENTS.Coat)))


func _ink(color: Color) -> ShaderMaterial:
	if not materials.has(color):
		var material := ShaderMaterial.new()
		material.shader = material_shader
		material.set_shader_parameter("pigment", Vector3(color.r, color.g, color.b))
		materials[color] = material
	return materials[color]


func _make_segment(color: Color) -> void:
	var segment := MeshInstance3D.new()
	segment.mesh = segment_shapes
	segment.material_override = _ink(color)
	segment.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(segment)
	rider_parts.push_back(segment)


func _position(key: Vector2i, clip: int, time: float, default: Vector3) -> Vector3:
	if not track_maps[clip].has(key):
		return default
	return animations[clip].position_track_interpolate(track_maps[clip][key], time)


func _scale(key: Vector2i, clip: int, time: float, default: Vector3) -> Vector3:
	if not track_maps[clip].has(key):
		return default
	return animations[clip].scale_track_interpolate(track_maps[clip][key], time)


func _rotation(key: Vector2i, clip: int, time: float, default: Quaternion) -> Quaternion:
	if not track_maps[clip].has(key):
		return default
	var index: int = track_maps[clip][key]
	var animation: Animation = animations[clip]
	if clip == 2:
		# The source motion contains a small flip in the forelegs at each end.
		# Bridge the bad span using the real surrounding poses.
		for span: Vector2 in [Vector2(0.095, 0.132), Vector2(0.884, 0.923)]:
			var a := span.x * animation.length
			var b := span.y * animation.length
			if time > a and time < b:
				return animation.rotation_track_interpolate(index, a).normalized().slerp(
					animation.rotation_track_interpolate(index, b).normalized(), inverse_lerp(a, b, time)
				)
	return animation.rotation_track_interpolate(index, time).normalized()


func _sample_skeleton(times: Vector3, gallop: float, rear: float) -> void:
	for b in skeleton.get_bone_count():
		var rest := skeleton.get_bone_rest(b)
		var rest_rotation := rest.basis.get_rotation_quaternion()
		var rest_scale := rest.basis.get_scale()
		var p := Vector2i(b, Animation.TYPE_POSITION_3D)
		var r := Vector2i(b, Animation.TYPE_ROTATION_3D)
		var s := Vector2i(b, Animation.TYPE_SCALE_3D)
		var pos := _position(p, 0, times.x, rest.origin)
		var rot := _rotation(r, 0, times.x, rest_rotation)
		var scl := _scale(s, 0, times.x, rest_scale)
		if gallop > 0.0:
			pos = pos.lerp(_position(p, 1, times.y, rest.origin), gallop)
			rot = rot.slerp(_rotation(r, 1, times.y, rest_rotation), gallop)
			scl = scl.lerp(_scale(s, 1, times.y, rest_scale), gallop)
		if rear > 0.0:
			pos = pos.lerp(_position(p, 2, times.z, rest.origin), rear)
			rot = rot.slerp(_rotation(r, 2, times.z, rest_rotation), rear)
			scl = scl.lerp(_scale(s, 2, times.z, rest_scale), rear)
		skeleton.set_bone_pose_position(b, pos)
		skeleton.set_bone_pose_rotation(b, rot)
		skeleton.set_bone_pose_scale(b, scl)
	skeleton.force_update_all_bone_transforms()


func _bone(bone_name: StringName, offset := Vector3.ZERO) -> Vector3:
	var origin := skeleton.get_bone_global_pose(bones[bone_name]) * offset
	# Convert in local space; this is invariant under the route basis and resize.
	return rig.transform * skeleton.get_parent_node_3d().transform * skeleton.transform * origin


func _rear_cycle(t: float) -> float:
	if t < 0.87 or t > 2.58:
		return 0.0
	if t <= 1.68:
		return 0.49 * clampf(inverse_lerp(0.87, 1.68, t), 0.0, 1.0)
	return 0.49 + 0.51 * clampf(inverse_lerp(1.68, 2.58, t), 0.0, 1.0)


func _phase(t: float) -> float:
	return TAU * (t * 1.83 + 0.165 * sin(t * 0.68))


func _rear_amount(t: float) -> float:
	return smoothstep(0.87, 1.68, t) * (1.0 - smoothstep(1.78, 2.58, t))


func _seat_adjust(t: float) -> void:
	var rear_cycle := _rear_cycle(t)
	var rear_weight := minf(1.0, rear_cycle * 16.0) * float(t < 2.58)
	var gallop := smoothstep(3.35, 3.85, t)
	var times := Vector3(
		fposmod(t, animations[0].length),
		fposmod(_phase(t) / TAU, 1.0) * animations[1].length,
		minf(rear_cycle * animations[2].length, animations[2].length - 0.0005)
	)
	rig.position = Vector3.ZERO
	_sample_skeleton(times, gallop, rear_weight)
	var low := INF
	for bone_name in FEET:
		low = minf(low, _bone(bone_name).y)
	if rear_weight > 0.0:
		var hind := (_bone(HIND[0]) + _bone(HIND[1])) * 0.5
		rig.position.x = (idle_hind.x - hind.x) * rear_weight
		rig.position.z = (idle_hind.z - hind.z) * rear_weight
	rig.position.y = (-minf(low, 0.0) + 0.02) * maxf(rear_weight, 0.7)
	seat = _bone(&"Spine", Vector3(0.0, 0.29, -0.12))


func _joint(a: Vector3, b: Vector3, radius: float, ratio: float, index: int) -> void:
	var segment := rider_parts[index]
	var direction := b - a
	var length := maxf(0.001, direction.length())
	var rotation_axis := Vector3.UP.cross(direction / length)
	var dot := clampf(Vector3.UP.dot(direction / length), -1.0, 1.0)
	var orientation := Basis.IDENTITY
	if rotation_axis.length_squared() > 0.00001:
		orientation = Basis(rotation_axis.normalized(), acos(dot))
	elif dot < 0.0:
		orientation = Basis(Vector3.RIGHT, PI)
	var scales := Vector3(radius * ratio, length * 0.5 + radius * 0.64, radius)
	segment.transform = Transform3D(orientation * Basis.from_scale(scales), (a + b) * 0.5)


func _draw_rider(t: float, offset: int) -> void:
	var phase := _phase(t)
	var rear := _rear_amount(t)
	var amp := lerpf(0.10, 1.0, smoothstep(3.35, 3.85, t))
	var lean := 0.68 - 0.54 * rear + 0.20 * amp * sin(phase - 0.9)
	var pelvis := seat + Vector3(0.0, 0.04, 0.0)
	var shoulders := seat + Vector3(0.0, 2.57, lean)
	var head := seat + Vector3(0.0, 3.33, lean + 0.22)
	_joint(pelvis, shoulders, 1.09, 0.86, offset)
	_joint(seat + Vector3(0.0, 2.30, lean), head, 0.55, 1.05, offset + 1)
	_joint(head, seat + Vector3(0.0, 3.99, lean + 0.05), 0.62, 0.96, offset + 2)
	_joint(seat + Vector3(0.0, 3.68, lean + 0.09), seat + Vector3(0.0, 4.30, lean + 0.02), 0.60, 0.97, offset + 3)
	_joint(seat + Vector3(0.0, 1.33, -0.51), seat + Vector3(0.0, 0.47, -2.28 - 0.18 * sin(phase)), 0.57, 1.19, offset + 4)
	for i in 2:
		var side := float(i * 2 - 1)
		var hip := seat + Vector3(side * 0.50, 0.05, 0.0)
		var knee := seat + Vector3(side * 1.39, -1.10, 1.26 - 0.32 * rear)
		var boot := seat + Vector3(side * 1.61, -2.87, 0.65 - 0.26 * rear)
		var shoulder := seat + Vector3(side * 0.79, 2.30, lean)
		var elbow := seat + Vector3(side * 0.91, 1.53, 1.42)
		var hand := seat + Vector3(side * 0.53, 1.27 + 0.37 * rear, 2.65)
		var j := offset + 5 + i * 6
		_joint(hip, knee, 0.47, 0.76, j)
		_joint(knee, boot, 0.35, 0.92, j + 1)
		_joint(boot, seat + Vector3(side * 1.62, -2.88, 1.20 - 0.27 * rear), 0.34, 1.0, j + 2)
		_joint(shoulder, elbow, 0.35, 0.91, j + 3)
		_joint(elbow, hand, 0.27, 0.97, j + 4)
		_joint(hand, seat + Vector3(side * 0.46, 0.43 + 0.61 * rear, 5.14), 0.07, 1.0, j + 5)


func _fallback_parts(t: float) -> Array[Vector3]:
	var phase := _phase(t)
	var rear := _rear_amount(t)
	var bob := 0.18 * sin(phase * 2.0)
	var points: Array[Vector3] = [
		Vector3(0, 7.3 + bob, -3.8), Vector3(0, 7.3 + bob, 3.6),
		Vector3(0, 7.5 + bob, 3.1), Vector3(0, 10.3 + bob, 5.7),
		Vector3(0, 10.6 + bob, 5.1), Vector3(0, 10.0 + bob, 7.1)
	]
	for i in 4:
		var side := float((i % 2) * 2 - 1)
		var front := i >= 2
		var roll := phase + (0.6 if front else 2.8) + (1.15 if side > 0.0 else 0.0)
		var z := 3.0 if front else -3.2
		var amp := lerpf(0.1, 1.0, smoothstep(3.35, 3.85, t))
		points.push_back(Vector3(side, 7.15 + bob, z))
		points.push_back(Vector3(side, 0.3 + maxf(0.0, sin(roll)) * 1.8 * amp, z + cos(roll) * amp * 1.55))
	for i in points.size():
		points[i] = (points[i] + Vector3(0.0, 0.0, 3.4)).rotated(Vector3.RIGHT, rear * -0.98) - Vector3(0.0, 0.0, 3.4)
	return points


func update_pose(t: float, sand: float, relief: float, depth: float, opacity: float, snow: bool = false) -> void:
	if opacity <= 0.001:
		hide()
		return
	show()
	var offset := 0
	if native_ok:
		_seat_adjust(t)
	else:
		var points := _fallback_parts(t)
		seat = (Vector3(0.0, 9.84, 2.82)).rotated(Vector3.RIGHT, _rear_amount(t) * -0.98) - Vector3(0.0, 0.0, 3.4)
		for i in 7:
			_joint(points[2*i], points[2*i+1], [2.42, 1.4, 1.1, 0.68, 0.68, 0.58, 0.58][i], 0.75, i)
		offset = 7
	_draw_rider(t, offset)
	var ground_uv := 0.5 + position.y / (maxf(8.0, depth) * 2.0 * tan(deg_to_rad(43.0) / 2.0))
	var air_t := smoothstep(0.05, 0.80, ground_uv)
	var air := Color(0.875 + 0.103*air_t, 0.697 + 0.169*air_t, 0.439 + 0.192*air_t)
	if snow:
		air = Color(0.638 + 0.172*air_t, 0.714 + 0.144*air_t, 0.754 + 0.118*air_t)
	var transmission := minf(1.0, exp(-depth * (0.30+sand*0.96) / 325.0) * (1.0 + 0.15*smoothstep(408.0, 565.0, depth)))
	for color: Color in materials:
		var material: ShaderMaterial = materials[color]
		var silhouette := color.lerp(Color("#27262c"), .35) if snow else color
		var ink := air.lerp(silhouette, transmission)
		material.set_shader_parameter("pigment", Vector3(ink.r, ink.g, ink.b))
		material.set_shader_parameter("visibility", opacity)
		material.set_shader_parameter("relief", relief * (1.0 - 0.44*sand) * transmission)


func shadow_points(t: float) -> Array[Vector3]:
	var points: Array[Vector3] = []
	if native_ok:
		for bone_name in CASTER:
			points.push_back(_bone(bone_name))
	else:
		points = _fallback_parts(t)
	var lean := 0.68 - 0.54 * _rear_amount(t)
	points.append_array([
		seat, seat + Vector3(0.0, 2.57, lean),
		seat + Vector3(0.0, 3.33, lean + 0.22), seat + Vector3(0.0, 4.3, lean + 0.02)
	])
	return points
