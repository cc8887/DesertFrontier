extends SceneTree
## Headless checks for physical walk surface, skinned boot seating and lifecycle.
const SCENE = preload("res://scenes/desert.tscn")
const WALL = preload("res://scripts/frontier_earthwork.gd")
const SUN = preload("res://scripts/desert_shadow.gd").SUN
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func expect(ok: bool, label: String) -> void:
	if not ok:
		push_error(label)
		failures += 1

func feet_offsets(guard: Node3D) -> Vector2:
	var min_y := Vector2(INF, INF)
	var sk: Skeleton3D = guard.skeleton
	for part in guard.model.find_children("*", "MeshInstance3D", true, false):
		var skin: Skin = part.skin
		var remap: Array[int] = []
		var matrices: Array[Transform3D] = []
		for b in skin.get_bind_count():
			var bone := skin.get_bind_bone(b)
			if bone < 0:
				bone = sk.find_bone(skin.get_bind_name(b))
			remap.append(bone)
			matrices.append(sk.global_transform * sk.get_bone_global_pose(bone) * skin.get_bind_pose(b))
		for i in part.mesh.get_surface_count():
			if part.mesh.surface_get_material(i).resource_name.get_slice(".",0) != "boot":
				continue
			var a: Array = part.mesh.surface_get_arrays(i)
			var verts: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var joints: PackedInt32Array = a[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
			var width := int(joints.size() / float(verts.size()))
			for v in verts.size():
				var p := Vector3.ZERO
				var side := -1
				for j in width:
					var idx := v * width + j
					var joint := joints[idx]
					p += (matrices[joint]*verts[v])*weights[idx]
					if weights[idx] > .5:
						match sk.get_bone_name(remap[joint]):
							&"Foot.L": side = 0
							&"Foot.R": side = 1
				if side >= 0:
					min_y[side] = minf(min_y[side], p.y - WALL.WALK_Y)
	return min_y

func _run() -> void:
	var scene := SCENE.instantiate()
	root.add_child(scene)
	scene.set_process(false)
	var d: Node = scene.defense
	expect(not d.earthwork.visible and not d.archer_key.visible, "No defense rampart or spotlight in the original observation mode")
	d.begin()
	await physics_frame
	await physics_frame
	expect(d.earthwork.visible and d.archer_key.visible and d.archer_key.shadow_enabled, "Defense must display wall and enable cast shadow")
	expect(d.archer_key.global_basis.z.dot(SUN.normalized()) > .9999, "Guard casts away from the same sun as the terrain")
	var station: Vector3 = d.archer.global_position
	var space: PhysicsDirectSpaceState3D = scene.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(station+Vector3.UP*2.0,station-Vector3.UP*2.0)
	var hit := space.intersect_ray(q)
	expect(not hit.is_empty() and absf(hit.get("position",Vector3.INF).y-WALL.WALK_Y) < .0001, "Physical floor uses the visible walk height")
	for elder in [false,true]:
		d.set_elder(elder)
		var idle := feet_offsets(d.archer)
		expect(idle.is_finite() and idle.abs().x < .012 and idle.abs().y < .012, "Both skinned boot soles sit on the deck: %s" % idle)
		d.shoot_at(Vector2(1060,300))
		for i in 7:
			d.step(.05)
		d.aim_at(Vector2(540,360))
		d.step(.03)
		var aiming := feet_offsets(d.archer)
		expect(aiming.is_equal_approx(idle), "Aiming must preserve physical boot seating")
		print("%s sole offsets above wall: %s" % ["elder" if elder else "young",idle])
		d.begin()
	d.leave()
	expect(not d.earthwork.visible and not d.archer_key.visible, "Returning to observation hides the wall and its caster light")
	if failures == 0:
		print("FRONTIER_WALL_OK: flat receiver, boot seating through aim, sun alignment, defense lifecycle")
	quit(failures)
