extends Node3D
## The three physical dune ribbons reconstructed from the web demo's picture coordinates.

const FOV_TAN := 0.3939104756149424 # tan(43 degrees / 2)
const NEAR := [142.0, 43.0, 8.0]
const FAR := [565.0, 238.0, 69.0]
const EARTH := [
	Vector3(0.765, 0.570, 0.354),
	Vector3(0.752, 0.519, 0.307),
	Vector3(0.772, 0.543, 0.294),
]
const POSTS := [
	Vector4(0.567, 0.012, 0.0032, -0.0021),
	Vector4(0.592, 0.030, 0.0047, 0.0033),
	Vector4(0.627, 0.023, 0.0033, -0.0012),
]
const TERRAIN := preload("res://shaders/desert_terrain.gdshader")
const SKY := preload("res://shaders/desert_sky.gdshader")
const GRAIN := preload("res://assets/desert_grain.png")

var _aspect: float = 0.0
var _materials: Array[ShaderMaterial] = []
var _geometry: Array[MeshInstance3D] = []


static func crest(layer: int, u: float) -> float:
	match layer:
		0:
			var falloff := 0.365 if u < 0.602 else 0.335
			return 0.587 + 0.233 * exp(-pow(absf((u - 0.602) / falloff), 1.52)) + 0.007 * sin((u - 0.30) * 11.0)
		1:
			return 0.302 + 0.144 * exp(-pow(absf((u - 0.085) / 0.52), 1.55)) + 0.026 * sin(u * 7.0 + 1.0) - 0.018 * u
		_:
			return 0.129 + 0.252 * exp(-pow(absf((u - 0.93) / 0.48), 1.52)) + 0.011 * sin(u * 10.0)


static func height_uv(layer: int, u: float, depth: float) -> float:
	var r := clampf(log(depth / FAR[layer]) / log(NEAR[layer] / FAR[layer]), 0.0, 1.0)
	return crest(layer, u) * (1.0 - r) - 0.075 * r + 0.022 * sin(5.0 * u + r * 5.0) * sin(PI * r)


static func ground_y(layer: int, x: float, depth: float, aspect: float) -> float:
	var u := 0.5 + x / (2.0 * depth * FOV_TAN * aspect)
	return (2.0 * height_uv(layer, u, depth) - 1.0) * depth * FOV_TAN


static func project(u: float, v: float, depth: float, aspect: float) -> Vector3:
	return Vector3((2.0 * u - 1.0) * depth * FOV_TAN * aspect, (2.0 * v - 1.0) * depth * FOV_TAN, -depth)


func setup(aspect: float) -> void:
	if absf(_aspect - aspect) < 0.00005:
		return
	_aspect = aspect
	while not _geometry.is_empty():
		var old := _geometry.pop_back() as MeshInstance3D
		remove_child(old)
		old.queue_free()

	if _materials.is_empty():
		var mat := ShaderMaterial.new()
		mat.shader = SKY
		_materials.append(mat)
		for layer in 3:
			mat = ShaderMaterial.new()
			mat.shader = TERRAIN
			mat.render_priority = -20 + layer
			mat.set_shader_parameter("uEarth", EARTH[layer])
			mat.set_shader_parameter("uBrushSeed", float(layer) + 0.93)
			mat.set_shader_parameter("uGrainMap", GRAIN)
			_materials.append(mat)
		mat = ShaderMaterial.new()
		mat.shader = TERRAIN
		mat.render_priority = -17
		mat.set_shader_parameter("uEarth", Vector3(0.64, 0.43, 0.24))
		mat.set_shader_parameter("uPosts", 1.0)
		mat.set_shader_parameter("uGrainMap", GRAIN)
		_materials.append(mat)
	for mat: ShaderMaterial in _materials:
		mat.set_shader_parameter("uAspect", aspect)
	var quad := QuadMesh.new()
	quad.size = Vector2(2.002 * 590.0 * FOV_TAN * aspect, 2.002 * 590.0 * FOV_TAN)
	var sky_mesh := _add_mesh("WhiteSunSky", quad, _materials[0])
	sky_mesh.position.z = -590.0
	for layer in 3:
		_add_mesh("DuneRibbon%d" % layer, _build_ribbon(layer), _materials[1 + layer])
	_add_mesh("FarRidgeMarkers", _build_posts(), _materials[4])


func update_look(phase: float, sand: float, sun: float, grain: float, brush: float, sky: float, relief: float, snow: bool = false) -> void:
	for mat: ShaderMaterial in _materials:
		mat.set_shader_parameter("uTravel", phase)
		mat.set_shader_parameter("uWinter", 1.0 if snow else 0.0)
		mat.set_shader_parameter("uSand", sand)
		mat.set_shader_parameter("uLight", sun)
		mat.set_shader_parameter("uRelief", relief)
	if not _materials.is_empty():
		_materials[0].set_shader_parameter("uSky", sky)
	for i in range(1, _materials.size()):
		_materials[i].set_shader_parameter("uGrain", grain)
		_materials[i].set_shader_parameter("uBrush", brush)


func _add_mesh(label: String, value: Mesh, mat: ShaderMaterial) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = value
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	_geometry.append(node)
	return node


func _build_ribbon(layer: int) -> ArrayMesh:
	const COLS := 136
	const ROWS := 43
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	var uv := PackedVector2Array()
	var indices := PackedInt32Array()
	for j in range(ROWS + 1):
		var r := float(j) / ROWS
		var depth: float = FAR[layer] * pow(NEAR[layer] / FAR[layer], r)
		for i in range(COLS + 1):
			var u := -0.055 + (float(i) / COLS) * 1.11
			var pt := project(u, height_uv(layer, u, depth), depth, _aspect)
			points.append(pt)
			var h_x := (ground_y(layer, pt.x + 0.2, depth, _aspect) - ground_y(layer, pt.x - 0.2, depth, _aspect)) / 0.4
			var h_depth := (ground_y(layer, pt.x, depth + 0.2, _aspect) - ground_y(layer, pt.x, depth - 0.2, _aspect)) / 0.4
			normals.append(Vector3(-h_x, 1.0, h_depth).normalized())
			uv.append(Vector2(u, r))
			if i > 0 and j > 0:
				var at := j * (COLS + 1) + i
				var top_left := at - COLS - 2
				var top_right := at - COLS - 1
				indices.append_array(PackedInt32Array([top_left, at-1, at, top_left, at, top_right]))
	return _array_mesh(points, normals, uv, indices)


func _build_posts() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uv := PackedVector2Array()
	var indices := PackedInt32Array()
	for marker: Vector4 in POSTS:
		var u := marker.x
		var y := crest(0, u) - 0.0025
		var d := float(FAR[0]) * 0.955
		var k := vertices.size()
		vertices.append_array(PackedVector3Array([
			project(u - marker.z * 0.6, y, d, _aspect),
			project(u + marker.z * 0.61, y, d, _aspect),
			project(u + marker.w - marker.z * 0.37, y + marker.y, d + 1.0, _aspect),
			project(u + marker.w + marker.z * 0.28, y + marker.y * 0.83, d + 1.0, _aspect),
		]))
		for i in 4:
			normals.append(Vector3(0.0, 0.0, 1.0))
			uv.append(Vector2(0.0, 0.45 if i < 2 else 0.5))
		indices.append_array(PackedInt32Array([k, k+1, k+2, k+2, k+1, k+3]))
	return _array_mesh(vertices, normals, uv, indices)


func _array_mesh(points: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
