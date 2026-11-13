"""Resumable, prompt-only Lux3D production for new ENV_09 dressing subjects.
No scene image is uploaded. Existing core assets and their manifest are untouched.
Usage: python scripts/art/produce_dressing.py generate|collect [ID ...]
"""
import argparse
import hashlib
import json
import os
import zipfile
import shutil
from datetime import datetime, timezone
from pathlib import Path
from produce_assets import ROOT, BASE, call, download

MANIFEST = BASE / 'dressing_production.json'
SPECS = json.loads((ROOT/'scripts/art/dressing_specs.json').read_text(encoding='utf-8'))
STYLE = ('A single isolated freestanding game asset in the visual style of Untitled Goose Game. '
         'Minimal low polygon pastoral British farm, matte solid broad color blocks, softly rounded edges. '
         'No photorealism, no detailed texture, no noise, no floor, no ground plane, no pedestal, no background, '
         'no cast shadow geometry, no extra objects, no text. Complete object with intact base. ')

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('operation', choices=['generate','collect','revise'])
    parser.add_argument('ids', nargs='*')
    parser.add_argument('--version', default='G1-Turbo', choices=['G1','G1-Turbo'],
                        help='Lux3D quality for `generate` (default G1-Turbo). Use G1 directly when the '
                             'subject is error-prone: the 2026-11 G1-Turbo batch was rejected for fragmented surfaces.')
    args=parser.parse_args()
    data=json.loads(MANIFEST.read_text(encoding='utf-8')) if MANIFEST.exists() else {
        'schema':1,'source':'Aholo Lux3D text_to_3d; new subjects without a matching 2D reference',
        'prompt_source':'docs/art/07_ENVIRONMENT_DRESSING.md','assets':{}}
    active=sum(r.get('status')=='submitted' for r in data['assets'].values())
    for asset_id in args.ids or SPECS:
        spec=SPECS[asset_id]
        record=data['assets'].setdefault(asset_id,{})
        if args.operation in ['generate','revise']:
            if record.get('task_id') and args.operation=='generate': continue
            if args.operation=='revise':
                if record.get('rejected_candidates'): continue
                if record.get('status')!='downloaded': raise ValueError('Review downloaded model first')
                old=record.copy()
                folder=BASE/asset_id
                archive=folder/'source'/'rejected_turbo';archive.mkdir(parents=True,exist_ok=True)
                for suffix in ['.glb','_lux3d.zip','.png','_game.glb']:
                    file=folder/(asset_id+suffix)
                    if file.exists(): shutil.copy2(file,archive/file.name)
                record.clear()
                record['rejected_candidates']=[dict(old,reason='Fragmented overlapping surfaces in runtime preview; retry with G1 quality model')]
            if active>=5:
                print('Five tasks in flight; collect them before submitting the next batch.',flush=True)
                break
            settings=dict(prompt=STYLE+spec['subject'],style='cartoon',
                          version='G1' if args.operation=='revise' else args.version,faceCount=10000,
                          outputFormat=['zip','glb'],enablePbr=True,aiPredictSize=False,wait=False)
            response=call('lux3d_text_to_3d',settings,'dressing_'+asset_id)
            record.update(task_id=response['taskId'],parameters=settings,status='submitted',
                          generated_at=datetime.now(timezone.utc).isoformat())
            active+=1
        else:
            if not record.get('task_id') or record.get('status')=='downloaded': continue
            response=call('lux3d_get_task',{'taskId':record['task_id']},'dressing_status_'+asset_id)
            record['remote_status']=response['status']
            if response['status']==3:
                folder=BASE/asset_id
                for output in response.get('outputs',[]):
                    url=output.get('content','')
                    ext=url.split('?')[0].rsplit('.',1)[-1].lower()
                    if ext not in ['zip','glb','png','jpg','jpeg']: continue
                    target=folder/(asset_id+('_lux3d.zip' if ext=='zip' else '.'+ext))
                    download(url,target)
                glb=folder/(asset_id+'.glb')
                archive=folder/(asset_id+'_lux3d.zip')
                if not glb.exists() and archive.exists():
                    with zipfile.ZipFile(archive) as z:
                        glb.write_bytes(z.read(next(n for n in z.namelist() if n.lower().endswith('.glb'))))
                if not glb.exists(): raise RuntimeError('No GLB output: '+asset_id)
                record.update(status='downloaded',raw_model=glb.relative_to(ROOT).as_posix(),
                              sha256=hashlib.sha256(glb.read_bytes()).hexdigest())
            elif response['status'] in [4,6]: record['status']='failed'
        temporary=MANIFEST.with_suffix('.tmp')
        temporary.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
        os.replace(temporary,MANIFEST)
        print(asset_id,record.get('status'),record.get('remote_status'),flush=True)

if __name__=='__main__':
    lock=BASE/'.dressing.lock'
    descriptor=os.open(lock,os.O_CREAT|os.O_EXCL|os.O_WRONLY)
    try:
        os.write(descriptor,str(os.getpid()).encode());os.close(descriptor)
        main()
    finally: lock.unlink(missing_ok=True)
