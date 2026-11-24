extends Node3D
## A baked-in-time, world-space trail. Each foot stamps once each gallop,
## on the matching dune ribbon; snow gradually covers it again.
const ROUTE = preload("res://scripts/desert_route.gd")
const TERRAIN = preload("res://scripts/desert_terrain.gd")
const TRACK_INK = preload("res://shaders/snow_tracks.gdshader")
const START := 3.85
const STOP := 17.33
const CLOCK := 20.0
const HOOF_STEPS := 72
const MARK_MAX_AGE := 10.50
const PRIMING_PHASES := [0.167, 0.104, 0.708, 0.562]
const PRIMING_FEET := [
	Vector3(-0.84, 0, -3.91), Vector3(0.87, 0, -4.81),
	Vector3(-0.86, 0, 2.97), Vector3(0.84, 0, 3.55),
]
const UVS := [Vector2(0.0, 0.0), Vector2(0.5, 0.0), Vector2(1.0, 0.0),
	Vector2(0.0, 0.5), Vector2(0.5, 0.5), Vector2(1.0, 0.5),
	Vector2(0.0, 1.0), Vector2(0.5, 1.0), Vector2(1.0, 1.0)]
const MESH_INDEX := [0, 3, 4, 0, 4, 1, 1, 4, 5, 1, 5, 2, 3, 6, 7, 3, 7, 4, 4, 7, 8, 4, 8, 5]
const MAX_MARKS := 128

var footprints: MeshInstance3D
var pigment: ShaderMaterial
var marks: Array[Dictionary] = []
var native_contacts := false
var _aspect := 0.0
var _phases: Array = PRIMING_PHASES.duplicate()
var _feet: Array = PRIMING_FEET.duplicate()

func _ready() -> void:
	pigment = ShaderMaterial.new()
	pigment.shader = TRACK_INK
	pigment.render_priority = 2
	footprints = MeshInstance3D.new()
	footprints.name = "WindSoftenedHoofprints"
	footprints.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	footprints.material_override = pigment
	footprints.hide()
	add_child(footprints)

func setup_from_rider(rider: Node3D) -> void:
	# Sample the real source gallop clip only once. The lowest point per hoof
	# yields both an art-consistent contact phase and the matching local xz.
	if not rider.native_ok:
		return
	var lowest := PackedFloat32Array([INF, INF, INF, INF])
	for frame in range(HOOF_STEPS):
		var phase := float(frame) / HOOF_STEPS
		rider._sample_skeleton(Vector3(0.0, phase * rider.animations[1].length, 0.0), 1.0, 0.0)
		for hoof in range(4):
			var foot: Vector3 = rider._bone(rider.FEET[hoof])
			if foot.y < lowest[hoof]:
				lowest[hoof] = foot.y
				_phases[hoof] = phase
				_feet[hoof] = foot
	rider._seat_adjust(0.0)
	native_contacts = true
	_aspect = 0.0

static func _cycle(seconds: float) -> float:
	return seconds * 1.83 + 0.165 * sin(seconds * 0.68)

static func _cycle_to_seconds(value: float) -> float:
	var lo := START - 0.60
	var hi := STOP + 0.60
	for _step in range(24):
		var mid := (lo + hi) * 0.5
		if _cycle(mid) < value:
			lo = mid
		else:
			hi = mid
	return (lo + hi) * 0.5

func update_tracks(t: float, aspect: float, snow_mode: bool, density: float = 0.68) -> void:
	if not snow_mode or not is_finite(t) or not is_finite(aspect) or aspect <= 0.0:
		footprints.hide()
		return
	if not is_equal_approx(aspect, _aspect):
		_build(aspect)
	var draw_marks := false
	for mark: Dictionary in marks:
		var age := t - float(mark.born)
		if age > 0.0 and age < MARK_MAX_AGE:
			draw_marks = true
			break
	footprints.visible = draw_marks
	if draw_marks:
		pigment.set_shader_parameter("now_time", t)
		pigment.set_shader_parameter("snow_density", clampf(density, 0.0, 1.0))

func _build(aspect: float) -> void:
	_aspect = aspect
	marks.clear()
	var low_cycle := floori(_cycle(START))
	var high_cycle := ceili(_cycle(STOP))
	for cycle in range(low_cycle, high_cycle + 1):
		for hoof in range(4):
			var born := _cycle_to_seconds(cycle + float(_phases[hoof]))
			if born < START or born > STOP:
				continue
			var pose: Dictionary = ROUTE.pose(born, aspect)
			var layer: int = pose.layer
			# The valley is not modeled as a continuous receiver. No phantom
			# prints on a separate nearer dune, or across the gap behind it.
			if layer < 0:
				continue
			var foot: Vector3 = _feet[hoof]
			var origin: Vector3 = pose.position
			var basis: Basis = pose.basis
			var world := origin + basis * (Vector3(foot.x, 0.0, foot.z) * float(pose.scale))
			var heading := Vector2(basis.z.x, basis.z.z).normalized()
			if -world.z <= float(TERRAIN.NEAR[layer]) or -world.z >= float(TERRAIN.FAR[layer]):
				continue
			var receiver := TERRAIN.ground_y(layer, world.x, -world.z, aspect)
			world.y = receiver
			marks.append({"born": born, "layer": layer, "position": world,
				"heading": heading, "scale": pose.scale, "seed": float(cycle * 4 + hoof)})
	marks.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.born < b.born)
	var verts := PackedVector3Array()
	var ink_uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for k in range(mini(marks.size(), MAX_MARKS)):
		var m: Dictionary = marks[k]
		var xz: Vector3 = m.position
		var layer: int = m.layer
		var heading: Vector2 = m.heading
		var right := Vector2(heading.y, -heading.x)
		var seed := fposmod(sin(float(m.seed) * 82.13) * 4197.27, 1.0)
		# COLOR is RGBA8 on the mesh. Carry time as two bytes so a track
		# cannot appear ±40ms before its actual hoof impact.
		var birth_code := ceili(float(m.born) / CLOCK * 65535.0)
		var high := float(birth_code >> 8) / 255.0
		var low := float(birth_code & 255) / 255.0
		var scale_: float = m.scale
		var width := (1.28 + 0.28 * seed) * scale_
		var length := (1.98 + 0.31 * seed) * scale_
		var min_depth := float(TERRAIN.NEAR[layer])
		var max_depth := float(TERRAIN.FAR[layer])
		var base := verts.size()
		for uv: Vector2 in UVS:
			var local := right * ((uv.x - 0.5) * width) + heading * ((0.5 - uv.y) * length)
			var wx := xz.x + local.x
			var depth := clampf(-(xz.z + local.y), min_depth, max_depth)
			# Every patch vertex is draped; a low depth-scaled bias avoids the
			# thin marks z-fighting the actual tessellated receiver ribbon.
			var lift := lerpf(0.049, 0.111, smoothstep(70.0, 500.0, depth))
			var y := TERRAIN.ground_y(layer, wx, depth, aspect) + lift
			verts.push_back(Vector3(wx, y, -depth))
			ink_uvs.push_back(uv)
			colors.push_back(Color(high, low, seed, 1.0 if layer == 2 else 0.0))
		for ix: int in MESH_INDEX:
			indices.push_back(base + ix)
	if verts.is_empty():
		footprints.mesh = null
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = ink_uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	footprints.mesh = mesh
