import sys, os, pickle, numpy as np, cv2
WORK=os.environ.get('BODY_WORK','body_proto_out')
from scipy import ndimage
from scipy.interpolate import splprep, splev
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
L_=np.array([-48.8,-113.15]); T_=np.array([64.2,-273.15])
yy,xx=np.mgrid[0:H,0:W]; PU=np.stack([xx/G+X0,yy/G+Y0],-1); ax=T_-L_; S_=((PU-L_)@ax)/(ax@ax)
def blur_bin(m,r):
    k=int(r*G)*2+1; return cv2.GaussianBlur(m.astype(np.float32),(k,k),0)>0.5
def biggest(m):
    n,lb,st,_=cv2.connectedComponentsWithStats(m.astype(np.uint8))
    return lb==(1+np.argmax(st[1:,cv2.CC_STAT_AREA])) if n>1 else m
# --- the torso's layers, top first; the ribcage takes the belly's sliver along its front (above its own bottom)
TORSO=['грудная клетка','пресс','живот','поясница','спина']
Z={n:mask(n) for n in TORSO}
rib=Z['грудная клетка']; front=rib&(PU[...,0]>np.median(PU[...,0][rib]))
s_bottom=np.percentile(S_[front],3)
Z['живот']=Z['живот']&~(S_>s_bottom+0.02)
Z['грудная клетка']=rib|(mask('живот')&(S_>s_bottom+0.02))
lab=np.zeros((H,W),np.int16)
for i in reversed(range(len(TORSO))): lab[Z[TORSO[i]]]=i+1
def partition(lab,n,outer,r):
    body=lab>0
    _,(iy,ix)=ndimage.distance_transform_edt(~body,return_indices=True)
    full=lab[iy,ix]; full[~outer]=0
    score=np.stack([cv2.GaussianBlur((full==i+1).astype(np.float32),(int(r*G)*2+1,)*2,0) for i in range(n)])
    return np.where(outer,score.argmax(0)+1,0).astype(np.int16)
def outer_of(m,close=12,r=14):
    k=cv2.getStructuringElement(cv2.MORPH_ELLIPSE,(int(close*G)*2+1,)*2)
    return biggest(blur_bin(ndimage.binary_fill_holes(cv2.morphologyEx(m.astype(np.uint8),cv2.MORPH_CLOSE,k).astype(bool)),r))
# the outer edge from the vanilla template (Back, Chest, Chest Under); Dima's zones divide the inside
VAN=lambda *ns: np.any([mask(n) for n in ns],axis=0)
torso_outer=outer_of(VAN('Back','Chest','Chest Under'),6,5)
tp=partition(lab,len(TORSO),torso_outer,22)
PIECES={}
grp={'back':['поясница','спина'],'belly':['пресс','живот'],'ribcage':['грудная клетка']}
# cut-out style: the lower pieces reach under the upper ones (no gaps), all within the torso's one smooth outline
under_k=cv2.getStructuringElement(cv2.MORPH_ELLIPSE,(int(14*G)*2+1,)*2)
for g,names in grp.items():
    m=np.zeros((H,W),bool)
    for n in names: m|=tp==TORSO.index(n)+1
    if g!='ribcage': m=cv2.dilate(m.astype(np.uint8),under_k).astype(bool)
    m=biggest(blur_bin(m&torso_outer,4))&torso_outer
    PIECES[g]=(m,{n:(tp==TORSO.index(n)+1) for n in names})
PEL=['анал','лобок','талия таз','вагина']; LEG=['ягодица','Слой_18','Слой_19','бедро1']
for g,names in [('pelvis',PEL),('leg',LEG)]:
    Zs=[mask(n) for n in names]; lb=np.zeros((H,W),np.int16)
    for i in reversed(range(len(Zs))): lb[Zs[i]]=i+1
    o=outer_of(lb>0,10,12) if g=='pelvis' else outer_of(VAN('Right Thigh')|Zs[0],6,5)   # the leg: the vanilla thigh (+ the buttock)
    p=partition(lb,len(names),o,16)
    PIECES[g]=(o,{n:(p==i+1)&o for i,n in enumerate(names)})
# --- smooth vector curves: a periodic smoothing spline through the raster contour
def curve(m,smooth=1.0,minarea=30):
    cs,_=cv2.findContours(m.astype(np.uint8),cv2.RETR_EXTERNAL,cv2.CHAIN_APPROX_NONE); out=[]
    for c in cs:
        if cv2.contourArea(c)<minarea*G*G: continue
        P=c[:,0,:].astype(float)/G+[X0,Y0]; P=P[::3]
        if len(P)<8: continue
        tck,_=splprep([P[:,0],P[:,1]],s=len(P)*smooth,per=True,k=3)
        u=np.linspace(0,1,max(60,len(P)*2),endpoint=False); x,y=splev(u,tck); out.append(np.c_[x,y])
    return out
# the far shoulder with its clavicle: the vanilla Left Shoulder and Dima's clavicle zone, under everything
cl=outer_of(VAN('Left Shoulder')|mask('ключица сздади'),4,4)
PIECES['clavicle']=(cl,{'ключица сздади':cl})
ORDER=['clavicle','back','belly','ribcage','pelvis','leg']
res={'order':ORDER,'pieces':{}}
for g in ORDER:
    o,zones=PIECES[g]
    res['pieces'][g]=dict(mask=o,outline=curve(o,3.0),zones={n:curve(z&o,2.0,12) for n,z in zones.items()},zmask=zones)
pickle.dump(res,open(os.path.join(WORK,'pieces.pkl'),'wb'))
print({g:(len(res['pieces'][g]['outline']),{n:len(v) for n,v in res['pieces'][g]['zones'].items()}) for g in ORDER})
