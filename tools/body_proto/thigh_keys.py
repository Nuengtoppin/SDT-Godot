"""The thigh as keyforms (Dima, 3 Nov): his three drawings of the thigh (and the kneecap riding over it) at three hip
angles are the shapes themselves; between them the doll interpolates, nothing is bent by weights.

Inputs: the three templates unpacked (rest pose first) and Dima's points on each thigh outline (template space, read
off his marked screenshots; the same points in every drawing, in order along the outline from the buttock's top).
A drawing may miss a point: it is placed at the same share of the way between its neighbours as in the others.
Each drawing's hip angle comes from fitting the rest thigh's far part onto it (rigid); the hip is the point those
turns keep still (least squares). Output: $BODY_WORK/thigh_keys.pkl for doll.py.

    python3 thigh_keys.py <rest template dir> <template 2 dir> <template 3 dir>
"""
import sys, os, pickle, numpy as np, cv2
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from xfl import Lib, X
import poses as _poses
WORK = os.environ.get('BODY_WORK', 'body_proto_out')
THIGH = ['ягодица', 'бедро1', 'Слой_18', 'Слой_19']; CAP = ['колено']
# Dima's points, in order from the buttock's top along the outline (None = not marked on that drawing):
# top, back of the buttock, under the thigh, knee back, knee bottom, knee front, front of the thigh, front of the buttock
DOTS = [
    [(-264.3, -115.5), (-295.0, 117.1), (-75.6, 241.5), (153.4, 328.6), (220.1, 332.8), (228.7, 233.1), (-61.0, 33.7), (-125.4, -30.6)],
    [(-267.8, -117.0), (-368.8, 56.8), (-283.8, 292.1), (-172.8, 505.8), (-65.2, 487.3), (-72.5, 417.0), (-123.8, 137.5), (-132.4, -43.1)],
    [(-225.5, -105.3), (-430.9, 5.7), None, (-674.7, 273.8), (-637.2, 323.9), (-528.2, 305.1), (-211.9, 105.5), (-109.5, 2.3)],
]
G = 4.0
def layers(root, names):
    lib = Lib(root); sym = lib.sym('Templates/Body/Body Template - копия'); out = {}
    for L in sym.iter(X + 'DOMLayer'):
        if L.get('name') in names and L.get('layerType') != 'folder':
            out[L.get('name')] = [np.array(p) for kind, c, al, ps in lib.render_layer(L, (1, 0, 0, 1, 0, 0)) if kind == 'fill' for p in ps if len(p) > 2]
    return out
def loop(polys, close=10.0, smooth=2.0):
    """The union's outer loop, counter-clockwise on screen (negative area), smoothed a little."""
    pts = np.vstack([p for v in polys.values() for p in v]); x0, y0 = pts.min(0) - 30
    W, H = ((pts.max(0) - pts.min(0) + 60) * G).astype(int); m = np.zeros((H, W), np.uint8)
    for v in polys.values():
        for p in v:
            t = np.zeros_like(m); cv2.fillPoly(t, [np.round((p - [x0, y0]) * G).astype(np.int32)], 1); m |= t
    k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (int(close * G) * 2 + 1,) * 2); m = cv2.morphologyEx(m, cv2.MORPH_CLOSE, k)
    m = (cv2.GaussianBlur(m.astype(np.float32), (0, 0), 2.0 * G) > 0.5).astype(np.uint8)
    cs, _ = cv2.findContours(m, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE); c = max(cs, key=cv2.contourArea)[:, 0, :] / G + [x0, y0]
    if cv2.contourArea(c.astype(np.float32), oriented=True) > 0: c = c[::-1]
    # a smooth closed curve through the traced edge (the drawings are brush strokes; Dima: "not smooth")
    from scipy.interpolate import splprep, splev
    c = c[::2].astype(float); tck, _ = splprep([c[:, 0], c[:, 1]], s=len(c) * smooth, per=True, k=3)
    x, y = splev(np.linspace(0, 1, len(c) * 3, endpoint=False), tck); return np.c_[x, y]
def arc(c):
    return np.r_[0, np.cumsum(np.linalg.norm(np.diff(np.vstack([c, c[:1]]), axis=0), axis=1))]
def at(c, s, u):
    L = s[-1]; u = u % L; j = np.clip(np.searchsorted(s, u, side='right') - 1, 0, len(c) - 1)
    t = (u - s[j]) / np.maximum(s[j + 1] - s[j], 1e-9); return c[j] * (1 - t)[:, None] + c[(j + 1) % len(c)] * t[:, None]

def main(dirs):
    thighs = [loop(layers(d, THIGH)) for d in dirs]; caps = [loop(layers(d, CAP), 2.0, 0.5) for d in dirs]
    # the points on each outline (arc length from the outline's start), missing ones placed by the others' shares
    U = []
    for c, dots in zip(thighs, DOTS):
        s = arc(c); U.append([None if p is None else s[int(np.argmin(np.linalg.norm(c - p, axis=1)))] for p in dots])
    for q, us in enumerate(U):
        for i, u in enumerate(us):
            if u is None:
                L = arc(thighs[q])[-1]; a, b = us[i - 1], us[(i + 1) % len(us)]
                share = np.mean([((o[i] - o[i - 1]) % arc(thighs[k])[-1]) / ((o[(i + 1) % len(o)] - o[i - 1]) % arc(thighs[k])[-1])
                                 for k, o in enumerate(U) if o[i] is not None and o[i - 1] is not None and o[(i + 1) % len(o)] is not None])
                us[i] = (a + share * ((b - a) % L)) % L
    # the same number of points per stretch in every drawing (by the rest drawing's lengths, ~5 units apart)
    s0 = arc(thighs[0]); L0 = s0[-1]; n = len(DOTS[0])
    counts = [max(3, int(round(((U[0][(i + 1) % n] - U[0][i]) % L0) / 5.0))) for i in range(n)]
    keys = []
    for c, us in zip(thighs, U):
        s = arc(c); L = s[-1]; pts = []
        for i in range(n):
            a = us[i]; span = (us[(i + 1) % n] - a) % L
            pts.append(at(c, s, a + span * np.arange(counts[i]) / counts[i]))
        keys.append(np.vstack(pts))
    # hip angles: the rest thigh's far part fitted onto each drawing; the hip: the point the turns keep still
    hip0 = np.array([-222.8, -8.9]); knee0 = np.array([174.5, 294.8])
    rest = _poses.resample(thighs[0]); sh = ((rest - hip0) @ (knee0 - hip0)) / ((knee0 - hip0) @ (knee0 - hip0)); far = rest[sh > 0.45]
    fits = [(np.eye(2), np.zeros(2), 0.0)] + [_poses._best(far, _poses.resample(c), hip0) for c in thighs[1:]]
    A = np.vstack([np.eye(2) - R for R, t, e in fits[1:]]); b = np.hstack([t for R, t, e in fits[1:]])
    hip = np.linalg.lstsq(A, b, rcond=None)[0]
    angles = [_poses._ang(R) for R, t, e in fits]
    # the kneecap: each drawing taken into the thigh's frame, started at the same place (its point furthest along
    # the thigh), the same number of points by length
    cap_keys = []; ax = (knee0 - hip0) / np.linalg.norm(knee0 - hip0); N = 48
    for c, (R, t, e) in zip(caps, fits):
        local = (c - t) @ R          # undo the thigh's turn: R^T (c - t)
        k0 = int(np.argmax(local @ ax)); c2 = np.roll(c, -k0, axis=0); s = arc(c2)
        cap_keys.append(at(c2, s, s[-1] * np.arange(N) / N))
    for a, (R, t, e) in zip(angles, fits): print(f'key at hip {a:7.1f}  fit rms {e:.1f}')
    print('hip', hip0, '->', hip.round(1), ' thigh points per key', len(keys[0]), ' stretches', counts)
    order = np.argsort(angles)
    out = dict(hip=hip, angles=[angles[i] for i in order], leg=[keys[i] for i in order], knee_cap=[cap_keys[i] for i in order])
    pickle.dump(out, open(os.path.join(WORK, 'thigh_keys.pkl'), 'wb'))

if __name__ == '__main__':
    main(sys.argv[1:4])
