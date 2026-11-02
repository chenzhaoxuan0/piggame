"""Prepare isolated subject images for the two rejected text-only outputs."""
import json
import sys
import hashlib
import shutil
from PIL import Image
from produce_assets import ROOT,BASE,call,download
from produce_dressing import MANIFEST,STYLE,SPECS

operation=sys.argv[1]
data=json.loads(MANIFEST.read_text(encoding='utf-8'))
for asset_id in ['ENV_09_BARREL','ENV_09_WOOL']:
    record=data['assets'][asset_id]
    folder=BASE/'_input'/asset_id
    if operation=='image':
        if record.get('subject_task'): continue
        prompt=STYLE+SPECS[asset_id]['subject']+' Entire single object centered on pure white, no cast shadow, square 1:1 image. Clean solid geometry, no thin shredded surfaces. Three quarter view.'
        result=call('lux3d_multimodal_to_image',{'prompt':prompt,'wait':False},'repair_subject_'+asset_id)
        record['subject_task']=result['taskId'];record['subject_prompt']=prompt
    elif operation=='collect':
        result=call('lux3d_get_task',{'taskId':record['subject_task']},'repair_subject_status_'+asset_id)
        if result['status']==3:
            download(result['outputs'][0]['content'],folder/'source.jpg')
            im=Image.open(folder/'source.jpg').convert('RGB');edge=max(im.size)
            square=Image.new('RGB',(edge,edge),'white');square.paste(im,((edge-im.width)//2,(edge-im.height)//2))
            square.save(folder/'subject.png')
            record['subject_input']=(folder/'subject.png').relative_to(ROOT).as_posix()
    elif operation=='approve':
        path=ROOT/record['subject_input'];im=Image.open(path)
        assert im.width==im.height
        record['subject_reviewed_sha256']=hashlib.sha256(path.read_bytes()).hexdigest()
    elif operation=='generate':
        if record.get('image_generation_task'): continue
        path=ROOT/record['subject_input']
        assert record['subject_reviewed_sha256']==hashlib.sha256(path.read_bytes()).hexdigest()
        history={k:v for k,v in record.items() if k in ['task_id','parameters','status','raw_model','sha256']}
        history['reason']='Text-only G1 output rejected: barrel is a flat lid; wool basket remains fragmented. Switch to reviewed isolated subject image.'
        archive=BASE/asset_id/'source'/'rejected_g1';archive.mkdir(exist_ok=True)
        for suffix in ['.glb','_lux3d.zip','.png','_game.glb']:
            file=BASE/asset_id/(asset_id+suffix)
            if file.exists(): shutil.copy2(file,archive/file.name)
        settings={'version':'G1-Turbo','localPath':str(path),'faceCount':20000,'outputFormat':['zip','glb'],'enablePbr':True,'aiPredictSize':False,'wait':False}
        result=call('lux3d_img_to_3d_from_file',settings,'repair_model_'+asset_id)
        record['rejected_candidates'].append(history)
        record.update(task_id=result['taskId'],image_generation_task=result['taskId'],parameters=settings,status='submitted')
    MANIFEST.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(asset_id,operation,flush=True)
