"""Flat-color subject paintovers for the generated barrel/basket references.
No scene background or ground shadow is retained. These isolated drawings are
reviewed before image-to-3D; the source references remain next to subject.png.
"""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/'assets/models/aholo/_input'
wood='#B39A70';dark='#665A48';light='#C7AE82';iron='#515A5A';cream='#E1DDC5'

im=Image.new('RGB',(1024,1024),'white');d=ImageDraw.Draw(im)
outline=[(240,220),(785,220),(816,430),(820,670),(760,852),(700,890),(328,890),(265,850),(208,670),(210,430)]
d.polygon(outline,fill=wood)
d.polygon([(240,220),(310,230),(278,640),(328,890),(265,850),(208,670),(210,430)],fill=light)
d.polygon([(730,230),(785,220),(816,430),(820,670),(760,852),(700,890),(735,650)],fill='#9C805E')
for x in [305,385,470,555,640,725]:
    d.line([(x,280),(x+(x-512)*.04,630),(512+(x-512)*.88,870)],fill='#9C805E',width=5)
for y in [365,735]:
    d.polygon([(218,y),(812,y),(812,y+55),(785,y+76),(245,y+76),(218,y+55)],fill=iron)
    d.ellipse((220,y-22,812,y+39),fill='#626B69')
    d.ellipse((220,y-34,812,y+4),fill=wood)
d.ellipse((238,105,786,338),fill=light)
d.ellipse((267,129,757,302),fill=dark)
d.ellipse((296,155,728,282),fill='#514838')
dest=BASE/'ENV_09_BARREL';dest.mkdir(exist_ok=True)
im.save(dest/'subject.png')
im.save(ROOT/'assets/2d/ENV_09_BARREL_木制储水桶_主体图.png')

im=Image.new('RGB',(1024,1024),'white');d=ImageDraw.Draw(im)
# Two thick intact loops; large bundles avoid fibre and wicker noise.
d.ellipse((162,178,322,602),outline=wood,width=44)
d.ellipse((706,167,866,595),outline=wood,width=44)
d.ellipse((170,335,855,695),fill=dark)
for box,color in [((345,195,665,540),'#D5D4BD'),((200,346,524,646),cream),((504,321,812,623),'#F0EBD6')]:
    d.ellipse(box,fill=color)
    x0,y0,x1,y1=box
    d.ellipse((x0+36,y0+10,x1-28,y1-50),fill=color)
d.polygon([(164,495),(861,495),(798,817),(711,861),(318,861),(227,813)],fill=wood)
d.ellipse((225,751,801,890),fill=wood)
d.arc((163,339,862,665),0,180,fill=light,width=39)
for y in [607,678,749,813]:
    d.arc((211,y-96,815,y+75),0,180,fill=light,width=20)
for x in [287,400,512,624,737]:
    d.line([(x,607),(512+(x-512)*.82,842)],fill='#9C805E',width=13)
d.arc((162,178,322,602),170,350,fill=light,width=18)
d.arc((706,167,866,595),-170,10,fill=light,width=18)
dest=BASE/'ENV_09_WOOL';dest.mkdir(exist_ok=True)
im.save(dest/'subject.png')
im.save(ROOT/'assets/2d/ENV_09_WOOL_剪毛棚羊毛篮_主体图.png')
