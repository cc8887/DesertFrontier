extends SceneTree
const SCENE = preload("res://scenes/desert.tscn")
const LOWER := [&"Hips", &"Thigh.L", &"Thigh.R", &"Shin.L", &"Shin.R", &"Foot.L", &"Foot.R"]
var failures := 0
var events: Array[Vector2] = []

func _initialize() -> void:
	call_deferred("_run")

func expect(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		push_error(what)

func click(p: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = p
	root.push_input(event, true)

func move_aim(p: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = p
	root.push_input(event, true)

func lower(archer: Node3D) -> Array[Transform3D]:
	var out: Array[Transform3D] = [archer.global_transform]
	var sk: Skeleton3D = archer.skeleton
	for name_: StringName in LOWER:
		out.append(sk.global_transform * sk.get_bone_global_pose(sk.find_bone(name_)))
	return out

func _run() -> void:
	var scene := SCENE.instantiate()
	root.add_child(scene)
	scene.set_process(false)
	var d: Node = scene.defense
	d.archer.released.connect(func(screen: Vector2, _w: Vector3) -> void: events.append(screen))
	for elder in [false, true]:
		for should_hit in [true,false]:
			d.begin()
			d.set_elder(elder)
			scene.t = 7.3
			scene.t += .45 * d.TRACK_SPEED
			scene.paint()
			var rider_points: Array[Vector3] = scene.rider.shadow_points(scene.t)
			var hit: Vector2 = scene.camera.unproject_position(scene.rider.to_global((rider_points[0]+rider_points[1])*.5))
			scene.t = 7.3
			scene.paint()
			d.step(0.0)
			var miss := Vector2(590,550)
			var event_count := events.size()
			var archer: Node3D = d.archer
			var sk: Skeleton3D = archer.skeleton
			var chest := sk.find_bone(&"Chest")
			var low := lower(archer)
			click(miss if should_hit else hit)
			for i in 7:
				d.step(.05)
			var old := sk.get_bone_global_pose(chest)
			var old_bow: Vector3 = archer.bow.global_basis.z
			var aim: Vector2 = hit if should_hit else miss
			move_aim(aim)
			d.step(0.0)
			expect(not old.is_equal_approx(sk.get_bone_global_pose(chest)), "Chest rotates with live mouse during draw")
			expect(old_bow.dot(archer.bow.global_basis.z) < .99, "Bow direction changed with mouse")
			var drawing := lower(archer)
			for i in low.size():
				expect(low[i].is_equal_approx(drawing[i]), "Lower body remains fixed during mouse sweep, not just after recovery")
			var shaft: Vector3 = archer.arrow.global_basis.y.normalized()
			var to_aim: Vector3 = (d._target_world(aim) - Vector3(archer.arrow_nock_world)).normalized()
			expect(shaft.dot(to_aim) > .9999, "Visible arrow shaft points at the live target")
			expect(d.enemy_hp == 2 and events.size() == event_count,"Moving aim cannot release a shot early")
			d.step(.05)
			d.step(.05)
			expect(events.size() == event_count+1 and events[-1].is_equal_approx(aim), "Release uses current aim exactly once")
			expect(d.enemy_hp == (1 if should_hit else 2), "Late aim chooses hit or miss, not the initial click")
			move_aim(miss if should_hit else hit)
			for i in 9:
				d.step(.05)
			expect(events.size() == event_count+1 and d.enemy_hp == (1 if should_hit else 2), "Post-release mouse cannot redirect or repeat")
			var finish := lower(archer)
			for i in low.size():
				expect(low[i].is_equal_approx(finish[i]), "Root, pelvis and legs remain fixed in world space")
	if failures == 0:
		print("AIM_AT_OK: both ages, real mouse events, retarget hit/miss during full draw, same visible arrow and release aim, fixed lower-body world transforms")
	quit(failures)
