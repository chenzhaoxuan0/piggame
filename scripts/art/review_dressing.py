"""Create a contact sheet; register only explicitly reviewed IDs with --accept."""
import argparse
import json
from pathlib import Path
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/'assets/models/aholo'
SPECS=json.loads((ROOT/'scripts/art/dressing_specs.json').read_text(encoding='utf-8'))
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--accept',nargs='*')
args=parser.parse_args()
if args.accept:
    path=BASE/'runtime_catalog.json';catalog=json.loads(path.read_text(encoding='utf-8'))
    export=ROOT/'export_presets.cfg';text=export.read_text(encoding='utf-8')
    for asset_id in args.accept:
        spec=SPECS[asset_id]
        report=json.loads((BASE/asset_id/'import_report.json').read_text(encoding='utf-8'))
        budget=7000 if asset_id=='ENV_09_WOOL' else (4500 if asset_id in ['ENV_09_BARREL','ENV_09_HURDLE','ENV_06_CRATE'] else 2600)
        if report['triangles']>budget: raise ValueError('Dressing exceeds review budget: '+asset_id)
        resource='res://'+report['runtime']
        catalog['assets'][asset_id]={'path':resource,'accepted':True,'yaw_degrees':0,
            'triangles':report['triangles'],'category':'environment_dressing',
            'triangle_budget':budget,
            'validation':'Isolated Lux3D subject and flat palette game preview visually reviewed; 2026-11-02'}
        if '"'+resource+'"' not in text: text=text.replace('export_files=PackedStringArray(', 'export_files=PackedStringArray("'+resource+'", ',1)
    path.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    export.write_text(text,encoding='utf-8')
else:
    sheet=Image.new('RGB',(1800,((len(SPECS)+5)//6)*330),'#e4e5da');draw=ImageDraw.Draw(sheet)
    for i,asset_id in enumerate(SPECS):
        path=BASE/asset_id/(asset_id+'.png')
        if not path.exists(): continue
        im=Image.open(path).convert('RGB');im.thumbnail((298,298))
        x=(i%6)*300;y=(i//6)*330
        sheet.paste(im,(x,y));draw.text((x+8,y+302),asset_id,fill='#26352c')
    dest=ROOT/'assets/art_references/enriched_farm';dest.mkdir(exist_ok=True)
    (dest/'.gdignore').write_text('',encoding='utf-8')
    sheet.save(dest/'00_dressing_catalog.png')
