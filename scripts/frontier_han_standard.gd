extends Node3D
## Worn garrison standard: a wind-deformed, double-sided cloth mesh.
const FABRIC = preload("res://shaders/frontier_han_standard.gdshader")
const GLYPH = preload("res://art_assets/props/han_standard/han_glyph.svg")
const WIDTH := 3.68
const HEIGHT := 3.36
const HOIST := 7.10
const HOIST_X := .115
var textile: ShaderMaterial

func _ready() -> void:
	# Local +X follows the same world wind vector that drives the guard ribbon.
	var span := Vector3(-1.0,0.0,.26).normalized()
	basis = Basis(span,Vector3.UP,span.cross(Vector3.UP))
	var wood := _ink(Color("#60392b"))
	var bronze := _ink(Color("#9f7445"))
	var brass := _ink(Color("#c79555"))
	_pin(_cylinder(.088,.130,HOIST+.24), Vector3(0.0,(HOIST+.18)*.5,0.0),wood)
	_pin(_cylinder(.24,.32,.28),Vector3(0.0,.10,0.0),bronze)
	_pin(_cylinder(.145,.145,.16),Vector3(0.0,HOIST+.11,0.0),bronze)
	_pin(_cylinder(0.0,.20,.48,4),Vector3(0.0,HOIST+.41,0.0),brass)
	for y in [HOIST-.12,HOIST-.52,HOIST-HEIGHT+.15]:
		_pin(_cylinder(.139,.139,.10),Vector3(0.0,y,0.0),brass)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in 28:
		for y in 12:
			var a := Vector2(float(x)/28.0,float(y)/12.0)
			var b := Vector2(float(x+1)/28.0,a.y)
			var c := Vector2(a.x,float(y+1)/12.0)
			var d := Vector2(b.x,c.y)
			for uv: Vector2 in [a,b,c,c,b,d]:
				# Notched end and slightly wandering hem. The lettering follows the cloth.
				var notch := (1.0-absf(uv.y*2.0-1.0))*.21
				var tail := uv.x*uv.x*notch
				var hem := .13*sin(uv.x*PI)*sin(uv.x*5.9+uv.y*2.4)
				st.set_uv(uv)
				st.add_vertex(Vector3(HOIST_X+(uv.x-tail)*WIDTH,HOIST-uv.y*HEIGHT+hem,0.0))
	textile = ShaderMaterial.new()
	textile.shader = FABRIC
	textile.set_shader_parameter("glyph",GLYPH)
	var cloth := _pin(st.commit(),Vector3.ZERO,textile)
	cloth.name = "SwallowtailCloth"
	cloth.extra_cull_margin = 1.5

func pose(phase: float, strength: float, snow: bool) -> void:
	textile.set_shader_parameter("wind_phase",phase)
	textile.set_shader_parameter("wind_strength",strength)
	textile.set_shader_parameter("winter",1.0 if snow else 0.0)

func _cylinder(top: float, bottom: float, height: float, sides := 10) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 0
	return mesh

func _ink(pigment: Color) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = "shader_type spatial; render_mode unshaded; uniform vec4 pigment : source_color; void fragment(){ ALBEDO = pigment.rgb * (.78+.22*max(0.0,dot(normalize(NORMAL),normalize(vec3(-.6,.54,.65))))); }"
	var material := ShaderMaterial.new()
	material.shader = sh
	material.set_shader_parameter("pigment",pigment)
	return material

func _pin(mesh: Mesh, where: Vector3, material: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.position = where
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(part)
	return part
