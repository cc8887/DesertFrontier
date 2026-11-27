extends Node3D
## Defense-only 3D earthen rampart. Broken edges use geometry; rammed lift bands
## and broad surface marks live in world space (no tiling UVs on the modules).
const EARTH := preload("res://shaders/frontier_earthwork.gdshader")
const WALK_Y := -4.43
const GUARD_X := -8.05
const GUARD_Z := -24.0
const WALL_LIGHT_LAYER := 1 << 17
const ARCHER_SHADOW_LAYER := 1 << 16

var material: ShaderMaterial

func _ready() -> void:
	material = ShaderMaterial.new()
	material.shader = EARTH
	var rng := RandomNumberGenerator.new()
	rng.seed = 19073
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# The broad open wall-walk leaves the player and the enemy lane readable.
	_block(st, rng, Vector3(-13.3, WALK_Y, -23.8), Vector2(30.7, 16.2), 23.0, .54, true)
	# The eroded outer parapet, with a wide missing section at the archer's bay.
	for x: float in [-26.8, -23.6, -20.4, -17.2, -14.3, -2.3, .10]:
		_block(st, rng, Vector3(x, WALK_Y + rng.randf_range(.85, 1.34), -30.9),
			Vector2(rng.randf_range(2.35, 3.25), 1.6), 1.85, .37)
	for x: float in [-25.8, -21.6, -17.9, -13.8, .3]:
		_block(st, rng, Vector3(x, WALK_Y + rng.randf_range(2.05, 2.90), -30.95),
			Vector2(rng.randf_range(1.46, 2.0), 1.45), 2.05, .31)
	# Lower remnant along the camera-near rim, kept below the guard's silhouette.
	for x: float in [-23.3, -20.65, -17.8, -14.8]:
		_block(st, rng, Vector3(x, WALK_Y + rng.randf_range(.56, 1.36), -16.45),
			Vector2(2.65, 1.35), 1.68, .34)
	# Lower return at the exposed end, battered and partly buried by the dune.
	_block(st, rng, Vector3(.65,WALK_Y-2.50,-23.3), Vector2(5.6,12.2), 17.0,.82,true)
	_block(st, rng, Vector3(3.05,WALK_Y-4.42,-24.9), Vector2(4.8,7.2), 15.0,.63,true)
	for i in 3:
		_block(st,rng,Vector3(2.65+float(i)*1.15,WALK_Y-1.66-float(i)*.73,-25.4-float(i)*2.0),
			Vector2(1.75,1.64),2.05,.33)
	# Broken bastion at frame left and terraced wall running into the desert.
	_block(st, rng, Vector3(-24.5, WALK_Y + 3.3, -34.0), Vector2(10, 9.2), 26.0, .64)
	for i in 4:
		_block(st, rng, Vector3(-29.0 + i * 2.8, WALK_Y + 4.5 + rng.randf_range(-.4,.45), -37.4),
			Vector2(1.94, 1.6), 2.30, .30)
	for i in 8:
		var x := -28.2 - float(i) * 1.1
		var z := -40.1 - float(i) * 5.0
		var y := WALK_Y + 2.0 - float(i) * .68
		_block(st, rng, Vector3(x, y, z), Vector2(6.2, 5.6), 24.0, .49)
		if i != 2 and i != 6:
			_block(st, rng, Vector3(x + 1.8, y + 1.43, z - .45), Vector2(1.8, 1.94), 2.06, .29)
	# A few larger clay spalls along the rims. Keep the standing/firing area clear.
	for i in 17:
		var side := i % 2
		var x := rng.randf_range(-22.0,-13.6) if side == 0 else rng.randf_range(-2.7,.7)
		var z := rng.randf_range(-30.1,-27.3) if i % 3 != 0 else rng.randf_range(-18.7,-16.25)
		var scale := rng.randf_range(.24,.64)
		_block(st, rng, Vector3(x, WALK_Y + scale * .46, z), Vector2(scale * 1.4, scale), scale, scale * .36)
	var draw := MeshInstance3D.new()
	draw.name = "SculptedRammedEarth"
	draw.mesh = st.commit()
	draw.material_override = material
	draw.layers = 1 | WALL_LIGHT_LAYER
	draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(draw)
	var floor_body := StaticBody3D.new()
	floor_body.name = "RampartWalkCollision"
	var shape_node := CollisionShape3D.new()
	var box := BoxShape3D.new()
	# The usable flat walk only; keep the eroded lips out of this collision slab.
	box.size = Vector3(28.2, .4, 14.5)
	shape_node.shape = box
	shape_node.position = Vector3(-13.3, WALK_Y - .2, -23.8)
	floor_body.add_child(shape_node)
	add_child(floor_body)

func floor_height(_p: Vector3) -> float:
	return WALK_Y

func set_weather(winter: bool, sun_power: float) -> void:
	material.set_shader_parameter("winter", 1.0 if winter else 0.0)
	material.set_shader_parameter("sun_power", sun_power)

func _block(st: SurfaceTool, rng: RandomNumberGenerator, top: Vector3,
	size: Vector2, height: float, chip: float, flat_walk := false) -> void:
	var hx := size.x * .5
	var hz := size.y * .5
	var c := minf(chip, minf(hx,hz) * .45)
	# More than four vertices preserves broken silhouettes at corners and middle bays.
	var footprint := PackedVector2Array([
		Vector2(-hx+c,-hz),Vector2(-hx*.37,-hz),Vector2(hx*.34,-hz),Vector2(hx-c,-hz),Vector2(hx,-hz+c),
		Vector2(hx,-hz*.34),Vector2(hx,hz*.31),Vector2(hx,hz-c),Vector2(hx-c,hz),Vector2(hx*.35,hz),
		Vector2(-hx*.37,hz),Vector2(-hx+c,hz),Vector2(-hx,hz-c),Vector2(-hx,hz*.34),
		Vector2(-hx,-hz*.36),Vector2(-hx,-hz+c)])
	var rings: Array[PackedVector3Array] = []
	for j in 4:
		var band := PackedVector3Array()
		for p in footprint:
			var inset := c * .55 if j == 0 else 0.0
			var width := 1.0 + (.115 if j == 3 else (.043 if j == 2 else 0.0))
			var y := top.y
			match j:
				0: y += 0.0 if flat_walk else rng.randf_range(-c*.37,c*.33)
				1: y -= c * rng.randf_range(.55,.98)
				2: y -= height * rng.randf_range(.24,.39)
				3: y -= height
			band.append(Vector3(top.x+p.x*width-signf(p.x)*inset+rng.randf_range(-c*.25,c*.25),
				y,top.z+p.y*width-signf(p.y)*inset+rng.randf_range(-c*.25,c*.25)))
		rings.append(band)
	for i in footprint.size():
		var n := (i+1)%footprint.size()
		_face(st, top, rings[0][i], rings[0][n], Vector3.UP)
		for j in 3:
			var hint := Vector3(footprint[i].x+footprint[n].x,0,footprint[i].y+footprint[n].y)
			_face(st, rings[j][i],rings[j+1][i],rings[j][n],hint)
			_face(st, rings[j][n],rings[j+1][i],rings[j+1][n],hint)

func _face(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, outside: Vector3) -> void:
	var normal := (c-a).cross(b-a).normalized() # Godot clockwise front.
	if normal.dot(outside) < 0.0:
		var tmp := b
		b = c
		c = tmp
		normal = -normal
	for p in [a,b,c]:
		st.set_normal(normal)
		st.add_vertex(p)
