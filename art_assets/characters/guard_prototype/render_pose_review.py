"""Optional Blender CPU pose review from Godot smoke JSON, not gameplay screenshots."""
import bpy, json, sys, math
from pathlib import Path
from mathutils import Vector, Matrix

args=sys.argv[sys.argv.index('--')+1:]
poses=json.loads(Path(args[0]).read_text())
out=Path(args[1]); out.mkdir(parents=True, exist_ok=True)
basis=Matrix(((1,0,0),(0,0,-1),(0,1,0))).to_4x4()
def matrix(row):
    p,x,y,z=row
    m=Matrix((x,y,z)).transposed().to_4x4()
    m.translation=Vector(p); return m

def material(name,col):
    m=bpy.data.materials.new(name); m.diffuse_color=(*col,1)
    return m

def track(obj,p):
    obj.rotation_euler=(Vector(p)-obj.location).to_track_quat('-Z','Y').to_euler()

def view(label, pose):
    src=Path(__file__).resolve().parent/('elder_guard.blend' if label.startswith('elder') else 'young_guard.blend')
    bpy.ops.wm.open_mainfile(filepath=str(src))
    rig=[o for o in bpy.context.scene.objects if o.type=='ARMATURE'][0]
    for name in ['Hips','Spine','Chest','Neck','Head']+[b.name for b in rig.pose.bones if b.name not in ['Hips','Spine','Chest','Neck','Head']]:
        b=rig.pose.bones[name]
        local,rest=pose['bones'][name]
        final=basis @ matrix(local) @ matrix(rest).inverted() @ basis.inverted() @ b.bone.matrix_local
        b.matrix=final; bpy.context.view_layer.update()
    inks=[material('Bow wood',(.16,.065,.033)),material('Warm string',(.83,.63,.40)),material('Arrow',(.72,.42,.17))]
    for i,(x,y) in enumerate(pose['segments']):
        a,b=basis@Vector(x),basis@Vector(y); d=b-a
        bpy.ops.mesh.primitive_cylinder_add(vertices=8,radius=.045 if i<6 else .025,depth=d.length,location=(a+b)*.5)
        bpy.context.object.rotation_euler=d.to_track_quat('Z','Y').to_euler()
        bpy.context.object.data.materials.append(inks[min(max(i-5,0),2)])
    cam=bpy.data.objects.new('Pose review',bpy.data.cameras.new('Orthographic')); bpy.context.collection.objects.link(cam)
    cam.location=(-10,-16,7.9)
    track(cam,(0,-.55,3.36))
    cam.data.type='ORTHO'; cam.data.ortho_scale=8.65
    sc=bpy.context.scene; sc.camera=cam
    sc.render.engine='BLENDER_WORKBENCH'
    sc.display.shading.light='STUDIO'; sc.display.shading.color_type='MATERIAL'
    sc.display.shading.show_cavity=True
    sc.display.shading.cavity_type='WORLD'
    sc.display.shading.show_shadows=False
    sc.display.shading.show_specular_highlight=False
    sc.display.shading.background_type='WORLD'
    sc.world.color=(.115,.125,.133)
    sc.view_settings.view_transform='Standard'
    sc.render.resolution_x=380;sc.render.resolution_y=420;sc.render.resolution_percentage=100
    sc.render.filepath=str(out/(label+'.png'))
    bpy.ops.render.render(write_still=True)
for k,v in poses.items(): view(k,v)
