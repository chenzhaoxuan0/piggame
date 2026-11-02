"""Reproducible, reviewed masks drawn on the original concept pixels.

No generative redraw: retain the concept silhouette and palette, remove scenery
and cast shadows, then centre on a square white canvas. Coordinates use a
1024-pixel-wide reference. Outputs still require visual approval before Lux3D.
"""
import json
import hashlib
import sys
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import binary_fill_holes, binary_erosion, label

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'assets/models/aholo'
POLYGONS = {
 'ENV_01_TROUGH': [(152,207),(181,192),(294,207),(293,224),(271,257),(152,233)],
 'ENV_06_HAY': [(587,221),(594,200),(606,185),(628,177),(663,170),(687,168),(701,179),(713,192),(722,220),(721,237),(707,258),(673,270),(647,280),(627,281),(606,270),(595,257),(588,242)],
 'ENV_06_CRATE': [(350,126),(392,110),(431,119),(432,155),(398,178),(351,168)],
 'ENV_06_TRACTOR': [(333,389),(338,369),(352,347),(369,339),(405,333),(407,318),(432,309),(441,313),(447,330),(454,330),(467,315),(479,315),(482,320),(476,334),(501,339),(502,305),(506,302),(505,295),(512,293),(515,299),(511,306),(513,340),(540,348),(556,356),(566,369),(568,381),(574,377),(580,381),(579,389),(572,395),(570,403),(582,409),(594,422),(601,440),(599,453),(587,465),(570,468),(552,454),(523,450),(520,474),(505,489),(490,494),(472,489),(464,472),(462,451),(441,443),(418,434),(402,452),(382,457),(359,446),(344,429),(337,410)],
 'CHAR_01': [(323,134),(343,135),(375,146),(388,164),(414,158),(448,159),(455,150),(497,133),(510,166),(517,173),(623,184),(643,194),(669,209),(679,194),(688,217),(680,230),(689,263),(696,305),(693,348),(701,379),(690,424),(689,443),(663,446),(656,444),(664,424),(664,395),(629,356),(611,367),(605,393),(597,411),(596,429),(566,433),(563,431),(572,414),(572,394),(564,378),(551,377),(536,421),(520,443),(517,462),(487,467),(477,465),(487,444),(484,413),(480,374),(456,371),(445,401),(439,423),(436,443),(405,446),(399,442),(408,422),(409,397),(403,351),(387,310),(373,300),(353,292),(338,279),(330,250),(331,242),(339,238),(346,220),(354,204),(347,193),(336,184)],
 'CHAR_04': [(324,330),(330,298),(338,279),(339,263),(350,247),(359,223),(377,210),(405,199),(436,180),(465,179),(482,181),(497,188),(513,186),(533,195),(548,193),(581,200),(600,214),(612,231),(640,241),(656,260),(665,276),(670,302),(678,314),(686,339),(682,361),(675,386),(672,401),(656,422),(655,434),(648,441),(635,442),(614,451),(584,454),(574,467),(564,471),(556,466),(557,459),(531,463),(498,462),(471,454),(460,463),(450,466),(443,463),(442,455),(447,449),(414,444),(399,439),(383,430),(382,433),(374,437),(368,435),(365,412),(350,405),(343,392),(338,371),(329,354)],
 'PROP_02': [(213,207),(246,190),(263,164),(301,169),(302,215),(329,224),(329,195),(339,182),(367,190),(367,237),(393,244),(393,212),(404,201),(431,209),(431,257),(459,265),(459,234),(470,221),(497,230),(497,278),(523,287),(523,254),(535,241),(562,250),(562,297),(588,306),(588,275),(600,262),(627,271),(627,320),(655,329),(655,295),(668,283),(694,292),(694,340),(725,350),(725,316),(737,303),(765,313),(765,360),(776,363),(776,408),(791,415),(791,851),(777,848),(776,832),(510,739),(509,725),(491,727),(248,645),(234,650),(214,642)],
 'PROP_06': [(255,127),(273,119),(291,122),(291,103),(318,90),(356,97),(356,134),(671,195),(671,181),(698,162),(740,171),(741,207),(770,216),(770,596),(741,609),(741,903),(714,921),(671,909),(671,591),(356,519),(356,797),(331,814),(291,804),(291,499),(255,489)]
}

def extract(asset_id):
    manifest = json.loads((BASE/'production.json').read_text(encoding='utf-8'))
    record = manifest['assets'][asset_id]
    if record.get('generation_task'):
        raise ValueError('Do not change an input already used for 3D: '+asset_id)
    folder = BASE/'_input'/asset_id
    folder.mkdir(parents=True,exist_ok=True)
    if asset_id == 'CHAR_07':
        source = folder/'extracted.jpg'
    else:
        source = ROOT/record['source']
    image = Image.open(source).convert('RGB')
    image = image.resize((1024, round(image.height*1024/image.width)), Image.Resampling.LANCZOS)
    rgb = np.asarray(image).astype(np.int16)
    if asset_id in POLYGONS:
        mask_image = Image.new('L', image.size)
        ImageDraw.Draw(mask_image).polygon(POLYGONS[asset_id],fill=255)
        mask = np.asarray(mask_image)>0
        if asset_id == 'PROP_02':
            mask &= rgb.mean(axis=2)<190
        elif asset_id == 'CHAR_01':
            mask &= (rgb[:,:,0]>rgb[:,:,1]+5) | ((np.indices(mask.shape)[0]>410)&(rgb.mean(axis=2)<115))
            mask = binary_fill_holes(mask)
            mask &= (rgb[:,:,0]>=rgb[:,:,1]) | (rgb.mean(axis=2)<75)
            mask = binary_erosion(mask,iterations=1)
        elif asset_id == 'CHAR_04':
            mask = binary_erosion(mask,iterations=3)
        elif asset_id.startswith('ENV_'):
            if asset_id == 'ENV_06_TRACTOR':
                holes=Image.new('L',image.size)
                ImageDraw.Draw(holes).polygon([(423,416),(461,434),(461,449),(439,441),(419,435)],fill=255)
                mask &= np.asarray(holes)==0
            mask = binary_erosion(mask,iterations=1)
    elif asset_id == 'PROP_03':
        mask = rgb.mean(axis=2)<215
    elif asset_id == 'PROP_04':
        mask = (rgb.mean(axis=2)<225) & (rgb[:,:,0]-rgb[:,:,2]<14)
    elif asset_id == 'PROP_05':
        mask = rgb.mean(axis=2)<248
    elif asset_id == 'CHAR_07':
        mask = (rgb.max(axis=2)-rgb.min(axis=2)>23) | (rgb.mean(axis=2)<65)
        mask = binary_fill_holes(mask)
        mask = binary_erosion(mask,iterations=1)
        # Remove the generated cap's fabric pattern; use the authored matte olive.
        cap = mask & (np.indices(mask.shape)[0]<155)
        flat=np.array(image);flat[cap]=(111,106,80);image=Image.fromarray(flat)
    else:
        raise ValueError(asset_id)
    labels, count = label(mask)
    sizes = np.bincount(labels.ravel()); sizes[0]=0
    mask = np.isin(labels,np.where(sizes>15)[0])
    mask_image = Image.fromarray(np.uint8(mask)*255)
    # The mask is retained at source-reference resolution for review and provenance.
    mask_image.save(folder/'subject_mask.png')
    bounds = mask_image.getbbox()
    cutout = Image.new('RGB',image.size,'white');cutout.paste(image,(0,0),mask_image)
    cutout = cutout.crop(bounds)
    edge=round(max(cutout.size)/.82)
    square=Image.new('RGB',(edge,edge),'white')
    square.paste(cutout,((edge-cutout.width)//2,(edge-cutout.height)//2))
    square.resize((1024,1024),Image.Resampling.LANCZOS).save(folder/'subject.png')
    (folder/'extraction.json').write_text(json.dumps({
        'method':'original-pixel manual silhouette mask; no generative redraw',
        'source':source.relative_to(ROOT).as_posix(),
        'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
        'mask':'subject_mask.png','reference_width':1024,
        'script':'scripts/art/extract_subjects.py','bounds':bounds,
    },indent=2)+'\n',encoding='utf-8')
    print(asset_id, bounds)

if __name__=='__main__':
    for asset_id in sys.argv[1:]: extract(asset_id)
