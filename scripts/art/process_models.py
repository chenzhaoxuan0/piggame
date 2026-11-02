"""Run with Blender --background --factory-startup --python this.py -- ASSET_ID ...
Convert Lux3D exports into grounded, metre-scaled, flat palette game meshes.
Raw exports remain intact. Runtime GLBs contain no lights/cameras/collision.
"""
import bpy
import json
import math
import sys
from pathlib import Path
from mathutils import Vector
import numpy as np
import bmesh

ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/'assets/models/aholo'
HEIGHTS={'CHAR_01':1.08,'CHAR_02':1.6,'CHAR_03':1.8,'CHAR_04':1.12,'CHAR_05':2.25,'CHAR_06':1.05,'CHAR_07':1.95,'PROP_01':4.3,'PROP_02':1.8,'PROP_03':0.16,'PROP_04':1.5,'PROP_05':0.42,'PROP_06':2.0,'PROP_07':0.65}
HEIGHTS.update(ENV_01_TROUGH=.42,ENV_06_HAY=.9,ENV_06_CRATE=1.0,ENV_06_TRACTOR=2.2)
PALETTES={
 'ENV_01_TROUGH':['9BA3A3','C1C6C2','767E7E'],
 'ENV_06_HAY':['E3BD57','CDA23F','F1CF75'],
 'ENV_06_CRATE':['AA8658','C19C6B','896E4C'],
 'ENV_06_TRACTOR':['4C793C','709454','2D522B','353937','E4BE56','BBC8C1'],
 'PROP_01':['B98850','D6A66A','946333','E3BD87','40464D','697079','CDA04C'],
 'PROP_02':['343A40','5A6269','22272C','E9B747','8B692F'],
 'PROP_03':['B85D3D','D4885A','7D422C','52B788','387F64'],
 'PROP_04':['A5A59F','CBCBC2','82857F','4E555B','343A40'],
 'PROP_05':['E0C097','F0D9B4','B08D60','D7CCC8','212121'],
 'PROP_06':['FFFFFF','2D5A27','A1887F','D3B18B','1E1E1E'],
 'PROP_07':['212121','FFD600','78909C','454B53','E4E6DD'],
 'CHAR_01':['F7C5C8','E7A3AE','D68796','FCD34D','B34F55','332E2C','836D60'],
 'CHAR_02':['CACBC4','E2E3D9','A3A79F','71746E','373A3B','212121','D5C6A6'],
 'CHAR_03':['865B3A','A4754C','65442E','C9AA7E','E2D5B8','342B25','171B19'],
 'CHAR_04':['F7F3E8','DFDFD5','F3B5BA','D6939D','353230','171B19'],
 'CHAR_05':['844830','A4603C','603525','322B25','1E2220','BD4943','E4D2A6'],
 'CHAR_06':['BA8A52','D0A470','8B643F','353631','1D2524','BD7E76'],
 'CHAR_07':['D1A968','E2BB8E','BA8C4A','637E92','415B71','345744','253D32','6F6A50','292C2D'],
}

def material(name, rgb):
 rgb=np.where(np.array(rgb)<=0.04045,np.array(rgb)/12.92,((np.array(rgb)+0.055)/1.055)**2.4)
 m=bpy.data.materials.new(name);m.diffuse_color=(*rgb,1);m.use_nodes=True
 shader=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
 shader.inputs['Base Color'].default_value=(*rgb,1);shader.inputs['Roughness'].default_value=1
 if 'Specular IOR Level' in shader.inputs: shader.inputs['Specular IOR Level'].default_value=0
 return m

def process(asset_id):
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 folder=BASE/asset_id
 bpy.ops.import_scene.gltf(filepath=str(folder/(asset_id+'.glb')))
 meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
 if not meshes: raise RuntimeError('No meshes: '+asset_id)
 raw_triangles=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes)
 # Apply the complete imported transform before changing origins or reducing geometry.
 for obj in meshes:
  world=obj.matrix_world.copy();obj.parent=None;obj.matrix_world=world
 bpy.ops.object.select_all(action='DESELECT')
 for obj in meshes: obj.select_set(True)
 bpy.context.view_layer.objects.active=meshes[0]
 bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
 bpy.ops.object.join();obj=bpy.context.object;obj.name=asset_id
 # Generated GLBs split UV seams into duplicate vertices. Weld before reduction
 # so decimation preserves the connected silhouette instead of collapsing shards.
 if asset_id=='CHAR_01':
  bm=bmesh.new();bm.from_mesh(obj.data)
  bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00001)
  bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(obj.data);bm.free()
  obj.data.validate(clean_customdata=False);obj.data.update()
 limit=6000 if asset_id.startswith('CHAR') else 4000
 if raw_triangles>limit:
  dec=obj.modifiers.new('Game silhouette reduction','DECIMATE');dec.ratio=limit/raw_triangles
  bpy.ops.object.modifier_apply(modifier=dec.name)
 # Sample source UV albedo at each face, then map to the authored solid palette.
 # This removes baked shadows, PBR noise and texture dependencies from runtime assets.
 palette=np.array([[int(h[i:i+2],16)/255 for i in (0,2,4)] for h in PALETTES[asset_id]])
 source_materials=list(obj.data.materials)
 texture_cache={}
 for index,mat in enumerate(source_materials):
  if not mat or not mat.use_nodes: continue
  shader=next((n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None)
  image=None
  if shader and shader.inputs['Base Color'].is_linked:
   source=shader.inputs['Base Color'].links[0].from_node
   if source.type=='TEX_IMAGE': image=source.image
  if image:
   pixels=np.empty(len(image.pixels),dtype=np.float32);image.pixels.foreach_get(pixels)
   texture_cache[index]=(pixels.reshape(image.size[1],image.size[0],4),image.size[:])
 assignments=[];uvs=obj.data.uv_layers.active
 for poly in obj.data.polygons:
  if poly.material_index in texture_cache and uvs:
   pixels,(w,h)=texture_cache[poly.material_index]
   uv=sum((uvs.data[i].uv for i in poly.loop_indices),Vector((0,0)))/len(poly.loop_indices)
   rgb=pixels[min(h-1,max(0,int(uv.y*h))),min(w-1,max(0,int(uv.x*w))),:3]
  else:
   mat=source_materials[poly.material_index] if source_materials else None
   rgb=np.array(mat.diffuse_color[:3] if mat else (0.6,0.5,0.4))
  # Chromaticity and value both matter; nearest palette is deterministic.
  rgb=np.where(rgb<=0.0031308,12.92*rgb,1.055*np.maximum(rgb,0)**(1/2.4)-0.055)
  assignments.append(int(np.argmin(np.sum((palette-rgb)**2,axis=1))))
 obj.data.materials.clear()
 for i,rgb in enumerate(palette): obj.data.materials.append(material(asset_id+'_flat_'+str(i),rgb))
 for poly,index in zip(obj.data.polygons,assignments):
  poly.material_index=0 if asset_id=='PROP_01' else index
  poly.use_smooth=True
 obj.data.set_sharp_from_angle(angle=math.radians(35))
 bounds=[Vector(c) for c in obj.bound_box]
 low=Vector(tuple(min(p[i] for p in bounds) for i in range(3)))
 high=Vector(tuple(max(p[i] for p in bounds) for i in range(3)))
 scale=HEIGHTS[asset_id]/(high.z-low.z)
 center=Vector(((low.x+high.x)*.5,(low.y+high.y)*.5,low.z))
 for vertex in obj.data.vertices:
  vertex.co=(vertex.co-center)*scale
  if asset_id=='PROP_01':
   # Turbo omitted the suspension. Preserve its cabin shell and repair suspension below.
   vertex.co.x*=3.2/((high.x-low.x)*scale)
   vertex.co.y*=2.6/((high.y-low.y)*scale)
   vertex.co.z*=1.6/HEIGHTS[asset_id]
 obj.data.update();bpy.context.view_layer.update()
 if asset_id=='PROP_01':
  components=[obj]
  iron=obj.data.materials[4]
  def beam(name,a,b,width):
   delta=Vector(b)-Vector(a)
   bpy.ops.mesh.primitive_cube_add(size=1,location=(Vector(a)+Vector(b))*.5)
   part=bpy.context.object;part.name=name;part.dimensions=(width,width,delta.length)
   part.rotation_euler=delta.to_track_quat('Z','Y').to_euler();part.data.materials.append(iron)
   bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);components.append(part)
  beam('Suspension',(0,0,1.4),(0,0,3.55),.16)
  beam('ForkLeft',(0,0,3.35),(0,-.7,3.85),.14)
  beam('ForkRight',(0,0,3.35),(0,.7,3.85),.14)
  for y in [-.7,.7]:
   bpy.ops.mesh.primitive_cylinder_add(vertices=16,radius=.24,depth=.16,location=(0,y,3.88),rotation=(0,math.pi/2,0))
   part=bpy.context.object;part.name='Pulley';part.data.materials.append(iron);components.append(part)
  bpy.ops.object.select_all(action='DESELECT')
  for part in components: part.select_set(True)
  bpy.context.view_layer.objects.active=obj;bpy.ops.object.join()
 output=folder/(asset_id+'_game.glb')
 bpy.ops.export_scene.gltf(filepath=str(output),export_format='GLB',use_selection=True,export_yup=True,export_animations=False,export_cameras=False,export_lights=False)
 stats={'asset_id':asset_id,'raw_triangles':raw_triangles,'triangles':sum(len(p.vertices)-2 for p in obj.data.polygons),'vertices':len(obj.data.vertices),'size_blender_xyz':list(obj.dimensions),'material_count':len(palette),'file_bytes':output.stat().st_size,'postprocess':'UV albedo sampled to authored solid palette; decimated; angle-split normals; grounded; metre scale','runtime':output.relative_to(ROOT).as_posix()}
 if asset_id=='PROP_01': stats['manual_repairs']='Cabin shell retained from Lux3D; flattened to 3.2 x 2.6 x 1.6 m; missing suspension and pulley wheels reconstructed in Blender; uniform authored wood palette.'
 (folder/'import_report.json').write_text(json.dumps(stats,indent=2)+'\n',encoding='utf-8')
 # Preview uses the same flat material colors as the exported model.
 scene=bpy.context.scene;scene.render.engine='BLENDER_WORKBENCH'
 scene.display.shading.light='STUDIO';scene.display.shading.color_type='MATERIAL'
 scene.display.shading.show_shadows=True;scene.display.shading.show_cavity=False
 scene.display.shading.background_type='WORLD';scene.world.color=(0.88,0.89,0.85)
 scene.render.resolution_x=768;scene.render.resolution_y=768;scene.render.resolution_percentage=100
 bpy.ops.object.camera_add();camera=bpy.context.object
 target=Vector((0,0,HEIGHTS[asset_id]*.5));size=max(obj.dimensions)
 camera.location=target+Vector((1.1,-1.5,.9))*size
 camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
 camera.data.type='ORTHO';camera.data.ortho_scale=size*1.45;scene.camera=camera
 scene.render.image_settings.file_format='PNG';scene.render.filepath=str(folder/(asset_id+'.png'))
 bpy.ops.render.render(write_still=True)
 print('PROCESSED',json.dumps(stats))

for asset_id in sys.argv[sys.argv.index('--')+1:]: process(asset_id)
