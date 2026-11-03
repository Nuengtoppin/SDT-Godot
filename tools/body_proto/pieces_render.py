import os, pickle, numpy as np, cv2
WORK=os.environ.get('BODY_WORK','body_proto_out')
from PIL import Image, ImageDraw, ImageFont
G=2.0; X0,Y0=-700,-560
R=pickle.load(open(os.path.join(WORK,'pieces.pkl'),'rb')); P=R['pieces']; ORDER=R['order']
COL={'анал':(200,90,90),'вагина':(120,200,230),'лобок':(190,150,230),'талия таз':(205,120,190),'ягодица':(225,180,230),'бедро1':(170,185,240),
 'Слой_18':(240,180,180),'Слой_19':(215,150,170),'пресс':(150,215,160),'живот':(205,240,150),'поясница':(240,190,130),
 'спина':(235,230,150),'ключица сздади':(230,200,140),'грудная клетка':(240,170,170)}
FILL=np.array([240,211,191]); SHADOW=np.array([212,158,158]); SOFT=np.array([236,190,180]); LINE=(92,66,52)
bx0,by0,bx1,by1=-520,-520,300,400; S=0.6; k=3
W,H=int((bx1-bx0)*S),int((by1-by0)*S)
tp=lambda Q:np.round(((np.asarray(Q)-[bx0,by0])*S*k)).astype(np.int32)
def crop(m):
    x0=int((bx0-X0)*G); y0=int((by0-Y0)*G); x1=int((bx1-X0)*G); y1=int((by1-Y0)*G)
    return cv2.resize(m[y0:y1,x0:x1].astype(np.float32),(W*k,H*k),interpolation=cv2.INTER_LINEAR)
def shade_of(g):
    p=P[g]; o=p['mask'].astype(np.uint8)
    def dome(m,Rr):
        d=cv2.distanceTransform(m.astype(np.uint8),cv2.DIST_L2,5)/G; t=np.minimum(d/Rr,1.0); return Rr*np.sqrt(1-(1-t)**2)
    h=dome(o,90).astype(np.float32)
    for n,z in p['zmask'].items(): h+=0.06*dome(z&p['mask'],28)
    h=cv2.GaussianBlur(h,(0,0),5*G); gy,gx=np.gradient(h*G)
    N=np.dstack([-gx,-gy,np.ones_like(h)]); N/=np.linalg.norm(N,axis=2,keepdims=True)
    L=np.array([-0.55,-0.55,0.63]); L/=np.linalg.norm(L); return crop(N@L)
def panel(names,mode,zones=True):
    img=np.full((H*k,W*k,3),255,np.uint8); lw=max(1,int(2.2*S*k))
    for g in names:
        p=P[g]; sil=np.zeros(img.shape[:2],np.uint8); cv2.fillPoly(sil,[tp(c) for c in p['outline']],1)
        if mode=='zones':
            img[sil>0]=FILL
            for n,cs in p['zones'].items():
                for c in cs:
                    t=np.zeros_like(sil); cv2.fillPoly(t,[tp(c)],1); img[(t>0)&(sil>0)]=COL[n]
        elif mode=='flat': img[sil>0]=FILL
        else:
            sh=shade_of(g); hard=sh<0.42; soft=np.clip((0.8-sh)/0.35,0,1)
            col=FILL[None,None,:]*(1-0.45*soft[...,None])+SOFT[None,None,:]*(0.45*soft[...,None])
            col=np.where(hard[...,None],SHADOW[None,None,:],col); img[sil>0]=col[sil>0].astype(np.uint8)
        if mode=='zones':
            for n,cs in p['zones'].items():
                for c in cs: cv2.polylines(img,[tp(c)],True,(160,120,105),max(1,k//2),cv2.LINE_AA)
            img[(sil==0)&(img.sum(2)==0)]=255
        for c in p['outline']: cv2.polylines(img,[tp(c)],True,LINE,lw,cv2.LINE_AA)
    return Image.fromarray(img).resize((W,H),Image.LANCZOS)
F=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',14)
def vs_vanilla():
    items=pickle.load(open(os.path.join(WORK,'body_items.pkl'),'rb'))['items']
    img=np.full((H*k,W*k,3),255,np.uint8)
    for n in ['Left Shoulder','Back','Chest','Chest Under','Right Thigh']:
        key=[kk for kk in items if kk.split('#')[0]==n][0]
        for kind,col,al,polys in items[key]:
            if kind!='fill': continue
            m=np.zeros(img.shape[:2],np.uint8)
            for poly in polys:
                if len(poly)<3: continue
                t=np.zeros_like(m); cv2.fillPoly(t,[tp(poly)],1); m^=t
            img[m>0]=(0.6*img[m>0]+0.4*np.array([150,150,150])).astype(np.uint8)
    for g in ORDER:
        for c in P[g]['outline']: cv2.polylines(img,[tp(c)],True,(200,30,30),max(1,k),cv2.LINE_AA)
    return Image.fromarray(img).resize((W,H),Image.LANCZOS)
PN=[('группы мышц (6 кусков)',panel(ORDER,'zones')),('контуры кусков',panel(ORDER,'flat')),('сверка: красное — наше, серое — ваниль',vs_vanilla())]
grid=Image.new('RGB',(len(PN)*W,H),(255,255,255))
for i,(t,im) in enumerate(PN):
    ImageDraw.Draw(im).text((8,6),t,fill=(0,0,0),font=F); grid.paste(im,(i*W,0))
grid.save(os.path.join(WORK,'pieces.png')); print(grid.size)
