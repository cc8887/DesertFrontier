"""Blender background build: produces two height-matched, skinned T-pose guards."""
import bpy, math, sys
from mathutils import Vector
from pathlib import Path

OUT = Path(sys.argv[sys.argv.index('--')+1]).resolve()
OUT.mkdir(parents=True,exist_ok=True)
H=6.7774184
RIBBON_BONES=8
RIBBON_STEPS=48
def pt(v): return Vector(v)*H
def material(name, hex):
    rgb=[int(hex[i:i+2],16)/255 for i in (0,2,4)]
    rgb=[x/12.92 if x<.04045 else ((x+.055)/1.055)**2.4 for x in rgb]
    m=bpy.data.materials.new(name); m.diffuse_color=(*rgb,1)
    m.use_nodes=True
    n=m.node_tree.nodes.get('Principled BSDF')
    n.inputs['Base Color'].default_value=(*rgb,1)
    n.inputs['Roughness'].default_value=.94
    return m

def build(old):
    bpy.ops.object.mode_set(mode='OBJECT') if bpy.context.object and bpy.context.object.mode!='OBJECT' else None
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.armatures, bpy.data.materials):
        for block in list(datablocks):
            if block.users == 0:
                datablocks.remove(block)
    data=bpy.data.armatures.new('GuardRig'); rig=bpy.data.objects.new('GuardRig',data)
    bpy.context.collection.objects.link(rig); rig.select_set(True); bpy.context.view_layer.objects.active=rig
    bpy.ops.object.mode_set(mode='EDIT')
    def bone(n,a,b,parent=None):
        e=data.edit_bones.new(n); e.head,e.tail=pt(a),pt(b)
        if parent: e.parent=data.edit_bones[parent]
    bone('Hips',(0,0,.48),(0,0,.57))
    bone('Spine',(0,0,.57),(0,0,.67),'Hips')
    bone('Chest',(0,0,.67),(0,0,.80),'Spine')
    bone('Neck',(0,0,.80),(0,0,.835),'Chest')
    bone('Head',(0,0,.835),(0,0,1),'Neck')
    for s,x in [('L',1),('R',-1)]:
        for n,a,b,p in [
          ('UpperArm',(.103*x,0,.774),(.239*x,0,.774),'Chest'),
          ('Forearm',(.239*x,0,.774),(.385*x,0,.774),'UpperArm.'+s),
          ('Hand',(.385*x,0,.774),(.476*x,0,.774),'Forearm.'+s),
          ('Thigh',(.052*x,0,.49),(.049*x,0,.289),'Hips'),
          ('Shin',(.049*x,0,.289),(.035*x,0,.08),'Thigh.'+s),
          ('Foot',(.035*x,0,.08),(.035*x,-.075,.035),'Shin.'+s),
        ]: bone(n+'.'+s,a,b,p)
    ribbon=[(-.012,.067,.93),(-.018,.153,.897),(-.018,.243,.850),(-.014,.326,.797),(-.009,.397,.736)]
    # Extend along the bind centreline from the unchanged head attachment;
    # the cross-section and UV extent stay the same.
    ribbon_root = Vector(ribbon[0])
    ribbon = [ribbon_root + (Vector(point) - ribbon_root) * 2.0 for point in ribbon]
    ribbon = [p for a,b in zip(ribbon,ribbon[1:]) for p in (a,a.lerp(b,.5))] + [ribbon[-1]]
    for i,(a,b) in enumerate(zip(ribbon,ribbon[1:])):
        bone(f'Ribbon.{i+1:02}',a,b,'Head' if i==0 else f'Ribbon.{i:02}')
    bpy.ops.object.mode_set(mode='OBJECT')
    pal=dict(red='a54a37', pant='a04b3c' if not old else '49454a',
      ribbon='b4563e' if not old else 'a74937',
      vest='dcc2a4' if not old else '624538', trim='f1d4ad' if not old else 'a78261',
      cloth='514640' if not old else '363338', boot='382d2b', sole='292021',
      skin='c48e6a' if not old else 'a97d64', hair='302823' if not old else 'd0c2ab',
      face='492d2a', lip='91624f', wrap='9e3e2e' if not old else '4b3832', eye='e0cdb4')
    mats={k:material(k,v) for k,v in pal.items()}
    parts=[]
    def bind(obj,name,k,weights):
        obj.name=name
        obj.data.materials.clear(); obj.data.materials.append(mats[k])
        for bn, pairs in weights.items():
            group=obj.vertex_groups.new(name=bn)
            for i,w in pairs:
                if w>0: group.add([i],w,'REPLACE')
        obj.parent=rig
        mod=obj.modifiers.new('GuardSkin','ARMATURE'); mod.object=rig
        parts.append(obj)
        return obj
    def mesh(name,verts,faces,k,bn):
        m=bpy.data.meshes.new(name); m.from_pydata([pt(v) for v in verts],[],faces); m.update()
        o=bpy.data.objects.new(name,m); bpy.context.collection.objects.link(o)
        return bind(o,name,k,{bn:list(enumerate([1]*len(verts)))})
    def blob(name,c,r,k,bn,seg=12,rows=7,tilt=0):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=seg,ring_count=rows)
        obj=bpy.context.object
        for v in obj.data.vertices:
            q=v.co.copy(); q.x*=r[0]; q.y*=r[1]; q.z*=r[2]
            q.x,q.z=q.x*math.cos(tilt)+q.z*math.sin(tilt),q.z*math.cos(tilt)-q.x*math.sin(tilt)
            v.co=pt(q+Vector(c))
        return bind(obj,name,k,{bn:[(i,1) for i in range(len(obj.data.vertices))]})
    def tube(name,profiles,k,bn,axis='z',N=12):
        verts=[]
        for a,b,c,r1,r2 in profiles:
            for j in range(N):
                t=math.tau*j/N
                verts.append((a+r1*math.cos(t),b+r2*math.sin(t),c) if axis=='z' else (a,b+r1*math.cos(t),c+r2*math.sin(t)))
        faces=[tuple(reversed(range(N)))]
        for i in range(len(profiles)-1):
            for j in range(N):
                a=i*N+j; b=i*N+(j+1)%N
                faces.append((a,b,b+N,a+N))
        faces.append(tuple(range(len(verts)-N,len(verts))))
        if axis=='x' and profiles[-1][0]<profiles[0][0]: faces=[tuple(reversed(f)) for f in faces]
        return mesh(name,verts,faces,k,bn)
    blob('Neck',(0,0,.823),(.035,.039,.044),'skin','Neck')
    blob('Face',(0,-.009,.907),(.063,.055,.087),'skin','Head',16,10)
    blob('Jaw',(0,-.027,.865),(.047,.038,.061),'skin','Head')
    for x in [-1,1]:
        blob('Ear',(.061*x,.001,.911),(.013,.015,.023),'skin','Head',8,6)
        blob('Eye',(.024*x,-.058,.92),(.013,.004,.004),'eye','Head',8,5)
        blob('Iris',(.024*x,-.061,.92),(.004,.002,.004),'face','Head',8,5)
        blob('Brow',(.024*x,-.056,.932),(.017,.005,.0045),'hair','Head',8,5,(-.15 if old else .19)*x)
    blob('Nose',(0,-.059,.906),(.012,.015,.021),'skin','Head',8,6)
    if old:
        blob('Silver hair',(0,.014,.946),(.064,.055,.054),'hair','Head',14,8)
        blob('Silver beard',(0,-.043,.854),(.05,.039,.054),'hair','Head',12,7)
        blob('Lower lip',(0,-.078,.875),(.018,.004,.004),'lip','Head')
    else:
        blob('Mouth',(0,-.05,.87),(.017,.008,.004),'lip','Head',8,5)
        tube('Wrapped headcloth',[(0,.007,.929,.062,.055),(0,.008,.949,.067,.061),(0,.013,.978,.058,.052),(0,.014,1,.014,.014)],'wrap','Head',N=16)
    tube('Forehead tie',[(0,.006,.93,.065,.059),(0,.006,.949,.067,.060)],'wrap','Head',N=16)
    blob('Knot',(-.012,.058,.932),(.020,.021,.018),'red','Head')
    # Blend across up to three neighboring bones with a quadratic B-spline.
    # Densify the strip so that the gradual skin deformation is visible.
    vs=[]; fs=[]; weight={f'Ribbon.{i:02}':[] for i in range(1,RIBBON_BONES+1)}
    for j in range(RIBBON_STEPS+1):
        t=j/RIBBON_STEPS
        d=t*RIBBON_BONES; lo=min(RIBBON_BONES-1,int(d))
        p=ribbon[lo].lerp(ribbon[lo+1],d-lo)
        w=.031*(.54+.46*math.sin(math.pi*t))*(1-.84*t**4)
        x=d-.5
        ws={}
        for k in range(math.floor(x)-1,math.floor(x)+3):
            e=abs(x-k)
            v=.75-e*e if e<.5 else .5*max(0,1.5-e)**2
            n=f'Ribbon.{max(0,min(RIBBON_BONES-1,k))+1:02}'
            ws[n]=ws.get(n,0)+v
        for off in (-w,w):
            idx=len(vs); vs.append(p+Vector((.69*off,.39*off,.60*off)))
            for n,v in ws.items():
                if v>0: weight[n].append((idx,v))
        if j: fs.append((2*j-2,2*j-1,2*j+1,2*j))
    ob=mesh('Single wind ribbon',vs,fs,'ribbon','Ribbon.01')
    ob.vertex_groups.clear()
    for n,pairs in weight.items():
        g=ob.vertex_groups.new(name=n)
        for idx,w in pairs:
            if w>0: g.add([idx],w,'REPLACE')
    tube('Lambskin vest chest',[(0,0,.62,.092,.055),(0,0,.68,.115,.063),(0,.003,.754,.122,.067),(0,.005,.805,.098,.056),(0,.005,.825,.046,.043)],'vest','Chest')
    # Keep the base tunic continuous under the short older vest.
    tube('Wool tunic and waist',[(0,0,.479,.092,.054),(0,0,.53,.099,.067),(0,0,.61,.085,.049),(0,0,.665,.092,.055)],'cloth','Hips')
    hem=.54 if old else .477
    tube('Lambskin lower vest',[(0,0,hem,.126 if not old else .11,.067),(0,0,.592,.091,.051),(0,0,.657,.097,.057)],'vest','Spine')
    tube('Fleece hem',[(0,0,hem-.004,.128 if not old else .112,.071),(0,0,hem+.015,.129 if not old else .113,.073)],'trim','Spine')
    tube('Red sash',[(0,0,.608,.093,.053),(0,0,.645,.099,.06)],'red','Spine')
    mesh('Crossed fleece facing',[(-.073,-.044,.81),(-.056,-.064,.818),(.064,-.066,.672),(.083,-.058,.686)],[(0,2,3,1)],'trim','Chest')
    for s,x in [('L',1),('R',-1)]:
        tube('Fleece arm hole '+s,[(x*.101,0,.774,.054,.051),(x*.121,0,.774,.054,.051)],'trim','Chest','x')
        tube('Wool upper sleeve '+s,[(x*.106,0,.774,.052,.048),(x*.153,0,.774,.049,.048),(x*.213,0,.774,.044,.044),(x*.243,0,.774,.041,.040)],'cloth','UpperArm.'+s,'x')
        tube('Wool lower sleeve '+s,[(x*.230,0,.774,.042,.04),(x*.251,0,.774,.043,.04),(x*.342,0,.774,.034,.036),(x*.385,0,.774,.027,.029)],'cloth','Forearm.'+s,'x')
        blob('Cuff '+s,(x*.377,0,.774),(.017,.031,.03),'boot','Forearm.'+s)
        blob('Gloveless hand '+s,(x*.42,0,.773),(.056,.028,.017),'skin','Hand.'+s,10,6)
        blob('Thumb '+s,(x*.41,-.019,.765),(.031,.014,.012),'skin','Hand.'+s,8,5)
        tube('Trouser thigh '+s,[(x*.049,0,.273,.048,.052),(x*.049,0,.335,.057,.058),(x*.052,0,.47,.061,.063),(x*.052,0,.514,.061,.055)],'pant','Thigh.'+s)
        tube('Trouser shin '+s,[(x*.039,0,.172,.04,.038),(x*.048,0,.226,.05,.055),(x*.049,0,.31,.049,.052)],'pant','Shin.'+s)
        tube('Boot shaft '+s,[(x*.035,0,.04,.033,.035),(x*.035,0,.19,.037,.039)],'boot','Shin.'+s)
        tube('Boot and sole '+s,[(x*.035,-.018,0,.035,.06),(x*.035,-.021,.009,.035,.062),(x*.035,-.02,.027,.034,.061),(x*.035,-.009,.055,.032,.049),(x*.035,0,.08,.028,.029)],'boot','Foot.'+s)
    # Stable mark coordinates: one binding-space projection, with a dedicated
    # width/length mapping for the ribbon's painted edges.
    for obj in parts:
        uv = obj.data.uv_layers.active or obj.data.uv_layers.new(name='PaintUV')
        uv.name = 'PaintUV'
        for lp in obj.data.loops:
            v = obj.data.vertices[lp.vertex_index].co / H
            uv.data[lp.index].uv = ((lp.vertex_index % 2, lp.vertex_index // 2 / RIBBON_STEPS)
                                   if obj == ob else (v.x+.58*v.y+.5, v.z))
        for poly in obj.data.polygons:
            poly.use_smooth=True
    # A thin fabric edge prevents a long tail from vanishing mid-twist when
    # the flat face is edge-on to the defense camera. This does not widen it.
    bpy.ops.object.select_all(action='DESELECT')
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    edge = ob.modifiers.new('Fabric thickness', 'SOLIDIFY')
    edge.thickness = .052
    edge.offset = 0.0
    ob.modifiers.move(1, 0)
    bpy.ops.object.modifier_apply(modifier=edge.name)
    # Join rigidly weighted pieces into a portable mesh without losing groups.
    bpy.ops.object.select_all(action='DESELECT')
    for obj in parts: obj.select_set(True)
    bpy.context.view_layer.objects.active=parts[0]; bpy.ops.object.join()
    merged=bpy.context.object; merged.name='ElderGuard' if old else 'YoungGuard'
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode='OBJECT')
    rig.show_in_front=True; rig.select_set(True); bpy.context.view_layer.objects.active=rig
    stem='elder_guard' if old else 'young_guard'
    bpy.ops.wm.save_as_mainfile(filepath=str(Path(__file__).resolve().parent/(stem+'.blend')))
    bpy.ops.export_scene.gltf(filepath=str(OUT/(stem+'.glb')),export_format='GLB',
       use_selection=True,export_animations=False,export_yup=True,export_materials='EXPORT')
for age in (False,True): build(age)
