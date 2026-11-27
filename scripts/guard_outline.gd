extends CanvasLayer
## Project-specific outline: the defense guard is always in the foreground.
## Uses the same live skinned geometry and camera as the gameplay view.
const MASK_LAYER := 1 << 18
const INK = preload("res://shaders/guard_outline.gdshader")
var mask: SubViewport
var mask_camera: Camera3D
var rect: ColorRect
var ink: ShaderMaterial

func setup(main_camera: Camera3D) -> void:
	if DisplayServer.get_name() == "headless":
		return
	# Layer 0 overlays the 3D scene, before the existing snow and gameplay HUD.
	layer = 0
	mask = SubViewport.new()
	mask.transparent_bg = true
	mask.msaa_3d = Viewport.MSAA_DISABLED
	mask.world_3d = main_camera.get_world_3d()
	mask.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(mask)
	mask_camera = Camera3D.new()
	mask_camera.cull_mask = MASK_LAYER
	mask.add_child(mask_camera)
	mask_camera.current = true
	# Explicit transparent clear instead of inheriting the game's background.
	mask_camera.environment = Environment.new()
	mask_camera.environment.background_mode = Environment.BG_CLEAR_COLOR
	rect = ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.hide()
	ink = ShaderMaterial.new()
	ink.shader = INK
	ink.set_shader_parameter("silhouette_tex", mask.get_texture())
	rect.material = ink
	add_child(rect)

func deactivate() -> void:
	if mask != null:
		mask.render_target_update_mode = SubViewport.UPDATE_DISABLED
		rect.hide()

func sync(main_camera: Camera3D, ground: Vector3, height: float) -> void:
	if mask == null:
		return
	var ext := main_camera.get_viewport().get_visible_rect().size
	if ext.x < 2.0 or ext.y < 2.0:
		deactivate()
		return
	# Match the main viewport pixels to keep the thin ink directly on the
	# silhouette. Only the guard is drawn in this isolated mask pass.
	var resolution := Vector2i(ext)
	if mask.size != resolution:
		mask.size = resolution
		ink.set_shader_parameter("radius_uv", Vector2(1.45 * ext.y / (720.0 * ext.x), 1.45 / 720.0))
	mask_camera.global_transform = main_camera.global_transform
	mask_camera.projection = main_camera.projection
	mask_camera.keep_aspect = main_camera.keep_aspect
	mask_camera.fov = main_camera.fov
	mask_camera.size = main_camera.size
	mask_camera.frustum_offset = main_camera.frustum_offset
	mask_camera.h_offset = main_camera.h_offset
	mask_camera.v_offset = main_camera.v_offset
	mask_camera.near = main_camera.near
	mask_camera.far = main_camera.far
	# Bound the shader overdraw to the local silhouette area, allowing its full
	# width (including the single ribbon) and all defense poses.
	var center := main_camera.unproject_position(ground + Vector3.UP * height * .5)
	var height_px := main_camera.unproject_position(ground + Vector3.UP * height).distance_to(main_camera.unproject_position(ground))
	rect.position = (center - Vector2(height_px * 1.11, height_px * .64)).floor()
	rect.size = Vector2(height_px * 2.22, height_px * 1.28).ceil()
	rect.show()
	mask.render_target_update_mode = SubViewport.UPDATE_ALWAYS
