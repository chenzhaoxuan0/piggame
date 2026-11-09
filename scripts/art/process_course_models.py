"""
Blender processing for Course 1 obstacle models:
- Normalizes mesh transforms and origins
- Scales to accurate real-world collision bounds
- Keeps authentic 2048x2048 albedo textures from Lux3D with flat toon shading
- Decimates triangles to <= 3500 while preserving UVs
- Exports runtime _game.glb
"""
import bpy
import json
import math
import sys
from pathlib import Path
from mathutils import Vector
import bmesh

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'assets/models/aholo'

# Dimensions in Blender coordinates (X, Y, Z; where Z is Up, which becomes Godot Y):
DIMENSIONS = {
    'PROP_C1_PIPE': {
        'target_x': 2.1,
        'target_y': 2.1,
        'target_z': 0.70,
        'ground_bottom': True,
        'center_xy': True,
    },
    'PROP_C1_BUMPER': {
        'target_x': 1.6,
        'target_y': 1.6,
        'target_z': 1.35,
        'ground_bottom': True,
        'center_xy': True,
    },
    'PROP_C1_HAMMER': {
        'target_x': 1.1,
        'target_y': 0.85,
        'target_z': 0.85,
        'ground_bottom': False,  # Center origin for rotating head
        'center_xy': True,
    },
    'PROP_C1_DOOR': {
        'target_x': 2.45,
        'target_y': 0.35,
        'target_z': 2.70,
        'ground_bottom': True,
        'center_xy': True,
    },
    'PROP_C1_PENDULUM': {
        'target_x': 1.8,
        'target_y': 1.8,
        'target_z': 1.8,
        'ground_bottom': False,  # Center origin for pendulum wrecking ball
        'center_xy': True,
    },
}

def process(asset_id):
    print(f"--- Processing {asset_id} ---", flush=True)
    folder = BASE / asset_id
    raw_glb = folder / f"{asset_id}.glb"
    if not raw_glb.exists():
        print(f"File not found: {raw_glb}", flush=True)
        return False
    
    bpy.ops.wm.read_factory_settings(use_empty=True)
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
    
    # Scale to dimensions
    spec = DIMENSIONS.get(asset_id, {})
    xs = [v.co.x for v in obj.data.vertices]
    ys = [v.co.y for v in obj.data.vertices]
    zs = [v.co.z for v in obj.data.vertices]
    dx = max(xs) - min(xs)
    dy = max(ys) - min(ys)
    dz = max(zs) - min(zs)
    
    tx = spec.get('target_x', dx)
    ty = spec.get('target_y', dy)
    tz = spec.get('target_z', dz)
    
    sx = tx / dx if dx > 0.001 else 1.0
    sy = ty / dy if dy > 0.001 else 1.0
    sz = tz / dz if dz > 0.001 else 1.0
    
    for v in obj.data.vertices:
        v.co.x *= sx
        v.co.y *= sy
        v.co.z *= sz
    
    # Re-calculate bounds after scaling
    xs = [v.co.x for v in obj.data.vertices]
    ys = [v.co.y for v in obj.data.vertices]
    zs = [v.co.z for v in obj.data.vertices]
    
    if spec.get('center_xy', True):
        cx = (max(xs) + min(xs)) * 0.5
        cy = (max(ys) + min(ys)) * 0.5
        for v in obj.data.vertices:
            v.co.x -= cx
            v.co.y -= cy
    
    if spec.get('ground_bottom', True):
        min_z = min(zs)
        for v in obj.data.vertices:
            v.co.z -= min_z
    else:
        # Center Z
        cz = (max(zs) + min(zs)) * 0.5
        for v in obj.data.vertices:
            v.co.z -= cz
            
    obj.data.update()
    
    # Decimate if faces > 3500 (preserving UVs and materials)
    triangles = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    print(f"Raw triangles for {asset_id}: {triangles}", flush=True)
    if triangles > 3500:
        dec = obj.modifiers.new('Decimate', 'DECIMATE')
        dec.ratio = 3500.0 / triangles
        bpy.ops.object.modifier_apply(modifier=dec.name)
        triangles = sum(len(p.vertices) - 2 for p in obj.data.polygons)
        print(f"Decimated to: {triangles} triangles", flush=True)
    
    # Tune materials for pastoral flat toon style (keep albedo texture, set roughness=1.0, metallic=0.0)
    for mat in obj.data.materials:
        if mat and mat.node_tree:
            for node in mat.node_tree.nodes:
                if node.type == 'BSDF_PRINCIPLED':
                    node.inputs['Roughness'].default_value = 1.0
                    if 'Metallic' in node.inputs:
                        node.inputs['Metallic'].default_value = 0.0
                    if 'Specular IOR Level' in node.inputs:
                        node.inputs['Specular IOR Level'].default_value = 0.0
                    # Disconnect normal maps / metallic maps so it stays cleanly flat
                    for inp_name in ['Normal', 'Metallic', 'Roughness']:
                        if inp_name in node.inputs and node.inputs[inp_name].is_linked:
                            for link in list(node.inputs[inp_name].links):
                                mat.node_tree.links.remove(link)
    
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
    args = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else list(DIMENSIONS.keys())
    for aid in args:
        process(aid)
