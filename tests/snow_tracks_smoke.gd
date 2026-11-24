extends SceneTree
## godot --headless --path . --script tests/snow_tracks_smoke.gd
const TRACKS = preload("res://scripts/snow_tracks.gd")
const RIDER = preload("res://scripts/mounted_rider.gd")
const ROUTE = preload("res://scripts/desert_route.gd")
const TERRAIN = preload("res://scripts/desert_terrain.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var rider := RIDER.new()
	root.add_child(rider)
	var tracks := TRACKS.new()
	root.add_child(tracks)
	assert(rider.native_ok, "Integration includes the reference GLB")
	tracks.setup_from_rider(rider)
	assert(tracks.native_contacts)
	tracks.update_tracks(1.68, 16.0/9.0, true)
	assert(not tracks.footprints.visible, "No track before first supported gallop step")
	tracks.update_tracks(7.4, 16.0/9.0, false)
	assert(not tracks.footprints.visible, "Baseline sand study must not have snow tracks")
	var now := 16.88
	for ratio in [1.0, 16.0/9.0, 2.2]:
		tracks.update_tracks(now, ratio, true, .88)
		assert(tracks.footprints.visible)
		assert(tracks.pigment.get_shader_parameter("snow_density") == .88)
		assert(tracks.marks.size() < tracks.MAX_MARKS)
		var stamps: Array = tracks.footprints.mesh.surface_get_arrays(0)
		assert((stamps[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() == tracks.marks.size() * 9)
		assert(tracks.marks[0].layer == 0 and tracks.marks[-1].layer == 2)
		var active_far := 0
		var active_near := 0
		for i in range(tracks.marks.size()):
			var step: Dictionary = tracks.marks[i]
			assert(step.layer == 0 or step.layer == 2)
			assert(ROUTE.pose(step.born, ratio).layer == step.layer)
			if step.born < now and now - step.born < tracks.MARK_MAX_AGE:
				if step.layer == 0: active_far += 1
				if step.layer == 2: active_near += 1
			for row in range(i * 9, (i + 1) * 9):
				var vertex: Vector3 = stamps[Mesh.ARRAY_VERTEX][row]
				var displacement := vertex.y - TERRAIN.ground_y(step.layer, vertex.x, -vertex.z, ratio)
				assert(displacement > 0.047 and displacement < 0.113)
				assert(-vertex.z >= TERRAIN.NEAR[step.layer] and -vertex.z <= TERRAIN.FAR[step.layer])
				var data: Color = stamps[Mesh.ARRAY_COLOR][row]
				var code := roundi(data.r * 255.0) * 256 + roundi(data.g * 255.0)
				var delta := float(code) * tracks.CLOCK / 65535.0 - float(step.born)
				assert(delta >= -0.0000001 and delta < 0.000308)
		assert(active_far > 0 and active_near > 0)
		tracks.update_tracks(3.6, ratio, true, .88)
		assert(not tracks.footprints.visible, "A rewind before the gallop clears all visible marks")
		tracks.update_tracks(now, ratio, true, .88)
		assert(tracks.footprints.visible and tracks.footprints.mesh.surface_get_arrays(0) == stamps)
		tracks.update_tracks(40.0, ratio, true, .88)
		assert(not tracks.footprints.visible, "Drift eventually erases all marks")
	print("SNOW_TRACKS_OK: actual gait contacts; far and near drapes at 3 ratios; deterministic rewind, fog response and clean disable.")
	quit()
