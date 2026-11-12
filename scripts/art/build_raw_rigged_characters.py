"""Build 100% Raw Rigged Character Models:
1. Zero decimation: Keep 100% of authentic G1 raw geometry (~75k-80k tris).
2. Zero palette quantization: Keep 100% of original 2048x2048 PBR albedo texture.
3. Zero smoothing/welding/modification: 100% pristine low-poly faceted appearance.
4. Correct spatial orientation: Align forward direction to Blender +Y (Godot -Z).
5. Add standard 8-bone armature rig & weights.
6. Add per-character NLA animation clips (loops: idle/walk/run/celebrate/talk;
   one-shots: pig jump/dodge/hit, dog attack/bark, farmer attack).
7. Ground to Y=0, export to {cid}_game.glb and render authentic preview {cid}.png.
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

YAWS = {
    'CHAR_01': -125,
    'CHAR_02': 180,
    'CHAR_03': 180,
    'CHAR_04': -135,
    'CHAR_05': 180,
    'CHAR_06': 180,
    'CHAR_07': 180,
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

def _track(p, keys):
    """Piecewise-linear keyframe track: keys = [(p, value), ...] with p in 0..1."""
    if p <= keys[0][0]: return keys[0][1]
    for i in range(1, len(keys)):
        p1, v1 = keys[i]
        if p <= p1:
            p0, v0 = keys[i - 1]
            span = p1 - p0
            return v0 + (v1 - v0) * ((p - p0) / span if span > 0 else 1.0)
    return keys[-1][1]

def clip_specs(cid):
    """Per-character clip list: (name, duration in seconds)."""
    specs = [('idle', 2.0), ('walk', 1.0), ('run', 0.6), ('celebrate', 1.2), ('talk', 1.2)]
    if cid == 'CHAR_01':
        specs += [('jump', 0.7), ('dodge', 0.5), ('hit', 0.6)]
    elif cid == 'CHAR_06':
        specs += [('attack', 0.5), ('bark', 0.7)]
    elif cid == 'CHAR_07':
        specs += [('attack', 0.6)]
    return specs

def clip_pose(clip, p, pb, h, cid):
    """Pose one bone at normalized time p (0..1) for a clip. Returns (euler, location)."""
    name = pb.name
    rot = [0.0, 0.0, 0.0]
    loc = [0.0, 0.0, 0.0]
    biped = cid == 'CHAR_07'
    phase = p * math.tau

    if clip in ['walk', 'run']:
        amp = 0.45 if clip == 'walk' else 0.65
        if name.startswith('Leg'):
            positive = name in ['LegLF', 'LegRB', 'LegL']
            rot[0] = math.sin(phase + (0 if positive else math.pi)) * amp
        elif name.startswith('Arm'):
            rot[0] = math.sin(phase) * amp * (1 if name == 'ArmL' else -1)
        elif name == 'Head':
            rot[0] = math.sin(phase) * (0.03 if clip == 'walk' else 0.04)
        elif name == 'Tail':
            rot[1] = math.sin(phase) * 0.12
        elif name == 'Body':
            loc[1] = abs(math.sin(phase)) * h * (0.045 if clip == 'run' else 0.018)
    elif clip == 'idle':
        if name == 'Head':
            rot[0] = math.sin(phase) * 0.018
        elif name == 'Tail':
            rot[1] = math.sin(phase) * 0.12
        elif name == 'Body':
            loc[1] = abs(math.sin(phase)) * h * 0.004
    elif clip == 'celebrate':
        if name == 'Body':
            loc[1] = abs(math.sin(phase * 2.0)) * h * 0.05
            rot[0] = math.sin(phase * 2.0) * 0.06
        elif name == 'Head':
            rot[0] = math.sin(phase) * 0.18
        elif name == 'Tail':
            rot[1] = math.sin(phase * 2.0) * 0.3
        elif name.startswith('Leg'):
            positive = name in ['LegLF', 'LegRB', 'LegL']
            rot[0] = (0.1 if positive else -0.1) + math.sin(phase * 2.0 + (0 if positive else math.pi)) * 0.3
    elif clip == 'jump':
        if name == 'Body':
            loc[2] = _track(p, [(0.0, 0.0), (0.25, -h * 0.05), (0.55, h * 0.10), (0.85, h * 0.01), (1.0, 0.0)])
        elif name.startswith('Leg'):
            rot[0] = _track(p, [(0.0, 0.0), (0.25, 0.7), (0.55, -0.9), (1.0, 0.0)])
        elif name == 'Head':
            rot[0] = _track(p, [(0.0, 0.0), (0.4, -0.2), (0.7, 0.1), (1.0, 0.0)])
    elif clip == 'dodge':
        if name == 'Body':
            rot[0] = -math.tau * (p * p * (3.0 - 2.0 * p))
        elif name.startswith('Leg'):
            rot[0] = 1.0
        elif name == 'Head':
            rot[0] = 0.5
    elif clip == 'hit':
        if name == 'Body':
            rot[0] = _track(p, [(0.0, 0.0), (0.15, -1.0), (0.5, -0.4), (1.0, 0.0)])
        elif name.startswith('Leg'):
            rot[0] = math.sin(p * 20.0) * 0.35 * (1.0 - p)
        elif name == 'Head':
            rot[0] = _track(p, [(0.0, 0.0), (0.15, -0.5), (1.0, 0.0)])
    elif clip == 'attack':
        if biped:
            if name == 'ArmL':
                rot[0] = _track(p, [(0.0, 0.0), (0.3, -1.6), (0.55, 0.9), (1.0, 0.0)])
            elif name == 'Body':
                rot[0] = _track(p, [(0.0, 0.0), (0.5, 0.15), (1.0, 0.0)])
            elif name == 'Head':
                rot[0] = _track(p, [(0.0, 0.0), (0.3, -0.2), (0.55, 0.15), (1.0, 0.0)])
        else:
            if name == 'Body':
                rot[0] = _track(p, [(0.0, 0.0), (0.3, 0.1), (0.45, 0.55), (0.8, 0.3), (1.0, 0.0)])
            elif name == 'Head':
                rot[0] = _track(p, [(0.0, 0.0), (0.35, -0.2), (0.5, 0.7), (1.0, 0.0)])
            elif name.startswith('Leg') and name.endswith('F'):
                rot[0] = _track(p, [(0.0, 0.0), (0.5, -0.6), (1.0, 0.0)])
            elif name.startswith('Leg'):
                rot[0] = _track(p, [(0.0, 0.0), (0.5, 0.5), (1.0, 0.0)])
    elif clip == 'bark':
        if name == 'Head':
            rot[0] = -0.35 + math.sin(p * math.tau * 6.0) * 0.08
        elif name == 'Tail':
            rot[1] = math.sin(p * math.tau * 4.0) * 0.35
        elif name == 'Body':
            loc[1] = abs(math.sin(p * math.tau * 3.0)) * h * 0.01
    elif clip == 'talk':
        if biped:
            if name == 'ArmR':
                rot[0] = math.sin(phase) * 0.35
            elif name == 'Head':
                rot[0] = math.sin(phase + math.pi * 0.5) * 0.06
        else:
            if name == 'Head':
                rot[0] = math.sin(phase) * 0.10
    return tuple(rot), tuple(loc)

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
    
    for clip, duration in clip_specs(cid):
        action = bpy.data.actions.new(clip)
        rig.animation_data.action = action
        end = round(duration * 24) + 1
        for f in range(1, end + 1):
            t = (f - 1) / (end - 1)
            for pb in rig.pose.bones:
                pb.rotation_mode = 'XYZ'
                rot, loc = clip_pose(clip, t, pb, h, cid)
                pb.rotation_euler = rot
                pb.location = loc
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
    print(f"\nProcessing {cid} with ZERO modification + Yaw alignment + Rigging...")
    folder = BASE / cid
    raw_glb = folder / f'{cid}.glb'
    game_glb = folder / f'{cid}_game.glb'
    preview_png = folder / f'{cid}.png'
    
    if not raw_glb.exists():
        print(f"[{cid}] Raw GLB does not exist: {raw_glb}")
        return 0
        
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    
    bpy.ops.import_scene.gltf(filepath=str(raw_glb))
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    if not meshes:
        print(f"[{cid}] No meshes found in {raw_glb}")
        return 0
        
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
    
    # 1. Rotate to face Blender +Y (Godot -Z forward)
    yaw = YAWS.get(cid, 0)
    if yaw != 0:
        rot = Matrix.Rotation(math.radians(yaw), 3, 'Z')
        for v in obj.data.vertices:
            v.co = rot @ v.co
        obj.data.update()
        bpy.context.view_layer.update()
    
    # 2. Scale to standard character height and ground to Y=0
    bounds = [Vector(c) for c in obj.bound_box]
    low = Vector(tuple(min(p[i] for p in bounds) for i in range(3)))
    high = Vector(tuple(max(p[i] for p in bounds) for i in range(3)))
    scale = HEIGHTS[cid] / (high.z - low.z)
    center = Vector(((low.x + high.x) * 0.5, (low.y + high.y) * 0.5, low.z))
    for v in obj.data.vertices:
        v.co = (v.co - center) * scale
        
    obj.data.update()
    bpy.context.view_layer.update()
    
    # 3. Make Rig
    bounds = [Vector(c) for c in obj.bound_box]
    low = Vector(tuple(min(p[i] for p in bounds) for i in range(3)))
    high = Vector(tuple(max(p[i] for p in bounds) for i in range(3)))
    rig = make_armature(obj, cid, low, high)
    
    # Count triangles
    tri_count = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    print(f"[{cid}] Authentic raw triangles: {tri_count}")
    
    # Export GLB
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
    
    # Render preview PNG with textured shading from front-right
    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_WORKBENCH'
    scene.display.shading.light = 'STUDIO'
    scene.display.shading.color_type = 'TEXTURE'
    scene.display.shading.show_shadows = True
    scene.render.resolution_x = 768
    scene.render.resolution_y = 768
    
    coords = [o.matrix_world @ Vector(c) for o in [obj] for c in o.bound_box]
    min_c = Vector([min(v[i] for v in coords) for i in range(3)])
    max_c = Vector([max(v[i] for v in coords) for i in range(3)])
    cam_center = (min_c + max_c) * 0.5
    size = max(max_c - min_c)
    
    cam_data = bpy.data.cameras.new('Cam')
    cam_data.type = 'ORTHO'
    cam_data.ortho_scale = size * 1.35
    cam = bpy.data.objects.new('Cam', cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    
    # Facing +Y, so front is +Y, right is -X, left is +X
    # To view from front-right (showing face and right ear tag): (-1.4, 1.8, 1.0)
    eye = cam_center + Vector((-1.4, 1.8, 1.0)) * (size / 1.5)
    cam.location = eye
    cam.rotation_euler = (cam_center - eye).to_track_quat('-Z', 'Y').to_euler()
    
    scene.render.filepath = str(preview_png)
    bpy.ops.render.render(write_still=True)
    print(f"[{cid}] Successfully exported {game_glb.name} and rendered {preview_png.name}")
    return tri_count

if __name__ == '__main__':
    cids = ['CHAR_01', 'CHAR_02', 'CHAR_03', 'CHAR_04', 'CHAR_05', 'CHAR_06', 'CHAR_07']
    results = {}
    for cid in cids:
        results[cid] = process_character(cid)
    print("\nSUMMARY:")
    for cid, tris in results.items():
        print(f"  {cid}: {tris} triangles")
