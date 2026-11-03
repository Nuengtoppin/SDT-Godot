import sys, os; sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
WORK=os.environ.get('BODY_WORK','body_proto_out'); os.makedirs(WORK,exist_ok=True)
from xfl import *
from PIL import Image, ImageDraw, ImageChops, ImageFont
import numpy as np
root=sys.argv[1]   # the .fla unpacked (unfla.py)
lib=Lib(root)
sym=lib.sym('Templates/Body/Body Template - копия')
layers=[L for L in sym.iter(X+'DOMLayer')]
names=[L.get('name') for L in layers]
I=(1,0,0,1,0,0)
items={L.get('name')+f'#{i}':lib.render_layer(L,I) for i,L in enumerate(layers) if L.get('layerType')!='folder'}
pts=[p for its in items.values() for it in its for poly in it[3] for p in poly]
xs=[p[0] for p in pts]; ys=[p[1] for p in pts]
bx0,by0,bx1,by1=min(xs),min(ys),max(xs),max(ys)
print('bounds',bx0,by0,bx1,by1)
S=1.0
W=int((bx1-bx0)*S)+20; H=int((by1-by0)*S)+20
tf=lambda p:((p[0]-bx0)*S+10,(p[1]-by0)*S+10)
def mask_of(polys):
    m=Image.new('1',(W,H),0)
    for poly in polys:
        if len(poly)<3: continue
        t=Image.new('1',(W,H),0); ImageDraw.Draw(t).polygon([tf(p) for p in poly],fill=1)
        m=ImageChops.logical_xor(m,t)
    return m
def draw_items(img,its,alpha=1.0,override=None):
    for kind,col,al,polys in its:
        if kind=='fill':
            c=override or col
            rgb=tuple(int(c[i:i+2],16) for i in (1,3,5))
            layer=Image.new('RGBA',(W,H),rgb+(int(255*al*alpha),))
            img.paste(layer,(0,0),mask_of(polys))
        else:
            d=ImageDraw.Draw(img)
            for poly in polys: d.line([tf(p) for p in poly],fill=col,width=max(1,int(al*S)))
import pickle
pickle.dump(dict(items=items,b=(bx0,by0,bx1,by1),names=names),open(os.path.join(WORK,'body_items.pkl'),'wb'))
