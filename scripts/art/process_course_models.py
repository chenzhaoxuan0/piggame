"""
Blender processing for Course 1 obstacle models:
- Normalizes mesh transforms and origins
- Scales to target real-world height
- Welds seams and decimates to <= 4000 triangles
- Replaces PBR noise with flat solid palette materials
- Exports runtime _game.glb
"""
import bpy
import json
import math
import sys
from pathlib import Path
from mathutils import Vector
import numpy as np
import bmesh

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'assets/models/aholo'

HEIGHTS = {
    'PROP_C1_BUMPER': 1.1,
    'PROP_C1_HAMMER': 0.9,
    'PROP_C1_PENDULUM': 1.5,
    'PROP_C1_DOOR': 2.6,
    'PROP_C1_PIPE': 1.2,
}

PALETTES = {
    'PROP_C1_BUMPER': ['FF1493', 'FF69B4', 'FFD700', '00E5FF', '2C3E50'],
    'PROP_C1_HAMMER': ['8D7B68', 'A0855B', '5D6D7E', '34495E', 'E67E22'],
    'PROP_C1_PENDULUM': ['34495E', '2C3E50', '7F8C8D', '95A5A6'],
    'PROP_C1_DOOR': ['E74C3C', 'C0392B', 'F39C12', 'FFFFFF', '34495E'],
    'PROP_C1_PIPE': ['2E7D32', '388E3C', '1B5E20', '1E272C'],
}

def create_toon_mat(name, hex_color):
    rgb = [int(hex_color[i:i+2], 16) / 255.0 for i in (0, 2, 4)]
    # sRGB to linear
    linear_rgb = [(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4) for c in rgb]
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*linear_rgb, 1.0)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    bsdf.inputs['Base Color'].default_value = (*linear_rgb, 1.0)
    bsdf.inputs['Roughness'].default_value = 1.0
    if 'Specular IOR Level' in bsdf.inputs:
        bsdf.inputs['Specular IOR Level'].default_value = 0.0
    return m

def process(asset_id):
    print(f"--- Processing {asset_id} ---", flush=True)
    folder = BASE / asset_id
    raw_glb = folder / f"{asset_id}.glb"
    if not raw_glb.exists():
        print(f"File not found: {raw_glb}", flush=True)
        return False
    
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    
    bpy.ops.import_scene.gltf(filepath=str(raw_glb))
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    if not meshes:
        print(f"No meshes in {asset_id}", flush=True)
        return False
    
    for obj in meshes:
        world = obj.matrix_world.copy()
        obj.parent = None
        obj.matrix_world = world
    
    bpy.ops.object.select_all(action='DESELECT')
    for obj in meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if len(meshes) > 1:
        bpy.ops.object.join()
    
    obj = bpy.context.object
    obj.name = asset_id
    
    # Scale to target height
    z_coords = [v.co.z for v in obj.data.vertices]
    initial_h = max(z_coords) - min(z_coords)
    target_h = HEIGHTS.get(asset_id, 1.0)
    if initial_h > 0.001:
        scale_fac = target_h / initial_h
        for v in obj.data.vertices:
            v.co *= scale_fac
    
    # Ground at y=0 (or z=min for Z-up)
    min_z = min(v.co.z for v in obj.data.vertices)
    for v in obj.data.vertices:
        v.co.z -= min_z
        # Also center X and Y
    center_x = (max(v.co.x for v in obj.data.vertices) + min(v.co.x for v in obj.data.vertices)) * 0.5
    center_y = (max(v.co.y for v in obj.data.vertices) + min(v.co.y for v in obj.data.vertices)) * 0.5
    for v in obj.data.vertices:
        v.co.x -= center_x
        v.co.y -= center_y
    
    obj.data.update()
    
    # Weld duplicate vertices
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=0.001)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.validate(clean_customdata=False)
    obj.data.update()
    
    # Decimate if faces > 3500
    triangles = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    print(f"Raw triangles: {triangles}", flush=True)
    if triangles > 3500:
        dec = obj.modifiers.new('Decimate', 'DECIMATE')
        dec.ratio = 3500.0 / triangles
        bpy.ops.object.modifier_apply(modifier=dec.name)
        triangles = sum(len(p.vertices) - 2 for p in obj.data.polygons)
        print(f"Reduced to: {triangles} triangles", flush=True)
    
    # Apply primary flat palette material
    palette_hex = PALETTES.get(asset_id, ['74A87C', 'E1DDC5'])
    main_mat = create_toon_mat(f"{asset_id}_Mat", palette_hex[0])
    obj.data.materials.clear()
    obj.data.materials.append(main_mat)
    
    # Export _game.glb
    out_glb = folder / f"{asset_id}_game.glb"
    bpy.ops.export_scene.gltf(
        filepath=str(out_glb),
        use_selection=True,
        export_format='GLB',
        export_cameras=False,
        export_lights=False,
        export_yup=True
    )
    print(f"Successfully exported game model: {out_glb}", flush=True)
    return True

if __name__ == '__main__':
    args = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else list(HEIGHTS.keys())
    for aid in args:
        process(aid)
