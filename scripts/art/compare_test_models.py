import json
import time
import urllib.request
import zipfile
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'assets/models/aholo/_ipc'
BASE.mkdir(parents=True, exist_ok=True)

TASKS = {
    'task_img_to_3d': {
        'taskId': 4584753,
        'label': '图生3D (G1 300K PBR)',
        'dir': BASE / 'test_img_to_3d_300k',
    },
    'task_text_to_3d': {
        'taskId': 4584861,
        'label': '文生3D+参考图 (G1 300K PBR)',
        'dir': BASE / 'test_text_to_3d_300k',
    },
}

def mcp_call(tool: str, payload: dict, tag: str) -> dict:
    inp = BASE / f'{tag}.in.json'
    out = BASE / f'{tag}.out.json'
    inp.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding='utf-8')
    cmd = ['node', str(ROOT / 'scripts/art/lux3d_client.mjs'), tool, str(inp), str(out)]
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if out.exists():
        raw = json.loads(out.read_text(encoding='utf-8'))
        if 'content' in raw and raw['content'] and 'text' in raw['content'][0]:
            return json.loads(raw['content'][0]['text'])
        return raw
    raise RuntimeError(f"MCP failed: {proc.stderr}")

def download(url: str, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    with urllib.request.urlopen(req) as resp, open(dest, 'wb') as f:
        f.write(resp.read())

def poll_and_download():
    done = set()
    while len(done) < len(TASKS):
        for key, info in TASKS.items():
            if key in done:
                continue
            tid = info['taskId']
            res = mcp_call('lux3d_get_task', {'taskId': tid}, f'poll_{tid}')
            status = res.get('status')
            print(f"[{info['label']}] Task {tid} status: {status}")
            if status == 3:
                outputs = res.get('outputs', [])
                target_dir = info['dir']
                target_dir.mkdir(parents=True, exist_ok=True)
                for out in outputs:
                    url = out.get('content', '')
                    ext = url.split('?')[0].rsplit('.', 1)[-1].lower()
                    if ext == 'zip':
                        download(url, target_dir / 'result.zip')
                    elif ext == 'glb':
                        download(url, target_dir / 'model.glb')
                    elif ext in ['png', 'jpg', 'jpeg']:
                        download(url, target_dir / 'preview.png')
                
                # Check glb inside zip if not direct
                glb_file = target_dir / 'model.glb'
                zip_file = target_dir / 'result.zip'
                if not glb_file.exists() and zip_file.exists():
                    with zipfile.ZipFile(zip_file) as z:
                        for name in z.namelist():
                            if name.lower().endswith('.glb'):
                                glb_file.write_bytes(z.read(name))
                                break
                print(f"[{info['label']}] Downloaded to {target_dir}")
                done.add(key)
            elif status == 4:
                raise RuntimeError(f"[{info['label']}] Task {tid} failed!")
        if len(done) < len(TASKS):
            time.sleep(10)

if __name__ == '__main__':
    poll_and_download()

