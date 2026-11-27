extends CanvasLayer
## Lightweight Chinese gameplay overlay. The pointer is the reticle.
signal weather_requested
var weather_button: Button
var info: Label
var tip: Label
var target: ColorRect
var hit_line: Line2D
var hit_time := 0.0
var was_hit := false

func _ready() -> void:
	layer = 4
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Noto Sans CJK SC", "PingFang SC", "Microsoft YaHei", "WenQuanYi Zen Hei", "Arial Unicode MS"])
	var theme := Theme.new()
	theme.default_font = font
	root.theme = theme
	weather_button = Button.new()
	root.add_child(weather_button)
	weather_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	weather_button.offset_left = -173
	weather_button.offset_right = -28
	weather_button.offset_top = 23
	weather_button.offset_bottom = 61
	weather_button.focus_mode = Control.FOCUS_NONE
	weather_button.text = "切换风雪［V］"
	weather_button.pressed.connect(func() -> void: weather_requested.emit())
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)
	panel.position = Vector2(28, 22)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#30231cde")
	style.border_color = Color("#bba07294")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 17
	style.content_margin_right = 17
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 3)
	panel.add_child(box)
	_label(box, "大漠边疆  /  守住前哨", 22)
	info = _label(box, "", 16)
	tip = _label(box, "", 15)
	_label(box, "鼠标瞄准 · 左键出击   |   1 / 2 年轻 / 老年   |   V 风雪   |   R 重开   |   Esc 返回观景", 14)
	hit_line = Line2D.new()
	hit_line.width = 2
	hit_line.visible = false
	root.add_child(hit_line)
	target = ColorRect.new()
	target.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target.size = Vector2(5, 5)
	target.color = Color("#ffe3a0")
	root.add_child(target)
	hide()

func _label(container: Container, line: String, size_px: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = line
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", Color("#f7e2b9"))
	container.add_child(label)
	return label

func update_state(status: String, instruction: String, aim_position: Vector2, delta: float) -> void:
	if info.text != status:
		info.text = status
	if tip.text != instruction:
		tip.text = instruction
	target.position = aim_position - target.size * 0.5
	if hit_time > 0:
		hit_time = maxf(0.0, hit_time - delta)
		hit_line.modulate.a = hit_time / 0.19
		if hit_time == 0:
			hit_line.hide()
	target.color = Color("#d97855") if hit_time > 0 and not was_hit else Color("#ffe3a0")

func effect(p: Vector2, hit: bool, from: Vector2) -> void:
	hit_time = 0.19
	was_hit = hit
	hit_line.points = PackedVector2Array([from, p])
	hit_line.default_color = Color("#ffdf9ddf") if hit else Color("#ead5a0a1")
	hit_line.modulate.a = 1.0
	hit_line.show()

func reset_effect() -> void:
	hit_time = 0.0
	hit_line.hide()

func update_weather(snow: bool) -> void:
	weather_button.text = "切回黄沙［V］" if snow else "切换风雪［V］"
