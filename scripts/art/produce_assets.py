"""Resumable Lux3D production using the repository MCP launcher, never embedded keys.

Examples: python scripts/art/produce_assets.py isolate CHAR_01 CHAR_02
          python scripts/art/produce_assets.py collect-inputs
          python scripts/art/produce_assets.py approve-input CHAR_01
          python scripts/art/produce_assets.py generate CHAR_01
          python scripts/art/produce_assets.py collect-models
Generation requires an explicitly reviewed square subject PNG. Failed jobs are not retried.
"""
import argparse
import hashlib
import json
import subprocess
import urllib.request
import zipfile
import os
from datetime import datetime, timezone
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'assets/models/aholo'
MANIFEST = BASE / 'production.json'
CACHE = ROOT / 'builds/lux3d'
SPECS = {
    'CHAR_01': ('the pale pink pig, yellow 047 ear tag, red flank stamp, curly tail; neutral standing on four complete legs, mouth empty, no pin', 30000),
    'CHAR_02': ('the old grey bighorn goat with curled dark horns; neutral standing on four complete legs; remove rocks, chains and ground', 30000),
    'CHAR_03': ('the brown ox with pale horns and a simple wooden neck yoke; neutral standing on four complete legs; remove trough, plow, rock and field', 30000),
    'CHAR_04': ('the small white fluffy sheep with pink face and black dot eyes; neutral standing on four short dark legs, no tag, no glow', 30000),
    'CHAR_05': ('the chestnut horse with black mane and red medal marked 41; remove fence and sign, reconstruct hidden legs; neutral standing on four complete legs', 30000),
    'CHAR_06': ('the tan and black guard dog with pointed ears and plain collar; neutral standing on four complete legs rather than running', 30000),
    'CHAR_07': ('the farmer wearing cap, mustard sweater, blue dungarees and green Wellington boots; reconstruct as standing neutral relaxed A-pose, both feet on same baseline, empty hands, no baton', 30000),
    'PROP_01': ('the wooden open-top cable car cabin including railings, central iron hanger, twin pulley wheels and brake slot; remove long cable beyond wheels', 20000),
    'PROP_02': ('ONLY the closed pair of dark iron gate leaves with vertical bars and small brass padlock; remove both stone pillars, shadows, ground; straight-on three quarter view', 20000),
    'PROP_03': ('the single bronze latch pin with ring handle and red copper/teal patina color blocks; remove all shadows', 10000),
    'PROP_04': ('the grey granite boulder with the chipped dark iron plow blade wedged against it, as one assembled prop; remove loose dirt and pebbles', 16000),
    'PROP_05': ('the single pale wooden grade tag and white cord loop, keep black markings; remove all shadows', 10000),
    'PROP_06': ('the single white 35s record sign with green border and both wooden posts; remove all shadows, same baseline for posts', 10000),
    'PROP_07': ('the single black and yellow electric baton with grey front tip; remove floating spark and all shadows', 10000),
}

def save(data):
    BASE.mkdir(parents=True, exist_ok=True)
    temporary=MANIFEST.with_suffix('.tmp')
    temporary.write_text(json.dumps(data, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    os.replace(temporary,MANIFEST)

def call(name, args, key):
    CACHE.mkdir(parents=True, exist_ok=True)
    # Persist a request-specific response before modifying the manifest. Recover that
    # response on restart instead of submitting the same paid generation twice.
    fingerprint=hashlib.sha256(json.dumps(args,sort_keys=True,ensure_ascii=False).encode()).hexdigest()[:12]
    argfile, outfile = CACHE / (key+'_'+fingerprint+'_args.json'), CACHE / (key+'_'+fingerprint+'_response.json')
    if name in ['lux3d_multimodal_to_image','lux3d_img_to_3d_from_file'] and outfile.exists():
        cached=json.loads(outfile.read_text(encoding='utf-8'))
        if not cached.get('isError'):
            payload=json.loads(next(c['text'] for c in cached['content'] if c['type']=='text'))
            if payload.get('taskId'): return payload
    argfile.write_text(json.dumps(args, ensure_ascii=False), encoding='utf-8')
    subprocess.run(['node', str(ROOT/'scripts/art/lux3d_client.mjs'), name, str(argfile), str(outfile)], cwd=ROOT, check=True, timeout=200)
    response = json.loads(outfile.read_text(encoding='utf-8'))
    if response.get('isError'): raise RuntimeError(str(response))
    return json.loads(next(c['text'] for c in response['content'] if c['type']=='text'))

def download(url, destination):
    destination.parent.mkdir(parents=True, exist_ok=True)
    with urllib.request.urlopen(url, timeout=120) as response:
        destination.write_bytes(response.read())

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('operation', choices=['isolate','revise-input','collect-inputs','approve-input','generate','collect-models'])
    parser.add_argument('ids', nargs='*')
    args=parser.parse_args()
    data=json.loads(MANIFEST.read_text(encoding='utf-8')) if MANIFEST.exists() else {'schema':1,'style_source':'docs/art/01_ART_STYLE_GUIDE_AND_PROMPT_SYSTEM.md','assets':{}}
    ids=args.ids or list(data['assets'])
    for asset_id in ids:
        if asset_id not in SPECS: raise ValueError(asset_id)
        spec, faces=SPECS[asset_id]
        record=data['assets'].setdefault(asset_id, {})
        if args.operation in ['isolate','revise-input']:
            if record.get('isolation_task') and args.operation=='isolate': continue
            if args.operation=='revise-input' and record.get('rejected_inputs'): raise ValueError('Two input candidates already attempted: '+asset_id)
            source=next(p for p in (ROOT/'assets/2d').glob(asset_id+'*.png') if '2D' in p.name)
            prompt=('必须严格遵守：输出是《无题大鹅模拟 Untitled Goose Game》风格的极简低多边形游戏模型立绘，不是照片！在原图基础上单独提取主体，'+
                    '保留原图的大块多边形纯色色块、极简黑圆点眼睛和轮廓比例。绝对禁止写实肌肉、毛发、皮毛细节、材质纹理、细碎噪点、摄影。'+
                    '移除所有场景、投影、地板、地面、无关物件。白底纯白无阴影，1:1正方形居中留白10%。'+
                    '具体唯一主体：'+spec+'. Flat polygonal 3D game render, completely untextured solid color materials, graphic silhouette, black bead eyes. Match the provided reference exactly.')
            response=call('lux3d_multimodal_to_image',{'localPath':str(source),'prompt':prompt,'wait':False}, 'isolate_'+asset_id)
            if record.get('isolation_task'):
                record['rejected_inputs']=[{'task':record['isolation_task'],'reason':'Photorealistic material drift; rejected before 3D'}]
            for stale in ['isolation_status','input_sha256']:
                record.pop(stale,None)
            record.update(source=source.relative_to(ROOT).as_posix(),extraction_prompt=prompt,isolation_task=response['taskId'],input_status='pending')
        elif args.operation=='collect-inputs':
            if record.get('input_status') in ['ready','reviewed','rejected']: continue
            if not record.get('isolation_task'): continue
            response=call('lux3d_get_task',{'taskId':record['isolation_task']}, 'input_status_'+asset_id)
            record['isolation_status']=response['status']
            if response['status']==3:
                folder=BASE/'_input'/asset_id
                source=folder/'extracted.jpg'
                download(response['outputs'][0]['content'],source)
                image=Image.open(source).convert('RGB')
                edge=max(image.size)
                square=Image.new('RGB',(edge,edge),'white')
                square.paste(image,((edge-image.width)//2,(edge-image.height)//2))
                square.save(folder/'subject.png')
                record['input']=(folder/'subject.png').relative_to(ROOT).as_posix()
                record['input_status']='ready'
        elif args.operation=='approve-input':
            if record.get('input_status') not in ['ready','reviewed']: raise ValueError('No current candidate ready for review: '+asset_id)
            path=ROOT/record['input']
            im=Image.open(path)
            if im.width!=im.height: raise ValueError('Input must be square')
            record['input_status']='reviewed'
            record['input_sha256']=hashlib.sha256(path.read_bytes()).hexdigest()
        elif args.operation=='generate':
            if record.get('generation_task'): continue
            if record.get('input_status')!='reviewed': raise ValueError('Visually review subject before approval: '+asset_id)
            path=ROOT/record['input']
            if hashlib.sha256(path.read_bytes()).hexdigest()!=record['input_sha256']: raise ValueError('Input changed after review')
            settings={'version':'G1-Turbo','faceCount':faces,'outputFormat':['zip','glb'],'enablePbr':True,'aiPredictSize':False,'wait':False}
            response=call('lux3d_img_to_3d_from_file',dict(settings,localPath=str(path)), 'generate_'+asset_id)
            record.update(generation_task=response['taskId'],generation_parameters=settings,model_status='pending',generated_at=datetime.now(timezone.utc).isoformat())
        elif args.operation=='collect-models':
            if not record.get('generation_task') or record.get('model_status')=='downloaded': continue
            response=call('lux3d_get_task',{'taskId':record['generation_task']}, 'model_status_'+asset_id)
            record['generation_status']=response['status']
            if response['status']==3:
                folder=BASE/asset_id
                for output in response.get('outputs',[]):
                    url=output.get('content','')
                    ext=url.split('?')[0].rsplit('.',1)[-1].lower()
                    if ext not in ['zip','glb','png','jpg','jpeg']: continue
                    filename=asset_id+('_lux3d.zip' if ext=='zip' else '.'+ext)
                    download(url,folder/filename)
                archive=folder/(asset_id+'_lux3d.zip')
                glb=folder/(asset_id+'.glb')
                if not glb.exists() and archive.exists():
                    with zipfile.ZipFile(archive) as z:
                        models=[n for n in z.namelist() if n.lower().endswith('.glb')]
                        if not models: raise ValueError('No GLB in output archive: '+asset_id)
                        glb.write_bytes(z.read(models[0]))
                if not glb.exists(): raise ValueError('No usable output: '+asset_id)
                record['raw_model']=glb.relative_to(ROOT).as_posix()
                record['model_sha256']=hashlib.sha256(glb.read_bytes()).hexdigest()
                record['model_status']='downloaded'
        save(data)
        print(asset_id,record.get('input_status'),record.get('model_status'),flush=True)

if __name__=='__main__':
    BASE.mkdir(parents=True,exist_ok=True)
    lock=BASE/'.production.lock'
    try:
        descriptor=os.open(lock,os.O_CREAT|os.O_EXCL|os.O_WRONLY)
    except FileExistsError:
        raise SystemExit('Another production command owns the manifest. If interrupted, inspect and remove .production.lock before resuming.')
    try:
        os.write(descriptor,str(os.getpid()).encode());os.close(descriptor)
        main()
    finally:
        lock.unlink(missing_ok=True)
