extends SceneTree
## Run with Godot Compatibility + a display, not --headless. Captures real gameplay frames.
const SCENE = preload("res://scenes/desert.tscn")
const ARCHER = preload("res://scripts/frontier_archer.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func key(code: Key) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = true
	root.push_input(e, true)

func shot(point: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = point
	root.push_input(e, true)

func move_aim(point: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = point
	root.push_input(e, true)

func capture(dir: String, frame_name: String) -> void:
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	if frame == null or frame.is_empty() or frame.save_png(dir.path_join(frame_name + ".png")) != OK:
		failures += 1

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("This capture requires a display and renderer")
		quit(2)
		return
	var args := OS.get_cmdline_user_args()
	if args.is_empty() or DirAccess.make_dir_recursive_absolute(args[0]) != OK:
		push_error("Pass an absolute capture directory after --")
		quit(2)
		return
	var dir := args[0]
	var video := "--video" in args
	var aim_proof := "--aim-at" in args
	var edge_proof := "--edge-proof" in args
	var scene := SCENE.instantiate()
	root.add_child(scene)
	scene.set_process(false)
	key(KEY_TAB)
	for variant in 3:
		var elder := variant > 0
		key(KEY_2 if elder else KEY_1)
		key(KEY_R)
		if variant == 2:
			key(KEY_V)
		scene.t = 6.65
		scene.wind_phase = 1.63
		scene.paint()
		var d: Node = scene.defense
		var original: float = scene.t
		scene.t += (17.0 / 24.0 if video else 0.45) * d.TRACK_SPEED
		scene.paint()
		var points: Array[Vector3] = scene.rider.shadow_points(scene.t)
		var point: Vector2 = scene.camera.unproject_position(scene.rider.to_global((points[0] + points[1]) * 0.5))
		scene.t = original
		scene.paint()
		if not aim_proof:
			root.warp_mouse(point)
		var label := "elder_snow" if variant == 2 else ("elder_sand" if elder else "young_sand")
		if video:
			var empty := root.get_visible_rect().size * Vector2(.46, .76)
			for i in 45:
				if aim_proof:
					if i < 6 or i > 21:
						move_aim(empty)
					else:
						move_aim(empty.lerp(point, smoothstep(6.0, 15.0, float(i))))
				if i == 6:
					shot(empty if aim_proof else point)
				d.step(1.0 / 24.0)
				if aim_proof and i == 19 and d.enemy_hp != 1:
					push_error("Aim At capture failed to hit after adjusting mouse during the draw")
					failures += 1
				await capture(dir, "clip_%03d" % (variant * 45 + i))
			continue
		shot(point)
		for i in 8:
			d.step(0.05)
			if i == 2:
				await capture(dir, label + "_raise")
		await capture(dir, label + "_full")
		if edge_proof:
			if d.guard_outline.rect == null or not d.guard_outline.rect.visible:
				push_error("The game camera must show its guard outline")
				failures += 1
			else:
				d.guard_outline.rect.hide()
				await capture(dir, label + "_without_outline")
				d.guard_outline.rect.show()
		d.step(0.05)
		await capture(dir, label + "_release")
		for i in 9:
			d.step(0.05)
		await capture(dir, label + "_recover")
	key(KEY_ESCAPE)
	if scene.defense.guard_outline.rect.visible or scene.defense.guard_outline.mask.render_target_update_mode != SubViewport.UPDATE_DISABLED:
		push_error("Leaving defense must stop the guard outline and mask")
		failures += 1
	if failures == 0:
		print("RENDER_OK: %d actual Compatibility frames at gameplay camera" % (135 if video else (15 if edge_proof else 12)))
	quit(0 if failures == 0 else 1)
