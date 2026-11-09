"""
Produce Course 1 3D assets for the obstacle course using Aholo Lux3D via MCP.
Tracks assets in assets/models/aholo/course_production.json.
Downloads ZIP/GLB/PNG and processes them for Godot.
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
MANIFEST = BASE / 'course_production.json'
CACHE = ROOT / 'builds/lux3d'

SPECS = {
    'PROP_C1_BUMPER': {
        'prompt': 'A single isolated freestanding game asset in the visual style of Untitled Goose Game and Fall Guys. Minimal low polygon, matte solid broad color blocks, softly rounded edges. No photorealism, no detailed texture, no noise, no floor, no ground plane, no pedestal, no background, no cast shadow geometry, no extra objects, no text. Complete object with intact base. One colorful inflatable bumper pillar for an obstacle course, thick cylindrical body in bright magenta pink with a golden yellow domed rubber cap on top and soft beveled circular base ring. Simple clean toy-like arcade obstacle.',
        'target_height': 1.1,
        'existing_task': 5035984,
        'palette': ['FF1493', 'FF69B4', 'FFD700', '00E5FF', '2C3E50'],
        'faceCount': 10000,
    },
    'PROP_C1_HAMMER': {
        'prompt': 'A single isolated freestanding game asset in the visual style of Untitled Goose Game. Minimal low polygon, matte solid broad color blocks, softly rounded edges. No photorealism, no detailed texture, no noise, no floor, no ground plane, no pedestal, no background, no cast shadow geometry, no extra objects, no text. Complete object with intact base. One heavy oversized cartoon wooden mallet hammer head, chunky cuboid block of rich oak wood with chamfered corners, dark grey iron bands around both ends, and a short round wooden handle socket. Comic slapstick prop.',
        'target_height': 0.9,
        'palette': ['8D7B68', 'A0855B', '5D6D7E', '34495E', 'E67E22'],
        'faceCount': 10000,
    },
    'PROP_C1_PENDULUM': {
        'prompt': 'A single isolated freestanding game asset in the visual style of Untitled Goose Game. Minimal low polygon, matte solid broad color blocks, softly rounded edges. No photorealism, no detailed texture, no noise, no floor, no ground plane, no pedestal, no background, no cast shadow geometry, no extra objects, no text. Complete object with intact base. One heavy cast iron spherical wrecking ball, dark slate grey matte iron, subtle low-poly facets, four blunt conical studs around equator, large sturdy iron suspension ring on top. Complete sphere.',
        'target_height': 1.5,
        'palette': ['34495E', '2C3E50', '7F8C8D', '95A5A6'],
        'faceCount': 10000,
    },
    'PROP_C1_DOOR': {
        'prompt': 'A single isolated freestanding game asset in the visual style of Untitled Goose Game and Fall Guys. Minimal low polygon, matte solid broad color blocks, softly rounded edges. No photorealism, no detailed texture, no noise, no floor, no ground plane, no pedestal, no background, no cast shadow geometry, no extra objects, no text. Complete object with intact base. One cartoon wooden barrier door panel for an obstacle race, bright orange red painted vertical wood planks with horizontal cross beams and diagonal brace, bold white painted question mark in center. Chunky foam-like toy door.',
        'target_height': 2.6,
        'palette': ['E74C3C', 'C0392B', 'F39C12', 'FFFFFF', '34495E'],
        'faceCount': 10000,
    },
    'PROP_C1_PIPE': {
        'prompt': 'A single isolated freestanding game asset in the visual style of Untitled Goose Game. Minimal low polygon, matte solid broad color blocks, softly rounded edges. No photorealism, no detailed texture, no noise, no floor, no ground plane, no pedestal, no background, no cast shadow geometry, no extra objects, no text. Complete object with intact base. One classic retro green warp pipe, chunky upright cylinder in bold emerald green with an enlarged round protruding top collar rim and dark hollow interior at the top. Clean arcade obstacle prop.',
        'target_height': 1.2,
        'palette': ['2E7D32', '388E3C', '1B5E20', '1E272C'],
        'faceCount': 10000,
    },
    'PROP_C1_LAUNCHPAD': {
        'prompt': 'A single isolated freestanding game asset in the visual style of Untitled Goose Game and Fall Guys. Minimal low polygon, matte solid broad color blocks, softly rounded edges. No photorealism, no detailed texture, no noise, no floor, no ground plane, no pedestal, no background, no cast shadow geometry, no extra objects, no text. Complete object with intact base. One colorful inflatable bounce pad for an obstacle course, rounded square cushion platform in bright golden yellow with a bold upward white arrow on the top surface, thick soft beveled foam sides in warm orange, short sturdy dark base. Simple clean toy-like arcade springboard.',
        'target_height': 0.55,
        'palette': ['F59E0B', 'E67E22', 'FFFFFF', '665A48'],
        'faceCount': 10000,
    },
    'PROP_C1_SWEEPER': {
        'prompt': 'A single isolated freestanding game asset in the visual style of Untitled Goose Game and Fall Guys. Minimal low polygon, matte solid broad color blocks, softly rounded edges. No photorealism, no detailed texture, no noise, no floor, no ground plane, no pedestal, no background, no cast shadow geometry, no extra objects, no text. Complete object. One long padded rotating sweeper bar for an obstacle course, horizontal cylindrical foam beam in bright orange with bold yellow hazard stripes near both rounded ends, small grey metal hub socket at the exact center. Straight uniform beam, toy-like arcade obstacle.',
        'target_height': 0.36,
        'palette': ['E67E22', 'F1C40F', 'E74C3C', '5D6D7E'],
        'faceCount': 10000,
    },
    'PROP_C1_HAYBALE': {
        'prompt': 'A single isolated freestanding game asset in the visual style of Untitled Goose Game. Minimal low polygon, matte solid broad color blocks, softly rounded edges. No photorealism, no detailed texture, no noise, no floor, no ground plane, no pedestal, no background, no cast shadow geometry, no extra objects, no text. Complete object. One round cylindrical hay bale lying on its side, golden straw yellow rolled hay with broad spiral wrap lines on the circular ends, soft low-poly facets, matte dry grass color blocks. Complete single bale, no straps.',
        'target_height': 1.4,
        'palette': ['F59E0B', 'D4A017', 'B8860B', '8D7B68'],
        'faceCount': 10000,
    },
    'PROP_C1_FAKEBRIDGE': {
        'prompt': 'A single isolated freestanding game asset in the visual style of Untitled Goose Game. Minimal low polygon, matte solid broad color blocks, softly rounded edges. No photorealism, no detailed texture, no noise, no floor, no ground plane, no pedestal, no background, no cast shadow geometry, no extra objects, no text. Complete object. One flat rectangular wooden plank bridge platform tile for an obstacle course, warm brown parallel wood planks with small gaps and rounded edges, thin flat slab shape, no legs, no rails, no supports underneath. Simple toy-like arcade floor tile.',
        'target_height': 0.3,
        'palette': ['8D7B68', 'A0855B', '665A48', '3E2723'],
        'faceCount': 10000,
    },
    'PROP_C1_QUESTIONBLOCK': {
        'prompt': 'A single isolated freestanding game asset in the visual style of Untitled Goose Game. Minimal low polygon, matte solid broad color blocks, softly rounded edges. No photorealism, no detailed texture, no noise, no floor, no ground plane, no pedestal, no background, no cast shadow geometry, no extra objects. Complete object. One golden mystery surprise block, chunky cube in bright golden yellow with softly rounded corners, one bold white question mark symbol on the front face, slightly darker orange beveled frame edges. Clean toy-like arcade box.',
        'target_height': 1.2,
        'palette': ['F59E0B', 'E67E22', 'FFFFFF', 'B8860B'],
        'faceCount': 10000,
    },
    'PROP_C1_FINISHARCH': {
        'prompt': 'A single isolated freestanding game asset in the visual style of Untitled Goose Game and Fall Guys. Minimal low polygon, matte solid broad color blocks, softly rounded edges. No photorealism, no detailed texture, no noise, no floor, no ground plane, no pedestal, no background, no cast shadow geometry, no extra objects, no text. Complete object with intact base. One festive carnival finish archway for an obstacle race, two chunky vertical posts in bright orange connected by a wide top beam in red with rounded corners, one golden yellow star on top center, colorful triangular bunting flags hanging under the beam. Complete freestanding arch structure.',
        'target_height': 4.5,
        'palette': ['F39C12', 'E74C3C', 'F1C40F', '2ECC71', '3498DB'],
        'faceCount': 10000,
    },
}

def call_mcp(operation, args, cache_key):
    CACHE.mkdir(parents=True, exist_ok=True)
    argfile = CACHE / f"{cache_key}_args.json"
    outfile = CACHE / f"{cache_key}_resp.json"
    argfile.write_text(json.dumps(args, ensure_ascii=False), encoding='utf-8')
    subprocess.run(['node', str(ROOT / 'scripts/art/lux3d_client.mjs'), operation, str(argfile), str(outfile)], cwd=ROOT, check=True)
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
        'description': 'Course 1 3D obstacle models produced with Aholo Lux3D',
        'assets': {}
    }

def save_manifest(data):
    BASE.mkdir(parents=True, exist_ok=True)
    temp = MANIFEST.with_suffix('.tmp')
    temp.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    os.replace(temp, MANIFEST)

def submit_all(data):
    for asset_id, spec in SPECS.items():
        rec = data['assets'].setdefault(asset_id, {})
        if rec.get('task_id'):
            print(f"[{asset_id}] Already submitted with task_id: {rec['task_id']}")
            continue
        
        # Check if we already have an existing in-flight task
        if spec.get('existing_task'):
            task_id = spec['existing_task']
            print(f"[{asset_id}] Adopting in-flight task_id: {task_id}")
            rec.update(
                task_id=task_id,
                prompt=spec['prompt'],
                status='submitted',
                submitted_at=datetime.now(timezone.utc).isoformat()
            )
            save_manifest(data)
            continue

        print(f"[{asset_id}] Submitting text_to_3d...")
        args = {
            'prompt': spec['prompt'],
            'style': 'cartoon',
            'version': 'G1-Turbo',
            'faceCount': spec['faceCount'],
            'outputFormat': ['zip', 'glb'],
            'enablePbr': True,
            'aiPredictSize': False,
            'wait': False
        }
        res = call_mcp('lux3d_text_to_3d', args, f"course_submit_{asset_id}")
        rec.update(
            task_id=res['taskId'],
            prompt=spec['prompt'],
            status='submitted',
            submitted_at=datetime.now(timezone.utc).isoformat()
        )
        save_manifest(data)
        print(f"[{asset_id}] Submitted -> taskId: {res['taskId']}")

def check_and_collect(data):
    for asset_id, rec in data['assets'].items():
        task_id = rec.get('task_id')
        if not task_id or rec.get('status') == 'downloaded':
            continue
        
        print(f"[{asset_id}] Checking status for task {task_id}...")
        res = call_mcp('lux3d_get_task', {'taskId': task_id}, f"course_check_{asset_id}_{task_id}")
        status = res.get('status')
        rec['remote_status'] = status
        print(f"[{asset_id}] Remote status: {status} (0:init, 1:running, 3:done, 4:fail)")
        
        if status == 3: # SUCCEEDED
            print(f"[{asset_id}] Task completed! Downloading outputs...")
            folder = BASE / asset_id
            folder.mkdir(parents=True, exist_ok=True)
            for out in res.get('outputs', []):
                url = out.get('content', '')
                clean_url = url.split('?')[0]
                ext = clean_url.rsplit('.', 1)[-1].lower()
                if ext in ['zip', 'glb', 'png', 'jpg']:
                    target = folder / (f"{asset_id}_lux3d.zip" if ext == 'zip' else f"{asset_id}.{ext}")
                    print(f"Downloading {ext} -> {target.name}...")
                    download(url, target)
            
            # Extract glb from zip if needed
            glb_path = folder / f"{asset_id}.glb"
            zip_path = folder / f"{asset_id}_lux3d.zip"
            if not glb_path.exists() and zip_path.exists():
                with zipfile.ZipFile(zip_path) as z:
                    for name in z.namelist():
                        if name.lower().endswith('.glb'):
                            glb_path.write_bytes(z.read(name))
                            break
            
            if glb_path.exists():
                rec['status'] = 'downloaded'
                rec['raw_model'] = glb_path.relative_to(ROOT).as_posix()
                rec['sha256'] = hashlib.sha256(glb_path.read_bytes()).hexdigest()
                print(f"[{asset_id}] Downloaded successfully: {glb_path}")
            else:
                print(f"[{asset_id}] Warning: GLB not found in outputs")
        elif status in [4, 6]:
            rec['status'] = 'failed'
            print(f"[{asset_id}] Task failed or cancelled!")
        
        save_manifest(data)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['submit', 'collect', 'status'])
    args = parser.parse_args()
    data = load_manifest()
    
    if args.action == 'submit':
        submit_all(data)
    elif args.action in ['collect', 'status']:
        check_and_collect(data)

if __name__ == '__main__':
    main()
