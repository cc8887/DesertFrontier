extends SceneTree
const SCENE = preload("res://scenes/desert.tscn")
const A = preload("res://scripts/frontier_archer.gd")
var failures := PackedStringArray()
var events: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, what: String) -> void:
	if not ok:
		failures.append(what)
		push_error(what)

func key(code: Key) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = true
	root.push_input(e, true)

func click(screen: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = screen
	root.push_input(e, true)

func _write_pose(archer: Node3D, out: Dictionary, label: String) -> void:
	var sk: Skeleton3D = archer.skeleton
	var joints := {}
	for b in sk.get_bone_count():
		var p := sk.get_bone_global_pose(b)
		var r := sk.get_bone_global_rest(b)
		joints[sk.get_bone_name(b)] = [[vec(p.origin),vec(p.basis.x),vec(p.basis.y),vec(p.basis.z)], [vec(r.origin),vec(r.basis.x),vec(r.basis.y),vec(r.basis.z)]]
	out[label] = {"bones": joints, "nock": vec(archer.to_local(archer.arrow_nock_world)), "segments": []}
	for rod in archer.wood + archer.string + [archer.arrow]:
		if rod.visible:
			out[label].segments.append([
				vec(archer.to_local(rod.to_global(Vector3(0,-0.5,0)))),
				vec(archer.to_local(rod.to_global(Vector3(0,0.5,0))))])

func vec(v: Vector3) -> Array:
	return [v.x, v.y, v.z]

func _run() -> void:
	var scene := SCENE.instantiate()
	root.add_child(scene)
	scene.set_process(false)
	var d: Node = scene.defense
	check(not d.archer.visible, "Cinematic remains unmodified")
	key(KEY_TAB)
	var archer: Node3D = d.archer
	archer.released.connect(func(screen: Vector2, world: Vector3) -> void:
		events.append({"screen": screen, "world": world}))
	var poses := {}
	var lift_heights: Array[float] = []
	for age in [false, true]:
		key(KEY_2 if age else KEY_1)
		var label := "elder" if age else "young"
		check(archer.elder == age and archer.visible, "Actual key switches age rig")
		var sk: Skeleton3D = archer.skeleton
		check(sk.get_bone_count() == 25 and A.RIBBONS.size() == 8, "Imported GLB has 17 body bones and 8 ribbon bones")
		for i in A.RIBBONS.size():
			var b := sk.find_bone(A.RIBBONS[i])
			var p := sk.find_bone(&"Head" if i == 0 else A.RIBBONS[i-1])
			check(b >= 0 and sk.get_bone_parent(b) == p, "Ribbon bone is in correct chain")
		var aim := Vector2(835, 368)
		var before: int = events.size()
		click(aim)
		check(archer.attacking and events.size() == before, "Mouse queues on real defense input path")
		archer.tick(0.12, 2.0, Vector3.RIGHT * 0.8)
		lift_heights.append(archer.grip_world.y)
		_write_pose(archer, poses, label + "_raise")
		archer.tick(0.30, 2.0, Vector3.RIGHT * 0.8)
		check(events.size() == before and archer.arrow.visible, "No release before marker")
		check(archer.string_nock_world.distance_to(archer.string_hand_world) < 0.0002, "Draw-hand and nock coincide")
		check(archer.bow_center_world.distance_to(archer.grip_world) < 0.0002, "Bow stays in grip")
		var screen_bounds := root.get_visible_rect()
		check(screen_bounds.has_point(scene.camera.unproject_position(archer.global_position + Vector3.UP * A.HEIGHT)), "Guard head framed by gameplay camera")
		check(screen_bounds.has_point(scene.camera.unproject_position(archer.bow_center_world)), "Bow grip framed by gameplay camera")
		_write_pose(archer, poses, label + "_full")
		archer.tick(0.04, 2.0, Vector3.RIGHT * 0.8)
		check(events.size() == before + 1 and not archer.arrow.visible, "Exactly one release event and mounted arrow hidden")
		check(events[-1].screen.is_equal_approx(aim), "Release retains selected screen point")
		var a := sk.find_bone(A.RIBBONS[0])
		var b := sk.find_bone(A.RIBBONS[-1])
		var anchor := sk.get_bone_global_pose(a).origin
		var tip := sk.get_bone_global_pose(b).origin
		archer.tick(0.0, 2.1, Vector3.RIGHT * 0.8)
		check(sk.get_bone_global_pose(a).origin.distance_to(anchor) < 0.0002, "Wind leaves knot anchored")
		check(sk.get_bone_global_pose(b).origin.distance_to(tip) > 0.04, "Wind moves ribbon tip independently")
		archer.tick(0.18, 2.2, Vector3.RIGHT * 0.8)
		_write_pose(archer, poses, label + "_recover")
		archer.tick(0.4, 2.3, Vector3.RIGHT * 0.8)
		check(events.size() == before + 1 and not archer.attacking, "Single event through recovery")
		d.cooldown = 0.0
		for yaw in [0.0, PI]:
			archer.rotation.y = yaw
			archer.tick(0.0, 2.7, Vector3.RIGHT * 0.85)
			var span_right := (sk.get_bone_global_pose(b).origin - sk.get_bone_global_pose(a).origin).dot(sk.global_basis.inverse() * Vector3.RIGHT)
			archer.tick(0.0, 2.7, Vector3.LEFT * 0.85)
			var span_left := (sk.get_bone_global_pose(b).origin - sk.get_bone_global_pose(a).origin).dot(sk.global_basis.inverse() * Vector3.RIGHT)
			check(span_right - span_left > 0.3, "Ribbon sways with crosswind at both yaws")
		archer.tick(0.0, 1.0, Vector3.ZERO)
		var still := sk.get_bone_global_pose(b).origin
		archer.tick(0.0, 4.0, Vector3.ZERO)
		check(still.distance_to(sk.get_bone_global_pose(b).origin) < 0.0002, "Zero wind settles rather than storing last angle")
	check(absf(lift_heights[0] - lift_heights[1]) > 0.28, "Distinct age poses at identical 120 ms")
	click(Vector2(835, 368))
	var count := events.size()
	key(KEY_ESCAPE)
	check(not archer.attacking and not archer.visible and not d.active, "Escape cancels pending shot and restores cinematic")
	check(events.size() == count, "Canceled shot has no release")
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		var file := FileAccess.open(args[0], FileAccess.WRITE)
		if file: file.store_string(JSON.stringify(poses))
	if failures.is_empty():
		print("PASS: young/elder GLB rigs, exact 0.44s release crossing, hand/bow/string/arrow, matched gameplay screen, independent 8-bone wind, Escape.")
	quit(0 if failures.is_empty() else 1)
