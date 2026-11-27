extends Node3D
## Shared contact solver; the two age variants choose different poses, not a global speed multiplier.
signal released(screen: Vector2, start_world: Vector3)

const YOUNG = preload("res://assets/guard/young_guard.glb")
const ELDER = preload("res://assets/guard/elder_guard.glb")
const PAINTER = preload("res://shaders/guard_painterly.gdshader")
const INK_LAYER = preload("res://scripts/guard_outline.gd").MASK_LAYER
const HEIGHT := 6.7774184
const RELEASE := 0.44
const CYCLE := 0.82
const RIBBONS := [&"Ribbon.01", &"Ribbon.02", &"Ribbon.03", &"Ribbon.04",
	&"Ribbon.05", &"Ribbon.06", &"Ribbon.07", &"Ribbon.08"]

var elder := false
var attacking := false
var elapsed := 0.0
var release_count := 0
var shot_screen := Vector2.ZERO
var shot_target := Vector3.ZERO
var stance_direction := Vector3.BACK
var model: Node3D
var skeleton: Skeleton3D
var bones := {}
var bow: Node3D
var wood: Array[MeshInstance3D] = []
var string: Array[MeshInstance3D] = []
var arrow: MeshInstance3D
var arrow_nock_world := Vector3.ZERO
var string_nock_world := Vector3.ZERO
var grip_world := Vector3.ZERO
var bow_center_world := Vector3.ZERO
var last_draw := 0.0
var string_hand_world := Vector3.ZERO
var floor_height: Callable
var painted: Array[ShaderMaterial] = []
var last_look := Vector4(-1, -1, -1, -1)
@onready var draws_pixels := DisplayServer.get_name() != "headless"

func _paint_material(color: Color, is_ribbon := false) -> ShaderMaterial:
	var ink := ShaderMaterial.new()
	ink.shader = PAINTER
	ink.set_shader_parameter("pigment", color)
	ink.set_shader_parameter("ribbon", is_ribbon)
	painted.append(ink)
	return ink

func update_pigment(snow: bool, sand: float, sun: float, brush: float) -> void:
	var look := Vector4(float(snow), sand, sun, brush)
	if last_look == look:
		return
	last_look = look
	for ink in painted:
		ink.set_shader_parameter("winter", look.x)
		ink.set_shader_parameter("airborne_sand", look.y)
		ink.set_shader_parameter("sun_power", look.z)
		ink.set_shader_parameter("brush_weight", look.w)

func _ready() -> void:
	_build_variant()
	bow = Node3D.new()
	add_child(bow)
	for i in 6:
		wood.append(_rod(Color("#5a3428"), 0.045, bow))
	for i in 2:
		string.append(_rod(Color("#f0d7ad"), 0.019, bow))
	arrow = _rod(Color("#e2b16e"), 0.034, bow)
	visible = false

func _rod(color: Color, radius: float, parent: Node3D) -> MeshInstance3D:
	var rod := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 1.0
	mesh.radial_segments = 6
	mesh.rings = 0
	rod.mesh = mesh
	if draws_pixels:
		rod.material_override = _paint_material(color)
	rod.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(rod)
	return rod

func _span(rod: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var length := a.distance_to(b)
	if length <= 0.0001:
		rod.hide()
		return
	rod.show()
	rod.position = (a + b) * 0.5
	rod.basis = Basis(Quaternion(Vector3.UP, (b - a) / length)).scaled_local(Vector3(1, length, 1))

func _build_variant() -> void:
	if model != null:
		remove_child(model)
		model.queue_free()
	var packed := ELDER if elder else YOUNG
	model = packed.instantiate()
	add_child(model)
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0]
	painted.clear()
	if bow != null:
		for rod in wood + string + [arrow]:
			if rod.material_override is ShaderMaterial:
				painted.append(rod.material_override)
		last_look = Vector4(-1, -1, -1, -1)
	if draws_pixels:
		for part in model.find_children("*", "MeshInstance3D", true, false):
			part.layers |= INK_LAYER
			for i in part.mesh.get_surface_count():
				var base := part.mesh.surface_get_material(i) as StandardMaterial3D
				if base != null:
					var is_ribbon := base.resource_name.get_slice(".", 0) == "ribbon"
					part.set_surface_override_material(i, _paint_material(base.albedo_color, is_ribbon))
	bones.clear()
	for b in skeleton.get_bone_count():
		bones[StringName(skeleton.get_bone_name(b))] = b

func set_elder(value: bool) -> void:
	if elder == value or attacking:
		return
	elder = value
	_build_variant()

func reset() -> void:
	attacking = false
	elapsed = 0.0
	release_count = 0

func start(screen: Vector2, target: Vector3) -> bool:
	if attacking:
		return false
	shot_screen = screen
	shot_target = target
	elapsed = 0.0
	attacking = true
	return true

func aim_at(screen: Vector2, target: Vector3) -> void:
	shot_screen = screen
	shot_target = target

func place(ground: Vector3, stance_target: Vector3) -> void:
	# Only the base stance can turn the hips and feet. The mouse never reaches it.
	global_position = ground
	var horizontal := stance_target - ground
	horizontal.y = 0.0
	if horizontal.length_squared() > 0.001:
		stance_direction = horizontal.normalized()
		rotation.y = atan2(horizontal.x, horizontal.z) - deg_to_rad(54.0 if elder else 59.0)

func tick(delta: float, wind_phase: float, wind: Vector3) -> void:
	var prior := elapsed
	if attacking:
		elapsed = minf(elapsed + maxf(delta, 0), CYCLE)
	# Sample the exact release pose even when the frame crosses it. This keeps
	# the nock, string and world-space visual tracer aligned at all frame rates.
	if attacking and prior < RELEASE and elapsed >= RELEASE:
		_pose(RELEASE, wind_phase, wind)
		release_count += 1
		released.emit(shot_screen, arrow_nock_world)
	if elapsed >= CYCLE:
		attacking = false
	_pose(elapsed if attacking else 0.0, wind_phase, wind)

func _joint(name_: StringName) -> Transform3D:
	return skeleton.get_bone_global_pose(bones[name_])

func _rotate(name_: StringName, value: Quaternion) -> void:
	var b: int = bones[name_]
	var rest := skeleton.get_bone_rest(b)
	skeleton.set_bone_pose_rotation(b, rest.basis.get_rotation_quaternion() * value)

func _point_bone(name_: StringName, direction: Vector3) -> void:
	var b: int = bones[name_]
	var tr := skeleton.get_bone_global_pose(b)
	var current := tr.basis.y.normalized()
	if direction.length_squared() > 0.000001:
		tr.basis = Basis(Quaternion(current, direction.normalized())) * tr.basis
		skeleton.set_bone_global_pose(b, tr)

func _arm(side: String, hand_target: Vector3, elbow_hint: Vector3, hand_axis: Vector3) -> Vector3:
	var upper := StringName("UpperArm." + side)
	var fore := StringName("Forearm." + side)
	var hand := StringName("Hand." + side)
	var a := _joint(upper).origin
	var l1 := a.distance_to(_joint(fore).origin)
	var l2 := _joint(fore).origin.distance_to(_joint(hand).origin)
	var reach := hand_target - a
	var d := clampf(reach.length(), absf(l1 - l2) + 0.006, l1 + l2 - 0.006)
	var line := reach.normalized()
	if line.is_zero_approx():
		line = Vector3.FORWARD
	var bend := elbow_hint - line * elbow_hint.dot(line)
	if bend.length_squared() < 0.001:
		bend = Vector3.UP - line * line.y
	var x := (d * d + l1 * l1 - l2 * l2) / (2.0 * d)
	var elbow := a + line * x + bend.normalized() * sqrt(maxf(0.0, l1 * l1 - x * x))
	var wrist := a + line * d
	_point_bone(upper, elbow - a)
	_point_bone(fore, wrist - _joint(fore).origin)
	_point_bone(hand, hand_axis)
	# Palm center is down the longitudinal (Y) axis of the hand bone.
	return _joint(hand) * Vector3(0, HEIGHT * 0.035, 0)

func _feet() -> void:
	for side in ["L", "R"]:
		var thigh := StringName("Thigh." + side)
		var shin := StringName("Shin." + side)
		var foot := StringName("Foot." + side)
		var sg := 1.0 if side == "L" else -1.0
		var a := _joint(thigh).origin
		var d := Vector3(sg * (0.119 if elder else 0.103), 0.08, sg * -0.034) * HEIGHT
		if floor_height.is_valid():
			var sole := skeleton.to_global(d + Vector3(0, -0.08, 0.035) * HEIGHT)
			d.y += float(floor_height.call(sole)) + 0.035 - sole.y
		var u := a.distance_to(_joint(shin).origin)
		var v := _joint(shin).origin.distance_to(_joint(foot).origin)
		var vec := d - a
		var unit := vec.normalized()
		var dist := clampf(vec.length(), absf(u - v) + 0.001, u + v - 0.001)
		var bend := Vector3.BACK - unit * unit.z
		var length := (dist * dist + u * u - v * v) / (2.0 * dist)
		var knee := a + unit * length + bend.normalized() * sqrt(maxf(0.0, u * u - length * length))
		_point_bone(thigh, knee - a)
		_point_bone(shin, a + unit * dist - _joint(shin).origin)
		var b: int = bones[foot]
		var rest := skeleton.get_bone_global_rest(b)
		rest.origin = _joint(foot).origin
		skeleton.set_bone_global_pose(b, rest)

func _pose_base() -> void:
	skeleton.reset_bone_poses()
	var hips: int = bones[&"Hips"]
	skeleton.set_bone_pose_position(hips, skeleton.get_bone_rest(hips).origin - Vector3.UP * 0.18)
	_feet()

func _pose(time: float, wind_phase: float, wind: Vector3) -> void:
	_pose_base()
	_pose_upper_body(time, wind_phase, wind)

func _pose_upper_body(time: float, wind_phase: float, wind: Vector3) -> void:
	var rise := smoothstep(0.0, 0.25 if elder else 0.14, time)
	var draw := smoothstep(0.12 if elder else 0.065, 0.39 if elder else 0.33, time)
	var loose := smoothstep(RELEASE, RELEASE + 0.10, time)
	var recovery := smoothstep(0.56 if elder else 0.48, 0.82 if elder else 0.73, time)
	var lift := rise * (1.0 - recovery)
	var load := draw * (1.0 - recovery)
	var aim_dir := skeleton.global_basis.inverse() * (shot_target - (global_position + Vector3.UP * HEIGHT * 0.76)).normalized()
	if aim_dir.length_squared() < .01:
		aim_dir = skeleton.global_basis.inverse() * stance_direction
	var neutral := skeleton.global_basis.inverse() * stance_direction
	var yaw := clampf(angle_difference(atan2(neutral.x, neutral.z), atan2(aim_dir.x, aim_dir.z)), -.85, .85)
	var pitch := clampf(-asin(aim_dir.y), -.44, .44)
	var aim_weight := lerpf(.43, 1.0, lift)
	# Aim At affects Spine and its descendants only. The age-specific draw is
	# still an additive chest motion, and the hand targets solve after it.
	_rotate(&"Spine", Quaternion(Vector3.UP, yaw * .30 * aim_weight)
		* Quaternion(Vector3.RIGHT, pitch * .22 * aim_weight))
	_rotate(&"Chest", Quaternion(Vector3.UP, yaw * .46 * aim_weight + (0.14 if elder else 0.32) * load)
		* Quaternion(Vector3.RIGHT, pitch * .31 * aim_weight + (0.105 if elder else 0.035) * (1.0 - 0.75 * draw) * (1.0 - recovery)))
	_rotate(&"Head", Quaternion(Vector3.UP, yaw * .24)
		* Quaternion(Vector3.RIGHT, pitch * .47 + (-0.10 if elder else -0.04) * lift))
	aim_dir.y = clampf(aim_dir.y, -0.40, 0.38)
	aim_dir = aim_dir.normalized()
	var flat := Vector3(aim_dir.x, 0.0, aim_dir.z).normalized()
	var left_of_aim := Vector3.UP.cross(flat)
	var left_idle := HEIGHT * Vector3(0.122, 0.575 if elder else 0.60, 0.057)
	var left_ready := HEIGHT * (flat * (0.29 if elder else 0.31) - 0.057 * left_of_aim + Vector3.UP * 0.774)
	left_ready.y += aim_dir.y * HEIGHT * 0.18
	var palm := _arm("L", left_idle.lerp(left_ready, lift), Vector3(0.65, -1, -0.12), Vector3.UP)
	var rhs_idle := HEIGHT * Vector3(-0.125, 0.56, 0.07)
	var rhs_draw := palm - aim_dir * HEIGHT * (0.095 + (0.160 if elder else 0.178) * draw) + Vector3.UP * 0.025
	var right_target := rhs_idle.lerp(rhs_draw, lift) + HEIGHT * Vector3(-0.051, 0.008, -0.024) * loose * (1.0 - recovery)
	var elbow_hint := Vector3(-0.79, -0.43 if elder else 0.17, -0.58)
	var pull := _arm("R", right_target, elbow_hint, Vector3.UP)

	# Head-relative rear cone: rear is -Z in the imported guard basis, not
	# screen-left or world-west. Crosswind can curl the strip but cannot carry it
	# over the face as the guard turns, draws or leans into the shot.
	var head: int = bones[&"Head"]
	var head_basis := skeleton.get_bone_global_pose(head).basis * skeleton.get_bone_global_rest(head).basis.inverse()
	var wind_head := head_basis.inverse() * skeleton.global_basis.inverse() * wind
	var strength := clampf(wind.length(), 0.0, 1.0)
	var billow := 1.0 - pow(1.0 - strength, 2.1)
	var incoming := wind_head.normalized()
	for i in RIBBONS.size():
		# Compare by normalized length, so extra joints sample the same wave
		# rather than introducing extra waves or speeding up the gust.
		var span := 3.0 * float(i) / float(RIBBONS.size() - 1)
		var phase := 11.5 * wind_phase - span * 1.38
		var hang := Vector3(0.0, -1.0, -.46 - .055 * span)
		var flown := Vector3(incoming.x * .57 + sin(phase * .87) * (.10 + .10*span),
			.21 - .08*span + sin(phase) * (.17 + .20*span) + incoming.y * .36,
			-.95 + incoming.z * .16 + cos(phase * .92) * .08)
		var along := hang.lerp(flown, billow)
		_point_bone(RIBBONS[i], head_basis * along)
		var tail := _joint(RIBBONS[i])
		var twist := billow * (.13 + .21 * span) * cos(phase * .81)
		tail.basis = Basis(Quaternion(tail.basis.y.normalized(), twist)) * tail.basis
		skeleton.set_bone_global_pose(bones[RIBBONS[i]], tail)

	var grip_at := skeleton.to_global(palm)
	grip_world = grip_at
	var direction := (shot_target - grip_at).normalized()
	if direction.length_squared() < .01 or absf(direction.y) > .99:
		direction = (skeleton.global_basis * aim_dir).normalized()
	var up := (Vector3.UP - direction * direction.y).normalized()
	var right := up.cross(direction).normalized()
	bow.global_transform = Transform3D(Basis(right, up, direction), grip_at)
	bow_center_world = bow.global_position
	var nock_neutral := Vector3(0, 0.20, -0.32)
	string_hand_world = skeleton.to_global(pull)
	var pull_local := bow.to_local(string_hand_world)
	last_draw = draw
	var nock := nock_neutral.lerp(pull_local, lift * (1.0 - loose))
	var tension := clampf(absf(nock.z) / 1.9, 0.0, 1.0)
	var p := PackedVector3Array([
		Vector3(0,-1.38 + 0.14*tension,-0.48-0.24*tension),
		Vector3(0,-1.03,-0.12-0.09*tension),
		Vector3(0,-0.57,0.03),
		Vector3.ZERO,
		Vector3(0,0.57,0.03),
		Vector3(0,1.03,-0.12-0.09*tension),
		Vector3(0,1.38-0.14*tension,-0.48-0.24*tension)])
	for i in wood.size():
		_span(wood[i], p[i], p[i+1])
	_span(string[0], p[0], nock)
	_span(string[1], p[-1], nock)
	string_nock_world = bow.to_global(nock)
	arrow_nock_world = string_nock_world
	if attacking and time <= RELEASE:
		var shaft_dir := (bow.to_local(shot_target) - nock).normalized()
		_span(arrow, nock, nock + shaft_dir * 2.20)
	else:
		arrow.hide()
