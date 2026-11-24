extends RefCounted
## Deterministic run matching the browser timing, camera and world-space slope.

const Terrain = preload("res://scripts/desert_terrain.gd")
const DURATION := 18.9
const REAR_START := 0.87
const REAR_PEAK := 1.68
const TOUCHDOWN := 2.58
const RESUME := 3.35
const ROUTE_OFFSET := 3.66
const NEAR_CREST := 11.70
const ENTER := 7.55
const LAST := 14.34
const H_SCALE := 0.3939104756149423
const DEPTH_RANGES := [Vector2(142, 565), Vector2(43, 238), Vector2(8, 69)]
const DEPTH_CURVE := [
	Vector2(ENTER, 257), Vector2(9.26, 158), Vector2(10.66, 110),
	Vector2(11.16, 85), Vector2(NEAR_CREST, 69), Vector2(12.61, 58.4), Vector2(LAST, 43.5)
]
const X_CURVE := [
	Vector2(ENTER, 0.711), Vector2(9.30, 0.747), Vector2(10.94, 0.734),
	Vector2(NEAR_CREST, 0.715), Vector2(12.34, 0.698), Vector2(LAST, 0.698)
]

static func _curve(knots: Array, k: float) -> float:
	var i := knots.size() - 2
	for j in range(knots.size() - 1):
		if k <= knots[j + 1].x:
			i = j
			break
	var a: Vector2 = knots[i]
	var b: Vector2 = knots[i + 1]
	var d := b.x - a.x
	var u := clampf((k - a.x) / d, 0.0, 1.0)
	var slope := _rate(a, b)
	var m := _combine(_rate(knots[i - 1], a), slope) if i > 0 else slope
	var n := _combine(slope, _rate(b, knots[i + 2])) if i + 2 < knots.size() else slope
	return (1.0 + 2.0 * u) * (1.0 - u) ** 2 * a.y + u * (1.0 - u) ** 2 * d * m + u * u * (3.0 - 2.0 * u) * b.y + u * u * (u - 1.0) * d * n

static func _rate(x: Vector2, y: Vector2) -> float:
	return (y.y - x.y) / (y.x - x.x)

static func _combine(l: float, r: float) -> float:
	return 0.0 if l * r <= 0.0 else 2.0 * l * r / (l + r)

static func route_time(t: float) -> float:
	var elapsed := maxf(0.0, t - RESUME)
	return elapsed * elapsed / 1.24 if elapsed < 0.62 else elapsed - 0.31

static func ground_height(time: float, u: float, depth: float) -> float:
	if time <= ENTER:
		return Terrain.height_uv(0, u, depth)
	if time >= NEAR_CREST:
		return Terrain.height_uv(2, u, depth)
	return _curve([
		Vector2(ENTER, Terrain.height_uv(0, 0.711, 257.0)),
		Vector2(8.47, 0.154), Vector2(9.35, 0.078), Vector2(10.18, 0.061),
		Vector2(10.72, 0.088), Vector2(11.15, 0.144), Vector2(11.47, 0.253),
		Vector2(NEAR_CREST, Terrain.height_uv(2, 0.715, 69.0))
	], time)

static func position_from_uv(u: float, v: float, depth: float, aspect: float) -> Vector3:
	return Vector3((2.0 * u - 1.0) * depth * H_SCALE * aspect, (2.0 * v - 1.0) * depth * H_SCALE, -depth)

static func sample(t: float) -> Dictionary:
	var time := clampf(route_time(t), 0.0, LAST)
	var p := clampf(time / ENTER, 0.0, 1.0)
	var advance := 0.16 * p + 0.84 * p ** 1.29
	var depth := 565.0 * (257.0 / 565.0) ** advance if time <= ENTER else _curve(DEPTH_CURVE, time)
	var v := clampf((565.0 - depth) / (565.0 - 257.0), 0.0, 1.0)
	var x := 0.498 + 0.213 * v * v * (2.45 - 1.45 * v) if time <= ENTER else _curve(X_CURVE, time)
	var y := ground_height(time, x, depth)
	var scale := 1.0 + 0.65 * smoothstep(390.0, 565.0, depth)
	var opacity := (0.68 + 0.32 * smoothstep(0.0, 0.64, t)) * (1.0 - smoothstep(13.61 + ROUTE_OFFSET, LAST + ROUTE_OFFSET, t))
	var layer := 0 if time <= ENTER else (2 if time >= NEAR_CREST else -1)
	return {"x": x, "y": y, "depth": depth, "scale": scale, "opacity": opacity, "time": time, "layer": layer}

static func world_position(p: Dictionary, aspect: float) -> Vector3:
	return position_from_uv(p.x, p.y, p.depth, aspect)

static func _surface(p: Dictionary, t: float, wx: float, depth: float, aspect: float) -> float:
	if p.layer >= 0:
		return Terrain.ground_y(p.layer, wx, depth, aspect)
	var before := sample(maxf(RESUME, t - 0.11))
	var after := sample(t + 0.11)
	var a := (2.0 * float(before.y) - 1.0) * float(before.depth) * H_SCALE
	var b := (2.0 * float(after.y) - 1.0) * float(after.depth) * H_SCALE
	var slope := (b - a) / minf(-0.001, float(after.depth) - float(before.depth))
	return world_position(p, aspect).y + (depth - float(p.depth)) * slope

static func _slopes(p: Dictionary, t: float, aspect: float) -> Vector2:
	var z: float = p.depth
	var x := world_position(p, aspect).x
	var d := 0.36
	var z1 := z - d
	var z2 := z + d
	if p.layer >= 0:
		var bounds: Vector2 = DEPTH_RANGES[p.layer]
		z1 = maxf(bounds.x, z1)
		z2 = minf(bounds.y, z2)
	return Vector2(
		(_surface(p, t, x + d, z, aspect) - _surface(p, t, x - d, z, aspect)) / (2.0 * d),
		(_surface(p, t, x, z1, aspect) - _surface(p, t, x, z2, aspect)) / maxf(0.001, z2 - z1)
	)

static func pose(t: float, aspect: float) -> Dictionary:
	var p := sample(t)
	var around := minf(LAST + ROUTE_OFFSET - 0.24, maxf(RESUME, t))
	var from := world_position(sample(maxf(RESUME, around - 0.08)), aspect)
	var to := world_position(sample(around + 0.12), aspect)
	var velocity := to - from
	var desired := atan2(velocity.x, velocity.z)
	var profile := 1.26
	var yaw := profile + angle_difference(profile, desired) * smoothstep(TOUCHDOWN + 0.03, RESUME, t)
	var slopes := _slopes(p, t, aspect)
	var route_t: float = p.time
	if absf(route_t - NEAR_CREST) < 0.48:
		var ridge := sample(NEAR_CREST + ROUTE_OFFSET)
		var rx := world_position(ridge, aspect).x
		var rz: float = ridge.depth
		var d := 0.45
		var reference := Vector2(
			(Terrain.ground_y(2, rx + d, rz, aspect) - Terrain.ground_y(2, rx - d, rz, aspect)) / (2.0 * d),
			(Terrain.ground_y(2, rx, rz - d, aspect) - Terrain.ground_y(2, rx, rz, aspect)) / d
		)
		var natural_slopes := slopes
		slopes = slopes.lerp(reference, smoothstep(NEAR_CREST - 0.48, NEAR_CREST, route_t))
		if route_t > NEAR_CREST:
			slopes = slopes.lerp(natural_slopes, smoothstep(NEAR_CREST, NEAR_CREST + 0.48, route_t))
	var support := smoothstep(TOUCHDOWN + 0.02, RESUME + 0.55, t)
	slopes.x *= 0.48 + 0.52 * support
	if route_t > NEAR_CREST - 0.39:
		slopes.x *= 1.0 - 0.72 * smoothstep(NEAR_CREST - 0.39, NEAR_CREST + 0.45, route_t)
	slopes.y *= 0.24 + 0.76 * support
	slopes *= minf(1.0, 0.72 / maxf(0.001, slopes.length()))
	var up := Vector3(-slopes.x, 1.0, -slopes.y).normalized()
	var heading := Vector2(sin(yaw), cos(yaw))
	var forward := Vector3(heading.x, slopes.dot(heading), heading.y).normalized()
	var right := up.cross(forward).normalized()
	p["position"] = world_position(p, aspect) + Vector3(0.0, 0.12, 0.0)
	p["basis"] = Basis(right, forward.cross(right), forward)
	p["yaw"] = yaw
	return p

static func phase_label(t: float) -> String:
	if t < REAR_START:
		return "远脊停驻"
	if t < TOUCHDOWN:
		return "远脊扬蹄"
	if t < RESUME:
		return "落蹄转向"
	if t < 11.2:
		return "迎面奔来"
	return "穿过谷地" if t < NEAR_CREST + ROUTE_OFFSET else "翻过近丘"
