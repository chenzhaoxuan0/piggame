import bpy
import json
import math
import sys
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'assets/models/aholo/_ipc'

MODELS = {
    'img_to_3d_300k': {
        'name': '单图直出图生3D (G1 300K PBR)',
        'path': BASE / 'test_img_to_3d_300k' / 'model.glb',
        'out_prefix': 'eval_img_to_3d',
    },
    'text_to_3d_300k': {
        'name': '文生3D+单图参考 (G1 300K PBR)',
        'path': BASE / 'test_text_to_3d_300k' / 'model.glb',
        'out_prefix': 'eval_text_to_3d',
    },
    'plan_b_g1': {
        'name': '方案B: 纯主体+DOC提示词+四视角 (G1 80K)',
        'path': ROOT / 'assets/models/aholo/CHAR_01/CHAR_01.glb',
        'out_prefix': 'eval_plan_b',
    },
}

def analyze_and_render(model_key, config):
    path = config['path']
    if not path.exists():
        print(f"[{model_key}] File does not exist: {path}")
        return None
    
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    
    bpy.ops.import_scene.gltf(filepath=str(path))
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    if not meshes:
        print(f"[{model_key}] No mesh found in {path}")
        return None
    
    total_verts = sum(len(o.data.vertices) for o in meshes)
    total_faces = sum(len(o.data.polygons) for o in meshes)
    
    # Calculate overall bounding box
    coords = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
    min_c = Vector([min(c[i] for c in coords) for i in range(3)])
    max_c = Vector([max(c[i] for c in coords) for i in range(3)])
    dims = max_c - min_c
    center = (min_c + max_c) * 0.5
    size = max(dims)
    
    # Material info
    materials = []
    tex_sizes = []
    for o in meshes:
        for m in o.data.materials:
            if m and m.name not in materials:
                materials.append(m.name)
                if m.use_nodes:
                    for n in m.node_tree.nodes:
                        if n.type == 'TEX_IMAGE' and n.image:
                            tex_sizes.append(list(n.image.size[:]))
    
    report = {
        'name': config['name'],
        'file_bytes': path.stat().st_size,
        'meshes_count': len(meshes),
        'total_vertices': total_verts,
        'total_polygons': total_faces,
        'bounding_box_xyz': [round(dims.x, 3), round(dims.y, 3), round(dims.z, 3)],
        'materials': materials,
        'texture_resolutions': tex_sizes,
    }
    
    # Render views
    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_WORKBENCH'
    scene.display.shading.light = 'STUDIO'
    scene.display.shading.color_type = 'TEXTURE'
    scene.display.shading.show_shadows = True
    scene.render.resolution_x = 768
    scene.render.resolution_y = 768
    
    cam_data = bpy.data.cameras.new('EvalCam')
    cam_data.type = 'ORTHO'
    cam_data.ortho_scale = size * 1.35
    cam_obj = bpy.data.objects.new('EvalCam', cam_data)
    scene.collection.objects.link(cam_obj)
    scene.camera = cam_obj
    
    views = [
        ('iso_front_right', center + Vector((1.5, -1.8, 1.2)) * (size / 1.5)),
        ('front', center + Vector((0, -2.5, 0)) * (size / 1.5)),
        ('side_right', center + Vector((2.5, 0, 0)) * (size / 1.5)),
        ('top', center + Vector((0, 0, 2.5)) * (size / 1.5)),
    ]
    
    rendered_images = {}
    for vname, eye in views:
        cam_obj.location = eye
        cam_obj.rotation_euler = (center - eye).to_track_quat('-Z', 'Y').to_euler()
        out_file = BASE / f"{config['out_prefix']}_{vname}.png"
        scene.render.filepath = str(out_file)
        bpy.ops.render.render(write_still=True)
        rendered_images[vname] = str(out_file)
    
    report['renders'] = rendered_images
    return report

if __name__ == '__main__':
    all_reports = {}
    for k, conf in MODELS.items():
        rep = analyze_and_render(k, conf)
        if rep:
            all_reports[k] = rep
    
    report_file = BASE / 'full_comparison_report.json'
    report_file.write_text(json.dumps(all_reports, indent=2, ensure_ascii=False), encoding='utf-8')
    print('COMPLETED_ANALYSIS', json.dumps(all_reports, ensure_ascii=False))

