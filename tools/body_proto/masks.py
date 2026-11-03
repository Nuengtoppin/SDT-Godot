import sys, os, pickle, json, numpy as np, cv2
from scipy.spatial import Delaunay
from scipy.sparse import lil_matrix
from scipy.sparse.linalg import spsolve
WORK=os.environ.get('BODY_WORK','body_proto_out')
d=pickle.load(open(os.path.join(WORK,'body_items.pkl'),'rb')); items=d['items']
G=2.0                       # raster px per unit
X0,Y0,X1,Y1=-700,-560,380,420
W=int((X1-X0)*G); H=int((Y1-Y0)*G)
to_px=lambda p:((p[0]-X0)*G,(p[1]-Y0)*G)
def mask(name):
    k=[k for k in items if k.split('#')[0]==name][0]
    m=np.zeros((H,W),np.uint8)
    for kind,col,al,polys in items[k]:
        if kind!='fill': continue
        mm=np.zeros((H,W),np.uint8)
        for poly in polys:
            if len(poly)<3: continue
            t=np.zeros((H,W),np.uint8)
            cv2.fillPoly(t,[np.array([to_px(p) for p in poly],np.float32).round().astype(np.int32)],1)
            mm^=t
        m|=mm
    return m.astype(bool)
GROUPS={'rib':['грудная клетка','ключица сздади'],
        'pelvis':['тазовая кость','седалище','лобок','анал','вагина','талия таз'],
        'waist':['живот','пресс','поясница','спина'],
        'butt':['ягодица'],'thigh':['бедро1','Слой_18','Слой_19']}
Z={n:mask(n) for g in GROUPS.values() for n in g}
R={n:mask(n) for n in ['Back','Chest','Chest Under','Right Thigh','Right Calf']}
body=R['Back']|R['Chest']|R['Chest Under']|R['Right Thigh']
grp={g:np.any([Z[n] for n in ns],axis=0)&body for g,ns in GROUPS.items()}
def smooth(m,r):
    k=cv2.getStructuringElement(cv2.MORPH_ELLIPSE,(int(2*r*G)+1,int(2*r*G)+1))
    m=cv2.morphologyEx(m.astype(np.uint8),cv2.MORPH_CLOSE,k); return cv2.morphologyEx(m,cv2.MORPH_OPEN,k).astype(bool)
under=smooth((Z['тазовая кость']|Z['талия таз']|Z['седалище'])&body,18)   # the pelvis under the thigh: big forms only, smooth
torso=R['Back']|R['Chest']|R['Chest Under']|grp['rib']|grp['waist']|under
thigh=R['Right Thigh']|grp['butt']|grp['thigh']
def clean(m):
    n,lab,st,_=cv2.connectedComponentsWithStats(m.astype(np.uint8))
    k=1+np.argmax(st[1:,cv2.CC_STAT_AREA]); m=lab==k
    m=cv2.morphologyEx(m.astype(np.uint8),cv2.MORPH_CLOSE,np.ones((5,5),np.uint8)).astype(bool)
    # fill holes
    ff=(~m).astype(np.uint8).copy(); h_,w_=ff.shape; msk=np.zeros((h_+2,w_+2),np.uint8)
    cv2.floodFill(ff,msk,(0,0),2); return m|(ff==1)
torso=smooth(clean(torso),6); thigh=smooth(clean(thigh),12)
torso_base=smooth(clean(R['Back']|R['Chest']|R['Chest Under']|grp['rib']|grp['waist']),6)
np.savez_compressed(os.path.join(WORK,'proto_masks.npz'),torso=torso,thigh=thigh,under=under,torso_base=torso_base,**{'g_'+g:m for g,m in grp.items()})
print('torso px',torso.sum()/G/G,'thigh',thigh.sum()/G/G)
