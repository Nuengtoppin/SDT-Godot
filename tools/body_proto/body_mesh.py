import sys, os, numpy as np, cv2, pickle
WORK=os.environ.get('BODY_WORK','body_proto_out')
from scipy.spatial import Delaunay
from scipy.sparse import lil_matrix, csr_matrix
from scipy.sparse.linalg import spsolve
G=2.0; X0,Y0=-700,-560
_mp=os.path.join(WORK,'proto_masks.npz')
M=np.load(_mp) if os.path.exists(_mp) else None   # frames.py needs masks.py first; doll.py does not
to_u=lambda px:np.array([px[...,0]/G+X0, px[...,1]/G+Y0]).T if px.ndim==2 else None
def inside(m,P):
    q=np.round((P-[X0,Y0])*G).astype(int); h,w=m.shape
    ok=(q[:,0]>=0)&(q[:,0]<w)&(q[:,1]>=0)&(q[:,1]<h)
    r=np.zeros(len(P),bool); r[ok]=m[q[ok,1],q[ok,0]]; return r
def build(m,step=14.0,bstep=7.0):
    cs,_=cv2.findContours(m.astype(np.uint8),cv2.RETR_EXTERNAL,cv2.CHAIN_APPROX_NONE)
    c=max(cs,key=cv2.contourArea)[:,0,:].astype(float)
    c=c/G+[X0,Y0]
    # resample boundary evenly
    seg=np.r_[0,np.cumsum(np.linalg.norm(np.diff(np.vstack([c,c[:1]]),axis=0),axis=1))]
    L=seg[-1]; n=int(L/bstep); t=np.linspace(0,L,n,endpoint=False)
    cc=np.vstack([c,c[:1]]); bx=np.interp(t,seg,cc[:,0]); by=np.interp(t,seg,cc[:,1])
    B=np.c_[bx,by]
    # interior: hex grid, away from boundary
    dist=cv2.distanceTransform(m.astype(np.uint8),cv2.DIST_L2,5)/G
    xs=np.arange(X0,X0+m.shape[1]/G,step); ys=np.arange(Y0,Y0+m.shape[0]/G,step*0.866)
    I=[]
    for j,y in enumerate(ys):
        for x in xs+(step/2 if j%2 else 0): I.append((x,y))
    I=np.array(I); q=np.round((I-[X0,Y0])*G).astype(int)
    ok=(q[:,0]<m.shape[1])&(q[:,1]<m.shape[0])
    I=I[ok]; q=q[ok]; I=I[dist[q[:,1],q[:,0]]>step*0.45]
    V=np.vstack([B,I]); nb=len(B)
    tri=Delaunay(V).simplices
    cen=V[tri].mean(axis=1); tri=tri[inside(m,cen)]
    # drop triangles across concave gaps: any edge longer than 2.5 step
    e=np.max([np.linalg.norm(V[tri[:,a]]-V[tri[:,b]],axis=1) for a,b in [(0,1),(1,2),(2,0)]],axis=0)
    tri=tri[e<step*2.2]
    return V,tri,nb
def harmonic(V,tri,fixed):  # fixed: {vertex: weight vector}; returns weights (n,k)
    n=len(V); k=len(next(iter(fixed.values())))
    A=lil_matrix((n,n)); 
    nbrs=[set() for _ in range(n)]
    for t in tri:
        for a in range(3):
            for b in range(3):
                if a!=b: nbrs[t[a]].add(t[b])
    free=[i for i in range(n) if i not in fixed]; fi={v:i for i,v in enumerate(free)}
    A=lil_matrix((len(free),len(free))); rhs=np.zeros((len(free),k))
    for v in free:
        r=fi[v]; nb=nbrs[v]; A[r,r]=len(nb) if nb else 1
        for u in nb:
            if u in fixed: rhs[r]+=fixed[u]
            else: A[r,fi[u]]-=1
    Wt=np.zeros((n,k))
    for v,w in fixed.items(): Wt[v]=w
    if free: Wt[free]=spsolve(csr_matrix(A),rhs).reshape(len(free),k)
    return Wt
def harmonic_grid(m, fixed_masks, cell=4.0):
    """Weights on a regular grid over mask m: fixed_masks = list of bool masks (one per bone, same shape as m),
    solved as Laplace (Neumann at the outline). Returns a sampler P -> (n,k)."""
    f=int(round(cell*G)); h,w=m.shape; hh,ww=(h+f-1)//f,(w+f-1)//f
    def down(a):
        p=np.zeros((hh*f,ww*f),bool); p[:h,:w]=a; return p.reshape(hh,f,ww,f).mean(axis=(1,3))>0.5
    D=down(m); F=[down(x)&D for x in fixed_masks]; k=len(F)
    fixed=np.zeros((hh,ww),int)-1
    for b,x in enumerate(F): fixed[x&(fixed<0)]=b
    idx=-np.ones((hh,ww),int); free=D&(fixed<0); idx[free]=np.arange(free.sum())
    n=free.sum(); rows=[];cols=[];vals=[]; rhs=np.zeros((n,k))
    ys,xs=np.nonzero(free)
    for y,x in zip(ys,xs):
        r=idx[y,x]; deg=0
        for dy,dx in ((1,0),(-1,0),(0,1),(0,-1)):
            yy,xx=y+dy,x+dx
            if 0<=yy<hh and 0<=xx<ww and D[yy,xx]:
                deg+=1
                if fixed[yy,xx]>=0: rhs[r,fixed[yy,xx]]+=1
                else: rows.append(r); cols.append(idx[yy,xx]); vals.append(-1.0)
        rows.append(r); cols.append(r); vals.append(max(deg,1))
    A=csr_matrix((vals,(rows,cols)),shape=(n,n))
    Wg=np.zeros((hh,ww,k))
    for b in range(k): Wg[fixed==b,b]=1
    if n: Wg[free]=spsolve(A,rhs).reshape(n,k)
    # fill outside cells from nearest inside (for boundary sampling)
    from scipy.ndimage import distance_transform_edt
    _,(iy,ix)=distance_transform_edt(~D,return_indices=True)
    Wg=Wg[iy,ix]
    from scipy.ndimage import map_coordinates
    def sample(P):
        cx=((P[:,0]-X0)*G)/f-0.5; cy=((P[:,1]-Y0)*G)/f-0.5
        out=np.stack([map_coordinates(Wg[:,:,b],[cy,cx],order=1,mode='nearest') for b in range(k)],1)
        return out/np.maximum(out.sum(1,keepdims=True),1e-9)
    return sample
