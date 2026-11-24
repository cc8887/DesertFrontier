extends CanvasLayer
## Scene is deliberately fullscreen; the translucent HUD can be hidden with H.
signal seeked(value: float)
signal defense_requested
signal weather_requested
signal playback_requested
signal restart_requested
signal sound_toggled
signal dust_toggled
signal look_changed(key: String, value: float)
const LABELS := {
	"sand": "沙幕浓度", "wind": "风速", "sun": "日轮透出",
	"grain": "沙粒遮罩", "brush": "印象笔触", "sky": "天空扬沙", "relief": "光影强度",
}
var controls: Dictionary = {}
var values: Dictionary = {}
var hud: Control
var timeline: HSlider
var playback: Button
var sound: Button
var dust: Button
var weather: Button
var density_label: Label
var grain_label: Label
var sky_label: Label
var tuning_label: Label
var tuning: PanelContainer
var stage_text: Label
var timer: Label

func _ready() -> void:
	layer = 3
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)

	var theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Noto Sans CJK SC", "PingFang SC", "Microsoft YaHei", "WenQuanYi Zen Hei", "Arial Unicode MS"])
	theme.default_font = font
	theme.default_font_size = 16
	for type: String in ["Label", "Button"]:
		theme.set_color("font_color", type, Color("#fae5bb"))
	var idle := _style(Color("#4b382bbd"), Color("#967955a2"))
	idle.content_margin_left = 12
	idle.content_margin_right = 12
	idle.content_margin_top = 4
	idle.content_margin_bottom = 4
	theme.set_stylebox("normal", "Button", idle)
	for style_name: String in ["hover", "pressed", "hover_pressed"]:
		var highlight := idle.duplicate() as StyleBoxFlat
		highlight.bg_color = Color("#795638e5")
		theme.set_stylebox(style_name, "Button", highlight)
	hud.theme = theme

	var title := Label.new()
	title.text = "大漠边疆   /   黄沙白日"
	title.position = Vector2(30, 18)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("#312620"))
	title.add_theme_color_override("font_shadow_color", Color("#f4deac88"))
	title.add_theme_constant_override("shadow_offset_x", 1)
	title.add_theme_constant_override("shadow_offset_y", 1)
	hud.add_child(title)

	stage_text = Label.new()
	stage_text.position = Vector2(31, 54)
	stage_text.add_theme_color_override("font_color", Color("#432f24"))
	hud.add_child(stage_text)

	var dock := PanelContainer.new()
	hud.add_child(dock)
	dock.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	dock.offset_left = 22
	dock.offset_right = -22
	dock.offset_top = -112
	dock.offset_bottom = -18
	dock.add_theme_stylebox_override("panel", _style(Color("#251e17dd"), Color("#9c7955a2")))
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 7)
	dock.add_child(rows)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	rows.add_child(bar)
	_button(bar, "开始防守").pressed.connect(func() -> void: defense_requested.emit())
	weather = _button(bar, "切换风雪［V］")
	weather.pressed.connect(func() -> void: weather_requested.emit())
	playback = _button(bar, "暂停")
	playback.pressed.connect(func() -> void: playback_requested.emit())
	_button(bar, "从头播放").pressed.connect(func() -> void: restart_requested.emit())
	dust = _button(bar, "关闭尘尾")
	dust.pressed.connect(func() -> void: dust_toggled.emit())
	sound = _button(bar, "开启声音")
	sound.pressed.connect(func() -> void: sound_toggled.emit())
	_button(bar, "场景调色").pressed.connect(func() -> void: tuning.visible = not tuning.visible)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	timer = Label.new()
	bar.add_child(timer)
	timeline = HSlider.new()
	timeline.max_value = 18.9
	timeline.step = 0.05
	timeline.custom_minimum_size.y = 22
	timeline.value_changed.connect(func(v: float) -> void: seeked.emit(v))
	rows.add_child(timeline)

	tuning = PanelContainer.new()
	hud.add_child(tuning)
	tuning.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	tuning.offset_left = -318
	tuning.offset_right = -22
	tuning.offset_top = -188
	tuning.offset_bottom = 176
	tuning.add_theme_stylebox_override("panel", _style(Color("#2a2018ef"), Color("#b58b5cba")))
	var pane := VBoxContainer.new()
	pane.add_theme_constant_override("separation", 7)
	tuning.add_child(pane)
	tuning_label = Label.new()
	tuning_label.text = "沙幕与日轮"
	tuning_label.add_theme_font_size_override("font_size", 21)
	pane.add_child(tuning_label)
	var presets := HBoxContainer.new()
	pane.add_child(presets)
	_button(presets, "晴薄").pressed.connect(func() -> void: _preset(19, 18, 78))
	_button(presets, "黄沙").pressed.connect(func() -> void: _preset(59, 29, 68))
	_button(presets, "浓沙").pressed.connect(func() -> void: _preset(89, 54, 56))
	for key: String in LABELS:
		var row := HBoxContainer.new()
		pane.add_child(row)
		var label := Label.new()
		label.text = LABELS[key]
		label.custom_minimum_size.x = 73
		row.add_child(label)
		if key == "sand":
			density_label = label
		elif key == "grain":
			grain_label = label
		elif key == "sky":
			sky_label = label
		var slider := HSlider.new()
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.max_value = 100
		slider.step = 1
		row.add_child(slider)
		var number := Label.new()
		number.custom_minimum_size.x = 42
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(number)
		controls[key] = slider
		values[key] = number
		slider.value_changed.connect(_on_slider.bind(key))
	tuning.hide()

func update_weather(snow: bool) -> void:
	weather.text = "切回黄沙［V］" if snow else "切换风雪［V］"
	dust.visible = not snow
	tuning_label.text = "风雪与白日" if snow else "沙幕与日轮"
	density_label.text = "风雪浓度" if snow else LABELS.sand
	grain_label.text = "飘雪强度" if snow else LABELS.grain
	sky_label.text = "云絮遮蔽" if snow else LABELS.sky


func _on_slider(value: float, key: String) -> void:
	values[key].text = "%d%%" % roundi(value)
	look_changed.emit(key, value / 100.0)

func _preset(sand: int, wind: int, sun: int) -> void:
	controls.sand.value = sand
	controls.wind.value = wind
	controls.sun.value = sun

func set_value(key: String, value: float) -> void:
	controls[key].set_value_no_signal(value * 100.0)
	values[key].text = "%d%%" % roundi(value * 100.0)

func update_status(t: float, caption: String, paused: bool, dust_on: bool, sound_on: bool) -> void:
	timeline.set_value_no_signal(t)
	stage_text.text = caption
	timer.text = "%04.1f / 18.9 秒" % t
	playback.text = "播放" if paused else "暂停"
	dust.text = "关闭尘尾" if dust_on else "开启尘尾"
	sound.text = "关闭声音" if sound_on else "开启声音"

func toggle_hud() -> void:
	hud.visible = not hud.visible

func _button(parent: Container, title: String) -> Button:
	var button := Button.new()
	button.text = title
	parent.add_child(button)
	return button

func _style(color: Color, line: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = line
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 9
	style.content_margin_bottom = 9
	return style
