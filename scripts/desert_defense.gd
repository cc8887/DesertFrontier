extends Node
## The prototype reuses the cinematic player and its camera, not a second map.
## Three successive encounters, deterministic route and no random hits.
const OVERLAY = preload("res://scripts/desert_defense_hud.gd")
const TERRAIN = preload("res://scripts/desert_terrain.gd")
const ROUTE = preload("res://scripts/desert_route.gd")
const RIDERS := 3
const MAX_INTEGRITY := 2
const GUARD_OUTLINE = preload("res://scripts/guard_outline.gd")
const EARTHWORK = preload("res://scripts/frontier_earthwork.gd")
const LIGHTING = preload("res://scripts/desert_shadow.gd")
const ARCHER = preload("res://scripts/frontier_archer.gd")
const FIRE_INTERVAL := ARCHER.CYCLE
const TRACK_SPEED := 1.38
const ENGAGEMENT_ROUTE_TIME := 5.6
const BREACH_ROUTE_TIME := 16.95
const SUPPORTS := [Vector2i(0, 1), Vector2i(2, 3), Vector2i(4, 5), Vector2i(14, 17)]

var host: Node3D
var overlay: CanvasLayer
var guard_outline: CanvasLayer
var active := false
var aim_screen := Vector2.ZERO
const REST_AIM := Vector2(.67, .54)
var enemy_index := 0
var enemy_hp := 0
var fort := MAX_INTEGRITY
var killed := 0
var state := "off"
var cooldown := 0.0
var gap_time := 0.0
var previous_time := 0.0
var return_time := 0.0
var return_paused := false
var return_hud := true
var prior_mouse_mode: Input.MouseMode
var archer: Node3D
var archer_key: DirectionalLight3D
var earthwork: Node3D

func _ready() -> void:
	overlay = OVERLAY.new()
	add_child(overlay)
	overlay.weather_requested.connect(host._toggle_weather)
	archer = ARCHER.new()
	add_child(archer)
	archer.released.connect(_release_shot)
	guard_outline = GUARD_OUTLINE.new()
	add_child(guard_outline)
	guard_outline.setup(host.camera)
	earthwork = EARTHWORK.new()
	earthwork.name = "FrontierEarthwork"
	add_child(earthwork)
	earthwork.hide()
	archer.floor_height = earthwork.floor_height
	archer_key = DirectionalLight3D.new()
	archer_key.name = "RampartSun"
	add_child(archer_key)
	archer_key.look_at(archer_key.global_position - LIGHTING.SUN)
	archer_key.light_cull_mask = EARTHWORK.WALL_LIGHT_LAYER
	archer_key.shadow_caster_mask = EARTHWORK.ARCHER_SHADOW_LAYER
	archer_key.light_color = Color("#fff6e7")
	archer_key.shadow_enabled = true
	archer_key.shadow_bias = 0.035
	archer_key.shadow_normal_bias = 0.0
	archer_key.shadow_opacity = .88
	archer_key.shadow_blur = 1.35
	archer_key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	archer_key.directional_shadow_max_distance = 58.0
	archer_key.directional_shadow_fade_start = .90
	archer_key.hide()

func begin() -> void:
	if not active:
		return_time = host.t
		return_paused = host.paused
		return_hud = host.hud.hud.visible
		prior_mouse_mode = Input.mouse_mode
		var viewport := get_viewport().get_visible_rect()
		aim_screen = viewport.size * REST_AIM
	active = true
	host._stop_sound()
	host.hud.hud.hide()
	overlay.show()
	archer.show()
	earthwork.show()
	archer_key.show()
	archer.reset()
	_pose_archer(0.0)
	overlay.update_weather(host.snow_mode)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	enemy_index = 0
	fort = MAX_INTEGRITY
	killed = 0
	overlay.reset_effect()
	_spawn()

func leave() -> void:
	if not active:
		return
	active = false
	state = "off"
	host._stop_sound()
	Input.mouse_mode = prior_mouse_mode
	overlay.hide()
	archer.reset()
	archer.hide()
	guard_outline.deactivate()
	earthwork.hide()
	archer_key.hide()
	host.hud.hud.visible = return_hud
	host.t = return_time
	host.paused = return_paused
	host.paint()

func _spawn() -> void:
	enemy_index += 1
	enemy_hp = 2 if enemy_index < 3 else 3
	state = "ride"
	cooldown = 0
	archer.reset()
	previous_time = 0.0
	host.t = 0.50
	host.paint()
	_update_hud(0.0)

func _resolve(breach: bool) -> void:
	if breach:
		fort -= 1
	else:
		killed += 1
	state = "breach" if breach else "down"
	gap_time = 1.05
	host._stop_sound()
	_hide_rider()
	_update_hud(0.0)

func _hide_rider() -> void:
	host.rider.hide()
	host.shadow.cast.hide()
	host.shadow.contact.hide()
	for particle in host.dust.particles:
		particle.hide()

func gust_envelope() -> float:
	# A slower swell and a shorter variation give the gusts room to breathe.
	var p: float = host.wind_phase
	return clampf(.56 + .31*sin(p*3.7-.65) + .13*sin(p*8.3+.8), 0.0, 1.0)

func wind_gain() -> float:
	return clampf(float(host.look.wind) * lerpf(1.12, 3.35, gust_envelope()), 0.0, 1.0)

func step(dt: float) -> void:
	var delta := minf(maxf(dt, 0), 0.05)
	cooldown = maxf(0.0, cooldown - delta)
	host.wind_phase += delta * float(host.look.wind) * lerpf(1.55, 3.45, gust_envelope())
	if state == "ride":
		previous_time = host.t
		host.t += delta * (1.0 if host.t < ROUTE.RESUME else TRACK_SPEED)
		if host.sound_on:
			if previous_time < 1.29 and host.t >= 1.29:
				host.whinny.play()
			if previous_time < 2.58 and host.t >= 2.58:
				host.hoof.play()
		if host.t >= BREACH_ROUTE_TIME:
			_resolve(true)
		else:
			host.paint()
	else:
		# Keep the wind alive during the gap and result screens, but no ghost riders.
		host.update_atmosphere()
		if state == "breach" or state == "down":
			gap_time -= delta
			if gap_time <= 0.0:
				if fort <= 0:
					state = "lost"
				elif enemy_index >= RIDERS:
					state = "won"
				else:
					_spawn()
	_pose_archer(delta)
	_update_hud(delta)

func _update_hud(dt: float) -> void:
	var instruction: String
	match state:
		"won": instruction = "守住了前哨。按 R 再打一轮。"
		"lost": instruction = "前哨失守。按 R 重新开始。"
		"breach": instruction = "骑兵已越过近丘，前哨受损！"
		"down": instruction = "已拦截。留意远脊上的下一匹马。"
		_: instruction = "沙脊上有动静…" if host.t < ENGAGEMENT_ROUTE_TIME else "等骑兵露出沙坡，在露出的轮廓上出击。"
	if host.snow_mode and state == "ride" and host.t < ENGAGEMENT_ROUTE_TIME:
		instruction = "雪脊上有动静…"
	var life := "骑兵耐久 %d" % enemy_hp if state == "ride" else "拦截 %d/%d" % [killed, RIDERS]
	overlay.update_state("%s  ·  来袭 %d/%d    前哨 %d/%d    %s" % ["老年守卫" if archer.elder else "年轻守卫", enemy_index, RIDERS, fort, MAX_INTEGRITY, life], instruction, aim_screen, dt)

func refresh_hud() -> void:
	overlay.update_weather(host.snow_mode)
	_update_hud(0.0)

func set_elder(value: bool) -> void:
	archer.set_elder(value)
	_pose_archer(0.0)
	_update_hud(0.0)

func _target_world(screen: Vector2) -> Vector3:
	var depth := clampf(-host.rider.position.z, 45.0, 300.0)
	return host.camera.project_position(screen, depth)

func _pose_archer(delta: float) -> void:
	var base := Vector3(EARTHWORK.GUARD_X, EARTHWORK.WALK_Y, EARTHWORK.GUARD_Z)
	var fixed_facing := get_viewport().get_visible_rect().size * REST_AIM
	var wind := Vector3(-1.0, 0.10, 0.26).normalized() * wind_gain()
	archer.place(base, host.camera.project_position(fixed_facing, 140.0))
	archer.aim_at(aim_screen, _target_world(aim_screen))
	earthwork.set_weather(host.snow_mode, host.look.sun)
	archer.update_pigment(host.snow_mode, host.look.sand, host.look.sun, host.look.brush)
	archer.tick(delta, host.wind_phase, wind)
	if active:
		guard_outline.sync(host.camera, base, ARCHER.HEIGHT)

func aim_at(screen: Vector2) -> void:
	if not active:
		return
	aim_screen = screen.clamp(Vector2.ZERO, get_viewport().get_visible_rect().size - Vector2.ONE)
	archer.aim_at(aim_screen, _target_world(aim_screen))

func shoot_at(screen: Vector2) -> bool:
	aim_at(screen)
	if not active or state != "ride" or cooldown > 0.0:
		return false
	if not archer.start(aim_screen, _target_world(aim_screen)):
		return false
	cooldown = FIRE_INTERVAL
	return true

func _release_shot(screen: Vector2, start_world: Vector3) -> void:
	if not active or state != "ride":
		return
	var hit := false
	if host.t >= ENGAGEMENT_ROUTE_TIME and host.rider.visible:
		hit = _hit_rider(screen)
	overlay.effect(screen, hit, host.camera.unproject_position(start_world))
	if hit:
		enemy_hp -= 1
		if enemy_hp <= 0:
			_resolve(false)
		_update_hud(0.0)

func _hit_rider(screen: Vector2) -> bool:
	var camera: Camera3D = host.camera
	var origin := camera.project_ray_origin(screen)
	var direction := camera.project_ray_normal(screen)
	var points: Array[Vector3] = host.rider.shadow_points(host.t)
	# Bounded aim-assist envelopes centered on animated horse/rider segments.
	for i in SUPPORTS.size():
		var bones: Vector2i = SUPPORTS[i]
		var center: Vector3 = host.rider.to_global((points[bones.x] + points[bones.y]) * 0.5)
		var radius: float = (2.1 if i == 3 else 2.76) * host.rider.scale.x
		var along := (center - origin).dot(direction)
		if along <= 0.0 or (center - origin - direction * along).length_squared() > radius * radius:
			continue
		var impact := origin + direction * along
		if not _dune_blocks_ray(origin, impact):
			return true
	return false

func _dune_blocks_ray(from: Vector3, to: Vector3) -> bool:
	var end_depth := -to.z
	for layer in 3:
		var low := float(TERRAIN.NEAR[layer])
		var high := minf(float(TERRAIN.FAR[layer]), end_depth - 2.0)
		if high <= low:
			continue
		for i in 31:
			var depth := lerpf(low, high, float(i) / 30.0)
			var ray := from.lerp(to, (-depth - from.z) / (to.z - from.z))
			if ray.y < TERRAIN.ground_y(layer, ray.x, depth, host.aspect) - 0.30:
				return true
	return false
