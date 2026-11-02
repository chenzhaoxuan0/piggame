"""Clean Plan B production pipeline for all characters:
1. Load authentic raw G1 Plan B models (CHAR_01.glb to CHAR_07.glb).
2. No destructive bmesh welding or normal recalculation.
3. Clean decimate to game budget (~6500-7500 tris) preserving low-poly facets.
4. Pure flat shading (p.use_smooth = False).
5. Automatic UV texture palette mapping preserving natural eyes, tags, and markings.
6. Standard 8-bone armature rig and animation clips for Godot.
7. Metre-scale and ground to Y=0, facing Godot -Z.
8. Render clean orthographic previews.
"""
import bpy
import json
import math
import sys
from pathlib import Path
from mathutils import Vector, Matrix
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'assets/models/aholo'
IPC = BASE / '_ipc'

PALETTES = {
    'CHAR_01': ['F7C5C8', 'E7A3AE', 'D68796', 'FCD34D', 'B34F55', '332E2C', '836D60', '171B19'],
    'CHAR_02': ['CACBC4', 'E2E3D9', 'A3A79F', '71746E', '373A3B', '212121', 'D5C6A6', '171B19'],
    'CHAR_03': ['865B3A', 'A4754C', '65442E', 'C9AA7E', 'E2D5B8', '342B25', '171B19'],
    'CHAR_04': ['F7F3E8', 'DFDFD5', 'F3B5BA', 'D6939D', '353230', '171B19', 'C29A66'],
    'CHAR_05': ['844830', 'A4603C', '603525', '322B25', '1E2220', 'BD4943', 'E4D2A6', '171B19'],
    'CHAR_06': ['BA8A52', 'D0A470', '8B643F', '353631', '1D2524', 'BD7E76', '171B19'],
    'CHAR_07': ['D1A968', 'E2BB8E', 'BA8C4A', '637E92', '415B71', '345744', '253D32', '6F6A50', '292C2D', '171B19'],
}

HEIGHTS = {
    'CHAR_01': 1.08,
    'CHAR_02': 1.60,
    'CHAR_03': 1.80,
    'CHAR_04': 1.12,
    'CHAR_05': 2.25,
    'CHAR_06': 1.05,
    'CHAR_07': 1.95,
}

LEG_HEIGHT = {
    'CHAR_01': 0.31,
    'CHAR_02': 0.35,
    'CHAR_03': 0.39,
    'CHAR_04': 0.27,
    'CHAR_05': 0.43,
    'CHAR_06': 0.43,
    'CHAR_07': 0.48,
}

def create_mat(name, hex_color):
    rgb = np.array([int(hex_color[i:i+2], 16) / 255.0 for i in (0, 2, 4)])
    linear = np.where(rgb <= 0.04045, rgb / 12.92, ((rgb + 0.055) / 1.055) ** 2.4)
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*linear, 1.0)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    bsdf.inputs['Base Color'].default_value = (*linear, 1.0)
    bsdf.inputs['Roughness'].default_value = 1.0
    if 'Specular IOR Level' in bsdf.inputs:
        bsdf.inputs['Specular IOR Level'].default_value = 0.0
    return m

def make_armature(obj, cid, lo, hi):
    h = hi.z
    leg_top = h * LEG_HEIGHT[cid]
    data = bpy.data.armatures.new(cid + '_skeleton')
    rig = bpy.data.objects.new('Rig', data)
    bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    
    def add_bone(name, start, end, parent_name=None):
        b = data.edit_bones.new(name)
        b.head = start
        b.tail = end
        if parent_name:
            b.parent = data.edit_bones[parent_name]
        return b
        
    add_bone('Root', (0, 0, 0), (0, 0, h * 0.15))
    add_bone('Body', (0, 0, h * 0.35), (0, 0, h * 0.65), 'Root')
    
    if cid == 'CHAR_07':
        add_bone('Head', (0, 0, h * 0.77), (0, 0, h * 0.96), 'Body')
        for s, x in [('L', hi.x * 0.34), ('R', -hi.x * 0.34)]:
            add_bone('Leg' + s, (x, 0, leg_top), (x, 0, 0.03), 'Body')
        for s, x in [('L', hi.x * 0.65), ('R', -hi.x * 0.65)]:
            add_bone('Arm' + s, (x, 0, h * 0.73), (x * 1.2, 0, h * 0.43), 'Body')
    else:
        add_bone('Head', (0, hi.y * 0.37, h * 0.57), (0, hi.y * 0.8, h * 0.72), 'Body')
        add_bone('Tail', (0, lo.y * 0.6, h * 0.55), (0, lo.y * 0.95, h * 0.68), 'Body')
        for side, signx in [('L', 1), ('R', -1)]:
            for end, signy in [('F', 1), ('B', -1)]:
                verts = [v.co for v in obj.data.vertices if v.co.z < leg_top * 0.6 and v.co.x * signx > 0 and v.co.y * signy > 0]
                x = float(np.median([v.x for v in verts])) if verts else hi.x * 0.6 * signx
                y = float(np.median([v.y for v in verts])) if verts else (hi.y if signy > 0 else lo.y) * 0.55
                add_bone('Leg' + side + end, (x, y, leg_top), (x, y, 0.02), 'Body')
                
    bpy.ops.object.mode_set(mode='OBJECT')
    groups = {b.name: obj.vertex_groups.new(name=b.name) for b in data.bones}
    
    for v in obj.data.vertices:
        c = v.co
        weights = {'Body': 1.0}
        if cid == 'CHAR_07':
            if c.z < leg_top:
                blend = min(1.0, (leg_top - c.z) / (h * 0.07))
                weights = {'LegL' if c.x > 0 else 'LegR': blend, 'Body': 1.0 - blend}
            elif c.z > h * 0.77:
                weights = {'Head': 1.0}
            elif abs(c.x) > hi.x * 0.57 and c.z < h * 0.76:
                weights = {'ArmL' if c.x > 0 else 'ArmR': 1.0}
        else:
            if c.z < leg_top:
                b_name = 'Leg' + ('L' if c.x > 0 else 'R') + ('F' if c.y > 0 else 'B')
                blend = min(1.0, (leg_top - c.z) / (h * 0.10))
                weights = {b_name: blend, 'Body': 1.0 - blend}
            elif c.y > hi.y * 0.42 and c.z > h * 0.38:
                blend = min(1.0, (c.y - hi.y * 0.42) / (hi.y * 0.25))
                weights = {'Head': blend, 'Body': 1.0 - blend}
            elif c.y < lo.y * 0.82 and c.z > h * 0.35:
                weights = {'Tail': 0.6, 'Body': 0.4}
                
        for b_name, w in weights.items():
            if w > 0:
                groups[b_name].add([v.index], w, 'REPLACE')
                
    obj.parent = rig
    mod = obj.modifiers.new('Skin', 'ARMATURE')
    mod.object = rig
    rig.animation_data_create()
    bpy.context.scene.render.fps = 24
    
    for clip, duration, amp in [('idle', 2, 0.018), ('walk', 1, 0.35), ('run', 0.6, 0.55), ('celebrate', 1.2, 0.12)]:
        action = bpy.data.actions.new(clip)
        rig.animation_data.action = action
        end = round(duration * 24) + 1
        for f in range(1, end + 1):
            phase = (f - 1) / (end - 1) * math.tau
            for pb in rig.pose.bones:
                pb.rotation_mode = 'XYZ'
                pb.rotation_euler = (0, 0, 0)
                pb.location = (0, 0, 0)
                if pb.name.startswith('Leg') and clip in ['walk', 'run']:
                    positive = pb.name in ['LegLF', 'LegRB', 'LegL']
                    pb.rotation_euler.x = math.sin(phase + (0 if positive else math.pi)) * amp
                elif pb.name.startswith('Arm'):
                    pb.rotation_euler.x = math.sin(phase) * (amp if clip in ['walk', 'run'] else 0.025) * (1 if pb.name == 'ArmL' else -1)
                elif pb.name == 'Head':
                    pb.rotation_euler.x = math.sin(phase) * (0.08 if clip == 'celebrate' else 0.018)
                elif pb.name == 'Tail':
                    pb.rotation_euler.y = math.sin(phase) * 0.12
                elif pb.name == 'Body':
                    pb.location.y = abs(math.sin(phase)) * h * (0.035 if clip == 'run' else 0.012 if clip == 'walk' else 0.004)
                pb.keyframe_insert(data_path='rotation_euler', frame=f)
                pb.keyframe_insert(data_path='location', frame=f)
        rig.animation_data.action = None
        track = rig.animation_data.nla_tracks.new()
        track.name = clip
        track.strips.new(clip, 1, action)
        track.mute = True
        
    for pb in rig.pose.bones:
        pb.rotation_euler = (0, 0, 0)
        pb.location = (0, 0, 0)
    return rig

def process_character(cid):
    print(f"\nProcessing {cid} with Clean Plan B pipeline...")
    folder = BASE / cid
    raw_glb = folder / f'{cid}.glb'
    game_glb = folder / f'{cid}_game.glb'
    preview_png = folder / f'{cid}.png'
    
    if not raw_glb.exists():
        print(f"[{cid}] Raw GLB does not exist: {raw_glb}")
        return
        
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    
    bpy.ops.import_scene.gltf(filepath=str(raw_glb))
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    if not meshes:
        print(f"[{cid}] No meshes found in {raw_glb}")
        return
        
    for o in meshes:
        world = o.matrix_world.copy()
        o.parent = None
        o.matrix_world = world
    bpy.ops.object.select_all(action='DESELECT')
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.object
    obj.name = cid
    
    # 1. Decimate cleanly to ~7000 tris directly without weld artifacts
    raw_tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    target_tris = 7000
    if raw_tris > target_tris:
        dec = obj.modifiers.new('Game silhouette reduction', 'DECIMATE')
        dec.ratio = target_tris / raw_tris
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=dec.name)
        
    # 2. Pure flat shading
    for p in obj.data.polygons:
        p.use_smooth = False
        
    # 3. Sample source UV albedo into solid palette colors
    palette_hexes = PALETTES[cid]
    palette_rgb = np.array([[int(h[i:i+2], 16) / 255.0 for i in (0, 2, 4)] for h in palette_hexes])
    
    source_materials = list(obj.data.materials)
    texture_cache = {}
    for idx, m in enumerate(source_materials):
        if not m or not m.use_nodes:
            continue
        bsdf = next((n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'), None)
        image = None
        if bsdf and bsdf.inputs['Base Color'].is_linked:
            src_node = bsdf.inputs['Base Color'].links[0].from_node
            if src_node.type == 'TEX_IMAGE':
                image = src_node.image
        if image:
            pixels = np.empty(len(image.pixels), dtype=np.float32)
            image.pixels.foreach_get(pixels)
            texture_cache[idx] = (pixels.reshape(image.size[1], image.size[0], 4), image.size[:])
            
    assignments = []
    uvs = obj.data.uv_layers.active
    for poly in obj.data.polygons:
        if poly.material_index in texture_cache and uvs:
            pixels, (w, h) = texture_cache[poly.material_index]
            uv = sum((uvs.data[i].uv for i in poly.loop_indices), Vector((0, 0))) / len(poly.loop_indices)
            rgb = pixels[min(h - 1, max(0, int(uv.y * h))), min(w - 1, max(0, int(uv.x * w))), :3]
        else:
            m = source_materials[poly.material_index] if source_materials else None
            rgb = np.array(m.diffuse_color[:3] if m else (0.6, 0.5, 0.4))
            
        rgb = np.where(rgb <= 0.0031308, 12.92 * rgb, 1.055 * np.maximum(rgb, 0) ** (1 / 2.4) - 0.055)
        best_palette_idx = int(np.argmin(np.sum((palette_rgb - rgb) ** 2, axis=1)))
        assignments.append(best_palette_idx)
        
    obj.data.materials.clear()
    for i, hex_col in enumerate(palette_hexes):
        obj.data.materials.append(create_mat(f"{cid}_flat_{i}", hex_col))
    for poly, mat_idx in zip(obj.data.polygons, assignments):
        poly.material_index = mat_idx
        poly.use_smooth = False
        
    # 4. Scale to standard character height and ground to Y=0
    bounds = [Vector(c) for c in obj.bound_box]
    low = Vector(tuple(min(p[i] for p in bounds) for i in range(3)))
    high = Vector(tuple(max(p[i] for p in bounds) for i in range(3)))
    scale = HEIGHTS[cid] / (high.z - low.z)
    center = Vector(((low.x + high.x) * 0.5, (low.y + high.y) * 0.5, low.z))
    for v in obj.data.vertices:
        v.co = (v.co - center) * scale
        
    obj.data.update()
    bpy.context.view_layer.update()
    
    # 5. Make Rig
    bounds = [Vector(c) for c in obj.bound_box]
    low = Vector(tuple(min(p[i] for p in bounds) for i in range(3)))
    high = Vector(tuple(max(p[i] for p in bounds) for i in range(3)))
    rig = make_armature(obj, cid, low, high)
    
    # 6. Export GLB
    objects = [obj, rig]
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:
        o.select_set(True)
    bpy.context.view_layer.objects.active = rig
    
    bpy.ops.export_scene.gltf(
        filepath=str(game_glb),
        export_format='GLB',
        use_selection=True,
        export_yup=True,
        export_animations=True,
        export_animation_mode='NLA_TRACKS',
        export_force_sampling=True,
        export_cameras=False,
        export_lights=False
    )
    
    # 7. Render clean preview PNG
    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_WORKBENCH'
    scene.display.shading.light = 'STUDIO'
    scene.display.shading.color_type = 'TEXTURE'
    scene.display.shading.show_shadows = True
    scene.display.shading.show_cavity = False
    scene.render.resolution_x = 768
    scene.render.resolution_y = 768
    
    coords = [o.matrix_world @ Vector(c) for o in [obj] for c in o.bound_box]
    min_c = Vector([min(v[i] for v in coords) for i in range(3)])
    max_c = Vector([max(v[i] for v in coords) for i in range(3)])
    center = (min_c + max_c) * 0.5
    size = max(max_c - min_c)
    
    cam_data = bpy.data.cameras.new('Cam')
    cam_data.type = 'ORTHO'
    cam_data.ortho_scale = size * 1.35
    cam = bpy.data.objects.new('Cam', cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    
    eye = center + Vector((1.5, -1.8, 1.2)) * (size / 1.5)
    cam.location = eye
    cam.rotation_euler = (center - eye).to_track_quat('-Z', 'Y').to_euler()
    
    scene.render.image_settings.file_format = 'PNG'
    scene.render.filepath = str(preview_png)
    bpy.ops.render.render(write_still=True)
    
    final_tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    print(f"[{cid}] Finalized clean model: {final_tris} tris, saved to {game_glb} and {preview_png}")

if __name__ == '__main__':
    for c in ['CHAR_01', 'CHAR_02', 'CHAR_03', 'CHAR_04', 'CHAR_05', 'CHAR_06', 'CHAR_07']:
        process_character(c)
