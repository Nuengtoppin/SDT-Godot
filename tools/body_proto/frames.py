import sys, os; sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from body_mesh import *
import matplotlib.tri as mtri
from PIL import Image, ImageDraw, ImageFont
H_=np.array([-240.8,3.85]); L_=np.array([-48.8,-113.15]); T_=np.array([64.2,-273.15]); N_=np.array([119.2,-453.15]); K_=np.array([160.3,291.1])
mt,mh=M['torso'],M['thigh']
Vh,Th,_=build(mh)
g=lambda n:M['g_'+n]
import pickle as pk
Zitems=pk.load(open(os.path.join(WORK,'body_items.pkl'),'rb'))['items']
_zc={}
def M_zone(n):
    if n not in _zc:
        k=[k for k in Zitems if k.split('#')[0]==n][0]; m=np.zeros(mt.shape,np.uint8)
        for kind,col,al,polys in Zitems[k]:
            if kind!='fill': continue
            mm=np.zeros(mt.shape,np.uint8)
            for poly in polys:
                if len(poly)<3: continue
                t=np.zeros(mt.shape,np.uint8); cv2.fillPoly(t,[np.round((np.array(poly)-[X0,Y0])*G).astype(np.int32)],1); mm^=t
            m|=mm
        _zc[n]=m.astype(bool)&(mt|mh)
    return _zc[n]
# thigh: [pelvis, thigh] - on a regular grid inside the outline
axh=K_-H_
yy,xx=np.mgrid[0:mh.shape[0],0:mh.shape[1]]; PU=np.stack([xx/G+X0,yy/G+Y0],-1)
shm=((PU-H_)@axh)/(axh@axh)
bone_core=cv2.erode((M_zone('тазовая кость')|M_zone('талия таз')|M_zone('седалище')).astype(np.uint8),np.ones((int(24*G),int(24*G)),np.uint8)).astype(bool)
edge=cv2.distanceTransform(mh.astype(np.uint8),cv2.DIST_L2,5)/G
Wh=harmonic_grid(mh,[bone_core&(edge>10),mh&(shm>0.6)])(Vh)
# the pelvis under the thigh: only where the thigh's skin still holds to the pelvis (else it peeks out as a corner)
wmap=np.zeros(mh.shape,np.float32)
tpx=lambda P:np.round((P-[X0,Y0])*G).astype(np.int32)
for t in Th:
    cv2.fillPoly(wmap,[tpx(Vh[t])],float(Wh[t,0].mean()))
under_ok=M['under']&((~mh)|(wmap>0.6))
def _smooth(m,r):
    k=cv2.getStructuringElement(cv2.MORPH_ELLIPSE,(int(2*r*G)+1,int(2*r*G)+1))
    m=cv2.morphologyEx(m.astype(np.uint8),cv2.MORPH_OPEN,k); return cv2.morphologyEx(m,cv2.MORPH_CLOSE,k).astype(bool)
mt=_smooth(M['torso_base']|under_ok,6)
Vt,Tt,_=build(mt)
# torso: [pelvis, ribcage]
ax=T_-L_
yy,xx=np.mgrid[0:mt.shape[0],0:mt.shape[1]]; PU=np.stack([xx/G+X0,yy/G+Y0],-1)
sm=((PU-L_)@ax)/(ax@ax)
Wt=harmonic_grid(mt,[mt&(g('pelvis')|(sm<-0.25)),mt&(g('rib')|(sm>1.1))])(Vt)
print('torso verts',len(Vt),'tris',len(Tt),' thigh verts',len(Vh),'tris',len(Th))
def rot(c,deg):
    r=np.radians(deg); C,S=np.cos(r),np.sin(r); R=np.array([[C,-S],[S,C]])
    return R, c-R@c
def comp(A,B):  # A after B
    return A[0]@B[0], A[0]@B[1]+A[1]
def apply(Tr,P): return P@Tr[0].T+Tr[1]
def pose(pelvis=0,waist=0,chest=0,hip=0):
    Mp=rot(H_,pelvis); Mw=comp(Mp,rot(L_,waist)); Mr=comp(Mw,rot(T_,chest)); Mt=comp(Mp,rot(H_,hip))
    vt=Wt[:,:1]*apply(Mp,Vt)+Wt[:,1:]*apply(Mr,Vt)
    vh=Wh[:,:1]*apply(Mp,Vh)+Wh[:,1:]*apply(Mt,Vh)
    bones=[apply(Mp,H_[None])[0],apply(Mw,L_[None])[0],apply(Mr,T_[None])[0],apply(Mr,N_[None])[0],apply(Mt,K_[None])[0]]
    return vt,vh,bones
# inner lines: zone contours mapped by barycentrics
def zone_lines(names,V,Tri):
    DL=Delaunay(V); out=[]
    f=lambda x,y: DL.find_simplex(np.c_[x,y])
    Tri=DL.simplices
    for n in names:
        cs,_=cv2.findContours(M_zone(n).astype(np.uint8),cv2.RETR_EXTERNAL,cv2.CHAIN_APPROX_NONE)
        for c in cs:
            if cv2.contourArea(c)<200: continue
            P=c[::3,0,:].astype(float)/G+[X0,Y0]
            ti=f(P[:,0],P[:,1]); ok=ti>=0; P=P[ok]; ti=ti[ok]
            a,b,cc=V[Tri[ti,0]],V[Tri[ti,1]],V[Tri[ti,2]]
            den=(b[:,1]-cc[:,1])*(a[:,0]-cc[:,0])+(cc[:,0]-b[:,0])*(a[:,1]-cc[:,1])
            l1=((b[:,1]-cc[:,1])*(P[:,0]-cc[:,0])+(cc[:,0]-b[:,0])*(P[:,1]-cc[:,1]))/den
            l2=((cc[:,1]-a[:,1])*(P[:,0]-cc[:,0])+(a[:,0]-cc[:,0])*(P[:,1]-cc[:,1]))/den
            out.append((Tri[ti],np.c_[l1,l2,1-l1-l2]))
    return out
tl=zone_lines(['грудная клетка','ключица сздади','живот','пресс','поясница','спина','тазовая кость','седалище','лобок','анал','вагина'],Vt,Tt)
hl=zone_lines(['ягодица','бедро1','Слой_18','Слой_19'],Vh,Th)
FILL=(240,211,191); LINE=(92,66,52)
def render(vt,vh,bones,title,S=0.5,box=(-560,-560,520,560)):
    bx0,by0,bx1,by1=box; w=int((bx1-bx0)*S); h=int((by1-by0)*S); k=4  # supersample
    tp=lambda P:np.round((P-[bx0,by0])*S*k).astype(np.int32)
    img=np.full((h*k,w*k,3),255,np.uint8)
    sil=np.zeros((h*k,w*k),np.uint8)
    for V,T in [(vt,Tt),(vh,Th)]:
        cv2.fillPoly(sil,[tp(V[t]) for t in T],1)
    grow=int(round(2.4*S*k*1.6))
    dark=cv2.dilate(sil,cv2.getStructuringElement(cv2.MORPH_ELLIPSE,(2*grow+1,2*grow+1)))
    img[dark>0]=LINE
    def fill(V,T): 
        for t in T: cv2.fillPoly(img,[tp(V[t])],FILL)
    def lines(L,V,col):
        for tri,bc in L:
            P=(V[tri]*bc[:,:,None]).sum(axis=1)
            cv2.polylines(img,[tp(P)],True,col,max(1,int(S*k*0.9)),cv2.LINE_AA)
    fill(vt,Tt); lines(tl,vt,(205,160,140)); fill(vh,Th); lines(hl,vh,(205,160,140))
    for a,b in [(0,1),(1,2),(2,3),(0,4)]:
        cv2.line(img,tuple(tp(bones[a][None])[0]),tuple(tp(bones[b][None])[0]),(255,130,0),max(1,int(S*k*1.5)),cv2.LINE_AA)
    for p in bones: cv2.circle(img,tuple(tp(p[None])[0]),int(S*k*5),(255,130,0),-1,cv2.LINE_AA)
    im=Image.fromarray(img).resize((w,h),Image.LANCZOS); dr=ImageDraw.Draw(im)
    dr.text((8,6),title,fill=(0,0,0),font=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',15))
    return im
frames=[("покой (шаблон)",{}),("талия +20",{'waist':20}),("талия -20",{'waist':-20}),
        ("бедро -35 (к животу)",{'hip':-35}),("бедро +45",{'hip':45}),("бедро +100 (без поправок)",{'hip':100}),
        ("таз +15, бедро на месте",{'pelvis':15,'hip':-15}),("таз -15, бедро на месте",{'pelvis':-15,'hip':15}),("грудь +15 / талия +10",{'waist':10,'chest':15})]
ims=[render(*pose(**kw),t) for t,kw in frames]
w,h=ims[0].size; grid=Image.new('RGB',(3*w,3*h),(255,255,255))
for i,im in enumerate(ims): grid.paste(im,((i%3)*w,(i//3)*h))
grid.save(os.path.join(WORK,'proto_frames.png')); print(grid.size)
pickle.dump(dict(Vt=Vt,Tt=Tt,Wt=Wt,Vh=Vh,Th=Th,Wh=Wh),open(os.path.join(WORK,'proto_mesh.pkl'),'wb'))
