import bpy
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'assets/models/aholo'
IPC = BASE / '_ipc'

for cid in ['CHAR_01', 'CHAR_02', 'CHAR_03', 'CHAR_04', 'CHAR_05', 'CHAR_06', 'CHAR_07']:
    glb_path = BASE / cid / f'{cid}.glb'
    if not glb_path.exists():
        continue
    
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    
    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_WORKBENCH'
    scene.display.shading.light = 'STUDIO'
    scene.display.shading.color_type = 'TEXTURE'
    scene.display.shading.show_shadows = True
    scene.render.resolution_x = 768
    scene.render.resolution_y = 768

    cam_data = bpy.data.cameras.new('EvalCam')
    cam_data.type = 'ORTHO'
    cam_obj = bpy.data.objects.new('EvalCam', cam_data)
    scene.collection.objects.link(cam_obj)
    scene.camera = cam_obj
    
    bpy.ops.import_scene.gltf(filepath=str(glb_path))
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    if not meshes:
        continue
    
    for o in meshes:
        for p in o.data.polygons:
            p.use_smooth = False
            
    coords = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
    min_c = Vector([min(c[i] for c in coords) for i in range(3)])
    max_c = Vector([max(c[i] for c in coords) for i in range(3)])
    center = (min_c + max_c) * 0.5
    size = max(max_c - min_c)
    cam_data.ortho_scale = size * 1.35
    
    # Render Front
    eye_front = center + Vector((0, -2.5, 0)) * (size / 1.5)
    cam_obj.location = eye_front
    cam_obj.rotation_euler = (center - eye_front).to_track_quat('-Z', 'Y').to_euler()
    scene.render.filepath = str(IPC / f"raw_eval_{cid}_front.png")
    bpy.ops.render.render(write_still=True)
    
    # Render Iso
    eye_iso = center + Vector((1.5, -1.8, 1.2)) * (size / 1.5)
    cam_obj.location = eye_iso
    cam_obj.rotation_euler = (center - eye_iso).to_track_quat('-Z', 'Y').to_euler()
    scene.render.filepath = str(IPC / f"raw_eval_{cid}_iso.png")
    bpy.ops.render.render(write_still=True)
    
    print(f"Rendered {cid} successfully.")
