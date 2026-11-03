import re, os, xml.etree.ElementTree as ET
X='{http://ns.adobe.com/xfl/2008/}'
def num(t):
    if t.startswith('#'):
        h=t[1:]; ip,_,fp=h.partition('.')
        v=int(ip,16)
        if v>=1<<23: v-=1<<24  # signed 24-bit? (XFL hex is 32-bit two's complement)
        return (v+(int(fp,16)/256 if fp else 0))/20
    return float(t)/20
TOK=re.compile(r'[!|/\[\]]|S\d+|#[0-9A-Fa-f]+(?:\.[0-9A-Fa-f]+)?|-?\d+(?:\.\d+)?')
def parse_edges(s):
    """-> list of paths: each list of points (pen down runs)"""
    runs=[]; cur=None; pen=None
    toks=TOK.findall(s); i=0
    def rd():
        nonlocal i
        v=num(toks[i]); i+=1; return v
    while i<len(toks):
        t=toks[i]; i+=1
        if t.startswith('S'): continue
        if t=='!':
            x,y=rd(),rd()
            if cur and len(cur)>1 and cur[-1]!=(x,y): runs.append(cur); cur=None
            if cur is None or cur[-1]!=(x,y): 
                if cur and len(cur)>1: runs.append(cur)
                cur=[(x,y)]
        elif t in '|/':
            x,y=rd(),rd(); cur.append((x,y))
        elif t in '[]':
            cx,cy,x,y=rd(),rd(),rd(),rd(); x0,y0=cur[-1]
            for k in range(1,9):
                u=k/8; cur.append(((1-u)**2*x0+2*u*(1-u)*cx+u*u*x,(1-u)**2*y0+2*u*(1-u)*cy+u*u*y))
    if cur and len(cur)>1: runs.append(cur)
    return runs
def mat(e):
    m=e.find(X+'matrix/'+X+'Matrix')
    if m is None: return (1,0,0,1,0,0)
    g=lambda k,d: float(m.get(k,d))
    return (g('a',1),g('b',0),g('c',0),g('d',1),g('tx',0),g('ty',0))
def mul(A,B):  # A after B
    a,b,c,d,tx,ty=A; a2,b2,c2,d2,tx2,ty2=B
    return (a*a2+c*b2, b*a2+d*b2, a*c2+c*d2, b*c2+d*d2, a*tx2+c*ty2+tx, b*tx2+d*ty2+ty)
def ap(M,p):
    a,b,c,d,tx,ty=M; return (a*p[0]+c*p[1]+tx, b*p[0]+d*p[1]+ty)
def shape_fills(e):
    """DOMShape -> list of (color, alpha, [loops]) and strokes [(color,width,[runs])]"""
    fills={}
    for k,f in enumerate(e.iter(X+'FillStyle')):
        sc=f.find(X+'SolidColor')
        if sc is not None: fills[int(f.get('index'))]=(sc.get('color','#000000'),float(sc.get('alpha',1)))
        else:
            g=f.find('.//'+X+'GradientEntry'); fills[int(f.get('index'))]=(g.get('color','#888888') if g is not None else '#888888',1.0)
    strokes={}
    for s in e.iter(X+'StrokeStyle'):
        ss=s.find('.//'+X+'SolidColor'); st=list(s)[0]
        strokes[int(s.get('index'))]=(ss.get('color','#000000') if ss is not None else '#000000', float(st.get('weight',1)))
    segs={k:[] for k in fills}; sruns=[]
    for ed in e.iter(X+'Edge'):
        es=ed.get('edges')
        if not es: continue
        runs=parse_edges(es)
        f0=ed.get('fillStyle0'); f1=ed.get('fillStyle1'); st=ed.get('strokeStyle')
        for r in runs:
            if f1 and int(f1) in segs: segs[int(f1)].append(r)
            if f0 and int(f0) in segs: segs[int(f0)].append(r[::-1])
            if st and int(st) in strokes: sruns.append((strokes[int(st)],r))
    out=[]
    for k,ss in segs.items():
        out.append((fills[k][0],fills[k][1],chain(ss)))
    return out,sruns
def key(p): return (round(p[0],2),round(p[1],2))
def chain(segs):
    from collections import defaultdict
    starts=defaultdict(list)
    for i,s in enumerate(segs): starts[key(s[0])].append(i)
    used=[False]*len(segs); loops=[]
    for i in range(len(segs)):
        if used[i]: continue
        used[i]=True; loop=list(segs[i])
        while key(loop[-1])!=key(loop[0]):
            nxt=None
            for j in starts.get(key(loop[-1]),[]):
                if not used[j]: nxt=j; break
            if nxt is None: break
            used[nxt]=True; loop+=segs[nxt][1:]
        loops.append(loop)
    return loops
class Lib:
    def __init__(s,root): s.root=root; s.cache={}
    def sym(s,name):
        if name not in s.cache:
            p=os.path.join(s.root,'LIBRARY',name+'.xml')
            s.cache[name]=ET.parse(p).getroot() if os.path.exists(p) else None
        return s.cache[name]
    def layers(s,symroot):
        return list(symroot.iter(X+'DOMLayer'))
    def render_layer(s,L,M,frame=0,depth=0):
        """-> list of draw items (kind, color, alpha, polys) bottom..top within the layer"""
        items=[]
        frs=list(L.iter(X+'DOMFrame'))
        fr=None
        for f in frs:
            idx=int(f.get('index')); dur=int(f.get('duration',1))
            if idx<=frame<idx+dur: fr=f
        if fr is None and frs: fr=frs[0]
        if fr is None: return items
        ee=fr.find(X+'elements')
        for e in (ee if ee is not None else []):
            items+=s.render_el(e,M,depth)
        return items
    def render_el(s,e,M,depth):
        tag=e.tag[len(X):]; items=[]
        if tag=='DOMShape':
            Me=mul(M,mat(e))
            fl,st=shape_fills(e)
            for col,al,loops in fl: items.append(('fill',col,al,[[ap(Me,p) for p in l] for l in loops]))
            for (col,w),r in st: items.append(('stroke',col,w,[[ap(Me,p) for p in r]]))
        elif tag=='DOMSymbolInstance' and depth<6:
            sr=s.sym(e.get('libraryItemName'))
            if sr is not None:
                Me=mul(M,mat(e)); ff=int(e.get('firstFrame',0))
                for L in reversed(s.layers(sr)):
                    if L.get('layerType') in ('folder','guide','mask'): continue
                    items+=s.render_layer(L,Me,ff,depth+1)
        elif tag=='DOMGroup':
            mm=e.find(X+'members')
            for c in (mm if mm is not None else []): items+=s.render_el(c,mul(M,mat(e)),depth)
        return items
