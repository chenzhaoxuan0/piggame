#!/usr/bin/env python3
"""Rebuild character models using Plan B (Robust Pipeline):
1. Generate standard four-view images from isolated subject.png using lux3d_image_to_four_view.
2. Generate G1 high-precision 3D models using lux3d_img_to_3d_from_file (version='G1', localPaths=four_views).
3. Concurrency-aware state machine with automatic retry and progressive downloading.
"""
import json
import time
import urllib.request
import zipfile
from datetime import datetime, timezone
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'assets/models/aholo'
IPC = BASE / '_ipc'
IPC.mkdir(parents=True, exist_ok=True)

CHARACTERS = {
    'CHAR_01': {
        'name': '一口猪包子',
        'subject': 'assets/models/aholo/_input/CHAR_01/subject.png',
        'prompt': "Single isolated low-poly 3D model of a stylized pale-pink pig, in the art style of Untitled Goose Game. Smooth flat-shaded pastel pink body, clean geometric silhouettes, four sturdy legs in neutral standing pose, curly tail, cute simple black dot eyes, flat pink snout with nostrils, bright flat yellow plastic tag stamped '047' on left ear, mouth empty, no pin. Minimalist indie game asset, watertight clean low-poly mesh, zero texture noise, completely flat untextured solid color materials. Pure solid white background, no floor, no cast shadows, studio lighting, isometric 45 degree angle.",
    },
    'CHAR_02': {
        'name': '老岩羊',
        'subject': 'assets/models/aholo/_input/CHAR_02/subject.png',
        'prompt': "Single isolated low-poly 3D model of an old bighorn goat, in the art style of Untitled Goose Game. Shaggy faceted low-poly body in light grey, large curved spiral horns in solid dark grey, neutral four-legged stance. Flat-shaded solid color materials, zero texture noise, clean beveled low-poly mesh, watertight topology. Pure solid white background, no floor, zero shadow, isometric view.",
    },
    'CHAR_03': {
        'name': '老黄牛',
        'subject': 'assets/models/aholo/_input/CHAR_03/subject.png',
        'prompt': "Single isolated low-poly 3D model of a sturdy brown draft ox, in the art style of Untitled Goose Game. Chunky blocky body in solid dark brown, blunt pale horns, neutral standing pose, wearing a simple pale wooden neck yoke. Flat-shaded low-poly indie game asset, clean watertight polygon mesh, pure flat colors, zero texture noise. Solid pure white background, no shadows, isometric view.",
    },
    'CHAR_04': {
        'name': '小绵羊',
        'subject': 'assets/models/aholo/_input/CHAR_04/subject.png',
        'prompt': "Single isolated low-poly 3D model of a cute little fluffy sheep, in the art style of Untitled Goose Game. Cloud-like rounded puffy white body, tiny black legs, flat pink face with dot eyes, wearing a tiny flat rectangular wooden tag. Clean low-poly manifold mesh, flat-shaded solid colors, smooth untextured matte material. Pure solid white background, no floor, no shadows, isometric view.",
    },
    'CHAR_05': {
        'name': '追风烈马',
        'subject': 'assets/models/aholo/_input/CHAR_05/subject.png',
        'prompt': "Single isolated low-poly 3D model of a slender dark chestnut racehorse, in the art style of Untitled Goose Game. Sleek faceted brown body, black mane, neutral standing pose on four slender legs, wearing a small flat red circular medal on its chest. Flat-shaded low-poly 3D asset, clean manifold mesh, pure solid color materials, zero texture noise. Solid pure white background, no floor, zero shadow, isometric view.",
    },
    'CHAR_06': {
        'name': '农场护院犬',
        'subject': 'assets/models/aholo/_input/CHAR_06/subject.png',
        'prompt': "Single isolated low-poly 3D model of a farm guard dog, in the art style of Untitled Goose Game. Athletic low-poly body in flat-shaded tan and black patches, pointed ears, neutral standing stance, wearing a plain brown collar. Clean watertight low-poly mesh, solid color materials, zero texture noise. Pure solid white background, no floor, isometric view.",
    },
    'CHAR_07': {
        'name': '农场主',
        'subject': 'assets/models/aholo/_input/CHAR_07/subject.png',
        'prompt': "Single isolated low-poly 3D model of a stylized human farmer, in the art style of Untitled Goose Game. Character in neutral A-pose, wearing a flat cap, dungarees over a sweater, and rubber boots, holding a chunky black and yellow baton. House House game character asset, clean faceted low-poly mesh, flat-shaded solid colors, zero texture noise, untextured matte materials. Pure solid white background, no floor, zero shadow, isometric view.",
    },
}

class ConcurrencyLimitError(Exception):
    pass

def mcp_call(tool: str, payload: dict, tag: str) -> dict:
    inp = IPC / f'{tag}.in.json'
    out = IPC / f'{tag}.out.json'
    inp.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding='utf-8')
    cmd = ['node', str(ROOT / 'scripts/art/lux3d_client.mjs'), tool, str(inp), str(out)]
    proc = subprocess.run(cmd, capture_output=True, text=True)
    
    if out.exists():
        raw = json.loads(out.read_text(encoding='utf-8'))
        if 'content' in raw and raw['content'] and 'text' in raw['content'][0]:
            inner = json.loads(raw['content'][0]['text'])
            if raw.get('isError') or 'error' in inner:
                detail = inner.get('detail', {})
                if detail.get('bizCode') == 'GENERATION_CONCURRENCY_LIMIT_EXCEEDED':
                    raise ConcurrencyLimitError(inner.get('message', 'Concurrency limit exceeded'))
                raise RuntimeError(f"MCP tool error ({tool}): {inner}")
            return inner
        return raw
    raise RuntimeError(f"MCP process failed ({tool}): {proc.stderr}")

def get_task(task_id: int, tag: str) -> dict:
    return mcp_call('lux3d_get_task', {'taskId': task_id}, f'get_{tag}_{task_id}')

def download(url: str, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    with urllib.request.urlopen(req) as resp, open(dest, 'wb') as f:
        f.write(resp.read())

def main():
    state_file = BASE / '_ipc' / 'plan_b_state.json'
    state = json.loads(state_file.read_text(encoding='utf-8')) if state_file.exists() else {}
    for cid in CHARACTERS:
        if cid not in state:
            state[cid] = {}
    
    iteration = 0
    while True:
        iteration += 1
        all_done = True
        state_modified = False
        
        print(f"\n--- Pipeline Loop Iteration {iteration} [{datetime.now().strftime('%H:%M:%S')}] ---")
        
        for cid, info in CHARACTERS.items():
            c_state = state[cid]
            name = info['name']
            
            # Stage 4: Check if 3D assets downloaded
            if c_state.get('g1_3d_downloaded'):
                print(f"[{cid} {name}] Status: G1 3D model downloaded and ready.")
                continue
            
            all_done = False
            
            # Stage 3: Polling G1 3D task
            if c_state.get('g1_3d_task'):
                task_id = c_state['g1_3d_task']
                if c_state.get('g1_3d_status') == 3:
                    # Download 3D assets
                    outputs = c_state.get('g1_3d_outputs', [])
                    folder = BASE / cid
                    archive = folder / f'{cid}_lux3d.zip'
                    glb = folder / f'{cid}.glb'
                    preview = folder / f'{cid}.png'
                    
                    print(f"[{cid} {name}] Downloading completed G1 3D assets...")
                    for out in outputs:
                        url = out.get('content', '')
                        ext = url.split('?')[0].rsplit('.', 1)[-1].lower()
                        if ext == 'zip':
                            download(url, archive)
                        elif ext == 'glb':
                            download(url, glb)
                        elif ext in ['png', 'jpg', 'jpeg']:
                            download(url, preview)
                    
                    if not glb.exists() and archive.exists():
                        with zipfile.ZipFile(archive) as z:
                            models = [n for n in z.namelist() if n.lower().endswith('.glb')]
                            if models:
                                glb.write_bytes(z.read(models[0]))
                    
                    c_state['g1_3d_downloaded'] = True
                    state_modified = True
                    print(f"[{cid} {name}] Finished downloading G1 3D assets to {folder}")
                    continue
                else:
                    # Poll
                    res = get_task(task_id, f'g1_poll_{cid}')
                    st = res.get('status')
                    print(f"[{cid} {name}] G1 3D task {task_id} status: {st}")
                    if st == 3:
                        c_state['g1_3d_status'] = 3
                        c_state['g1_3d_outputs'] = res.get('outputs', [])
                        state_modified = True
                    elif st == 4:
                        raise RuntimeError(f"[{cid} {name}] G1 3D task {task_id} failed!")
                    continue
            
            # Stage 2: Check if four_view downloaded, ready to submit G1 3D
            if c_state.get('four_view_downloaded'):
                paths = c_state['four_view_paths']
                payload = {
                    'localPaths': paths,
                    'version': 'G1',
                    'faceCount': 80000,
                    'outputFormat': ['zip', 'glb'],
                    'aiPredictSize': False,
                    'wait': False,
                }
                try:
                    res = mcp_call('lux3d_img_to_3d_from_file', payload, f'g1_submit_{cid}')
                    task_id = res['taskId']
                    print(f"[{cid} {name}] Submitted G1 3D task: {task_id}")
                    c_state['g1_3d_task'] = task_id
                    state_modified = True
                except ConcurrencyLimitError:
                    print(f"[{cid} {name}] Concurrency limit reached for G1 3D submission. Waiting...")
                continue
            
            # Stage 1: Check if four_view task running/completed
            if c_state.get('four_view_task'):
                task_id = c_state['four_view_task']
                res = get_task(task_id, f'fv_poll_{cid}')
                st = res.get('status')
                print(f"[{cid} {name}] Four-view task {task_id} status: {st}")
                if st == 3:
                    outputs = res.get('outputs', [])
                    if outputs:
                        urls = json.loads(outputs[0]['content'])
                        fv_dir = BASE / '_input' / cid / 'four_view'
                        paths = []
                        for idx, url in enumerate(urls):
                            view_file = fv_dir / f'view_{idx}.png'
                            download(url, view_file)
                            paths.append(str(view_file))
                        c_state['four_view_status'] = 3
                        c_state['four_view_paths'] = paths
                        c_state['four_view_downloaded'] = True
                        state_modified = True
                        print(f"[{cid} {name}] Four views downloaded successfully ({len(paths)} views).")
                elif st == 4:
                    raise RuntimeError(f"[{cid} {name}] Four-view task {task_id} failed!")
                continue
            
            # Stage 0: Submit four_view task
            subj = ROOT / info['subject']
            payload = {
                'localPath': str(subj),
                'prompt': info['prompt'],
                'wait': False,
            }
            try:
                res = mcp_call('lux3d_image_to_four_view', payload, f'fv_submit_{cid}')
                task_id = res['taskId']
                print(f"[{cid} {name}] Submitted four_view task: {task_id}")
                c_state['four_view_task'] = task_id
                state_modified = True
            except ConcurrencyLimitError:
                print(f"[{cid} {name}] Concurrency limit reached for four_view submission. Waiting...")
        
        if state_modified:
            state_file.write_text(json.dumps(state, indent=2, ensure_ascii=False), encoding='utf-8')
        
        if all_done:
            print("\n=== ALL 7 CHARACTERS G1 3D REBUILT SUCCESSFULLY! ===")
            break
        
        time.sleep(12)

    # Final update of production.json
    prod_file = BASE / 'production.json'
    prod = json.loads(prod_file.read_text(encoding='utf-8'))
    for cid in CHARACTERS:
        if cid in prod.get('assets', {}):
            rec = prod['assets'][cid]
            rec['generation_parameters'] = {
                'version': 'G1',
                'method': 'Plan B: four_view -> G1 multiview',
                'faceCount': 80000,
                'outputFormat': ['zip', 'glb'],
                'aiPredictSize': False,
                'four_view_task': state[cid]['four_view_task'],
                'generation_task': state[cid]['g1_3d_task'],
            }
            rec['generation_task'] = state[cid]['g1_3d_task']
            rec['generation_status'] = 3
            rec['generated_at'] = datetime.now(timezone.utc).isoformat()
            rec['model_status'] = 'downloaded'
            rec['raw_model'] = f'assets/models/aholo/{cid}/{cid}.glb'
    
    prod_file.write_text(json.dumps(prod, indent=2, ensure_ascii=False), encoding='utf-8')
    print("Updated production.json with G1 3D records.")

if __name__ == '__main__':
    main()

