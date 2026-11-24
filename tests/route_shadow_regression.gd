extends SceneTree
## Run: godot --headless --path . -s tests/route_shadow_regression.gd
## Golden positions are from the published browser v11 math at 16:9.

const Route = preload("res://scripts/desert_route.gd")
const Shadow = preload("res://scripts/desert_shadow.gd")
const Terrain = preload("res://scripts/desert_terrain.gd")
const ASPECT := 16.0 / 9.0
const CAST_POINTS: Array[Vector3] = [
	Vector3(0.0, 7.45, -3.85), Vector3(0.0, 7.35, 3.59),
	Vector3(0.0, 7.45, 3.10), Vector3(0.0, 10.29, 5.72),
	Vector3(0.0, 10.50, 5.05), Vector3(0.0, 9.95, 7.07),
	Vector3(0.0, 8.1, -0.2), Vector3(0.0, 12.73, 0.34),
]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var patch: Node3D = Shadow.new()
	root.add_child(patch)
	var golden: Array[Vector4] = [
		Vector4(0.0, 0.498, 0.793630486, 565.0),
		Vector4(1.68, 0.498, 0.793630486, 565.0),
		Vector4(7.4, 0.594326784, 0.592431034, 406.26894),
		Vector4(11.25, 0.7118412354, 0.286470710, 254.670661),
		Vector4(13.83, 0.7425145462, 0.061003402, 127.144475),
		Vector4(15.36, 0.715, 0.325007227, 69.0),
		Vector4(16.6, 0.698, 0.271367997, 55.2789313),
	]
	var last_z := INF
	for anchor in golden:
		var p := Route.pose(anchor.x, ASPECT)
		assert(absf(p.x - anchor.y) < 0.0001 and absf(p.y - anchor.z) < 0.0001)
		assert(absf(p.depth - anchor.w) < 0.002 and p.depth <= last_z)
		assert(absf(p.basis.determinant() - 1.0) < 0.00001)
		last_z = p.depth

	assert(Route.pose(7.4, ASPECT).basis.z.y < -0.49)
	assert(Route.pose(1.68, ASPECT).basis.z.x > 0.94)
	assert(Route.pose(16.6, ASPECT).basis.z.z > 0.96)
	var far_pose := Route.pose(7.4, ASPECT)
	var far_pos: Vector3 = far_pose.position
	var far_basis: Basis = far_pose.basis
	var source := far_pos + far_basis * (CAST_POINTS[0] * float(far_pose.scale))
	var hit: Vector3 = patch._project_ray(source, 0, Route.DEPTH_RANGES[0], ASPECT)
	assert(hit.is_finite() and source.distance_to(hit) > 100.0)

	for ratio in [1.0, ASPECT, 2.2]:
		for t in [7.35, 7.4, 7.45]:
			var p := Route.pose(t, ratio)
			patch.update_shadow(p, CAST_POINTS, ratio, 0.59, 0.72)
			assert(patch.cast.visible and patch.contact.visible)
			var arrays: Array = patch.cast.mesh.surface_get_arrays(0)
			for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
				assert(vertex.is_finite() and -vertex.z >= 142.0 and -vertex.z <= 565.0)
				assert(absf(vertex.x) <= -vertex.z * 1.11 * Route.H_SCALE * ratio + 0.0001)
				assert(absf(vertex.y - Terrain.ground_y(0, vertex.x, -vertex.z, ratio) - 0.14) < 0.0001)
	patch.update_shadow(far_pose, CAST_POINTS, ASPECT, 0.89, 0.72)
	var heavy: float = patch.cast.material_override.get_shader_parameter("alpha_factor")
	patch.update_shadow(far_pose, CAST_POINTS, ASPECT, 0.19, 0.72)
	var light: float = patch.cast.material_override.get_shader_parameter("alpha_factor")
	assert(light > heavy)
	patch.update_shadow(far_pose, CAST_POINTS, ASPECT, 0.59, 0.0)
	assert(not patch.cast.visible and patch.contact.visible)
	patch.update_shadow(Route.pose(12.5, ASPECT), CAST_POINTS, ASPECT, 0.59, 0.72)
	assert(not patch.cast.visible and not patch.contact.visible)
	patch.update_shadow(Route.pose(16.6, ASPECT), CAST_POINTS, ASPECT, 0.59, 0.72)
	assert(patch.cast.visible and patch.contact.visible)
	patch.update_shadow(Route.pose(18.1, ASPECT), CAST_POINTS, ASPECT, 0.59, 0.72)
	assert(not patch.cast.visible and not patch.contact.visible)
	print("ROUTE_SHADOW_OK: browser timing/height/pitch, bounded downhill cast + contact at 7.35–7.45, 0%/thick sand/valley/near crest")
	quit()
