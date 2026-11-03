"""The foot as keyforms (Dima, 3 Nov): his three foot drawings (pointed as in the rest pose, half, flexed up) are the
foot's shapes in the calf's frame; the doll mixes them around the ankle by the foot bone's angle. The ankle link
(связка стопы) goes with them and draws without a line of its own, so it merges with the shin; the ankle bone
(чашечка стопы) keeps one shape on the calf, in front of everything.

Each drawing's calf is fitted onto the rest calf (thigh first, then calf, rigid), which takes the drawing into the
rest calf's frame; there the foot is fitted onto the first drawing's foot: its angle is the drawing's foot angle,
and the ankle is the point those turns keep still (least squares). Outlines are matched point by point after
being turned back by their angle (the link by half of it), in order along the loop. Output: $BODY_WORK/foot_keys.pkl

    BODY_WORK=<rest pieces> python3 foot_keys.py <pieces dir of foot drawing 1 (= rest)> <2> <3>
"""
import sys, os, pickle, numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import poses as _poses
from calf_keys import ccw, dtw
WORK = os.environ.get('BODY_WORK', 'body_proto_out')
HIP = np.array([-213.5, 4.2]); KNEE = np.array([182.3, 300.9]); ANKLE0 = np.array([-304.5, 349.0])

def turn(P, c, deg):
    r = np.radians(deg); R = np.array([[np.cos(r), -np.sin(r)], [np.sin(r), np.cos(r)]]); return (P - c) @ R.T + c

SHIN_R = 55.0   # px around the ankle: the shin Dima drew with each foot joins its ankle link (heel and shin stay as drawn)

def with_shin(link, calf, ankle, r=SHIN_R, k=4.0):
    # the link and the drawn shin's end (the calf inside a circle around the ankle) as one loop, on a raster k x finer
    import cv2
    pts = np.vstack([link, calf]); o = pts.min(0) - 10; size = np.ceil((pts.max(0) - o + 10) * k).astype(int)
    m1 = np.zeros((size[1], size[0]), np.uint8); m2 = m1.copy(); m3 = m1.copy()
    cv2.fillPoly(m1, [np.round((link - o) * k).astype(np.int32)], 1); cv2.fillPoly(m2, [np.round((calf - o) * k).astype(np.int32)], 1)
    cv2.circle(m3, tuple(int(v) for v in np.round((ankle - o) * k)), int(r * k), 1, -1)
    m = (m1 | (m2 & m3)).astype(np.uint8)
    cs, _ = cv2.findContours(m, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
    c = max(cs, key=cv2.contourArea)[:, 0, :].astype(float) / k + o
    return ccw(_poses.resample(c, 2.0))

def main(dirs):
    R = pickle.load(open(os.path.join(WORK, 'pieces.pkl'), 'rb'))['pieces']
    leg = _poses.resample(R['leg']['outline'][0]); s = ((leg - HIP) @ (KNEE - HIP)) / ((KNEE - HIP) @ (KNEE - HIP)); far = leg[s > 0.45]
    rest_calf = _poses.resample(R['calf']['outline'][0])
    local = []
    for d in dirs:
        P = pickle.load(open(os.path.join(d, 'pieces.pkl'), 'rb'))['pieces']
        Rt, tt, et = _poses._best(far, _poses.resample(P['leg']['outline'][0]), HIP)
        Rc, tc, ec = _poses._best(rest_calf, _poses.resample(P['calf']['outline'][0]), KNEE, (Rt, tt))
        back = lambda g, step=2.0: ccw((_poses.resample(P[g]['outline'][0], step) - tc) @ Rc)
        local.append(dict(foot=back('foot'), link=back('ankle_joint'), calf=back('calf'), cap=back('ankle_cap', 1.5), calf_rms=ec))
    base = ccw(_poses.resample(local[0]['foot'], 4.0))
    fits = [_poses._best(base, L['foot'], ANKLE0) for L in local]
    A = np.vstack([np.eye(2) - Rf for Rf, tf, e in fits[1:]]); b = np.hstack([tf for Rf, tf, e in fits[1:]])
    ankle = np.linalg.lstsq(A, b, rcond=None)[0]
    angles = [_poses._ang(Rf) for Rf, tf, e in fits]
    for L in local:
        L['link'] = with_shin(L['link'], L['calf'], ankle)
    link0 = ccw(_poses.resample(local[0]['link'], 4.0))
    foot_keys, link_keys = [], []
    for L, a in zip(local, angles):
        foot_keys.append(dtw(base, L['foot'], turn(L['foot'], ankle, -a)))
        link_keys.append(dtw(link0, L['link'], turn(L['link'], ankle, -a / 2)))
    for i, (a, (Rf, tf, e)) in enumerate(zip(angles, fits)):
        print(f'foot drawing {i + 1}: angle {a:.1f}, foot fit rms {e:.1f}, calf fit rms {local[i]["calf_rms"]:.1f}')
    print('ankle', ANKLE0, '->', ankle.round(1))
    order = np.argsort(angles)
    out = dict(pivot=ankle, angles=[angles[i] - angles[0] for i in order], foot=[foot_keys[i] for i in order],
               link=[link_keys[i] for i in order], cap=ccw(_poses.resample(local[0]['cap'], 3.0)))
    pickle.dump(out, open(os.path.join(WORK, 'foot_keys.pkl'), 'wb'))
    print('foot keys at', [round(a, 1) for a in out['angles']], ' points', len(base), len(link0))

if __name__ == '__main__':
    main(sys.argv[1:4])
