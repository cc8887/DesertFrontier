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
	# Each damaged run is one packed-earth mass with a broken crest, not a
	# row of individual blocks. Keep the archer's firing bay open.
	_eroded_run(st, -30.90, 2.12, [
		Vector2(-28.6,1.56),Vector2(-25.8,1.78),Vector2(-23.2,1.33),
		Vector2(-21.7,1.28),Vector2(-20.4,2.26),Vector2(-18.9,2.18),
		Vector2(-17.1,1.29),Vector2(-15.7,1.37),Vector2(-14.1,1.02),
		Vector2(-12.95,.42)])
	_eroded_run(st, -30.76, 2.00, [
		Vector2(-4.25,.20),Vector2(-3.27,.62),Vector2(-2.33,.81),
		Vector2(-1.3,.89),Vector2(-.32,1.61),Vector2(.73,1.65),
		Vector2(1.54,1.16)])
	# A low continuous shoulder near the camera rather than scattered debris.
	_eroded_run(st, -16.55, 1.51, [
		Vector2(-25.0,.43),Vector2(-23.7,.67),Vector2(-21.1,.76),
		Vector2(-19.0,.53),Vector2(-16.9,.62),Vector2(-15.1,.27),
		Vector2(-14.0,.10)])
	_block(st, rng, Vector3(.48,WALK_Y-2.50,-23.3), Vector2(5.8,12.0), 17.0,.52,true)
	_block(st, rng, Vector3(2.87,WALK_Y-4.42,-24.9), Vector2(4.8,7.2), 15.0,.46,true)
	# Left bastion and its long, lower tail. Weathering reads on the crest
	# and in horizontal layers, not as a stack of loose masonry.
	_block(st, rng, Vector3(-25.3,WALK_Y+2.13,-34.9),Vector2(10.6,10.4),26.0,.42)
	_eroded_run(st, -36.8, 2.6, [
		Vector2(-30.45,2.20),Vector2(-29.0,2.90),Vector2(-27.2,2.74),
		Vector2(-25.5,2.72),Vector2(-23.7,2.32),Vector2(-21.1,2.18)])
	for i in 8:
		var x := -28.0 - float(i) * 1.1
		var z := -39.9 - float(i) * 5.0
		var y := WALK_Y + 1.34 - float(i) * .68
		_block(st, rng, Vector3(x, y, z), Vector2(6.4,6.65), 24.0, .34)
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

# Swept clay cross-section. Neighboring triangles share averaged normals on
# the continuous eroded surface; the designed silhouette still stays irregular.
func _eroded_run(st: SurfaceTool, z: float, width: float, profile: Array[Vector2]) -> void:
	var rings: Array[PackedVector3Array] = []
	var vertex_normals: Dictionary = {}
	var faces: Array[PackedVector3Array] = []
	var section := [Vector2(-.54,-.24),Vector2(-.48,.37),
		Vector2(-.36,.79),Vector2(-.21,.98),Vector2(.04,1.02),
		Vector2(.28,.93),Vector2(.43,.66),Vector2(.48,.31),Vector2(.54,-.24)]
	for k in profile.size():
		var point := profile[k]
		var ring := PackedVector3Array()
		var strength := .76 if k == 0 or k == profile.size()-1 else 1.0
		for j in section.size():
			var q: Vector2 = section[j]
			var y := WALK_Y + maxf(.18,point.y)*q.y
			if j == 0 or j == section.size()-1:
				y = WALK_Y - .60
			ring.append(Vector3(point.x,y,z+q.x*width*strength+.13*sin(point.x*.62)))
		rings.append(ring)
	for k in range(rings.size()-1):
		for j in range(section.size()-1):
			var a := rings[k][j]
			var b := rings[k+1][j]
			var c := rings[k][j+1]
			var d := rings[k+1][j+1]
			var q0: Vector2 = section[j]
			var q1: Vector2 = section[j+1]
			var hint := Vector3(0.0, q1.x-q0.x, q0.y-q1.y)
			_add_smooth_face(faces,vertex_normals,a,b,c,hint)
			_add_smooth_face(faces,vertex_normals,c,b,d,hint)
	for end: int in [0,rings.size()-1]:
		var n := Vector3.LEFT if end == 0 else Vector3.RIGHT
		var ring := rings[end]
		var center := ring[4].lerp((ring[0]+ring[-1])*.5,.50)
		for j in ring.size():
			_add_smooth_face(faces,vertex_normals,center,ring[j],ring[(j+1)%ring.size()],n)
	for face in faces:
		for p in face:
			var n: Vector3 = vertex_normals[p]
			st.set_normal(n.normalized())
			st.add_vertex(p)

func _add_smooth_face(faces: Array[PackedVector3Array], normals: Dictionary,
	a: Vector3, b: Vector3, c: Vector3, outside: Vector3) -> void:
	var n := (c-a).cross(b-a)
	if n.dot(outside) < 0.0:
		var tmp := b
		b = c
		c = tmp
		n = -n
	if n.length_squared() < .0000001:
		return
	n = n.normalized()
	faces.append(PackedVector3Array([a,b,c]))
	for p in [a,b,c]:
		normals[p] = normals.get(p,Vector3.ZERO) + n

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
