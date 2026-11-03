"""Leg poses Dima drew (other templates with the same layers): find how each was turned, correct the hip and knee
points from them, and give each piece's drawn outline in that pose. doll.py stores them in the scene; doll.gd makes
correctives from them (the piece's mesh takes the drawn shape when the bones come to that pose).

Thigh and calf are rigid in the drawings (rms 2-4 units), so each pose is found by fitting the rest thigh's far part
and the rest calf onto the drawing (rotation + shift, ICP from coarse angle steps). The hip is the point both thigh
moves keep still, the knee the point the calf's moves relative to the thigh keep still (least squares over poses).
"""
import os, pickle, numpy as np
from scipy.spatial import cKDTree

# the foot is not matched yet (Dima, 3 Nov); the pelvis junction is, so its crotch keeps the drawn shape
POSE_PIECES = ['pelvis', 'leg', 'calf', 'knee_joint', 'ankle_cap']   # the kneecap rides its own bone (BODY_47)

def _rot(d):
    r = np.radians(d); return np.array([[np.cos(r), -np.sin(r)], [np.sin(r), np.cos(r)]])
def _ang(R): return float(np.degrees(np.arctan2(R[1, 0], R[0, 0])))
def resample(C, step=3.0):
    C = np.vstack([C, C[:1]]); s = np.r_[0, np.cumsum(np.linalg.norm(np.diff(C, axis=0), axis=1))]
    t = np.arange(0, s[-1], step); return np.c_[np.interp(t, s, C[:, 0]), np.interp(t, s, C[:, 1])]
def _icp(src, dst, R, t, it=60, trim=0.8):
    tree = cKDTree(dst)
    for _ in range(it):
        d, i = tree.query(src @ R.T + t); keep = d <= np.quantile(d, trim)
        a, b = src[keep], dst[i[keep]]; ma, mb = a.mean(0), b.mean(0)
        U, S, Vt = np.linalg.svd((a - ma).T @ (b - mb)); D = np.eye(2); D[1, 1] = np.sign(np.linalg.det(Vt.T @ U.T))
        R = Vt.T @ D @ U.T; t = mb - R @ ma
    d, _ = tree.query(src @ R.T + t); return R, t, float(np.sqrt(np.mean(np.sort(d)[:int(len(d) * trim)] ** 2)))
def _best(src, dst, pivot, base=(np.eye(2), np.zeros(2))):
    """Coarse angles around a pivot (after a base move), each refined by ICP; the lowest error wins."""
    out = None
    for a in range(-180, 180, 15):
        Rr = base[0] @ _rot(a); t = base[0] @ (pivot - _rot(a) @ pivot) + base[1]
        r = _icp(src, dst, Rr, t)
        if out is None or r[2] < out[2]: out = r
    return out

def load(rest_pieces, work_dirs, hip, knee):
    """-> hip, knee (corrected when there are poses), [dict(name, hip, knee, rms, outlines{piece: Nx2})]"""
    poses = []
    LA = resample(rest_pieces['leg']['outline'][0]); s = ((LA - hip) @ (knee - hip)) / ((knee - hip) @ (knee - hip))
    far = LA[s > 0.45]; calf = resample(rest_pieces['calf']['outline'][0])
    for w in work_dirs:
        P = pickle.load(open(os.path.join(w, 'pieces.pkl'), 'rb'))['pieces']
        Rt, tt, et = _best(far, resample(P['leg']['outline'][0]), hip)
        Rc, tc, ec = _best(calf, resample(P['calf']['outline'][0]), knee, (Rt, tt))
        outl = {g: resample(P[g]['outline'][0]) for g in POSE_PIECES if g in P and P[g]['outline']}
        poses.append(dict(name=os.path.basename(w.rstrip('/')), Rt=Rt, tt=tt, Rc=Rc, tc=tc, rms=(et, ec), outlines=outl))
    if poses:
        A1 = np.vstack([np.eye(2) - p['Rt'] for p in poses]); b1 = np.hstack([p['tt'] for p in poses])
        rel = [(p['Rt'].T @ p['Rc'], p['Rt'].T @ (p['tc'] - p['tt'])) for p in poses]
        A2 = np.vstack([np.eye(2) - R for R, _ in rel]); b2 = np.hstack([t for _, t in rel])
        hip = np.linalg.lstsq(A1, b1, rcond=None)[0]; knee = np.linalg.lstsq(A2, b2, rcond=None)[0]
    for p in poses:
        p['hip'] = _ang(p['Rt']); p['knee'] = _ang(p['Rc']) - _ang(p['Rt'])
    return hip, knee, poses
