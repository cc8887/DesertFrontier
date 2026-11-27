extends SceneTree
## Render the true gameplay camera with a fixed scene time, not a mock preview.
const SCENE = preload("res://scenes/desert.tscn")
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func key(code: Key) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = true
	root.push_input(e,true)

func aim(p: Vector2, click := false) -> void:
	if click:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = true
		e.position = p
		root.push_input(e,true)
	else:
		var e := InputEventMouseMotion.new()
		e.position = p
		root.push_input(e,true)

func frame() -> Image:
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func save(im: Image, dir: String, name_: String) -> void:
	if im.is_empty() or im.save_png(dir.path_join(name_+".png")) != OK:
		failures += 1

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(2)
		return
	var args := OS.get_cmdline_user_args()
	if args.is_empty() or DirAccess.make_dir_recursive_absolute(args[0]) != OK:
		quit(2)
		return
	var dir := args[0]
	var scene := SCENE.instantiate()
	root.add_child(scene)
	scene.set_process(false)
	key(KEY_TAB)
	var d: Node = scene.defense
	for variant in 2:
		key(KEY_R)
		if variant == 1:
			key(KEY_2)
			key(KEY_V)
		scene.t = 8.85
		scene.wind_phase = 2.15
		scene.paint()
		var original: float = scene.t
		scene.t += .45 * d.TRACK_SPEED
		scene.paint()
		var points: Array[Vector3] = scene.rider.shadow_points(scene.t)
		var p: Vector2 = scene.camera.unproject_position(scene.rider.to_global((points[0]+points[1])*.5))
		scene.t = original
		scene.paint()
		aim(Vector2(880,450),true)
		for i in 7:
			d.step(.05)
		aim(p)
		d.step(.05)
		var label := "young_sand" if variant == 0 else "elder_snow"
		var shadow: Image = await frame()
		save(shadow,dir,label)
		d.archer_key.shadow_caster_mask = 0
		var lit: Image = await frame()
		save(lit,dir,label+"_shadow_off")
		var changed := 0
		var max_delta := 0.0
		var sums := Vector3.ZERO
		var feet: Vector2 = scene.camera.unproject_position(d.archer.global_position)
		for y in range(int(feet.y)-18,shadow.get_height()):
			for x in range(int(feet.x)-8,mini(int(shadow.get_width()*.65),shadow.get_width())):
				var difference := lit.get_pixel(x,y).get_luminance() - shadow.get_pixel(x,y).get_luminance()
				max_delta = maxf(max_delta,difference)
				if difference > .025:
					changed += 1
					sums += Vector3(x,y,1.0)
		if changed < 150 or (sums.x/maxf(sums.z,1.0) < feet.x+20.0):
			push_error("Native cast shadow did not darken the wall away from the sun")
			failures += 1
		print("%s cast comparison: %d darker receiver pixels; feet %s; shadow centroid %s; max delta %.4f" %
			[label,changed,feet,Vector2(sums.x,sums.y) / maxf(sums.z,1.0),max_delta])
		d.archer_key.shadow_caster_mask = d.earthwork.ARCHER_SHADOW_LAYER
		d.step(.05)
		if d.enemy_hp != 1:
			push_error("Archer on the rampart did not hit a live rider after mouse retarget")
			failures += 1
		var fired: Image = await frame()
		save(fired,dir,label+"_hit")
	key(KEY_ESCAPE)
	if d.earthwork.visible or d.archer_key.visible:
		failures += 1
	if failures == 0:
		print("WALL_RENDER_OK: sand and snow, native cast shadow A/B, hit after mouse retarget")
	quit(0 if failures == 0 else 1)
