"""Build the decorative DesertFrontier prop. Run with Blender's --background.
Coordinates are visual proportions in game units, not construction data.
"""
import pathlib
import sys

import bpy
from math import cos, sin, tau

root = pathlib.Path(__file__).resolve().parent
if "--" in sys.argv and sys.argv.index("--") + 1 < len(sys.argv):
    root = pathlib.Path(sys.argv[sys.argv.index("--") + 1]).resolve()
root.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)

def material(label, color, rough, metal=0.0):
    mat = bpy.data.materials.new(label)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True
    pbr = mat.node_tree.nodes.get("Principled BSDF")
    pbr.inputs["Base Color"].default_value = (*color, 1.0)
    pbr.inputs["Roughness"].default_value = rough
    pbr.inputs["Metallic"].default_value = metal
    return mat

wood = material("weathered walnut", (0.181, 0.108, 0.063), .91)
wood_facet = material("wood dry grain", (0.236, 0.146, 0.082), .94)
grip = material("soot-brown wrap", (0.078, 0.050, 0.042), .98)
seam = material("muted binding seam", (0.115, 0.080, 0.061), .95)
iron = material("matte blue-gray patina", (0.158, 0.190, 0.192), .72, .23)
iron_face = material("matte lighter facet", (0.197, 0.227, 0.222), .76, .19)
iron_spine = material("matte shadow facet", (0.099, 0.120, 0.125), .78, .20)

def shaped(name, verts, faces, mats, surface):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    for mat in mats:
        obj.data.materials.append(mat)
    for face, slot in zip(mesh.polygons, surface):
        face.material_index = slot
    return obj

def bands(name, profile, mats, sectors=8, accent=(0, 4), center=(0, 0)):
    verts = [(center[0] + r*cos(tau*j/sectors), center[1] + r*sin(tau*j/sectors), z)
             for z, r in profile for j in range(sectors)]
    faces = [tuple(reversed(range(sectors)))]
    mat_slots = [0]
    for i in range(len(profile)-1):
        lo, hi = i*sectors, (i+1)*sectors
        for j in range(sectors):
            k = (j + 1) % sectors
            faces.append((lo+j, lo+k, hi+k, hi+j))
            mat_slots.append(int(len(mats) > 1 and j in accent))
    faces.append(tuple(range(len(verts)-sectors, len(verts))))
    mat_slots.append(0)
    return shaped(name, verts, faces, mats, mat_slots)

shaft = bands("Shaft", [(-0.81,.012),(-.787,.016),(-.19,.017),(.21,.016),(.76,.012),(.82,.011)], (wood,wood_facet), accent=(1,6))
handle_profile = [(-.14, .016), (-.132, .020)]
for i in range(6):
    z = -.120 + i * .043
    handle_profile += [(z,.021), (z+.035,.020), (z+.037,.0188)]
handle_profile += [(.149,.019),(.157,.016)]
handle = bands("Quiet grip bands", handle_profile, (grip,seam), accent=(6,))
collar = bands("Dark socket",[(.732,.013),(.744,.021),(.768,.021),(.774,.0185),(.809,.0185),(.814,.0205),(.846,.020)],(iron,iron_spine),accent=(5,))
# Stylized slim diamond-shaped blade with a raised central ridge, faceted and
# asymmetrical for lighting; the point is an art silhouette, not engineering.
tip_rows = [(.818,.018,.011),(.852,.032,.015),(.902,.043,.014),(.990,.034,.010),(1.075,.018,.006)]
verts = [(x,y,z) for z,w,d in tip_rows for (x,y) in [(w,0),(0,d),(-w,0),(0,-d)]]
verts += [(-.004,0,1.135)]
faces = [(3,2,1,0)]
slots = [0]
for k in range(len(tip_rows)-1):
    for j in range(4):
        i, q = k*4+j, k*4+(j+1)%4
        faces.append((i,q,q+4,i+4))
        slots.append((1,0,2,0)[j])
for j in range(4):
    faces.append((16+j,16+(j+1)%4,20))
    slots.append((1,0,2,0)[j])
blade = shaped("Faceted matte tip", verts, faces,(iron,iron_face,iron_spine),slots)

objs=(shaft,handle,collar,blade)
for obj in objs:
    obj.select_set(True)
    mod=obj.modifiers.new("Export triangles","TRIANGULATE")
    mod.quad_method="FIXED"
bpy.context.view_layer.objects.active=shaft
bpy.context.scene.unit_settings.system='NONE'
bpy.context.scene["asset_note"]="DesertFrontier decorative game prop, hand origin, +Z authoring / +Y glTF."
bpy.ops.wm.save_as_mainfile(filepath=str(root/"frontier_spear.blend"),compress=True)
bpy.ops.export_scene.gltf(filepath=str(root/"frontier_spear.glb"),export_format="GLB",
    export_yup=True,use_selection=True,export_apply=True,export_animations=False,
    export_cameras=False,export_lights=False)
