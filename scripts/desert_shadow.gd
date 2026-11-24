extends Node3D
## Depth-tested cast and independent contact. The receiving bounds stop rays at
## the actual dune, and a diffuse approximation handles grazing far intersections.

const Terrain = preload("res://scripts/desert_terrain.gd")
const Route = preload("res://scripts/desert_route.gd")
const SHADER = preload("res://shaders/shadow.gdshader")
const SUN := Vector3(-0.677, 0.468, -0.568)
const RADII := [2.42, 1.4, 1.1, 0.42, 0.42, 0.42, 0.42, 1.15, 0.42]
const GRID := Vector2i(18, 20)

var cast: MeshInstance3D
var contact: MeshInstance3D
var _cast_material: ShaderMaterial
var _contact_material: ShaderMaterial
var _indices := PackedInt32Array()

func _ready() -> void:
	for j in range(GRID.y):
		for i in range(GRID.x):
			var a := j * (GRID.x + 1) + i
			var b := a + GRID.x + 1
			_indices.append_array(PackedInt32Array([a, b, a + 1, a + 1, b, b + 1]))
	_cast_material = _new_material(-15, false)
	_contact_material = _new_material(-14, true)
	cast = _new_patch("DuneCastShadow", _cast_material)
	contact = _new_patch("HoofContactShadow", _contact_material)

func _new_material(priority: int, is_contact: bool) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.render_priority = priority
	material.set_shader_parameter("contact_only", is_contact)
	return material

func _new_patch(node_name: String, material: ShaderMaterial) -> MeshInstance3D:
	var patch := MeshInstance3D.new()
	patch.name = node_name
	patch.material_override = material
	patch.mesh = ArrayMesh.new()
	patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	patch.hide()
	add_child(patch)
	return patch

func _project_ray(p: Vector3, layer: int, bounds: Vector2, aspect: float) -> Vector3:
	var sun := SUN.normalized()
	var dx := -sun.x
	var dz := -sun.z
	var lateral := 1.11 * Route.H_SCALE * aspect
	var start := maxf(0.0, (-bounds.y - p.z) / dz)
	var stop := (-bounds.x - p.z) / dz
	for side: float in [-1.0, 1.0]:
		var f := side * p.x + lateral * p.z
		var fd := side * dx + lateral * dz
		if fd > 0.0000000001:
			stop = minf(stop, -f / fd)
		elif fd < -0.0000000001:
			start = maxf(start, -f / fd)
		elif f > 0.0:
			return Vector3.INF
	if stop < start:
		return Vector3.INF
	var prior := _ray_height(p, sun, start, bounds, lateral, layer, aspect)
	if is_zero_approx(start) and prior <= 0.0:
		return _ray_point(p, sun, start, bounds, lateral, layer, aspect) if prior > -0.8 else Vector3.INF
	if is_zero_approx(prior):
		return _ray_point(p, sun, start, bounds, lateral, layer, aspect)
	var previous := start
	var step := 1.0
	while previous < stop:
		var sample_at := minf(stop, previous + step)
		var next := _ray_height(p, sun, sample_at, bounds, lateral, layer, aspect)
		if prior > 0.0 and next <= 0.0:
			var lo := previous
			var hi := sample_at
			for i in range(12):
				var m := (lo + hi) * 0.5
				if _ray_height(p, sun, m, bounds, lateral, layer, aspect) <= 0.0:
					hi = m
				else:
					lo = m
			return _ray_point(p, sun, hi, bounds, lateral, layer, aspect)
		previous = sample_at
		prior = next
		step = minf(7.0, step * 1.30)
	return Vector3.INF

func _ray_point(p: Vector3, sun: Vector3, d: float, bounds: Vector2, lateral: float, layer: int, aspect: float) -> Vector3:
	var depth := clampf(-p.z + sun.z * d, bounds.x, bounds.y)
	var x := clampf(p.x - sun.x * d, -depth * lateral, depth * lateral)
	return Vector3(x, Terrain.ground_y(layer, x, depth, aspect), -depth)

func _ray_height(p: Vector3, sun: Vector3, d: float, bounds: Vector2, lateral: float, layer: int, aspect: float) -> float:
	return p.y - sun.y * d - _ray_point(p, sun, d, bounds, lateral, layer, aspect).y

func _soft_ray(p: Vector3, layer: int, bounds: Vector2, aspect: float, travel: float) -> Vector4:
	var sun := SUN.normalized()
	var lateral := 1.11 * Route.H_SCALE * aspect
	var depth := clampf(-p.z, bounds.x, bounds.y)
	var floor_x := clampf(p.x, -depth * lateral, depth * lateral)
	var base := maxf(0.0, p.y - Terrain.ground_y(layer, floor_x, depth, aspect))
	var hit := _project_ray(p, layer, bounds, aspect)
	var local := minf(travel * 0.72, base / 0.66)
	var distance := maxf(0.0, (p.x - hit.x) / sun.x) if hit.is_finite() else travel
	var approximation := smoothstep(0.55, 1.0, distance / travel)
	var reach := lerpf(minf(distance, travel), local, approximation)
	var ground := _ray_point(p, sun, reach, bounds, lateral, layer, aspect)
	# If the depth cap shortens the ray, shorten the lateral movement too.
	var actual := clampf((p.z - ground.z) / sun.z, 0.0, reach)
	ground = _ray_point(p, sun, actual, bounds, lateral, layer, aspect)
	return Vector4(ground.x, ground.y, ground.z, approximation)

func _drape(patch: MeshInstance3D, min_x: float, max_x: float, min_depth: float, max_depth: float, layer: int, aspect: float, lift: float) -> void:
	if min_x >= max_x or min_depth >= max_depth:
		patch.hide()
		return
	var points := PackedVector3Array()
	points.resize((GRID.x + 1) * (GRID.y + 1))
	var lateral := 1.11 * Route.H_SCALE * aspect
	for j in range(GRID.y + 1):
		var depth := lerpf(min_depth, max_depth, float(j) / GRID.y)
		var edge := depth * lateral
		for i in range(GRID.x + 1):
			var x := clampf(lerpf(min_x, max_x, float(i) / GRID.x), -edge, edge)
			points[j * (GRID.x + 1) + i] = Vector3(x, Terrain.ground_y(layer, x, depth, aspect) + lift, -depth)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_INDEX] = _indices
	var mesh := patch.mesh as ArrayMesh
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	patch.show()

func update_shadow(pose: Dictionary, points: Array[Vector3], aspect: float, sand: float, relief: float) -> void:
	var layer: int = pose.layer
	var opacity: float = pose.opacity
	if layer < 0 or opacity < 0.001:
		cast.hide()
		contact.hide()
		return
	var bounds: Vector2 = Route.DEPTH_RANGES[layer]
	var pos: Vector3 = pose.position
	var basis: Basis = pose.basis
	var rider_scale: float = pose.scale
	var depth: float = pose.depth
	var yaw: float = pose.yaw
	var contact_x := 8.1 - 3.9 * relief
	var contact_z := 6.2 - 2.8 * relief
	var pad := sqrt(contact_x * contact_x + contact_z * contact_z)
	_contact_material.set_shader_parameter("footprint", Vector4(pos.x, pos.z, contact_x, contact_z))
	_contact_material.set_shader_parameter("footprint_heading", Vector2(sin(yaw), cos(yaw)))
	_contact_material.set_shader_parameter("alpha_factor", opacity * (0.51 - 0.15 * sand) * (1.0 - 0.46 * relief))
	_contact_material.set_shader_parameter("sand_density", sand)
	_drape(contact, pos.x - pad, pos.x + pad, maxf(bounds.x, depth - pad), minf(bounds.y, depth + pad), layer, aspect, 0.17)
	if relief < 0.001 or points.size() < 2:
		cast.hide()
		return

	var reach := lerpf(42.0, 25.0, smoothstep(135.0, 430.0, depth)) * minf(rider_scale, 1.3)
	var segments := PackedVector4Array()
	var widths := PackedVector3Array()
	segments.resize(9)
	widths.resize(9)
	var min_x := INF
	var max_x := -INF
	var min_depth := INF
	var max_depth := -INF
	for i in range(mini(9, points.size() / 2)):
		var local_a := points[2 * i]
		var local_b := points[2 * i + 1]
		var a := _soft_ray(pos + basis * (local_a * rider_scale), layer, bounds, aspect, reach)
		var b := _soft_ray(pos + basis * (local_b * rider_scale), layer, bounds, aspect, reach)
		var blend := (a.w + b.w) * 0.5
		var radius: float = RADII[i] * rider_scale
		var soft := (0.58 + 0.72 * sand + maxf(0.0, (local_a.y + local_b.y) * 0.5) * 0.043 + 0.5 * blend) * rider_scale
		var margin := radius + soft + 0.14
		segments[i] = Vector4(a.x, a.z, b.x, b.z)
		widths[i] = Vector3(radius, soft, 1.0 - 0.42 * blend)
		min_x = minf(min_x, minf(a.x, b.x) - margin)
		max_x = maxf(max_x, maxf(a.x, b.x) + margin)
		min_depth = minf(min_depth, minf(-a.z, -b.z) - margin)
		max_depth = maxf(max_depth, maxf(-a.z, -b.z) + margin)
	_cast_material.set_shader_parameter("capsules", segments)
	_cast_material.set_shader_parameter("penumbra", widths)
	_cast_material.set_shader_parameter("alpha_factor", opacity * relief * (0.68 - 0.22 * sand))
	_cast_material.set_shader_parameter("sand_density", sand)
	_drape(cast, min_x, max_x, maxf(bounds.x, min_depth), minf(bounds.y, max_depth), layer, aspect, 0.14)

func set_snow(snow: bool) -> void:
	_cast_material.set_shader_parameter("snow_mode", snow)
	_contact_material.set_shader_parameter("snow_mode", snow)
