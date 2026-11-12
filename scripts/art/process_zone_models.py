"""
Blender processing for zone-style course models (C0/C2/C3/C4):
- Normalizes mesh transforms and origins
- Scales to the real-world collision bounds from docs/ZONE_STYLE_ASSET_PLAN.md
- Material treatment per zone style:
    pbr  (C0 realistic): keep Roughness/Metallic/normal maps - real lighting
    flat (C2/C3) + neon (C4): flat toon look, keep only the albedo texture
- Decimates triangles to a per-zone cap (C0 6000, others 3500)
- Exports runtime _game.glb next to the raw asset

Usage (Blender coordinates: X/Y ground plane, Z up -> Godot Y):
  blender --background --python scripts/art/process_zone_models.py -- ASSET_ID [ASSET_ID...]
  (no ids after '--' processes every downloaded zone asset)
"""
import bpy
import json
import math
import sys
from pathlib import Path
from mathutils import Vector, Matrix

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'assets/models/aholo'
MANIFEST = BASE / 'zone_assets_production.json'

STYLE_FIELD = {'C0': 'pbr', 'C2': 'flat', 'C3': 'flat', 'C4': 'neon'}
DECIMATE_CAP = {'C0': 6000, 'C2': 3500, 'C3': 3500, 'C4': 3500}

# Dimensions in Blender coordinates (X, Y ground; Z up, which becomes Godot Y):
DIMENSIONS = {
    # ---- C0 nightmare slaughterhouse (photorealistic) ----
    'ENV_C0_FLOOR':        {'target_x': 4.0,  'target_y': 4.0,  'target_z': 0.2,  'ground_bottom': True,  'center_xy': True},
    'ENV_C0_WALL':         {'target_x': 4.0,  'target_y': 0.4,  'target_z': 4.2,  'ground_bottom': True,  'center_xy': True},
    'PROP_C0_CAGE':        {'target_x': 5.0,  'target_y': 2.4,  'target_z': 1.6,  'ground_bottom': True,  'center_xy': True},
    'PROP_C0_CONVEYOR':    {'target_x': 10.0, 'target_y': 7.2,  'target_z': 0.7,  'ground_bottom': True,  'center_xy': True},
    'PROP_C0_MEATHOOK':    {'target_x': 0.5,  'target_y': 0.5,  'target_z': 1.7,  'ground_bottom': False, 'center_xy': True},
    'PROP_C0_STEAM_VENT':  {'target_x': 1.6,  'target_y': 1.6,  'target_z': 0.3,  'ground_bottom': True,  'center_xy': True},
    'PROP_C0_STUN_PROD':   {'target_x': 1.2,  'target_y': 1.2,  'target_z': 1.5,  'ground_bottom': True,  'center_xy': True},
    'PROP_C0_CRATE':       {'target_x': 2.0,  'target_y': 2.0,  'target_z': 1.6,  'ground_bottom': True,  'center_xy': True},
    'PROP_C0_ROLLER_DOOR': {'target_x': 10.0, 'target_y': 0.5,  'target_z': 4.2,  'ground_bottom': True,  'center_xy': True},
    'PROP_C0_PAINTED_DOOR': {'target_x': 2.4, 'target_y': 0.4,  'target_z': 3.2,  'ground_bottom': True,  'center_xy': True},
    'ENV_C0_MACHINERY':    {'target_x': 3.0,  'target_y': 0.8,  'target_z': 3.0,  'ground_bottom': True,  'center_xy': True},
    'PROP_C0_HAZARD_SIGN': {'target_x': 1.6,  'target_y': 0.15, 'target_z': 1.6,  'ground_bottom': False, 'center_xy': True},
    'PROP_C0_LIGHT':       {'target_x': 2.0,  'target_y': 0.5,  'target_z': 0.4,  'ground_bottom': False, 'center_xy': True},
    'PROP_C0_HURDLE':      {'target_x': 11.2, 'target_y': 0.5,  'target_z': 0.55, 'ground_bottom': True,  'center_xy': True},
    # ---- C2 voxel creek (Minecraft) ----
    'ENV_C2_GRASS_BLOCK':    {'target_x': 4.0,  'target_y': 4.0,  'target_z': 1.0,  'ground_bottom': True,  'center_xy': True},
    'ENV_C2_STONE_BLOCK':    {'target_x': 4.0,  'target_y': 4.0,  'target_z': 1.0,  'ground_bottom': True,  'center_xy': True},
    'ENV_C2_CANYON_WALL':    {'target_x': 4.0,  'target_y': 2.0,  'target_z': 6.0,  'ground_bottom': True,  'center_xy': True},
    'PROP_C2_MOSSY_STONE':   {'target_x': 1.6,  'target_y': 1.3,  'target_z': 0.7,  'ground_bottom': True,  'center_xy': True},
    'ENV_C2_OAK_TREE':       {'target_x': 3.2,  'target_y': 3.2,  'target_z': 7.4,  'ground_bottom': True,  'center_xy': True},
    'PROP_C2_NETHER_PORTAL': {'target_x': 6.0,  'target_y': 1.2,  'target_z': 7.2,  'ground_bottom': True,  'center_xy': True},
    'PROP_C2_TNT':           {'target_x': 1.8,  'target_y': 1.8,  'target_z': 1.8,  'ground_bottom': True,  'center_xy': True},
    'PROP_C2_DIRT_BLOCK':    {'target_x': 1.8,  'target_y': 1.8,  'target_z': 1.8,  'ground_bottom': True,  'center_xy': True},
    'PROP_C2_SAND_BLOCK':    {'target_x': 1.8,  'target_y': 1.8,  'target_z': 1.8,  'ground_bottom': True,  'center_xy': True},
    'PROP_C2_SLIME_BLOCK':   {'target_x': 2.0,  'target_y': 2.0,  'target_z': 1.0,  'ground_bottom': True,  'center_xy': True},
    'PROP_C2_PRESSURE_PLATE': {'target_x': 1.4, 'target_y': 1.4,  'target_z': 0.12, 'ground_bottom': True,  'center_xy': True},
    'PROP_C2_SWEET_POTATO':  {'target_x': 0.8,  'target_y': 0.8,  'target_z': 0.6,  'ground_bottom': True,  'center_xy': True},
    'PROP_C2_OBSIDIAN_WALL': {'target_x': 10.0, 'target_y': 1.2,  'target_z': 4.0,  'ground_bottom': True,  'center_xy': True},
    # ---- C3 fairytale woodland (hand-painted) ----
    'ENV_C3_MEADOW_TILE':    {'target_x': 4.0,  'target_y': 4.0,  'target_z': 1.0,  'ground_bottom': True,  'center_xy': True},
    'ENV_C3_GOLD_TILE':      {'target_x': 4.0,  'target_y': 4.0,  'target_z': 1.0,  'ground_bottom': True,  'center_xy': True},
    'ENV_C3_PURPLE_TILE':    {'target_x': 4.0,  'target_y': 4.0,  'target_z': 1.0,  'ground_bottom': True,  'center_xy': True},
    'ENV_C3_TREE':           {'target_x': 4.0,  'target_y': 4.0,  'target_z': 9.0,  'ground_bottom': True,  'center_xy': True},
    'PROP_C3_TOADSTOOL':     {'target_x': 1.8,  'target_y': 1.8,  'target_z': 1.4,  'ground_bottom': True,  'center_xy': True},
    'PROP_C3_CHEST':         {'target_x': 1.4,  'target_y': 1.0,  'target_z': 1.1,  'ground_bottom': True,  'center_xy': True},
    'PROP_C3_MAZE_WALL':     {'target_x': 6.0,  'target_y': 0.8,  'target_z': 2.4,  'ground_bottom': True,  'center_xy': True},
    'PROP_C3_HOLLOW_TREE':   {'target_x': 6.6,  'target_y': 1.4,  'target_z': 7.3,  'ground_bottom': True,  'center_xy': True},
    'PROP_C3_CARDBOARD_BOX': {'target_x': 1.6,  'target_y': 2.0,  'target_z': 1.4,  'ground_bottom': True,  'center_xy': True},
    'PROP_C3_GOLDEN_PINECONE': {'target_x': 0.5, 'target_y': 0.5, 'target_z': 0.6, 'ground_bottom': True,  'center_xy': True},
    'PROP_C3_ILLUSORY_WALL': {'target_x': 10.0, 'target_y': 0.8,  'target_z': 4.5,  'ground_bottom': True,  'center_xy': True},
    'PROP_C3_BOUNCY_MUSHROOM': {'target_x': 2.4, 'target_y': 2.4, 'target_z': 2.2, 'ground_bottom': True,  'center_xy': True},
    'ENV_C3_BUSH':           {'target_x': 1.6,  'target_y': 1.6,  'target_z': 1.2,  'ground_bottom': True,  'center_xy': True},
    # ---- C4 neon courtyard (Fall Guys x Mario Kart) ----
    'ENV_C4_ASPHALT':       {'target_x': 10.0, 'target_y': 10.0, 'target_z': 1.0,  'ground_bottom': True,  'center_xy': True},
    'ENV_C4_GRAVEL':        {'target_x': 10.0, 'target_y': 10.0, 'target_z': 1.0,  'ground_bottom': True,  'center_xy': True},
    'PROP_C4_GUARDRAIL':    {'target_x': 4.0,  'target_y': 0.4,  'target_z': 1.2,  'ground_bottom': True,  'center_xy': True},
    'PROP_C4_BOOST_PAD':    {'target_x': 3.5,  'target_y': 3.0,  'target_z': 0.12, 'ground_bottom': True,  'center_xy': True},
    'PROP_C4_TIRE':         {'target_x': 1.6,  'target_y': 1.6,  'target_z': 1.6,  'ground_bottom': False, 'center_xy': True},
    'PROP_C4_TRAFFIC_CONE': {'target_x': 0.5,  'target_y': 0.5,  'target_z': 0.7,  'ground_bottom': True,  'center_xy': True},
    'PROP_C4_SWEEPER':      {'target_x': 7.6,  'target_y': 0.36, 'target_z': 0.36, 'ground_bottom': False, 'center_xy': True, 'align': 'longest_x'},
    'PROP_C4_NEON_SIGN':    {'target_x': 2.4,  'target_y': 0.3,  'target_z': 2.0,  'ground_bottom': False, 'center_xy': True, 'align': 'longest_x'},
    'PROP_C4_ITEM_BOX':     {'target_x': 1.3,  'target_y': 1.3,  'target_z': 1.3,  'ground_bottom': False, 'center_xy': True},
    'PROP_C4_STUNT_RAMP':   {'target_x': 6.0,  'target_y': 6.0,  'target_z': 2.2,  'ground_bottom': True,  'center_xy': True},
    'PROP_C4_BUMPER':       {'target_x': 1.6,  'target_y': 1.6,  'target_z': 1.5,  'ground_bottom': True,  'center_xy': True},
    'PROP_C4_FINISH_GATE':  {'target_x': 10.0, 'target_y': 1.0,  'target_z': 5.5,  'ground_bottom': True,  'center_xy': True},
    'PROP_C4_START_GANTRY': {'target_x': 10.0, 'target_y': 0.6,  'target_z': 4.6,  'ground_bottom': True,  'center_xy': True},
    'PROP_C4_STADIUM_LIGHT': {'target_x': 1.2, 'target_y': 0.8,  'target_z': 6.8,  'ground_bottom': True,  'center_xy': True},
    'PROP_C4_TIRE_STACK':   {'target_x': 1.4,  'target_y': 1.4,  'target_z': 1.2,  'ground_bottom': True,  'center_xy': True},
}


def set_input(node, names, value):
    """Set the first existing input from `names` (Blender 4.x/5.x renames)."""
    for name in names:
        if name in node.inputs:
            try:
                node.inputs[name].default_value = value
            except Exception:
                pass
            return


def flatten_material(mat):
    """Flat toon treatment: keep albedo texture only (C1 process contract)."""
    if not (mat and mat.node_tree):
        return
    for node in mat.node_tree.nodes:
        if node.type == 'BSDF_PRINCIPLED':
            set_input(node, ['Roughness'], 1.0)
            set_input(node, ['Metallic'], 0.0)
            set_input(node, ['Specular IOR Level', 'Specular'], 0.0)
            for inp_name in ['Normal', 'Metallic', 'Roughness']:
                if inp_name in node.inputs and node.inputs[inp_name].is_linked:
                    for link in list(node.inputs[inp_name].links):
                        mat.node_tree.links.remove(link)


def style_of(asset_id):
    zone = None
    if MANIFEST.exists():
        manifest = json.loads(MANIFEST.read_text(encoding='utf-8'))
        zone = manifest['assets'].get(asset_id, {}).get('zone')
    if zone is None:
        zone = asset_id.split('_')[1] if '_' in asset_id else 'C1'
    return STYLE_FIELD.get(zone, 'flat'), DECIMATE_CAP.get(zone, 3500)


def process(asset_id):
    spec = DIMENSIONS[asset_id]
    folder = BASE / asset_id
    raw_glb = folder / f"{asset_id}.glb"
    if not raw_glb.exists():
        print(f"Skip {asset_id}: raw GLB missing ({raw_glb})", flush=True)
        return False

    style, cap = style_of(asset_id)

    # Fresh scene per asset
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(raw_glb))

    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    if not meshes:
        print(f"Skip {asset_id}: no meshes in GLB", flush=True)
        return False

    # Join into one mesh object, apply transforms (headless empty scenes have
    # no active object, so set it explicitly)
    obj = meshes[0]
    bpy.ops.object.select_all(action='DESELECT')
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = obj
    if len(meshes) > 1:
        bpy.ops.object.join()
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    # Scale to the target bounding box (X/Y ground plane, Z up)
    xs = [v.co.x for v in obj.data.vertices]
    ys = [v.co.y for v in obj.data.vertices]
    zs = [v.co.z for v in obj.data.vertices]
    if not xs:
        print(f"Skip {asset_id}: empty mesh", flush=True)
        return False
    size = Vector((max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs)))
    scale = Vector((
        spec['target_x'] / max(size.x, 1e-4),
        spec['target_y'] / max(size.y, 1e-4),
        spec['target_z'] / max(size.z, 1e-4),
    ))
    for v in obj.data.vertices:
        v.co.x *= scale.x
        v.co.y *= scale.y
        v.co.z *= scale.z

    if spec.get('align') == 'longest_x':
        # Re-measure and rotate so the longest horizontal extent sits on X
        xs = [v.co.x for v in obj.data.vertices]
        ys = [v.co.y for v in obj.data.vertices]
        if (max(ys) - min(ys)) > (max(xs) - min(xs)):
            obj.data.transform(Matrix.Rotation(math.pi / 2.0, 4, 'Z'))
            xs = [v.co.x for v in obj.data.vertices]
            ys = [v.co.y for v in obj.data.vertices]

    xs = [v.co.x for v in obj.data.vertices]
    ys = [v.co.y for v in obj.data.vertices]
    zs = [v.co.z for v in obj.data.vertices]
    cx = (max(xs) + min(xs)) * 0.5
    cy = (max(ys) + min(ys)) * 0.5
    if spec.get('center_xy', True):
        for v in obj.data.vertices:
            v.co.x -= cx
            v.co.y -= cy
    if spec.get('ground_bottom', True):
        min_z = min(zs)
        for v in obj.data.vertices:
            v.co.z -= min_z
    else:
        cz = (max(zs) + min(zs)) * 0.5
        for v in obj.data.vertices:
            v.co.z -= cz
    obj.data.update()

    # Decimate down to the zone cap (preserving UVs and materials)
    triangles = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    print(f"Raw triangles for {asset_id} ({style}): {triangles}", flush=True)
    if triangles > cap:
        dec = obj.modifiers.new('Decimate', 'DECIMATE')
        dec.ratio = cap / float(triangles)
        bpy.ops.object.modifier_apply(modifier=dec.name)
        triangles = sum(len(p.vertices) - 2 for p in obj.data.polygons)
        print(f"Decimated to: {triangles} triangles", flush=True)

    # Material treatment per zone style
    if style != 'pbr':
        for mat in obj.data.materials:
            flatten_material(mat)

    out_glb = folder / f"{asset_id}_game.glb"
    bpy.ops.export_scene.gltf(
        filepath=str(out_glb),
        use_selection=True,
        export_format='GLB',
        export_cameras=False,
        export_lights=False,
        export_yup=True,
    )
    print(f"Successfully exported game model ({style}): {out_glb}", flush=True)
    return True


def main():
    argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
    ids = argv if argv else sorted(
        aid for aid in DIMENSIONS
        if (BASE / aid / f"{aid}.glb").exists()
    )
    for aid in ids:
        if aid in DIMENSIONS:
            process(aid)
        else:
            print(f"Unknown asset id: {aid}", flush=True)


if __name__ == '__main__':
    main()
