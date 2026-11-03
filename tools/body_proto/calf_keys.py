"""The calf as keyforms (Dima, 3 Nov): his drawings of the calf at different knee angles - pressed to the thigh with
the calf muscle squashed (the rest pose) and unfolded - are the calf's shapes; the doll mixes them by the knee angle.

Each drawing's calf is fitted (rigid) onto the rest calf, which gives its knee angle (calf turn minus thigh turn)
and takes it back into the rest calf's frame; there the outlines nearly lie on each other and are matched point by
point in order along the loops (dynamic time warping). Output: $BODY_WORK/calf_keys.pkl for doll.py.

    BODY_WORK=<rest pieces> python3 calf_keys.py <pieces dir of the unfolded drawing>
"""
import sys, os, pickle, numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import poses as _poses
WORK = os.environ.get('BODY_WORK', 'body_proto_out')
HIP = np.array([-213.5, 4.2]); KNEE = np.array([174.5, 294.8])
RELAX = -45.0

def ccw(c):   # the same turning direction as every other loop here (negative area on screen)
    a = np.sum(c[:, 0] * np.roll(c[:, 1], -1) - np.roll(c[:, 0], -1) * c[:, 1])
    return c[::-1] if a > 0 else c
def dtw(A, B, Bmatch=None):
    """For each point of loop A the matching point of loop B (both in order, B started near A[0]). Bmatch: B moved
    onto A for the matching only (same points, same order), when B lies elsewhere."""
    Bm = B if Bmatch is None else Bmatch
    k0 = int(np.argmin(np.linalg.norm(Bm - A[0], axis=1))); B = np.roll(B, -k0, axis=0); Bm = np.roll(Bm, -k0, axis=0)
    n, m = len(A), len(B); D = np.linalg.norm(A[:, None] - Bm[None], axis=2); C = np.full((n, m), np.inf); C[0, 0] = D[0, 0]
    for i in range(n):
        for j in range(m):
            if i == 0 and j == 0: continue
            best = min(C[i - 1, j - 1] if i and j else np.inf, C[i - 1, j] if i else np.inf, C[i, j - 1] if j else np.inf)
            C[i, j] = D[i, j] + best
    i, j = n - 1, m - 1; first = np.full(n, m); last = np.full(n, -1)
    while True:
        first[i] = min(first[i], j); last[i] = max(last[i], j)
        if i == 0 and j == 0: break
        if i == 0: j -= 1
        elif j == 0: i -= 1
        else:
            o = np.argmin([C[i - 1, j - 1], C[i - 1, j], C[i, j - 1]]); i, j = (i - 1, j - 1) if o == 0 else (i - 1, j) if o == 1 else (i, j - 1)
    return B[(first + last) // 2]

def main(others):
    R = pickle.load(open(os.path.join(WORK, 'pieces.pkl'), 'rb'))['pieces']
    rest_calf = ccw(_poses.resample(R['calf']['outline'][0], 6.0))
    leg = _poses.resample(R['leg']['outline'][0]); s = ((leg - HIP) @ (KNEE - HIP)) / ((KNEE - HIP) @ (KNEE - HIP)); far = leg[s > 0.45]
    keys = [(0.0, rest_calf, 0.0)]; A = []; b = []
    rest_cap = ccw(_poses.resample(R['knee_cap']['outline'][0], 3.0)); caps = [(0.0, rest_cap)]
    for d in others:
        P = pickle.load(open(os.path.join(d, 'pieces.pkl'), 'rb'))['pieces']
        Rt, tt, et = _poses._best(far, _poses.resample(P['leg']['outline'][0]), HIP)
        Rc, tc, ec = _poses._best(_poses.resample(R['calf']['outline'][0]), _poses.resample(P['calf']['outline'][0]), KNEE, (Rt, tt))
        knee = _poses._ang(Rc) - _poses._ang(Rt)
        Rrel, trel = Rt.T @ Rc, Rt.T @ (tc - tt); A.append(np.eye(2) - Rrel); b.append(trel)   # the knee keeps still
        # the kneecap where Dima drew it with this calf, in the thigh's frame (it rides the thigh, slides with the knee)
        cap_local = ccw((_poses.resample(P['knee_cap']['outline'][0], 1.5) - tt) @ Rt)
        # Dima: the kneecap keeps one shape - the rest kneecap moved (rigid fit) to where this drawing has it
        Ra, ta, ea = _poses._best(rest_cap, cap_local, rest_cap.mean(0))
        caps.append((knee, rest_cap @ Ra.T + ta)); print(f'   kneecap moved {np.linalg.norm(ta + rest_cap.mean(0) @ Ra.T - rest_cap.mean(0)):.1f}, turned {_poses._ang(Ra):.1f}, fit rms {ea:.1f}')
        local = ccw((_poses.resample(P['calf']['outline'][0], 2.0) - tc) @ Rc)   # back into the rest calf's frame
        keys.append((knee, dtw(rest_calf, local), ec))
        print(f'{os.path.basename(d.rstrip("/"))}: knee {knee:.1f}, calf fit rms {ec:.1f}, thigh fit rms {et:.1f}')
    # Dima: two forms are enough - pressed to the thigh (squashed) and not; the unfolded drawing also stands at
    # RELAX degrees, so the squash is gone once the knee opens that far (and the scene's angles can be edited)
    if len(keys) == 2 and RELAX is not None and keys[1][0] < RELAX:
        keys.append((RELAX, keys[1][1], keys[1][2]))
    keys.sort(key=lambda k: k[0])
    knee_pt = np.linalg.lstsq(np.vstack(A), np.hstack(b), rcond=None)[0] if A else KNEE
    print('knee point', KNEE, '->', np.round(knee_pt, 1))
    caps.sort(key=lambda k: k[0])
    out = dict(pivot=knee_pt, angles=[k[0] for k in keys], calf=[k[1] for k in keys],
               cap_angles=[k[0] for k in caps], cap=[k[1] for k in caps])
    print('kneecap keys at knee', [round(k[0], 1) for k in caps], ' centre moves', np.round(caps[0][1].mean(0) - caps[-1][1].mean(0), 1))
    pickle.dump(out, open(os.path.join(WORK, 'calf_keys.pkl'), 'wb'))
    print('calf keys at knee', [round(a, 1) for a in out['angles']], 'points', len(rest_calf))

if __name__ == '__main__':
    main(sys.argv[1:])
