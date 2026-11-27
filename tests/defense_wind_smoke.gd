extends SceneTree
const ARCHER = preload("res://scripts/frontier_archer.gd")
const SCENE = preload("res://scenes/desert.tscn")
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, reason: String) -> void:
	if not ok:
		failures += 1
		push_error(reason)

func _run() -> void:
	var scene := SCENE.instantiate()
	root.add_child(scene)
	scene.set_process(false)
	var d: Node = scene.defense
	d.begin()
	scene.wind_phase = 1.63
	var sk: Skeleton3D = d.archer.skeleton
	var tail := sk.find_bone(ARCHER.RIBBONS[-1])
	var first_phase: float = scene.wind_phase
	var speeds := Vector2(INF, -INF)
	var ordinates := Vector2(INF, -INF)
	var previous_output: float = d.wind_gain()
	var gain := Vector2(previous_output, previous_output)
	for i in 120:
		var prior: float = scene.wind_phase
		d.step(1.0 / 60.0)
		var output: float = d.wind_gain()
		var rate: float = (scene.wind_phase - prior) * 60.0
		var y := sk.get_bone_global_pose(tail).origin.y
		speeds = Vector2(minf(speeds.x,rate),maxf(speeds.y,rate))
		ordinates = Vector2(minf(ordinates.x,y),maxf(ordinates.y,y))
		gain = Vector2(minf(gain.x,output),maxf(gain.y,output))
		check(absf(output - scene.snowstorm.storm.get_shader_parameter("uGust")) < .0001, "Sand air and cloth share the gust envelope")
	check(scene.wind_phase - first_phase > 2.0 * float(scene.look.wind) * 1.6, "Defense clocks faster than observation")
	check(gain.y - gain.x > .30, "Gust peaks and lulls are distinct")
	check(ordinates.y - ordinates.x > .40, "Rear ribbon tip rises and falls at default wind")
	scene._toggle_weather()
	check(scene.snowstorm.storm.get_shader_parameter("uIsSnow") and is_equal_approx(scene.snowstorm.storm.get_shader_parameter("uGust"),d.wind_gain()), "Weather switch preserves gust phase")
	scene._toggle_weather()
	scene.set_look("wind",0.0)
	var still: float = scene.wind_phase
	d.step(.04)
	var drooped := sk.get_bone_global_pose(tail).origin
	d.step(.04)
	check(scene.wind_phase == still and d.wind_gain() == 0.0 and not scene.snowstorm.visible, "Zero wind disables warm foreground gust and freezes the clock")
	check(drooped.distance_to(sk.get_bone_global_pose(tail).origin) < .0001, "Still-air ribbon settles")
	scene.set_look("wind",.29)
	d.leave()
	check(not scene.snowstorm.visible, "Observation keeps its original warm atmospheric layer only")
	print("Wind test: phase/s %.3f..%.3f; gain %.3f..%.3f; tip vertical range %.3f project units" % [speeds.x,speeds.y,gain.x,gain.y,ordinates.y-ordinates.x])
	quit(failures)
