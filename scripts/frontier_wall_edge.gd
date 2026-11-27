extends CanvasLayer
## Painterly transition across only the visible wall boundary.
const EDGE = preload("res://shaders/frontier_wall_edge.gdshader")
const MASK = preload("res://shaders/frontier_wall_edge_mask.gdshader")
var mask: SubViewport
var camera: Camera3D
var rect: ColorRect
var ink: ShaderMaterial
var front_dunes: Array[MeshInstance3D] = []
var proxies: Array[MeshInstance3D] = []
var last_camera := PackedFloat32Array()
var running := false
var radius_at_720 := 6.4

func setup(wall: MeshInstance3D, terrain: Node3D, guard_mask: SubViewport) -> void:
	if guard_mask == null:
		return
	layer = -1 # After the 3D scene, before the guard outline, snow and HUD.
	mask = SubViewport.new()
	mask.own_world_3d = true
	mask.transparent_bg = true
	mask.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(mask)
	camera = Camera3D.new()
	camera.current = true
	mask.add_child(camera)
	# Copy only mesh references, never painter material, lights or shadows.
	var proxy := MeshInstance3D.new()
	proxy.mesh = wall.mesh
	proxy.material_override = ShaderMaterial.new()
	proxy.material_override.shader = MASK
	proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mask.add_child(proxy)
	proxy.transform = wall.global_transform
	var dune_mat := ShaderMaterial.new()
	dune_mat.shader = MASK
	dune_mat.set_shader_parameter("wall",false)
	for i in [1,2]:
		var dune_proxy := MeshInstance3D.new()
		dune_proxy.material_override = dune_mat
		dune_proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mask.add_child(dune_proxy)
		proxies.append(dune_proxy)
		front_dunes.append(null)
	rect = ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.hide()
	ink = ShaderMaterial.new()
	ink.shader = EDGE
	ink.set_shader_parameter("wall_tex",mask.get_texture())
	ink.set_shader_parameter("guard_tex",guard_mask.get_texture())
	rect.material = ink
	add_child(rect)
	_refresh_dunes(terrain)

func _refresh_dunes(terrain: Node3D) -> bool:
	var changed := false
	for i in proxies.size():
		var dune := terrain.get_node_or_null("DuneRibbon%d" % (i+1)) as MeshInstance3D
		if dune != front_dunes[i] or (dune != null and dune.mesh != proxies[i].mesh):
			front_dunes[i] = dune
			proxies[i].mesh = dune.mesh if dune != null else null
			if dune != null: proxies[i].transform = dune.global_transform
			changed = true
	return changed

func deactivate() -> void:
	running = false
	if rect != null:
		rect.hide()
		mask.render_target_update_mode = SubViewport.UPDATE_DISABLED

func sync(main: Camera3D, terrain: Node3D, wall: MeshInstance3D) -> void:
	if rect == null:
		return
	var size := main.get_viewport().get_visible_rect().size
	if size.x < 2 or size.y < 2:
		deactivate()
		return
	ink.set_shader_parameter("edge_radius", radius_at_720 * size.y / 720.0)
	var had_change := _refresh_dunes(terrain)
	var key := PackedFloat32Array([main.fov,main.near,main.far,main.h_offset,main.v_offset,main.size,
		main.frustum_offset.x,main.frustum_offset.y,main.keep_aspect,main.projection])
	if not running or mask.size != Vector2i(size) or camera.global_transform != main.global_transform or key != last_camera or had_change:
		mask.size = Vector2i(size)
		camera.global_transform = main.global_transform
		camera.keep_aspect = main.keep_aspect
		camera.projection = main.projection
		camera.fov = main.fov
		camera.near = main.near
		camera.far = main.far
		camera.size = main.size
		camera.frustum_offset = main.frustum_offset
		camera.h_offset = main.h_offset
		camera.v_offset = main.v_offset
		last_camera = key
		# Restrict work to the projected wall's bounds. The mask is static on
		# the gameplay camera and only re-renders when its geometry or view changes.
		var bounds := wall.get_aabb()
		var lo := size
		var hi := Vector2.ZERO
		for n in 8:
			var p := wall.to_global(bounds.get_endpoint(n))
			var q := main.unproject_position(p)
			lo = lo.min(q)
			hi = hi.max(q)
		rect.position = (lo - Vector2.ONE*12).floor().max(Vector2.ZERO)
		rect.size = (hi + Vector2.ONE*12).ceil().min(size) - rect.position
		mask.render_target_update_mode = SubViewport.UPDATE_ONCE
		rect.show()
		running = true
