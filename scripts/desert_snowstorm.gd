extends CanvasLayer
## Wind veil over the terrain and guard, below the HUDs.
const SNOW = preload("res://shaders/snowstorm.gdshader")
var storm: ShaderMaterial

func _ready() -> void:
	layer = 1
	var screen := ColorRect.new()
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
	storm = ShaderMaterial.new()
	storm.shader = SNOW
	screen.material = storm
	hide()

func update_storm(snow: bool, phase: float, density: float, intensity: float, aspect: float, gust := 0.0) -> void:
	visible = snow or gust > 0.002
	if visible:
		storm.set_shader_parameter("uPhase", phase)
		storm.set_shader_parameter("uDensity", density)
		storm.set_shader_parameter("uSize", intensity)
		storm.set_shader_parameter("uAspect", aspect)
		storm.set_shader_parameter("uGust", gust)
		storm.set_shader_parameter("uIsSnow", snow)
