extends SceneTree
## Check the actual ribbon's weighted vertices even when no renderer is available.
const GUARD = preload("res://scripts/frontier_archer.gd")
var count := 0
var closest := -INF
var max_anchor_shift := 0.0

func _initialize() -> void:
	call_deferred("_run")

func _scan(sk: Skeleton3D, skin: Skin, arrays: Array) -> void:
	var head := sk.find_bone(&"Head")
	var knot := sk.find_bone(GUARD.RIBBONS[0])
	var hp := sk.get_bone_global_pose(head)
	var undo_head := (hp.basis * sk.get_bone_global_rest(head).basis.inverse()).inverse()
	max_anchor_shift = maxf(max_anchor_shift, (hp.affine_inverse() * sk.get_bone_global_pose(knot).origin).distance_to(sk.get_bone_rest(knot).origin))
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var joints: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var width: int = int(joints.size() / float(verts.size()))
	var transforms: Array[Transform3D] = []
	for binding in skin.get_bind_count():
		var bone := skin.get_bind_bone(binding)
		if bone < 0:
			bone = sk.find_bone(skin.get_bind_name(binding))
		transforms.append(sk.get_bone_global_pose(bone) * skin.get_bind_pose(binding))
	for v in verts.size():
		var point := Vector3.ZERO
		for k in width:
			var idx := v * width + k
			point += (transforms[joints[idx]] * verts[v]) * weights[idx]
		var head_space := undo_head * (point - hp.origin)
		closest = maxf(closest, head_space.z)
		count += 1

func _run() -> void:
	var guard := GUARD.new()
	root.add_child(guard)
	var winds := [Vector3.ZERO, Vector3.RIGHT*.49, Vector3.LEFT*.49, Vector3.FORWARD,
		Vector3.BACK, Vector3.UP, Vector3.DOWN, Vector3(.7,.15,.7).normalized()]
	for age in [false,true]:
		guard.set_elder(age)
		var sk := guard.skeleton
		var mesh := guard.model.find_children("*","MeshInstance3D",true,false)[0] as MeshInstance3D
		var arrays := []
		for i in mesh.mesh.get_surface_count():
			if mesh.mesh.surface_get_material(i).resource_name.get_slice(".",0) == "ribbon":
				arrays = mesh.mesh.surface_get_arrays(i)
		if arrays.is_empty() or mesh.skin == null:
			push_error("Missing bound ribbon geometry")
			quit(1)
			return
		for yaw in [0.0,1.2,PI,4.7]:
			for wind in winds:
				guard.reset()
				guard.rotation.y = yaw
				guard.start(Vector2(800,380), Vector3(5.0, 4.5, -80.0))
				for frame in 11:
					guard.tick(.078, float(frame)*.163, wind)
					_scan(sk, mesh.skin, arrays)
	if count > 20000 and closest < -.34 and max_anchor_shift < .0001:
		print("REAR_RIBBON_OK: %d vertex samples; nearest head-projected z=%.4f; fixed knot residual=%.8f" % [count,closest,max_anchor_shift])
		quit()
	else:
		push_error("Rear ribbon check failed: %s, %.8f, %.8f" % [count,closest,max_anchor_shift])
		quit(1)
