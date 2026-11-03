import os, pickle, numpy as np, cv2
WORK=os.environ.get('BODY_WORK','body_proto_out')
from PIL import Image, ImageDraw, ImageFont
G=2.0; X0,Y0=-700,-560
A=pickle.load(open(os.path.join(WORK,'assemblies.pkl'),'rb'))
COL={'анал':(200,90,90),'вагина':(120,200,230),'лобок':(190,150,230),'талия таз':(205,120,190),'ягодица':(225,180,230),'бедро1':(170,185,240),
 'Слой_18':(240,180,180),'Слой_19':(215,150,170),'пресс':(150,215,160),'живот':(205,240,150),'поясница':(240,190,130),
 'спина':(235,230,150),'ключица сздади':(230,200,140),'грудная клетка':(240,170,170)}
FILL=np.array([240,211,191]); SHADOW=np.array([214,160,160]); SOFT=np.array([236,190,180]); LINE=(92,66,52)
bx0,by0,bx1,by1=-520,-500,260,330; S=0.6; k=3
W,H=int((bx1-bx0)*S),int((by1-by0)*S)
tp=lambda P:np.round(((P-[bx0,by0])*S*k)).astype(np.int32)
def crop(m):   # raster mask (G grid) -> panel grid (S*k)
    x0=int((bx0-X0)*G); y0=int((by0-Y0)*G); x1=int((bx1-X0)*G); y1=int((by1-Y0)*G)
    return cv2.resize(m[y0:y1,x0:x1].astype(np.float32),(W*k,H*k),interpolation=cv2.INTER_LINEAR)
def panel(names,mode):
    img=np.full((H*k,W*k,3),255,np.uint8)
    for nm in names:
        a=A[nm]
        sil=np.zeros(img.shape[:2],np.uint8); cv2.fillPoly(sil,[tp(c) for c in a['outline']],1)
        g=int(round(2.4*S*k*1.4)); dark=cv2.dilate(sil,cv2.getStructuringElement(cv2.MORPH_ELLIPSE,(2*g+1,)*2))
        img[dark>0]=LINE
        if mode=='zones':
            for n in a['layers'][::-1]:
                for c in a['zones'][n]: cv2.fillPoly(img,[tp(c)],COL[n])
            img[(sil==0)&(dark>0)]=LINE
            for n in a['layers']:
                for c in a['zones'][n]: cv2.polylines(img,[tp(c)],True,(150,110,95),max(1,k//2),cv2.LINE_AA)
            # re-clip zones to the outline
            m=(sil>0)
            bg=img.copy(); 
        else:   # volume: a dome for the whole assembly + a smaller one per muscle group -> normals -> light
            outer=a['outer'].astype(np.uint8); hgt=np.zeros(outer.shape,np.float32)
            def dome(m,R):
                d=cv2.distanceTransform(m.astype(np.uint8),cv2.DIST_L2,5)/G; t=np.minimum(d/R,1.0); return R*np.sqrt(1-(1-t)**2)
            hgt+=dome(outer,95)
            for i,n in enumerate(a['layers']): hgt+=0.12*dome(a['part']==i+1,30)
            hgt=cv2.GaussianBlur(hgt,(0,0),2*G)
            gy,gx=np.gradient(hgt*G)
            N=np.dstack([-gx,-gy,np.ones_like(hgt)]); N/=np.linalg.norm(N,axis=2,keepdims=True)
            L=np.array([-0.55,-0.55,0.63]); L/=np.linalg.norm(L)
            sh=crop((N@L)); hard=sh<0.42; soft=np.clip((0.8-sh)/0.35,0,1)
            col=FILL[None,None,:]*(1-0.45*soft[...,None])+SOFT[None,None,:]*(0.45*soft[...,None])
            col=np.where(hard[...,None],SHADOW[None,None,:],col)
            img[sil>0]=col[sil>0].astype(np.uint8)
    im=Image.fromarray(img).resize((W,H),Image.LANCZOS)
    return im
F=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',14)
P=[('1. торс',panel(['torso'],'zones')),('2. стык таза',panel(['pelvis'],'zones')),('3. нога',panel(['leg'],'zones')),
   ('вместе (1 < 2 < 3)',panel(['torso','pelvis','leg'],'zones')),('проба объёма и тени',panel(['torso','pelvis','leg'],'volume'))]
grid=Image.new('RGB',(3*W,2*H),(255,255,255))
for i,(t,im) in enumerate(P):
    ImageDraw.Draw(im).text((8,6),t,fill=(0,0,0),font=F); grid.paste(im,((i%3)*W,(i//3)*H))
grid.save(os.path.join(WORK,'assemblies.png')); print(grid.size)
