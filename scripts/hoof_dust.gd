extends Node3D
## Depth-aware procedural wake. Rebuilt from absolute timeline, not delta emissions:
## scrubbing back and re-playing the same frame reproduces exactly the same plumes.
const ROUTE = preload("res://scripts/desert_route.gd")
const TERRAIN = preload("res://scripts/desert_terrain.gd")
const SHADER = preload("res://shaders/hoof_dust.gdshader")
const FOV_TAN = 0.3939104756
const TOUCHDOWN = 2.58
const ROUTE_OFFSET = 3.66
const SPACING = 0.145
const POOL = 32
var particles: Array[MeshInstance3D] = []

func _ready() -> void:
	var plane := QuadMesh.new()
	plane.size = Vector2(2.0, 2.0)
	for i in POOL:
		var node := MeshInstance3D.new()
		node.mesh = plane
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := ShaderMaterial.new()
		material.shader = SHADER
		material.render_priority = 8
		node.material_override = material
		node.visible = false
		particles.append(node)
		add_child(node)

func update_dust(t: float, phase: float, sand: float, aspect: float, enabled: bool) -> void:
	var count := 0
	if enabled:
		var first: int = maxi(0, ceili((t - 0.34 - 2.8) / SPACING))
		var last: int = floori((minf(t, 13.85 + ROUTE_OFFSET) - 0.34) / SPACING)
		for i in range(first, last + 1):
			var born := 0.34 + i * SPACING
			var age := t - born
			if born < 3.53 or age < 0.0 or age > 2.8:
				continue
			var pose: Dictionary = ROUTE.pose(born, aspect)
			var at: Vector3 = pose.position
			var z: float = pose.depth
			var jitter := sin(i * 11.773 + 0.3)
			var span := (5.5 + age * 7.2) * (1.0 + 0.27 * jitter) * (0.39 + 0.61 * smoothstep(45.0, 210.0, z))
			var size := span / (2.0 * z * FOV_TAN)
			var wind := age * (0.008 + 0.004 * (jitter + 1.0)) * (0.77 + 0.23 * sin(phase * 0.58 + age))
			var x := 0.5 + at.x / (2.0 * z * FOV_TAN * aspect) + ((i % 3) - 1.0) * size * 0.18 + wind
			var base := 0.5 + at.y / (2.0 * z * FOV_TAN)
			if pose.layer >= 0:
				base = TERRAIN.height_uv(pose.layer, x, z)
			var y := base + size * (0.15 + age * 0.15) + 0.001
			var alpha := smoothstep(0.0, 0.20, age) * (1.0 - smoothstep(0.46, 2.8, age))
			alpha *= (0.64 + 0.36 * (0.5 + 0.5 * jitter)) * (1.0 - smoothstep(14.75 + ROUTE_OFFSET, 18.9, t))
			if _place(count, x, y, z, span, alpha, 0.07 + jitter * 0.13, i * 3.09, phase, sand, aspect):
				count += 1
		for i in 9:
			var age := t - (TOUCHDOWN + i * 0.028)
			if age < 0.0 or age > 1.6:
				continue
			var spread := 1.0 - exp(-age * 2.8)
			var z := 565.0 - 0.14 - i * 0.25 - 1.28 * spread
			var direction := (i - 4.0) / 4.0
			var span := 2.55 + i * 0.16 + age * 6.3
			var x := 0.504 + direction * (0.001 + 0.0047 * spread) + age * 0.003
			var y := TERRAIN.height_uv(0, x, z) + span / (2.0 * z * FOV_TAN) * (0.15 + 0.41 * smoothstep(0.0, 0.30, age))
			var alpha := smoothstep(0.0, 0.105, age) * (1.0 - smoothstep(0.27, 1.6, age)) * 0.82
			if _place(count, x, y, z, span, alpha, direction * 0.23, 301 + i * 7.1, phase, sand, aspect):
				count += 1
	for i in range(count, particles.size()):
		particles[i].visible = false

func _place(index: int, x: float, y: float, depth: float, span: float, alpha: float, tilt: float, seed: float, phase: float, sand: float, aspect: float) -> bool:
	var sheet := 0.47 + 0.53 * (0.5 + 0.5 * sin(phase * 0.75 - x * 15.0 + y * 12.0))
	var transmission := exp(-depth * (0.39 + 1.45 * sand) / 302.0 - sand * sheet * 0.52)
	var opacity := minf(0.96, alpha * transmission * 2.10)
	if opacity < 0.002 or index >= particles.size():
		return false
	var node := particles[index]
	node.position = Vector3((2.0 * x - 1.0) * depth * FOV_TAN * aspect, (2.0 * y - 1.0) * depth * FOV_TAN, -depth)
	node.scale = Vector3(span, span * 0.35, 1.0)
	node.rotation.z = tilt
	var material := node.material_override as ShaderMaterial
	material.set_shader_parameter("opacity", opacity)
	material.set_shader_parameter("seed", seed)
	material.set_shader_parameter("drift", phase)
	node.visible = true
	return true
