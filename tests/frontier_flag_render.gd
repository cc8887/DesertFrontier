extends SceneTree
## Native render acceptance: force two wind phases at one frozen gameplay frame.
const SCENE = preload("res://scenes/desert.tscn")
const CLOTH_REGION := Rect2i(0,170,145,192)

func _initialize() -> void:
	call_deferred("_run")

func frame() -> Image:
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(2)
		return
	var scene := SCENE.instantiate()
	root.add_child(scene)
	scene.set_process(false)
	var d: Node = scene.defense
	if d.standard.is_visible_in_tree():
		push_error("No defense flag in observation mode")
		quit(1)
		return
	d.begin()
	scene.t = 8.85
	scene.paint()
	d.step(.01)
	var initial_phase: float = scene.wind_phase
	d.step(.17)
	if scene.wind_phase <= initial_phase or not is_equal_approx(d.standard.textile.get_shader_parameter("wind_phase"), scene.wind_phase):
		push_error("The flag must receive the active scene wind")
		quit(1)
		return
	d.standard.pose(.12,.82,false)
	var a: Image = await frame()
	d.standard.pose(.39,.82,false)
	var b: Image = await frame()
	var moved := 0
	var unchanged_away := true
	for y in range(158,374):
		for x in range(0,216):
			if a.get_pixel(x,y).is_equal_approx(b.get_pixel(x,y)):
				continue
			if CLOTH_REGION.has_point(Vector2i(x,y)):
				moved += 1
			elif x > 160:
				unchanged_away = false
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		DirAccess.make_dir_recursive_absolute(args[0])
		a.save_png(args[0].path_join("flag_phase_a.png"))
		b.save_png(args[0].path_join("flag_phase_b.png"))
	d.leave()
	if moved < 500 or not unchanged_away or d.standard.is_visible_in_tree():
		push_error("Expected local cloth motion and defense-only visibility; changed pixels %d" % moved)
		quit(1)
		return
	print("HAN_STANDARD_OK: gameplay wind, %d cloth pixels moved, hidden when leaving defense" % moved)
	quit()
