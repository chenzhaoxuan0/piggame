"""Authored game finishing of Lux3D meshes: palette, axes, rigs and gate hinges.

Run after process_models.py. This is local Blender postproduction, not an AI
animation claim. Every runtime model faces Godot -Z, with feet/base at Y=0.
The editable .blend, rig clips, GLB and preview are exported together.
"""
import bpy, bmesh, math, sys, json, re, ast
import numpy as np
from pathlib import Path
from mathutils import Vector, Matrix

ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/'assets/models/aholo'
PALETTES=next(ast.literal_eval(n.value) for n in ast.parse((ROOT/'scripts/art/process_models.py').read_text()).body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='PALETTES' for t in n.targets))
YAWS={'CHAR_01':135,'CHAR_02':180,'CHAR_03':180,'CHAR_04':155,'CHAR_05':135,'CHAR_06':180,'CHAR_07':180}
LEG_HEIGHT={'CHAR_01':.31,'CHAR_02':.35,'CHAR_03':.39,'CHAR_04':.27,'CHAR_05':.43,'CHAR_06':.43,'CHAR_07':.48}

def mat(name,color):
 m=bpy.data.materials.new(name);m.use_nodes=True
 rgb=np.array([int(color[i:i+2],16)/255 for i in (0,2,4)])
 linear=np.where(rgb<=.04045,rgb/12.92,((rgb+.055)/1.055)**2.4)
 m.diffuse_color=(*linear,1)
 s=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED');s.inputs['Base Color'].default_value=(*linear,1);s.inputs['Roughness'].default_value=1
 s.inputs['Specular IOR Level'].default_value=0
 return m

def bounds(obj):
 c=[v.co for v in obj.data.vertices]
 return Vector([min(v[i] for v in c) for i in range(3)]),Vector([max(v[i] for v in c) for i in range(3)])

def recenter(obj):
 lo,hi=bounds(obj);center=Vector(((lo.x+hi.x)/2,(lo.y+hi.y)/2,lo.z))
 for v in obj.data.vertices:v.co-=center
 obj.data.update()
 return bounds(obj)

def sphere(name,position,scale,material):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=8,radius=1,location=position)
 o=bpy.context.object;o.name=name;o.scale=scale;o.data.materials.append(material)
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 for p in o.data.polygons:p.use_smooth=True
 return o

def join(parts,active):
 bpy.ops.object.select_all(action='DESELECT')
 for p in parts:p.select_set(True)
 bpy.context.view_layer.objects.active=active;bpy.ops.object.join()

def rebuild_sheep(obj):
 # Turbo produced a folded, nearly legless shell from the rounded illustration.
 # Reconstruct the wool masses and feet to the approved concept, retaining the
 # raw Lux3D export separately and recording this as an authored reconstruction.
 wool=mat('CHAR_04_flat_0','F7F3E8');pink=mat('CHAR_04_flat_2','F3B5BA');hoof=mat('CHAR_04_flat_4','353230')
 parts=[]
 def mass(name,p,s,m):
  bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=1,location=p);o=bpy.context.object;o.name=name;o.scale=s;o.data.materials.append(m)
  bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);parts.append(o)
 mass('WoolBody',(0,-.02,.64),(.65,.70,.47),wool)
 for x,y,z in [(-.42,-.16,.7),(.42,-.16,.7),(-.32,.3,.78),(.32,.3,.78),(0,-.43,.72),(0,0,.92)]:mass('WoolLobe',(x,y,z),(.32,.34,.25),wool)
 mass('Face',(0,.59,.72),(.31,.27,.27),pink)
 mass('Forelock',(0,.54,.96),(.35,.25,.18),wool)
 for sign in [-1,1]:mass('Ear',(sign*.37,.55,.89),(.19,.09,.07),pink)
 for x in [-.36,.36]:
  for y in [-.4,.32]:mass('Hoof',(x,y,.17),(.085,.095,.17),hoof)
 bpy.data.objects.remove(obj,do_unlink=True);obj=parts[0];join(parts,obj);obj.name='CHAR_04'
 bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
 return obj

def finish_colors(obj,a,lo,hi):
 h=hi.z;depth=hi.y-lo.y
 # glTF compacts unused material slots; recover authored IDs from material names.
 original=[]
 for p in obj.data.polygons:
  name=obj.data.materials[p.material_index].name;match=re.search(r'_flat_(\d+)',name)
  original.append(int(match.group(1)) if match else 0)
 obj.data.materials.clear()
 for i,color in enumerate(PALETTES[a]):obj.data.materials.append(mat(a+'_flat_'+str(i),color))
 for p,idx in zip(obj.data.polygons,original):
  c=p.center
  if a=='CHAR_01':idx=5 if c.z<h*.12 else (3 if idx==3 and c.z>h*.7 else 0)
  elif a=='CHAR_02':idx=4 if (c.z>h*.74 and abs(c.x)>hi.x*.23) or c.z<h*.13 else 0
  elif a=='CHAR_03':
   idx=6 if c.z<h*.09 else 0
   if c.y>hi.y*.55 and c.z>h*.77 and abs(c.x)>hi.x*.35:idx=4
  elif a=='CHAR_04':
   idx=4 if c.z<h*.065 else 0
   if c.y>hi.y*.50 and h*.38<c.z<h*.73:idx=2
  elif a=='CHAR_05':
   idx=4 if (idx in [3,4] and (c.z>h*.68 or c.y<lo.y*.65)) or c.z<h*.085 else 0
  elif a=='CHAR_06':
   idx=4 if idx in [3,4] else 0
  elif a=='CHAR_07':
   if c.z>h*.91:idx=7
   elif c.z>h*.77:idx=1
   elif c.z<h*.23:idx=5
   elif c.z<h*.50 and abs(c.x)<hi.x*.65:idx=3
   elif c.z<h*.50:idx=1
   elif abs(c.x)>hi.x*.54:idx=2
   else:idx=3
  elif a=='PROP_07':
   idx=2 if c.z>h*.77 else 0
  elif a=='PROP_05':idx=3 if c.z>h*.55 else 0
  elif a=='PROP_06':
   idx=2 if c.z<h*.42 else (1 if abs(c.x)>hi.x*.82 or c.z>h*.93 or c.z<h*.52 else 0)
  elif a=='PROP_03':idx=3 if idx in [3,4] else 0
  elif a=='PROP_04':idx=3 if idx in [3,4] else 0
  elif a.startswith('ENV_') and a!='ENV_06_TRACTOR':idx=0
  p.material_index=idx
  p.use_smooth=a=='CHAR_01'
 obj.data.update()

def add_eyes(obj,a,lo,hi):
 h=hi.z;eye=mat(a+'_bead_eye','171B19');parts=[obj]
 # Side eyes are cast onto the generated head; the mesh determines lateral position.
 yz={'CHAR_01':(.76,.68),'CHAR_02':(.69,.62),'CHAR_03':(.78,.62),'CHAR_04':(.69,.64),'CHAR_05':(.71,.79),'CHAR_06':(.66,.77),'CHAR_07':(.8,.866)}
 yf,zf=yz[a];y=hi.y*yf;z=h*zf
 if a in ['CHAR_07','CHAR_04']:
  z=h*(.866 if a=='CHAR_07' else .66)
  for x in [-h*.042,h*.042]:
   if a=='CHAR_04':x*=2.5
   hit,loc,n,_=obj.ray_cast(Vector((x,hi.y+2,z)),Vector((0,-1,0)))
   if hit:parts.append(sphere('Eye',loc+n*.012,(h*.013,)*3,eye))
 else:
  for sign in [-1,1]:
   hit,loc,n,_=obj.ray_cast(Vector((sign*(hi.x+2),y,z)),Vector((-sign,0,0)))
   if hit:parts.append(sphere('Eye',loc+n*.012,(h*.018,)*3,eye))
 if a=='CHAR_01':
  pink=mat('Nostril','A96673')
  for x in [-h*.065,h*.065]:
   hit,loc,n,_=obj.ray_cast(Vector((x,hi.y+2,h*.51)),Vector((0,-1,0)))
   if hit:parts.append(sphere('Nostril',loc+n*.009,(h*.018,)*3,pink))
  def number(label,position,sign,size,color):
   bpy.ops.object.text_add(location=position);text=bpy.context.object;text.name='Mark047';text.data.body=label;text.data.align_x='CENTER';text.data.align_y='CENTER';text.data.size=size;text.data.extrude=0;text.data.resolution_u=2
   text.rotation_euler=Matrix(((0,0,sign),(sign,0,0),(0,1,0))).to_euler();text.data.materials.append(color)
   bpy.ops.object.convert(target='MESH');parts.append(bpy.context.object)
  stamp=mat('Farm_stamp','B85D68')
  for sign in [-1,1]:
   hit,loc,n,_=obj.ray_cast(Vector((sign*(hi.x+2),-.18,h*.60)),Vector((-sign,0,0)))
   if hit:
    number('047',loc+n*.014,sign,.09,stamp)
    bpy.ops.mesh.primitive_torus_add(major_segments=24,minor_segments=4,major_radius=.13,minor_radius=.008,location=loc+n*.012,rotation=(0,math.pi/2,0))
    ring=bpy.context.object;ring.data.materials.append(stamp);parts.append(ring)
  tag_faces=[p for p in obj.data.polygons if p.material_index==3]
  if tag_faces:
   center=sum((p.center for p in tag_faces),Vector())/len(tag_faces);sign=1 if center.x>0 else -1
   hit,loc,n,_=obj.ray_cast(Vector((sign*(hi.x+2),center.y,center.z)),Vector((-sign,0,0)))
   if hit:number('047',loc+n*.012,sign,.06,eye)
 if a=='CHAR_05':
  red=mat('Race_medal','BD4943')
  for sign in [-1,1]:
   hit,loc,n,_=obj.ray_cast(Vector((sign*(hi.x+2),hi.y*.18,h*.61)),Vector((-sign,0,0)))
   if hit:parts.append(sphere('Medal',loc+n*.025,(.035,.115,.14),red))
 join(parts,obj)

def make_rig(obj,a,lo,hi):
 h=hi.z;leg_top=h*LEG_HEIGHT[a]
 data=bpy.data.armatures.new(a+'_skeleton');rig=bpy.data.objects.new('Rig',data);bpy.context.collection.objects.link(rig)
 bpy.context.view_layer.objects.active=rig;rig.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
 def bone(name,start,end,parent=None):
  b=data.edit_bones.new(name);b.head=start;b.tail=end
  if parent:b.parent=data.edit_bones[parent]
  return b
 bone('Root',(0,0,0),(0,0,h*.15));bone('Body',(0,0,h*.35),(0,0,h*.65),'Root')
 if a=='CHAR_07':
  bone('Head',(0,0,h*.77),(0,0,h*.96),'Body')
  for s,x in [('L',hi.x*.34),('R',-hi.x*.34)]:bone('Leg'+s,(x,0,leg_top),(x,0,.03),'Body')
  for s,x in [('L',hi.x*.65),('R',-hi.x*.65)]:bone('Arm'+s,(x,0,h*.73),(x*1.2,0,h*.43),'Body')
 else:
  bone('Head',(0,hi.y*.37,h*.57),(0,hi.y*.8,h*.72),'Body')
  bone('Tail',(0,lo.y*.6,h*.55),(0,lo.y*.95,h*.68),'Body')
  for side,signx in [('L',1),('R',-1)]:
   for end,signy in [('F',1),('B',-1)]:
    verts=[v.co for v in obj.data.vertices if v.co.z<leg_top*.6 and v.co.x*signx>0 and v.co.y*signy>0]
    x=float(np.median([v.x for v in verts])) if verts else hi.x*.6*signx
    y=float(np.median([v.y for v in verts])) if verts else (hi.y if signy>0 else lo.y)*.55
    bone('Leg'+side+end,(x,y,leg_top),(x,y,.02),'Body')
 bpy.ops.object.mode_set(mode='OBJECT')
 groups={b.name:obj.vertex_groups.new(name=b.name) for b in data.bones}
 for v in obj.data.vertices:
  c=v.co;weights={'Body':1.0}
  if a=='CHAR_07':
   if c.z<leg_top:
    blend=min(1,(leg_top-c.z)/(h*.07));weights={'LegL' if c.x>0 else 'LegR':blend,'Body':1-blend}
   elif c.z>h*.77:weights={'Head':1}
   elif abs(c.x)>hi.x*.57 and c.z<h*.76:weights={'ArmL' if c.x>0 else 'ArmR':1}
  else:
   if c.z<leg_top:
    b='Leg'+('L' if c.x>0 else 'R')+('F' if c.y>0 else 'B');blend=min(1,(leg_top-c.z)/(h*.10))
    weights={b:blend,'Body':1-blend}
   elif c.y>hi.y*.42 and c.z>h*.38:
    blend=min(1,(c.y-hi.y*.42)/(hi.y*.25));weights={'Head':blend,'Body':1-blend}
   elif c.y<lo.y*.82 and c.z>h*.35:weights={'Tail':.6,'Body':.4}
  for b,w in weights.items():
   if w>0:groups[b].add([v.index],w,'REPLACE')
 obj.parent=rig;mod=obj.modifiers.new('Skin','ARMATURE');mod.object=rig
 rig.animation_data_create();bpy.context.scene.render.fps=24
 for clip,duration,amp in [('idle',2,.018),('walk',1,.35),('run',.6,.55),('celebrate',1.2,.12)]:
  action=bpy.data.actions.new(clip);rig.animation_data.action=action
  end=round(duration*24)+1
  for f in range(1,end+1):
   phase=(f-1)/(end-1)*math.tau
   for pb in rig.pose.bones:
    pb.rotation_mode='XYZ';pb.rotation_euler=(0,0,0);pb.location=(0,0,0)
    if pb.name.startswith('Leg') and clip in ['walk','run']:
     positive=pb.name in ['LegLF','LegRB','LegL'];pb.rotation_euler.x=math.sin(phase+(0 if positive else math.pi))*amp
    elif pb.name.startswith('Arm'):
     pb.rotation_euler.x=math.sin(phase)*(amp if clip in ['walk','run'] else .025)*(1 if pb.name=='ArmL' else -1)
    elif pb.name=='Head':pb.rotation_euler.x=math.sin(phase)*(.08 if clip=='celebrate' else .018)
    elif pb.name=='Tail':pb.rotation_euler.y=math.sin(phase)*.12
    elif pb.name=='Body':pb.location.y=abs(math.sin(phase))*h*(.035 if clip=='run' else .012 if clip=='walk' else .004)
    pb.keyframe_insert(data_path='rotation_euler',frame=f);pb.keyframe_insert(data_path='location',frame=f)
  rig.animation_data.action=None
  track=rig.animation_data.nla_tracks.new();track.name=clip;track.strips.new(clip,1,action)
  track.mute=True
 for pb in rig.pose.bones:pb.rotation_euler=(0,0,0);pb.location=(0,0,0)
 return rig

def split_gate(obj):
 materials=list(obj.data.materials);objects=[]
 for sign,name in [(-1,'GateLeft'),(1,'GateRight')]:
  selected=[p for p in obj.data.polygons if p.center.x*sign>=0]
  indices=sorted({i for p in selected for i in p.vertices});mapping={old:new for new,old in enumerate(indices)}
  pivot=Vector((sign*2.4,0,0));mesh=bpy.data.meshes.new(name+'Mesh')
  mesh.from_pydata([obj.data.vertices[i].co-pivot for i in indices],[],[[mapping[i] for i in p.vertices] for p in selected])
  for m in materials:mesh.materials.append(m)
  for dst,src in zip(mesh.polygons,selected):dst.material_index=src.material_index
  root=bpy.data.objects.new(name,None);root.location=pivot;bpy.context.collection.objects.link(root)
  leaf=bpy.data.objects.new(name+'Mesh',mesh);bpy.context.collection.objects.link(leaf);leaf.parent=root;objects.extend([root,leaf])
 bpy.data.objects.remove(obj,do_unlink=True)
 return objects

def finish(a):
 folder=BASE/a;path=folder/(a+'_game.glb')
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 bpy.ops.import_scene.gltf(filepath=str(path))
 meshes=[o for o in bpy.context.scene.objects if o.type=='MESH'];obj=meshes[0]
 for o in meshes:
  world=o.matrix_world.copy();o.parent=None;o.matrix_world=world
 join(meshes,obj);bpy.ops.object.transform_apply(location=True,rotation=True,scale=True);obj.name=a
 if a=='CHAR_01':
  bm=bmesh.new();bm.from_mesh(obj.data)
  bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.0001)
  bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(obj.data);bm.free()
  for edge in obj.data.edges:edge.use_edge_sharp=False
  soft=obj.modifiers.new('Silhouette polish','SMOOTH');soft.factor=.65;soft.iterations=3
  bpy.ops.object.modifier_apply(modifier=soft.name)
 if a in YAWS:
  rotation=Matrix.Rotation(math.radians(YAWS[a]),3,'Z')
  for v in obj.data.vertices:v.co=rotation@v.co
 if a=='PROP_07':
  coords=np.array([v.co[:] for v in obj.data.vertices]);_,vectors=np.linalg.eigh(np.cov(coords.T));axis=Vector(vectors[:,-1]);axis=-axis if axis.z>0 else axis
  rotation=axis.rotation_difference(Vector((0,0,1)))
  for v in obj.data.vertices:v.co=rotation@v.co
 lo,hi=recenter(obj);size=hi-lo
 if a=='PROP_02':scale=Vector((4.8/size.x,1,2.15/size.z))
 elif a=='PROP_03':scale=Vector((.55/max(size),)*3)
 elif a=='PROP_07':scale=Vector((.65/size.z,)*3)
 elif a=='CHAR_06':scale=Vector((.5/size.x,1,1))
 elif a=='ENV_01_TROUGH':scale=Vector((1.8/size.x,.9/size.y,1))
 elif a=='ENV_06_CRATE':scale=Vector((1/size.x,1/size.y,1))
 elif a=='ENV_06_HAY':scale=Vector((1.7/size.x,1.15/size.y,1))
 else:scale=Vector((1,1,1))
 for v in obj.data.vertices:v.co=Vector([v.co[i]*scale[i] for i in range(3)])
 lo,hi=recenter(obj);obj.data.update()
 # Force current polygon centres after coordinate edits.
 bpy.context.view_layer.update()
 finish_colors(obj,a,lo,hi);rig=None
 if a=='CHAR_04':
  obj=rebuild_sheep(obj);lo,hi=recenter(obj);bpy.context.view_layer.update()
 if a=='PROP_07':
  parts=[obj];gold=mat('Baton_safety_band','FFD600')
  for z in [.14,.24,.34,.44]:
   bpy.ops.mesh.primitive_cylinder_add(vertices=16,radius=.064,depth=.032,location=(0,0,z))
   band=bpy.context.object;band.name='SafetyBand';band.data.materials.append(gold);parts.append(band)
  join(parts,obj)
 if a=='ENV_01_TROUGH':
  # The generated cavity was non-manifold. Rebuild its five stone slabs to the
  # concept silhouette instead of accepting a filled trough or bad boolean.
  stone=obj.data.materials[0];parts=[]
  for dimensions,position in [((1.8,.9,.12),(0,0,.06)),((1.8,.14,.35),(0,.38,.245)),((1.8,.14,.35),(0,-.38,.245)),((.14,.62,.35),(.83,0,.245)),((.14,.62,.35),(-.83,0,.245))]:
   bpy.ops.mesh.primitive_cube_add(size=1,location=position);part=bpy.context.object;part.dimensions=dimensions;part.data.materials.append(stone)
   bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
   bevel=part.modifiers.new('Soft stone edges','BEVEL');bevel.width=.018;bevel.segments=1;bpy.ops.object.modifier_apply(modifier=bevel.name);parts.append(part)
  bpy.data.objects.remove(obj,do_unlink=True);obj=parts[0];join(parts,obj);obj.name=a
 if a.startswith('CHAR_'):
  add_eyes(obj,a,lo,hi);rig=make_rig(obj,a,lo,hi)
 if a=='PROP_02':split_gate(obj)
 objects=[o for o in bpy.context.scene.objects if o.type in ['MESH','ARMATURE','EMPTY']]
 bpy.ops.object.select_all(action='DESELECT')
 for o in objects:o.select_set(True)
 bpy.context.view_layer.objects.active=rig or next(o for o in objects if o.type=='MESH')
 bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_yup=True,export_animations=bool(rig),export_animation_mode='NLA_TRACKS',export_force_sampling=True,export_cameras=False,export_lights=False)
 scene=bpy.context.scene;scene.render.engine='BLENDER_WORKBENCH';scene.view_settings.view_transform='Standard'
 scene.display.shading.light='STUDIO';scene.display.shading.color_type='MATERIAL';scene.display.shading.show_shadows=False
 scene.display.shading.show_cavity=False;scene.display.shading.background_type='WORLD';scene.world.color=(.82,.84,.80)
 scene.render.resolution_x=768;scene.render.resolution_y=768;scene.render.resolution_percentage=100
 coords=[o.matrix_world@Vector(c) for o in objects if o.type=='MESH' for c in o.bound_box]
 low=Vector([min(v[i] for v in coords) for i in range(3)]);high=Vector([max(v[i] for v in coords) for i in range(3)]);center=(low+high)/2;size=max(high-low)
 bpy.ops.object.camera_add();cam=bpy.context.object;cam.location=center+Vector((1.2,1.7,.8))*size;cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=size*1.4;scene.camera=cam
 scene.render.image_settings.file_format='PNG';scene.render.filepath=str(folder/(a+'.png'));bpy.ops.render.render(write_still=True)
 source_dir=folder/'source';source_dir.mkdir(exist_ok=True);(source_dir/'.gdignore').write_text('')
 bpy.context.preferences.filepaths.save_version=0
 bpy.ops.wm.save_as_mainfile(filepath=str(source_dir/(a+'.blend')))
 report=json.loads((folder/'import_report.json').read_text());report.update(triangles=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in objects if o.type=='MESH'),file_bytes=path.stat().st_size,size_godot_xyz=[high.x-low.x,high.z-low.z,high.y-low.y],finishing='Authored palette regions, facing Godot -Z, local Blender postproduction',rig_bones=len(rig.data.bones) if rig else 0,animations=['idle','walk','run','celebrate'] if rig else [],gate_hinges=a=='PROP_02')
 if a=='ENV_01_TROUGH':report['manual_repairs']='Lux3D cavity rejected as non-manifold. Five bevelled stone slabs rebuilt in Blender to original concept and gameplay dimensions.'
 if a=='CHAR_04':report['manual_repairs']='Lux3D folded wool shell and missing feet rejected. Wool lobes, pink face, ears and four hooves reconstructed to approved concept, with an authored eight-bone rig.'
 (folder/'import_report.json').write_text(json.dumps(report,indent=2)+'\n');print('FINALIZED',a,json.dumps(report))

for a in sys.argv[sys.argv.index('--')+1:]:finish(a)
