extends SceneTree
const SCENE = preload("res://scenes/desert.tscn")
var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func expect(value: bool, reason: String) -> void:
	if not value:
		failures.append(reason)
		push_error(reason)

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event, true)

func _click(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = point
	event.global_position = point
	root.push_input(event, true)

func _tick(defense: Node, seconds: float) -> void:
	for i in ceili(seconds / 0.05):
		defense.step(0.05)

func _aim(scene: Node) -> Vector2:
	var points: Array[Vector3] = scene.rider.shadow_points(scene.t)
	return scene.camera.unproject_position(scene.rider.to_global((points[0] + points[1]) * 0.5))

func _run() -> void:
	var scene := SCENE.instantiate()
	root.add_child(scene)
	scene.set_process(false)
	var defense: Node = scene.defense
	_key(KEY_2)
	expect(is_equal_approx(scene.t, 7.4) and scene.paused and scene.shadow.cast.visible, "Cinematic key 2 remains usable")
	_key(KEY_TAB)
	expect(defense.active and defense.enemy_index == 1 and not scene.hud.hud.visible and defense.overlay.visible, "Tab enters first encounter, overlays switch")
	var start: Vector3 = scene.rider.position
	_tick(defense, 1.3)
	expect(scene._stage_label() == "远脊扬蹄", "Existing distant rear sequence retained")
	_tick(defense, 4.8)
	expect(scene.rider.position.z > start.z + 100.0 and scene.shadow.cast.visible, "Rider advances and casts stable downhill shadow")
	_click(Vector2(4, 4))
	expect(defense.enemy_hp == 2 and defense.cooldown > 0.0, "Miss consumed cooldown, not health")
	var point := _aim(scene)
	_click(point)
	expect(defense.enemy_hp == 2, "Immediate next shot cannot bypass cooldown")
	_tick(defense, 0.35)
	_click(_aim(scene))
	expect(defense.enemy_hp == 1, "Actual mouse event hits the current bone pose")
	_tick(defense, 0.35)
	_click(_aim(scene))
	expect(defense.state == "down" and defense.killed == 1 and not scene.rider.visible, "Defeated rider cannot remain visible")
	_tick(defense, 1.10)
	expect(defense.enemy_index == 2 and defense.state == "ride" and scene.rider.visible, "Second rider queued")

	# Exercise all-ride completion via real mouse input, not direct health writes.
	for rider_number in range(2, 4):
		_tick(defense, 5.2)
		for i in (2 if rider_number == 2 else 3):
			_click(_aim(scene))
			_tick(defense, 0.35)
		_tick(defense, 1.12)
	expect(defense.state == "won" and defense.killed == 3 and defense.fort == 2, "Survive three aimed encounters")

	_key(KEY_R)
	expect(defense.active and defense.enemy_index == 1 and defense.fort == 2 and defense.killed == 0, "R resets encounter and integrity")
	_tick(defense, 30.0)
	expect(defense.state == "lost" and defense.fort == 0 and not scene.rider.visible, "Two missed riders breach after the near crest")
	_key(KEY_ESCAPE)
	expect(not defense.active and is_equal_approx(scene.t, 7.4) and scene.paused and scene.hud.hud.visible and scene.shadow.cast.visible, "Esc returns to exact cinematic pose and shadow")
	if failures.is_empty():
		print("PASS: Tab, rear & approach, actual mouse input, miss, cooldown, damage, 3-kill win, R, 2-breach loss, Escape restores 7.4s shadow.")
	quit(0 if failures.is_empty() else 1)
