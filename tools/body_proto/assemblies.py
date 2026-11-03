import sys, os, pickle, numpy as np, cv2
WORK=os.environ.get('BODY_WORK','body_proto_out')
from scipy import ndimage
G=2.0; X0,Y0,X1,Y1=-700,-560,380,420; W=int((X1-X0)*G); H=int((Y1-Y0)*G)
items=pickle.load(open(os.path.join(WORK,'body_items.pkl'),'rb'))['items']
def mask(name):
    k=[k for k in items if k.split('#')[0]==name][0]; m=np.zeros((H,W),np.uint8)
    for kind,col,al,polys in items[k]:
        if kind!='fill': continue
        mm=np.zeros((H,W),np.uint8)
        for poly in polys:
            if len(poly)<3: continue
            t=np.zeros((H,W),np.uint8); cv2.fillPoly(t,[np.round((np.array(poly)-[X0,Y0])*G).astype(np.int32)],1); mm^=t
        m|=mm
    return m.astype(bool)
# Dima's assemblies, bottom to top; layers inside each top first (his .fla order)
ASM=[('torso',['грудная клетка','ключица сздади','пресс','живот','поясница','спина']),
     ('pelvis',['анал','лобок','талия таз','вагина']),
     ('leg',['ягодица','Слой_18','Слой_19','бедро1'])]
INNER=['тазовая кость','седалище']
def blur_bin(m,r):
    k=int(r*G)*2+1; return cv2.GaussianBlur(m.astype(np.float32),(k,k),0)>0.5
def contours(m,eps=0.8,minarea=40):
    cs,_=cv2.findContours(m.astype(np.uint8),cv2.RETR_EXTERNAL,cv2.CHAIN_APPROX_NONE); out=[]
    for c in cs:
        if cv2.contourArea(c)<minarea*G*G: continue
        c=cv2.approxPolyDP(c,eps*G,True)[:,0,:].astype(float)/G+[X0,Y0]
        for _ in range(3):
            n=np.roll(c,-1,0); c=np.stack([0.75*c+0.25*n,0.25*c+0.75*n],1).reshape(-1,2)
        out.append(c)
    return out
res={}
for name,layers in ASM:
    Z=[mask(n) for n in layers]
    lab=np.zeros((H,W),np.int16)
    for i in reversed(range(len(Z))): lab[Z[i]]=i+1
    body=lab>0
    k=np.ones((int(10*G),int(10*G)),np.uint8)
    outer=blur_bin(ndimage.binary_fill_holes(cv2.morphologyEx(body.astype(np.uint8),cv2.MORPH_CLOSE,k).astype(bool)),9)
    n_,lb,st,_=cv2.connectedComponentsWithStats(outer.astype(np.uint8)); outer=lb==(1+np.argmax(st[1:,cv2.CC_STAT_AREA]))
    _,(iy,ix)=ndimage.distance_transform_edt(~body,return_indices=True)
    full=lab[iy,ix]; full[~outer]=0
    score=np.stack([cv2.GaussianBlur((full==i+1).astype(np.float32),(int(8*G)*2+1,)*2,0) for i in range(len(Z))])
    part=np.where(outer,score.argmax(0)+1,0).astype(np.int16)
    res[name]=dict(layers=layers,outer=outer,part=part,outline=contours(outer,1.2),
                   zones={n:contours(part==i+1,0.8,15) for i,n in enumerate(layers)})
    print(name,{n:len(v) for n,v in res[name]['zones'].items()},'outline pieces',len(res[name]['outline']))
res['inner']={n:contours(blur_bin(mask(n),5)) for n in INNER}
pickle.dump(res,open(os.path.join(WORK,'assemblies.pkl'),'wb'))
