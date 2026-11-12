"""
Produce zone-style 3D assets (C0/C2/C3/C4) for the hidden courses using Aholo
Lux3D via MCP. Tracks assets in assets/models/aholo/zone_assets_production.json.

Hard rule (AGENTS.md 3.1 / user requirement): MCP-direct outputs cannot be
recovered later, so `collect` downloads the RAW export into
assets/models/aholo/<ASSET_ID>/ (raw .glb + preview .png) BEFORE any processing.

Usage:
  python scripts/art/produce_zone_assets.py submit  [--zone C0|C2|C3|C4]
  python scripts/art/produce_zone_assets.py collect [--zone C0|C2|C3|C4]
  python scripts/art/produce_zone_assets.py status
  python scripts/art/produce_zone_assets.py catalog [--zone C0|C2|C3|C4]
"""
import argparse
import hashlib
import json
import os
import shutil
import subprocess
import urllib.request
import zipfile
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'assets/models/aholo'
MANIFEST = BASE / 'zone_assets_production.json'
CACHE = ROOT / 'builds/lux3d'
CATALOG = BASE / 'runtime_catalog.json'

# Per-zone style headers + shared anti-pollution suffix (C1-proven template).
SUFFIX = ('No floor, no ground plane, no pedestal, no background, no cast shadow '
          'geometry, no extra objects, no text. Complete object with intact base. '
          'Single object only.')

HEADERS = {
    'C0': ('A single isolated freestanding game asset. Photorealistic industrial '
           'slaughterhouse factory equipment: worn painted steel, stained grey '
           'concrete, aged metal, subtle surface grime and scratches, matte '
           'industrial finish, realistic weathering, not cartoonish. '),
    'C2': ('A single isolated freestanding game asset in the blocky voxel style of '
           'Minecraft. Constructed entirely from clean cubic voxel blocks with flat '
           'pixel-art color cells and sharp 90-degree edges. '),
    'C3': ('A single isolated freestanding game asset in hand-painted storybook '
           'fairy-tale style. Soft rounded shapes, warm painterly colors, gentle '
           'brush-stroke texture, whimsical children\'s book illustration look. '),
    'C4': ('A single isolated freestanding game asset in the style of a Fall Guys '
           'neon variety-show arena mixed with Mario Kart arcade racing. Glossy '
           'saturated candy colors, chunky toy-like shapes, bold glowing neon '
           'accents, playful TV-game-show look. '),
}

def P(zone, body):
    return HEADERS[zone] + body + ' ' + SUFFIX

SPECS = {
    # ---------------- C0 nightmare slaughterhouse (photorealistic) ----------------
    'ENV_C0_FLOOR': {
        'zone': 'C0', 'style': 'photorealistic', 'faceCount': 20000,
        'prompt': P('C0', 'One square concrete factory floor tile, four metres wide, '
        'light grey concrete slab with darker expansion joint grooves along the edges, '
        'faint dark stains and scuff marks, shallow chamfered corners, flat slab 0.2 '
        'metres thick.'),
    },
    'ENV_C0_WALL': {
        'zone': 'C0', 'style': 'photorealistic', 'faceCount': 20000,
        'prompt': P('C0', 'One straight industrial wall panel segment four metres long '
        'and four point two metres tall, stained grey concrete lower half with a dark '
        'steel upper band, one thin faded amber safety stripe near the top, flat '
        'rectangular panel 0.4 metres thick, clean vertical edges.'),
    },
    'PROP_C0_CAGE': {
        'zone': 'C0', 'style': 'photorealistic', 'faceCount': 20000,
        'prompt': P('C0', 'One steel livestock holding cage, rectangular frame of worn '
        'grey-painted steel tube with nine vertical bars on the front face, riveted '
        'corner plates, flat metal top grate, slightly rusted bolts, cage standing on '
        'four short feet.'),
    },
    'PROP_C0_CONVEYOR': {
        'zone': 'C0', 'style': 'photorealistic', 'faceCount': 20000,
        'prompt': P('C0', 'One industrial belt conveyor section, long flat dark rubber '
        'belt on a riveted steel side frame with visible end rollers and a small motor '
        'box on one end, standing on two A-shaped steel legs, belt surface with faint '
        'transverse wear marks.'),
    },
    'PROP_C0_MEATHOOK': {
        'zone': 'C0', 'style': 'photorealistic', 'faceCount': 20000,
        'prompt': P('C0', 'One heavy steel meat hook hanging on a short chain, polished '
        'worn steel hook with blunt rounded tip, three forged chain links above it, '
        'single hook assembly.'),
    },
    'PROP_C0_STEAM_VENT': {
        'zone': 'C0', 'style': 'photorealistic', 'faceCount': 10000,
        'prompt': P('C0', 'One round floor steam vent grate, dark cast iron ring with '
        'radial slats over a dark opening, four hex bolts, squat ring shape one point '
        'six metres across.'),
    },
    'PROP_C0_STUN_PROD': {
        'zone': 'C0', 'style': 'photorealistic', 'faceCount': 10000,
        'prompt': P('C0', 'One industrial electric shocker pillar, vertical yellow and '
        'black hazard striped cylinder on a heavy round base ring, small red indicator '
        'lamp near the top, worn paint.'),
    },
    'PROP_C0_CRATE': {
        'zone': 'C0', 'style': 'photorealistic', 'faceCount': 10000,
        'prompt': P('C0', 'One wooden shipping crate, chunky box of weathered pale pine '
        'planks with darker corner battens and cross braces on the faces, worn '
        'surfaces, proportions two wide, one point six tall, two deep.'),
    },
    'PROP_C0_ROLLER_DOOR': {
        'zone': 'C0', 'style': 'photorealistic', 'faceCount': 20000,
        'prompt': P('C0', 'One industrial roller shutter door, ten metres wide and four '
        'point two metres tall, horizontal corrugated steel slats in faded grey green, '
        'small faded red signal lamp housing centered on the top rail, flat door face, '
        'steel guide rails on both sides.'),
    },
    'PROP_C0_PAINTED_DOOR': {
        'zone': 'C0', 'style': 'photorealistic', 'faceCount': 10000,
        'prompt': P('C0', 'One flat painted fake door on a thin concrete wall panel, two '
        'point four metres wide and three point two metres tall, cheap wooden door '
        'shape painted directly onto the grey concrete wall, a crude childlike yellow '
        'crayon sun painted above the door shape, flaking paint edges.'),
    },
    'ENV_C0_MACHINERY': {
        'zone': 'C0', 'style': 'photorealistic', 'faceCount': 20000,
        'prompt': P('C0', 'One wall-mounted factory machinery cluster, grey steel '
        'electrical cabinet with riveted door, two vertical pipes with flanges and one '
        'round valve wheel, small conduit tray above, mounted on a flat backplate three '
        'metres wide and three metres tall.'),
    },
    'PROP_C0_HAZARD_SIGN': {
        'zone': 'C0', 'style': 'photorealistic', 'faceCount': 10000,
        'prompt': P('C0', 'One hanging industrial warning sign, square yellow metal '
        'plate with a bold black exclamation triangle symbol printed on it, thin steel '
        'frame border, two small chain eyelets on top edge, slight paint wear.'),
    },
    'PROP_C0_LIGHT': {
        'zone': 'C0', 'style': 'photorealistic', 'faceCount': 10000,
        'prompt': P('C0', 'One industrial fluorescent light fixture, long slim white '
        'tube behind a grey metal reflector trough two metres long, two thin suspension '
        'rods on top, clean simple housing.'),
    },
    'PROP_C0_HURDLE': {
        'zone': 'C0', 'style': 'photorealistic', 'faceCount': 10000,
        'prompt': P('C0', 'One low industrial jump hurdle, eleven metres long light '
        'steel barrier beam half a metre tall on small square feet, faded amber and '
        'white diagonal hazard stripes along the beam face.'),
    },

    # ---------------- C2 voxel creek (Minecraft) ----------------
    'ENV_C2_GRASS_BLOCK': {
        'zone': 'C2', 'style': 'cartoon', 'faceCount': 10000,
        'prompt': P('C2', 'One giant voxel grass ground block, four metre square slab '
        'with bright green pixel grass top face and brown pixel dirt sides, clean cubic '
        'voxel texture of flat square color cells.'),
    },
    'ENV_C2_STONE_BLOCK': {
        'zone': 'C2', 'style': 'cartoon', 'faceCount': 10000,
        'prompt': P('C2', 'One giant voxel stone ground block, four metre square slab '
        'of grey cobblestone voxel cells on the top face and darker stone brick voxel '
        'sides, flat square cell texture.'),
    },
    'ENV_C2_CANYON_WALL': {
        'zone': 'C2', 'style': 'cartoon', 'faceCount': 10000,
        'prompt': P('C2', 'One tall voxel cliff wall segment, vertical face of stacked '
        'grey cobblestone cube cells with a few brown dirt voxel cells mixed in near '
        'the bottom, four metres wide, six metres tall, two metres thick.'),
    },
    'PROP_C2_MOSSY_STONE': {
        'zone': 'C2', 'style': 'cartoon', 'faceCount': 10000,
        'prompt': P('C2', 'One mossy cobblestone stepping stone block, single grey '
        'voxel stone cube with bright green moss pixel cells across the top face.'),
    },
    'ENV_C2_OAK_TREE': {
        'zone': 'C2', 'style': 'cartoon', 'faceCount': 10000,
        'prompt': P('C2', 'One Minecraft-style voxel oak tree, brown voxel wood trunk '
        'column with a big solid bright green voxel leaf cube canopy on top, classic '
        'cubic blocky look.'),
    },
    'PROP_C2_NETHER_PORTAL': {
        'zone': 'C2', 'style': 'cartoon', 'faceCount': 10000,
        'prompt': P('C2', 'One Minecraft-style nether portal, rectangular frame of dark '
        'purple-black obsidian voxel blocks around a swirling violet portal interior of '
        'layered purple voxel shades, standing upright on a base block.'),
    },
    'PROP_C2_TNT': {
        'zone': 'C2', 'style': 'cartoon', 'faceCount': 10000,
        'prompt': P('C2', 'One Minecraft-style TNT voxel block, single red cube with a '
        'white pixel band around the middle carrying three blocky black letter shapes, '
        'flat pixel texture.'),
    },
    'PROP_C2_DIRT_BLOCK': {
        'zone': 'C2', 'style': 'cartoon', 'faceCount': 10000,
        'prompt': P('C2', 'One Minecraft-style dirt voxel block, single brown cube of '
        'flat pixel dirt cells with a few darker speckles.'),
    },
    'PROP_C2_SAND_BLOCK': {
        'zone': 'C2', 'style': 'cartoon', 'faceCount': 10000,
        'prompt': P('C2', 'One Minecraft-style gravity sand voxel block, single golden '
        'yellow cube of flat pixel sand cells with slight tone variation.'),
    },
    'PROP_C2_SLIME_BLOCK': {
        'zone': 'C2', 'style': 'cartoon', 'faceCount': 10000,
        'prompt': P('C2', 'One Minecraft-style slime voxel block, single glossy green '
        'cube with a darker green square core inset on each face, shiny toy look.'),
    },
    'PROP_C2_PRESSURE_PLATE': {
        'zone': 'C2', 'style': 'cartoon', 'faceCount': 10000,
        'prompt': P('C2', 'One Minecraft-style stone pressure plate, flat grey stone '
        'slab, thin and low, lying flat with two pixel tones on top.'),
    },
    'PROP_C2_SWEET_POTATO': {
        'zone': 'C2', 'style': 'cartoon', 'faceCount': 10000,
        'prompt': P('C2', 'One Minecraft-style sweet potato, chunky pixel-art orange '
        'brown tuber with tapered ends and darker pixel speckles, blocky item look.'),
    },
    'PROP_C2_OBSIDIAN_WALL': {
        'zone': 'C2', 'style': 'cartoon', 'faceCount': 10000,
        'prompt': P('C2', 'One Minecraft-style obsidian wall section, wide row of dark '
        'purple-black obsidian voxel cubes with deep purple sheen flecks, ten metres '
        'wide, four metres tall, one point two metres thick.'),
    },

    # ---------------- C3 fairytale woodland (hand-painted) ----------------
    'ENV_C3_MEADOW_TILE': {
        'zone': 'C3', 'style': 'hand_painted', 'faceCount': 10000,
        'prompt': P('C3', 'One hand-painted storybook meadow ground tile, four metre '
        'square soft grass green dotted with tiny painted daisies and clover, gently '
        'rounded soil edges at the sides, painterly brush texture.'),
    },
    'ENV_C3_GOLD_TILE': {
        'zone': 'C3', 'style': 'hand_painted', 'faceCount': 10000,
        'prompt': P('C3', 'One hand-painted storybook golden meadow tile, four metre '
        'square warm cream-gold grass dotted with little painted buttercups, rounded '
        'soil sides, painterly brush texture.'),
    },
    'ENV_C3_PURPLE_TILE': {
        'zone': 'C3', 'style': 'hand_painted', 'faceCount': 10000,
        'prompt': P('C3', 'One hand-painted storybook wisteria path tile, four metre '
        'square soft violet grass scattered with painted purple foxglove flowers, '
        'rounded soil sides, painterly brush texture.'),
    },
    'ENV_C3_TREE': {
        'zone': 'C3', 'style': 'hand_painted', 'faceCount': 10000,
        'prompt': P('C3', 'One whimsical hand-painted storybook tree, tall brown curvy '
        'trunk with wood swirl strokes, big rounded puffy canopy of layered soft green '
        'leaf blobs, tiny painted highlights, fairy-tale children\'s book look.'),
    },
    'PROP_C3_TOADSTOOL': {
        'zone': 'C3', 'style': 'hand_painted', 'faceCount': 10000,
        'prompt': P('C3', 'One hand-painted storybook toadstool mushroom, fat cream '
        'stem and glossy red cap with white polka dots, slightly tilted cap, soft '
        'rounded shapes, painterly texture.'),
    },
    'PROP_C3_CHEST': {
        'zone': 'C3', 'style': 'hand_painted', 'faceCount': 10000,
        'prompt': P('C3', 'One hand-painted storybook treasure chest, rounded wooden '
        'chest in warm mahogany brown with gold trim bands, curved lid closed, big '
        'golden keyhole plate on the front, soft painterly shading.'),
    },
    'PROP_C3_MAZE_WALL': {
        'zone': 'C3', 'style': 'hand_painted', 'faceCount': 10000,
        'prompt': P('C3', 'One hand-painted storybook stone maze wall segment, six '
        'metres long, mossy grey-green rounded stone blocks with small painted ivy '
        'leaves creeping over the top, soft fairy-tale texture.'),
    },
    'PROP_C3_HOLLOW_TREE': {
        'zone': 'C3', 'style': 'hand_painted', 'faceCount': 10000,
        'prompt': P('C3', 'One giant hollow fairy-tale tree trunk arch, enormous rounded '
        'brown trunk with a tall doorway arch cut through the middle, leafy green crown '
        'spilling over the top, hand-painted storybook style.'),
    },
    'PROP_C3_CARDBOARD_BOX': {
        'zone': 'C3', 'style': 'hand_painted', 'faceCount': 10000,
        'prompt': P('C3', 'One plain cardboard moving box, light tan kraft cardboard '
        'cube with slightly open top flaps and a packing tape strip, soft rounded '
        'edges, clean simple prop.'),
    },
    'PROP_C3_GOLDEN_PINECONE': {
        'zone': 'C3', 'style': 'hand_painted', 'faceCount': 10000,
        'prompt': P('C3', 'One golden pinecone, chunky stylized pinecone with layered '
        'rounded scales, warm metallic gold, hand-painted storybook style.'),
    },
    'PROP_C3_ILLUSORY_WALL': {
        'zone': 'C3', 'style': 'hand_painted', 'faceCount': 10000,
        'prompt': P('C3', 'One faintly shimmering stone wall segment, ten metres wide, '
        'pale grey-blue rounded stone blocks with a subtle magical pale violet glow '
        'along the cracks between blocks, hand-painted fairy-tale style.'),
    },
    'PROP_C3_BOUNCY_MUSHROOM': {
        'zone': 'C3', 'style': 'hand_painted', 'faceCount': 10000,
        'prompt': P('C3', 'One giant bouncy storybook mushroom, springy red and white '
        'spotted cap like a trampoline on a thick cream stem, playful toy proportions, '
        'hand-painted look.'),
    },
    'ENV_C3_BUSH': {
        'zone': 'C3', 'style': 'hand_painted', 'faceCount': 10000,
        'prompt': P('C3', 'One hand-painted storybook bush, rounded cluster of layered '
        'green leaf blobs with a few tiny painted flowers, soft fairy-tale texture.'),
    },

    # ---------------- C4 neon courtyard (Fall Guys x Mario Kart) ----------------
    'ENV_C4_ASPHALT': {
        'zone': 'C4', 'style': 'cartoon', 'faceCount': 10000,
        'prompt': P('C4', 'One arcade racing track asphalt tile, ten metre square dark '
        'navy asphalt slab with glossy sheen, thin glowing cyan neon lane edge strip '
        'along two opposite sides, subtle tire mark smudges, toy-like game arena look.'),
    },
    'ENV_C4_GRAVEL': {
        'zone': 'C4', 'style': 'cartoon', 'faceCount': 10000,
        'prompt': P('C4', 'One gravel infield tile for a neon game arena, ten metre '
        'square sandy tan gravel with chunky rounded pebble clusters and slightly '
        'darker blotches, toy-like game look.'),
    },
    'PROP_C4_GUARDRAIL': {
        'zone': 'C4', 'style': 'cartoon', 'faceCount': 10000,
        'prompt': P('C4', 'One neon arena guardrail segment, four metre long glossy '
        'dark barrier beam with a bright glowing neon light strip along its full top '
        'edge, two chunky support feet, Fall Guys TV-show style.'),
    },
    'PROP_C4_BOOST_PAD': {
        'zone': 'C4', 'style': 'cartoon', 'faceCount': 10000,
        'prompt': P('C4', 'One arcade racing boost pad, flat glossy platform plate with '
        'three bold forward chevron arrows in glowing yellow-orange on a bright yellow '
        'top, thick dark base rim.'),
    },
    'PROP_C4_TIRE': {
        'zone': 'C4', 'style': 'cartoon', 'faceCount': 10000,
        'prompt': P('C4', 'One giant glossy black racing tire, chunky rounded tire with '
        'deep tread block pattern around the rim and a small silver hub disc in the '
        'centre, toy-like arcade look. Complete tire.'),
    },
    'PROP_C4_TRAFFIC_CONE': {
        'zone': 'C4', 'style': 'cartoon', 'faceCount': 10000,
        'prompt': P('C4', 'One bright traffic cone, glossy orange cone with one white '
        'reflective band and a square base plate, chunky toy proportions, slight neon '
        'glow look.'),
    },
    'PROP_C4_SWEEPER': {
        'zone': 'C4', 'style': 'cartoon', 'faceCount': 10000,
        'prompt': P('C4', 'One neon rotating sweeper bar, long horizontal glossy round '
        'beam in glowing hot pink with a bright cyan neon band near both rounded ends, '
        'small chrome hub at the exact centre. Straight uniform beam.'),
    },
    'PROP_C4_NEON_SIGN': {
        'zone': 'C4', 'style': 'cartoon', 'faceCount': 10000,
        'prompt': P('C4', 'One neon signboard pendulum weight, rounded rectangular '
        'glossy sign panel in deep pink with a glowing white star emblem and a neon '
        'tube border, two mount eyelets on top edge.'),
    },
    'PROP_C4_ITEM_BOX': {
        'zone': 'C4', 'style': 'cartoon', 'faceCount': 10000,
        'prompt': P('C4', 'One arcade item box, glossy golden yellow cube with rounded '
        'corners and a bold white question mark emblem on the front face, floating toy '
        'look.'),
    },
    'PROP_C4_STUNT_RAMP': {
        'zone': 'C4', 'style': 'cartoon', 'faceCount': 10000,
        'prompt': P('C4', 'One giant arcade stunt jump ramp, wide upward sloping wedge '
        'in glossy dark navy with glowing yellow-orange chevron stripes up the slope '
        'face and chunky side rails, toy-like arena look.'),
    },
    'PROP_C4_BUMPER': {
        'zone': 'C4', 'style': 'cartoon', 'faceCount': 10000,
        'prompt': P('C4', 'One neon pinball bumper pillar, glossy white cylindrical '
        'base with a glowing hot pink dome cap and a bright cyan ring band under the '
        'cap, chunky toy proportions.'),
    },
    'PROP_C4_FINISH_GATE': {
        'zone': 'C4', 'style': 'cartoon', 'faceCount': 20000,
        'prompt': P('C4', 'One festive neon finish gate arch, two glossy chunky posts '
        'in deep navy with glowing cyan strips, joined by a wide top beam carrying a '
        'bright white and black checkered flag banner, glowing pink accent bulbs, ten '
        'metres wide, freestanding arch structure.'),
    },
    'PROP_C4_START_GANTRY': {
        'zone': 'C4', 'style': 'cartoon', 'faceCount': 10000,
        'prompt': P('C4', 'One racing start line gantry, wide flat beam across two '
        'chunky posts with three round traffic lamp housings in red amber green on the '
        'beam face, glossy toy arena style, ten metres wide, freestanding.'),
    },
    'PROP_C4_STADIUM_LIGHT': {
        'zone': 'C4', 'style': 'cartoon', 'faceCount': 10000,
        'prompt': P('C4', 'One stadium floodlight tower, tall slim dark pole with a '
        'wide rounded lamp head of four bright glowing bulbs behind a frame on top, '
        'chunky toy look.'),
    },
    'PROP_C4_TIRE_STACK': {
        'zone': 'C4', 'style': 'cartoon', 'faceCount': 10000,
        'prompt': P('C4', 'One stack of three black racing tires, chunky glossy tires '
        'stacked with slight offsets, a small white painted stripe on the top tire '
        'sidewall, toy-like arcade look.'),
    },
}

STYLE_FIELD = {'C0': 'pbr', 'C2': 'flat', 'C3': 'flat', 'C4': 'neon'}


def call_mcp(operation, args, cache_key):
    CACHE.mkdir(parents=True, exist_ok=True)
    argfile = CACHE / f"{cache_key}_args.json"
    outfile = CACHE / f"{cache_key}_resp.json"
    argfile.write_text(json.dumps(args, ensure_ascii=False), encoding='utf-8')
    subprocess.run(['node', str(ROOT / 'scripts/art/lux3d_client.mjs'), operation,
                    str(argfile), str(outfile)], cwd=ROOT, check=True)
    resp = json.loads(outfile.read_text(encoding='utf-8'))
    if resp.get('isError'):
        raise RuntimeError(f"MCP error: {resp}")
    text_content = next(c['text'] for c in resp['content'] if c['type'] == 'text')
    return json.loads(text_content)


def download(url, destination):
    destination.parent.mkdir(parents=True, exist_ok=True)
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    with urllib.request.urlopen(req, timeout=120) as response:
        destination.write_bytes(response.read())


def load_manifest():
    if MANIFEST.exists():
        return json.loads(MANIFEST.read_text(encoding='utf-8'))
    return {
        'schema': 1,
        'description': ('Zone-style course assets (C0 realistic, C2 voxel, C3 '
                        'hand-painted, C4 neon) produced with Aholo Lux3D. '
                        'Raw exports are kept per AGENTS.md 3.1 for asset reuse.'),
        'assets': {},
    }


def save_manifest(data):
    BASE.mkdir(parents=True, exist_ok=True)
    temp = MANIFEST.with_suffix('.tmp')
    temp.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    os.replace(temp, MANIFEST)


def zone_of(asset_id):
    return SPECS[asset_id]['zone']


def selected(zone_filter):
    return {k: v for k, v in SPECS.items() if zone_filter is None or v['zone'] == zone_filter}


def submit_all(data, zone_filter):
    for asset_id, spec in selected(zone_filter).items():
        rec = data['assets'].setdefault(asset_id, {})
        if rec.get('task_id'):
            print(f"[{asset_id}] Already submitted with task_id: {rec['task_id']}")
            continue
        print(f"[{asset_id}] Submitting text_to_3d ({spec['style']})...")
        args = {
            'prompt': spec['prompt'],
            'style': spec['style'],
            'version': 'G1-Turbo',
            'faceCount': spec['faceCount'],
            'outputFormat': ['zip', 'glb'],
            'enablePbr': True,
            'aiPredictSize': False,
            'wait': False,
        }
        res = call_mcp('lux3d_text_to_3d', args, f"zone_submit_{asset_id}")
        rec.update(
            task_id=res['taskId'],
            prompt=spec['prompt'],
            style=spec['style'],
            zone=spec['zone'],
            faceCount=spec['faceCount'],
            status='submitted',
            submitted_at=datetime.now(timezone.utc).isoformat(),
        )
        save_manifest(data)
        print(f"[{asset_id}] Submitted -> taskId: {res['taskId']}")


def check_and_collect(data, zone_filter):
    for asset_id, rec in data['assets'].items():
        if asset_id not in SPECS or (zone_filter and SPECS[asset_id]['zone'] != zone_filter):
            continue
        task_id = rec.get('task_id')
        if not task_id or rec.get('status') == 'downloaded':
            continue
        print(f"[{asset_id}] Checking status for task {task_id}...")
        res = call_mcp('lux3d_get_task', {'taskId': task_id}, f"zone_check_{asset_id}_{task_id}")
        status = res.get('status')
        rec['remote_status'] = status
        print(f"[{asset_id}] Remote status: {status} (0:init, 1:running, 3:done, 4:fail)")
        if status == 3:
            print(f"[{asset_id}] Task completed! Downloading RAW exports first...")
            folder = BASE / asset_id
            folder.mkdir(parents=True, exist_ok=True)
            for out in res.get('outputs', []):
                url = out.get('content', '')
                clean_url = url.split('?')[0]
                ext = clean_url.rsplit('.', 1)[-1].lower()
                if ext in ['zip', 'glb', 'png', 'jpg']:
                    target = folder / (f"{asset_id}_lux3d.zip" if ext == 'zip' else f"{asset_id}.{ext}")
                    print(f"  Downloading {ext} -> {target.name}...")
                    download(url, target)
            glb_path = folder / f"{asset_id}.glb"
            zip_path = folder / f"{asset_id}_lux3d.zip"
            if not glb_path.exists() and zip_path.exists():
                with zipfile.ZipFile(zip_path) as z:
                    for name in z.namelist():
                        if name.lower().endswith('.glb'):
                            glb_path.write_bytes(z.read(name))
                            break
            if glb_path.exists():
                rec.update(
                    status='downloaded',
                    raw_model=glb_path.relative_to(ROOT).as_posix(),
                    sha256=hashlib.sha256(glb_path.read_bytes()).hexdigest(),
                    downloaded_at=datetime.now(timezone.utc).isoformat(),
                )
                print(f"[{asset_id}] RAW asset saved: {glb_path}")
            else:
                print(f"[{asset_id}] Warning: GLB not found in outputs")
        elif status in [4, 6]:
            rec['status'] = 'failed'
            print(f"[{asset_id}] Task failed or cancelled!")
        save_manifest(data)


def update_catalog(data, zone_filter):
    if not CATALOG.exists():
        raise SystemExit('runtime_catalog.json missing')
    catalog = json.loads(CATALOG.read_text(encoding='utf-8'))
    updated = 0
    for asset_id, spec in selected(zone_filter).items():
        rec = data['assets'].get(asset_id, {})
        game_glb = BASE / asset_id / f"{asset_id}_game.glb"
        if not rec.get('status') == 'downloaded' or not game_glb.exists():
            print(f"[{asset_id}] skipped (not downloaded/processed)")
            continue
        catalog['assets'][asset_id] = {
            'path': f"res://assets/models/aholo/{asset_id}/{asset_id}_game.glb",
            'accepted': True,
            'yaw_degrees': 0,
            'style': STYLE_FIELD[spec['zone']],
            'zone': spec['zone'],
            'triangles': rec.get('triangles', -1),
            'validation': f"Zone-style asset ({spec['zone']}); processed via process_zone_models.py",
        }
        updated += 1
    temp = CATALOG.with_suffix('.json.tmp')
    temp.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    os.replace(temp, CATALOG)
    print(f"Catalog updated: {updated} assets added")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['submit', 'collect', 'status', 'catalog'])
    parser.add_argument('--zone', choices=['C0', 'C2', 'C3', 'C4'], default=None)
    args = parser.parse_args()
    data = load_manifest()
    if args.action == 'submit':
        submit_all(data, args.zone)
    elif args.action == 'collect':
        check_and_collect(data, args.zone)
    elif args.action == 'catalog':
        update_catalog(data, args.zone)
    else:
        for asset_id, spec in selected(args.zone).items():
            rec = data['assets'].get(asset_id, {})
            print(f"{asset_id}: task={rec.get('task_id')} status={rec.get('status')} "
                  f"remote={rec.get('remote_status')}")


if __name__ == '__main__':
    main()
