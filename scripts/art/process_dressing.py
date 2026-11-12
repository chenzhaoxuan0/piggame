"""Blender: clean Lux3D dressing geometry, transfer coarse pigment, save sources.
Weld and normal repair retain the generated silhouette before reduction.
This processes the generated silhouette; it does not replace it with primitives.
"""
import bpy
import json
import sys
import math
from pathlib import Path
from mathutils import Vector
from mathutils.kdtree import KDTree
import numpy as np
import bmesh

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(Path(__file__).resolve().parent))
from process_models import material
SPECS=json.loads((ROOT/'scripts/art/dressing_specs.json').read_text(encoding='utf-8'))
BASE=ROOT/'assets/models/aholo'

def process(asset_id):
    spec=SPECS[asset_id];folder=BASE/asset_id
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=str(folder/(asset_id+'.glb')))
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
    for obj in meshes:
        transform=obj.matrix_world.copy();obj.parent=None;obj.matrix_world=transform
    bpy.ops.object.select_all(action='DESELECT')
    for obj in meshes: obj.select_set(True)
    bpy.context.view_layer.objects.active=meshes[0]
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    if len(meshes)>1: bpy.ops.object.join()
    obj=bpy.context.object;obj.name=asset_id
    obj.data.validate();obj.data.update()
    # Lux3D exports can be extremely small before their node transform. Work in
    # stable metre units before welding/decimation, with no scale-sensitive epsilons.
    bpy.context.view_layer.update()
    initial_height=max(v.co.z for v in obj.data.vertices)-min(v.co.z for v in obj.data.vertices)
    print('SOURCE_SCALE',asset_id,initial_height,flush=True)
    for v in obj.data.vertices: v.co*=spec['height']/initial_height
    obj.data.update();bpy.context.view_layer.update()
    raw=sum(len(p.vertices)-2 for p in obj.data.polygons)
    textures={}
    for index,mat in enumerate(obj.data.materials):
        if not mat or not mat.use_nodes: continue
        shader=next((n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None)
        if not shader or not shader.inputs['Base Color'].is_linked: continue
        node=shader.inputs['Base Color'].links[0].from_node
        if node.type!='TEX_IMAGE': continue
        image=node.image;pixels=np.empty(len(image.pixels),dtype=np.float32)
        image.pixels.foreach_get(pixels)
        textures[index]=(pixels.reshape(image.size[1],image.size[0],4),image.size[:])
    tree=KDTree(len(obj.data.polygons));colors=[]
    uvs=obj.data.uv_layers.active
    for i,poly in enumerate(obj.data.polygons):
        tree.insert(poly.center,i)
        rgb=np.array((.5,.6,.35))
        if poly.material_index in textures and uvs:
            pixels,(w,h)=textures[poly.material_index]
            uv=sum((uvs.data[j].uv for j in poly.loop_indices),Vector((0,0)))/len(poly.loop_indices)
            rgb=pixels[min(h-1,max(0,int(uv.y*h))),min(w-1,max(0,int(uv.x*w))),:3]
            rgb=np.where(rgb<=.0031308,12.92*rgb,1.055*np.maximum(rgb,0)**(1/2.4)-.055)
        colors.append(rgb)
    tree.balance()
    # No UV data or texture dependency survives into the game mesh.
    while obj.data.uv_layers: obj.data.uv_layers.remove(obj.data.uv_layers[0])
    bm=bmesh.new();bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.0001)
    bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=.00001)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(obj.data);bm.free();obj.data.validate();obj.data.update()
    count=sum(len(p.vertices)-2 for p in obj.data.polygons)
    if count>spec['budget']:
        dec=obj.modifiers.new('Game silhouette','DECIMATE')
        # Hard-surface slatted/planked silhouettes tear under collapse decimation;
        # planar dissolve keeps their flat faces clean (same contract as barrel/hurdle).
        if asset_id in ['ENV_09_BARREL','ENV_09_WOOL','ENV_09_HURDLE','ENV_06_CRATE']:
            dec.decimate_type='DISSOLVE';dec.angle_limit=math.radians(35 if asset_id=='ENV_09_WOOL' else 12)
            dec.use_dissolve_boundaries=False
        else: dec.ratio=spec['budget']/count
        bpy.ops.object.modifier_apply(modifier=dec.name)
    obj.data.validate();obj.data.update()
    palette=np.array([[int(h[i:i+2],16)/255 for i in (0,2,4)] for h in spec['palette']])
    obj.data.materials.clear()
    for i,rgb in enumerate(palette): obj.data.materials.append(material(asset_id+'_pigment_'+str(i),rgb))
    low=min(v.co.z for v in obj.data.vertices);high=max(v.co.z for v in obj.data.vertices)
    y_min=min(v.co.y for v in obj.data.vertices);y_max=max(v.co.y for v in obj.data.vertices)
    for poly in obj.data.polygons:
        _,index,_=tree.find(poly.center)
        rgb=colors[index]
        chosen=int(np.argmin(np.sum((palette-rgb)**2,axis=1)))
        relative=(poly.center.z-low)/(high-low)
        if asset_id in ['ENV_09_OAK','ENV_09_PINE','ENV_09_APPLE']:
            if relative<(.37 if asset_id=='ENV_09_APPLE' else .32): chosen=len(palette)-1
            elif asset_id=='ENV_09_APPLE' and rgb[0]>rgb[1]*1.12: chosen=2
            else: chosen=0 if asset_id=='ENV_09_APPLE' else 1
        elif asset_id=='ENV_09_BIRCH': chosen=2 if relative<.48 else 0
        elif asset_id=='ENV_09_BARREL': chosen=3 if .15<relative<.25 or .75<relative<.84 else 0
        elif asset_id=='ENV_09_WOOL': chosen=2 if relative>.45 else 0
        elif asset_id=='ENV_09_HURDLE':
            horizontal=(poly.center.y-y_min)/(y_max-y_min)
            chosen=(int(horizontal*8)%2) if .20<horizontal<.80 and relative>.25 else 2
        poly.material_index=chosen
        poly.use_smooth=False
    bounds=[v.co for v in obj.data.vertices]
    center=Vector(((min(v.x for v in bounds)+max(v.x for v in bounds))*.5,
                   (min(v.y for v in bounds)+max(v.y for v in bounds))*.5,low))
    scale=spec['height']/(high-low)
    for v in obj.data.vertices: v.co=(v.co-center)*scale
    obj.data.update();bpy.context.view_layer.update()
    source=folder/'source';source.mkdir(exist_ok=True)
    (source/'.gdignore').write_text('',encoding='utf-8')
    bpy.context.preferences.filepaths.save_version=0
    bpy.context.preferences.filepaths.file_preview_type='NONE'
    bpy.data.orphans_purge(do_recursive=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(source/(asset_id+'.blend')))
    out=folder/(asset_id+'_game.glb')
    bpy.ops.export_scene.gltf(filepath=str(out),export_format='GLB',use_selection=True,
        export_yup=True,export_animations=False,export_cameras=False,export_lights=False)
    report={'asset_id':asset_id,'raw_triangles':raw,'triangles':sum(len(p.vertices)-2 for p in obj.data.polygons),
        'size_blender_xyz':list(obj.dimensions),'file_bytes':out.stat().st_size,
        'postprocess':'Lux3D silhouette welded and normals repaired; reduction; sampled solid palette with tree trunk/crown correction; no textures; ground origin; metre scale',
        'runtime':out.relative_to(ROOT).as_posix()}
    (folder/'import_report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    scene=bpy.context.scene;scene.render.engine='BLENDER_WORKBENCH'
    scene.display.shading.light='STUDIO';scene.display.shading.color_type='MATERIAL'
    scene.display.shading.show_shadows=False;scene.display.shading.show_cavity=False
    scene.display.shading.show_specular_highlight=False
    scene.display.shading.background_type='WORLD';scene.world.color=(.78,.80,.74)
    scene.render.resolution_x=600;scene.render.resolution_y=600;scene.render.resolution_percentage=100
    bpy.ops.object.camera_add();camera=bpy.context.object
    target=Vector((0,0,spec['height']*.48));size=max(obj.dimensions)
    camera.location=target+Vector((1.1,-1.5,.8))*size
    camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
    camera.data.type='ORTHO';camera.data.ortho_scale=size*1.4;scene.camera=camera
    scene.render.image_settings.file_format='PNG';scene.render.filepath=str(folder/(asset_id+'.png'))
    bpy.ops.render.render(write_still=True)
    print('DRESSING_PROCESSED',json.dumps(report),flush=True)

for asset_id in sys.argv[sys.argv.index('--')+1:]: process(asset_id)
