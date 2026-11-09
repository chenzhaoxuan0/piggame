"""Textured orthographic QA views (front + iso) of course runtime GLBs."""
import bpy
import sys
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'builds/course_qa'
OUT.mkdir(parents=True, exist_ok=True)

for a in sys.argv[sys.argv.index('--') + 1:]:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(ROOT / 'assets/models/aholo' / a / (a + '_game.glb')))
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    coords = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
    lo = Vector([min(v[i] for v in coords) for i in range(3)])
    hi = Vector([max(v[i] for v in coords) for i in range(3)])
    mid = (lo + hi) / 2
    size = max(hi - lo)
    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_WORKBENCH'
    scene.view_settings.view_transform = 'Standard'
    scene.display.shading.light = 'FLAT'
    scene.display.shading.color_type = 'TEXTURE'
    scene.display.shading.show_shadows = False
    scene.display.shading.background_type = 'WORLD'
    if scene.world is None:
        scene.world = bpy.data.worlds.new('QAWorld')
    scene.world.color = (0.75, 0.75, 0.75)
    scene.render.resolution_x = 384
    scene.render.resolution_y = 384
    scene.render.resolution_percentage = 100
    bpy.ops.object.camera_add()
    camera = bpy.context.object
    camera.data.type = 'ORTHO'
    camera.data.ortho_scale = size * 1.15
    scene.camera = camera
    for view, direction in [('front', (0, -1, 0.03)), ('iso', (1, -1, 0.8))]:
        camera.location = mid + Vector(direction).normalized() * size * 3
        camera.rotation_euler = (mid - camera.location).to_track_quat('-Z', 'Y').to_euler()
        scene.render.image_settings.file_format = 'PNG'
        scene.render.filepath = str(OUT / f'{a}_{view}.png')
        bpy.ops.render.render(write_still=True)
    print(a, 'QA views rendered', flush=True)