extends SceneTree

const SCENE = preload("res://scenes/desert.tscn")
var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func expect(value: bool, context: String) -> void:
	if not value:
		failures.push_back(context)
		push_error(context)

func _run() -> void:
	var scene = SCENE.instantiate()
	root.add_child(scene)
	scene.set_process(false)
	var ui = scene.hud
	expect(scene.terrain.get_child_count() == 5, "Sky, three dune ribbons, staves")
	expect(scene.aspect > 1.2 and scene.aspect < 2.0, "Reference camera ratio")
	expect(scene.camera.keep_aspect == Camera3D.KEEP_HEIGHT, "43 degree vertical FOV")
	expect(scene.camera.far > 590.0, "Camera far plane includes sky")
	expect(not scene.sound_on, "Sound starts opt-in")
	ui.timeline.value = 1.7
	expect(scene.paused and absf(scene.t - 1.7) < 0.001, "UI seek drives actual scene and pauses")
	expect(scene._stage_label() == "远脊扬蹄", "Distant rear stage")
	expect(not scene.whinny.playing and not scene.hoof.playing, "Scrubbing cannot trigger sound")
	var crest: Vector3 = scene.rider.position
	ui.timeline.value = 7.4
	expect(scene.rider.position.z > crest.z + 140.0, "Downhill runner follows toward camera")
	expect(scene.shadow.cast.visible and scene.shadow.contact.visible, "7.4s down slope maintains projected and contact shadows")
	var endpoints: Array = scene.rider.shadow_points(7.4)
	expect(endpoints.size() == 18, "Mounted rig exposes horse and rider shadow segments")
	var shadow_vertices: PackedVector3Array = scene.shadow.cast.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for vertex in shadow_vertices:
		expect(vertex.is_finite() and vertex.z <= -142.0 and vertex.z >= -565.0, "Far shadow receiver bounds")
	var default_dust: float = 0.0
	for puff in scene.dust.particles:
		if puff.visible:
			default_dust = maxf(default_dust, puff.material_override.get_shader_parameter("opacity"))
	expect(default_dust > 0.0, "Wake exists at downhill point")
	ui.controls.sand.value = 89
	var heavy_dust: float = 0.0
	for puff in scene.dust.particles:
		if puff.visible:
			heavy_dust = maxf(heavy_dust, puff.material_override.get_shader_parameter("opacity"))
	expect(heavy_dust < default_dust, "Dense panorama sand attenuates local wake")
	ui.dust.pressed.emit()
	for puff in scene.dust.particles:
		expect(not puff.visible, "Wake disabled cleanly")
	expect(scene.shadow.cast.visible, "Shadow independent of dust visibility")
	ui.controls.relief.value = 0
	expect(not scene.shadow.cast.visible and scene.shadow.contact.visible, "Zero light keeps grounding and disables cast")
	ui.controls.relief.value = 72
	ui.timeline.value = 12.5
	expect(not scene.shadow.cast.visible and not scene.shadow.contact.visible, "Valley lacks visible receiver; no shadow leaks")
	ui.timeline.value = 16.6
	expect(scene.shadow.cast.visible and scene.rider.position.z > -70.0, "Cast returns after near dune crest")
	ui.timeline.value = 18.9
	expect(not scene.rider.visible and not scene.shadow.cast.visible, "End of demo has no hanging shade or rider")
	ui.timeline.value = 7.4
	expect(scene.rider.shadow_points(7.4) == endpoints, "Native motion sampling deterministic on rewind")
	if failures.is_empty():
		print("PASS: native Godot scene, HUD scrubbing, mounted GLB, dense sand, hillside cast, valley, near ridge, rewind.")
	quit(0 if failures.is_empty() else 1)
