extends SceneTree
const SCENE = preload("res://scenes/desert.tscn")
var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func expect(value: bool, why: String) -> void:
	if not value:
		failures.append(why)
		push_error(why)

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event, true)

func _run() -> void:
	var scene := SCENE.instantiate()
	root.add_child(scene)
	scene.set_process(false)
	key(KEY_2)
	var normal := scene.terrain._materials[0] as ShaderMaterial
	var dust_exists := false
	for puff in scene.dust.particles:
		dust_exists = dust_exists or puff.visible
	expect(dust_exists and not scene.snowstorm.visible, "Original mode retains warm dust only")
	var anchor: Vector3 = scene.rider.position
	scene.hud.weather.pressed.emit()
	expect(scene.snow_mode and scene.snowstorm.visible, "Cinematic weather button enables snow")
	expect(normal.get_shader_parameter("uWinter") == 1.0, "Sky swaps into snow pigment")
	expect(scene.terrain._materials[1].get_shader_parameter("uWinter") == 1.0, "Dune uses its own snow pigment")
	expect(scene.shadow._contact_material.get_shader_parameter("snow_mode") == true, "Snow uses cold shadow pigment")
	expect(scene.rider.position == anchor and scene.shadow.cast.visible, "Same route and hill shadow when toggled")
	expect(not scene.hud.dust.visible and scene.hud.density_label.text == "风雪浓度", "Tuning switches to snow vocabulary")
	expect(is_equal_approx(scene.snowstorm.storm.get_shader_parameter("uDensity"), .59), "Snow overlay initial density")
	scene.hud.controls.sand.value = 82
	expect(is_equal_approx(scene.snowstorm.storm.get_shader_parameter("uDensity"), .82), "Density adjusts blowing snow")
	for puff in scene.dust.particles:
		expect(not puff.visible, "No brown wake in snow")
	expect(scene.tracks.footprints.visible and scene.tracks.native_contacts, "Native hoof contacts yield a white-slope trail")
	var marks: Array = scene.tracks.marks.duplicate(true)
	key(KEY_1)
	expect(not scene.tracks.footprints.visible, "No track before the gallop")
	key(KEY_2)
	expect(scene.tracks.marks == marks and scene.tracks.footprints.visible, "Seek rewind reproduces identical world tracks")

	key(KEY_TAB)
	expect(scene.defense.active and scene.snow_mode, "Defense inherits snow")
	expect(scene.defense.overlay.weather_button.text.begins_with("切回黄沙"), "Defensive overlay has live weather switch")
	scene.defense.overlay.weather_button.pressed.emit()
	expect(not scene.snow_mode and scene.snowstorm.visible and not scene.snowstorm.storm.get_shader_parameter("uIsSnow") and not scene.tracks.footprints.visible, "Keyboard switches to warm sand gusts, with no snow or tracks")
	for n in range(310):
		scene.defense.step(.05)
		if scene.defense.state == "breach":
			break
	expect(scene.defense.state == "breach" and not scene.rider.visible, "Reach breach interval")
	var old_phase: float = scene.wind_phase
	key(KEY_V)
	scene.defense.step(.05)
	expect(scene.snow_mode and scene.snowstorm.visible and not scene.rider.visible, "Weather swap cannot resurrect rider in breach gap")
	expect(scene.snowstorm.storm.get_shader_parameter("uPhase") > old_phase, "Wind keeps moving in breach gap")
	key(KEY_ESCAPE)
	expect(scene.snow_mode and scene.t == 7.4 and scene.tracks.footprints.visible, "Return to cinematic keeps selected weather")
	key(KEY_V)
	expect(not scene.snow_mode and normal.get_shader_parameter("uWinter") == 0.0 and not scene.tracks.footprints.visible, "Warm mode cleanly restored")
	if failures.is_empty():
		print("PASS: V/button weather, unchanged route/ground shadows, wind density, no yellow dust in snow, native hoofprints+scrubbing, defense weather + breach/return.")
	quit(0 if failures.is_empty() else 1)
