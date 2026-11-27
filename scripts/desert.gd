extends Node3D
## Native 3D re-creation of the v11 "黄沙白日" browser art study.
const TERRAIN = preload("res://scripts/desert_terrain.gd")
const ROUTE = preload("res://scripts/desert_route.gd")
const RIDER = preload("res://scripts/mounted_rider.gd")
const SHADOW = preload("res://scripts/desert_shadow.gd")
const SNOWSTORM = preload("res://scripts/desert_snowstorm.gd")
const SNOW_TRACKS = preload("res://scripts/snow_tracks.gd")
const DUST = preload("res://scripts/hoof_dust.gd")
const DEFENSE = preload("res://scripts/desert_defense.gd")
const HUD = preload("res://scripts/desert_hud.gd")
const WHINNY = preload("res://assets/horse/whinny.mp3")
const HOOF = preload("res://assets/horse/hoof.mp3")
const DURATION := 18.9
const DEFAULT_LOOK := {"sand": 0.59, "wind": 0.29, "sun": 0.68, "grain": 0.63, "brush": 0.72, "sky": 0.72, "relief": 0.72}
@onready var camera: Camera3D = $FixedCamera
var terrain: Node3D
var rider: Node3D
var shadow: Node3D
var dust: Node3D
var tracks: Node3D
var snowstorm: CanvasLayer
var snow_mode := false
var hud: CanvasLayer
var defense: Node
var whinny: AudioStreamPlayer
var hoof: AudioStreamPlayer
var look := DEFAULT_LOOK.duplicate()
var t := 0.6
var wind_phase := 1.5
var aspect := 16.0 / 9.0
var paused := false
var sound_on := false
var dust_on := true

func _ready() -> void:
	var size := get_viewport().get_visible_rect().size
	if size.x > 0 and size.y > 0:
		aspect = size.x / size.y
	terrain = TERRAIN.new()
	terrain.name = "DuneRibbons"
	add_child(terrain)
	terrain.setup(aspect)
	rider = RIDER.new()
	rider.name = "MountedRider"
	add_child(rider)
	shadow = SHADOW.new()
	shadow.name = "SlopeShadows"
	add_child(shadow)
	dust = DUST.new()
	dust.name = "HoofDust"
	add_child(dust)
	snowstorm = SNOWSTORM.new()
	add_child(snowstorm)
	tracks = SNOW_TRACKS.new()
	tracks.name = "HoofprintsInSnow"
	add_child(tracks)
	tracks.setup_from_rider(rider)
	whinny = _audio(WHINNY, 0.62)
	hoof = _audio(HOOF, 0.52)
	hud = HUD.new()
	add_child(hud)
	hud.seeked.connect(set_timeline)
	hud.playback_requested.connect(_toggle_playback)
	hud.restart_requested.connect(_restart)
	hud.dust_toggled.connect(_toggle_dust)
	hud.sound_toggled.connect(_toggle_sound)
	hud.look_changed.connect(set_look)
	hud.weather_requested.connect(_toggle_weather)
	defense = DEFENSE.new()
	defense.host = self
	add_child(defense)
	hud.defense_requested.connect(defense.begin)
	_sync_sliders()
	paint()

func _process(delta: float) -> void:
	if defense.active:
		defense.step(delta)
		return
	if paused:
		return
	var step := minf(delta, 0.05)
	var previous := t
	t = fposmod(t + step, DURATION)
	wind_phase += step * look.wind
	if sound_on and t > previous:
		if previous < 1.29 and t >= 1.29:
			whinny.play()
		if previous < 2.58 and t >= 2.58:
			hoof.play()
	paint()

func _unhandled_input(event: InputEvent) -> void:
	if defense.active and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		defense.shoot_at(event.position)
		get_viewport().set_input_as_handled()

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key := (event as InputEventKey).physical_keycode
	if key == KEY_V:
		_toggle_weather()
		get_viewport().set_input_as_handled()
		return
	if defense.active:
		match key:
			KEY_ESCAPE: defense.leave()
			KEY_R: defense.begin()
			KEY_1: defense.set_elder(false)
			KEY_2: defense.set_elder(true)
			_: return
		get_viewport().set_input_as_handled()
		return
	match key:
		KEY_TAB: defense.begin()
		KEY_SPACE: _toggle_playback()
		KEY_H: hud.toggle_hud()
		KEY_R: _restart()
		KEY_F1: _reset()
		KEY_1: set_timeline(1.68)
		KEY_2: set_timeline(7.4)
		KEY_3: set_timeline(12.5)
		KEY_4: set_timeline(16.6)
		_: return
	get_viewport().set_input_as_handled()

func set_timeline(time_seconds: float) -> void:
	t = clampf(time_seconds, 0.0, DURATION)
	paused = true
	_stop_sound()
	paint()

func set_look(key: String, value: float) -> void:
	if not look.has(key):
		return
	look[key] = clampf(value, 0.0, 1.0)
	hud.set_value(key, look[key])
	paint()

func paint() -> void:
	var pose: Dictionary = ROUTE.pose(t, aspect)
	var pos: Vector3 = pose.position
	var basis: Basis = pose.basis
	rider.transform = Transform3D(basis.scaled(Vector3.ONE * float(pose.scale)), pos)
	rider.visible = float(pose.opacity) > 0.002
	rider.update_pose(t, look.sand, look.relief, pose.depth, pose.opacity, snow_mode)
	shadow.update_shadow(pose, rider.shadow_points(t), aspect, look.sand, look.relief)
	dust.update_dust(t, wind_phase, look.sand, aspect, dust_on and not snow_mode)
	tracks.update_tracks(t, aspect, snow_mode, look.sand)
	update_atmosphere()
	hud.update_status(t, _stage_label(), paused, dust_on, sound_on)

func update_atmosphere() -> void:
	terrain.update_look(wind_phase, look.sand, look.sun, look.grain, look.brush, look.sky, look.relief, snow_mode)
	var gust: float = defense.wind_gain() if is_instance_valid(defense) and defense.active else 0.0
	snowstorm.update_storm(snow_mode, wind_phase, look.sand, look.grain, aspect, gust)

func _toggle_weather() -> void:
	snow_mode = not snow_mode
	shadow.set_snow(snow_mode)
	hud.update_weather(snow_mode)
	if defense.active and defense.state != "ride":
		# Switching during a result panel must not resurrect the last rider.
		tracks.update_tracks(t, aspect, snow_mode, look.sand)
		update_atmosphere()
	else:
		paint()
	if defense.active:
		defense.refresh_hud()


func _stage_label() -> String:
	if t < 0.87: return "远脊停驻"
	if t < 2.58: return "远脊扬蹄"
	if t < 3.35: return "落蹄转向"
	if t < 11.2: return "迎面奔来"
	if t < 15.36: return "穿过谷地"
	return "翻过近丘"

func _audio(stream: AudioStream, gain: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = linear_to_db(gain)
	add_child(player)
	return player

func _stop_sound() -> void:
	whinny.stop()
	hoof.stop()

func _toggle_playback() -> void:
	paused = not paused
	if paused:
		_stop_sound()
	paint()

func _toggle_dust() -> void:
	dust_on = not dust_on
	paint()

func _toggle_sound() -> void:
	sound_on = not sound_on
	if not sound_on:
		_stop_sound()
	paint()

func _restart() -> void:
	_stop_sound()
	t = 0.0
	paused = false
	paint()

func _reset() -> void:
	look = DEFAULT_LOOK.duplicate()
	t = 0.6
	wind_phase = 1.5
	paused = false
	dust_on = true
	sound_on = false
	_stop_sound()
	_sync_sliders()
	paint()

func _sync_sliders() -> void:
	for key: String in look:
		hud.set_value(key, look[key])
