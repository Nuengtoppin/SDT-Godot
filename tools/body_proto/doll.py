"""The body doll (Dima, 3 Nov): the BODY_40 pieces as a Godot scene - pieces turn on bones, only the back bends.

Pieces, bottom first: belly + abs (an underlay: its top holds to the ribcage, its bottom to the pubis, the middle
stretches), clavicle, back (lower back and back, each on its own bone, soft between them), the neck slot, ribcage,
pelvis junction, buttock + thigh. Belly, clavicle and back get only the outer outline (their outlines sit under all
fills); ribcage, pelvis and leg keep theirs as inner lines (the ribcage's bottom, the pelvis V, the buttock).

Bones (template space; Dima's points from his sketch, the neck base ours, the knee and ankle in his joint pieces):
  pelvis      at the hip (it tilts around the hip, as in body-her) -> the lower back's pivot
  lower_back  -> upper_back -> ribcage -> the neck base
  thigh at the hip -> calf at the knee -> foot at the ankle; knee_auto and ankle_auto carry the joint pieces and
  turn half as much as the calf / the foot (doll.gd), so the joint hides the seam from both sides
Writes $BODY_WORK/doll.tscn for res://debug/body_doll/ (the scene holds template outlines: never commit it).
"""
import sys, os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pickle, numpy as np, cv2
from scipy.spatial import Delaunay
WORK = os.environ.get('BODY_WORK', 'body_proto_out')
R = pickle.load(open(os.path.join(WORK, 'pieces.pkl'), 'rb')); P = R['pieces']
G, X0, Y0 = R.get('grid', (2.0, -700, -560))
SH = P['back']['mask'].shape
px = lambda Q: np.round((np.asarray(Q) - [X0, Y0]) * G).astype(np.int32)

HIP = np.array([-221.6, -2.3]); PELVIS_J = np.array([-152.4, -68.0]); LUMBAR_J = np.array([-79.5, -146.3])
RIB_J = np.array([-25.0, -211.7]); NECK = np.array([119.2, -453.15])
# the knee: the anatomical axis (thigh (387, 280) in the game = the vanilla calf point (160.3, 291.1) + (29.6, -6.1)),
# inside Dima's knee joint; the ankle: the middle of his ankle bone (the cyan cap); the foot's tip: its far end
KNEE = np.array([189.9, 285.0]); ANKLE = np.array([-304.5, 349.0]); TOE = np.array([-527.0, 359.5])
# Dima's leg poses (BODY_POSES = work dirs of other templates, comma separated): they correct the hip and the knee
import poses as _poses
_pose_dirs = [d for d in os.environ.get('BODY_POSES', '').split(',') if d]
_hip0, _knee0 = HIP.copy(), KNEE.copy()
HIP, KNEE, POSES = _poses.load(P, _pose_dirs, HIP, KNEE)
for _p in POSES:
    print(f"pose {_p['name']}: hip {_p['hip']:.1f}, knee {_p['knee']:.1f}, fit rms thigh {_p['rms'][0]:.1f} calf {_p['rms'][1]:.1f}")
if POSES: print('hip', _hip0, '->', HIP.round(1), ' knee', _knee0, '->', KNEE.round(1))
# name, parent, origin, tip, half_of: a joint piece's bone turns half as much as its neighbour (the doll script)
BONES = [('pelvis', None, HIP, PELVIS_J, None), ('lower_back', 'pelvis', PELVIS_J, LUMBAR_J, None),
         ('upper_back', 'lower_back', LUMBAR_J, RIB_J, None), ('ribcage', 'upper_back', RIB_J, NECK, None),
         ('thigh', 'pelvis', HIP, KNEE, None), ('calf', 'thigh', KNEE, ANKLE, None),
         ('knee_auto', 'thigh', KNEE, KNEE + (ANKLE - KNEE) * 0.15, 'calf'), ('foot', 'calf', ANKLE, TOE, None),
         ('ankle_auto', 'calf', ANKLE, ANKLE + (TOE - ANKLE) * 0.25, 'foot')]
BI = {b[0]: i for i, b in enumerate(BONES)}
def bpath(n):
    out = [];
    while n: out.append(n); n = next(b[1] for b in BONES if b[0] == n)
    return '/'.join(reversed(out))
LW = 2.4   # outline width, template units (as BODY_27)

def mesh(outline, step=12.0, bstep=6.0):
    """Boundary = the smooth outline resampled evenly (first nb vertices, in order); inside: a hex grid."""
    c = np.vstack([outline, outline[:1]]); seg = np.r_[0, np.cumsum(np.linalg.norm(np.diff(c, axis=0), axis=1))]
    t = np.linspace(0, seg[-1], int(seg[-1] / bstep), endpoint=False)
    B = np.c_[np.interp(t, seg, c[:, 0]), np.interp(t, seg, c[:, 1])]
    m = np.zeros(SH, np.uint8); cv2.fillPoly(m, [px(B)], 1)
    dist = cv2.distanceTransform(m, cv2.DIST_L2, 5) / G
    x0, y0 = B.min(0); x1, y1 = B.max(0); I = []
    for j, y in enumerate(np.arange(y0, y1, step * 0.866)):
        for x in np.arange(x0, x1, step) + (step / 2 if j % 2 else 0): I.append((x, y))
    I = np.array(I); q = px(I); ok = (q[:, 0] >= 0) & (q[:, 1] >= 0) & (q[:, 0] < SH[1]) & (q[:, 1] < SH[0])
    I = I[ok]; q = q[ok]; I = I[dist[q[:, 1], q[:, 0]] > step * 0.45]
    V = np.vstack([B, I]); tri = Delaunay(V).simplices
    cen = px(V[tri].mean(1)); tri = tri[m[np.clip(cen[:, 1], 0, SH[0] - 1), np.clip(cen[:, 0], 0, SH[1] - 1)] > 0]
    return V, tri, len(B), m.astype(bool)

def grown(V, nb, w):
    """The same mesh with its boundary pushed out by w: drawn dark under the fill, it is the outline."""
    B = V[:nb]; a = np.sum(B[:, 0] * np.roll(B[:, 1], -1) - np.roll(B[:, 0], -1) * B[:, 1]) / 2
    d = np.roll(B, -1, 0) - np.roll(B, 1, 0); n = np.c_[d[:, 1], -d[:, 0]] * (1 if a > 0 else -1)
    n /= np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-9)
    out = V.copy(); out[:nb] = B + n * w
    return out

# --- marks: points on each piece's outline, each with the bones' weights there. Along the outline the weights go
# over linearly from mark to mark: two neighbours with the same weights make a rigid stretch, different ones a bend;
# the inside follows the outline. doll.gd turns the marks into the mesh weights (in the editor: a button), so Dima
# moves marks or edits their weights and rebuilds. Placed here: the bends Dima marked on 3 Nov and ours (under the
# knee, the instep, the groin); the crease side short, the stretch side long.
RIGID = {'clavicle': 'ribcage', 'ribcage': 'ribcage', 'calf': 'calf', 'ankle_cap': 'calf', 'knee_joint': 'knee_auto',
         'knee_cap': 'knee_auto', 'ankle_joint': 'ankle_auto', 'foot': 'foot', 'pelvis': 'pelvis', 'leg': 'thigh'}
H = lambda **w: w
MANUAL = {   # (point near the outline, shift along it in units, weights)
    'leg': [((-187, -143), 0, H(pelvis=1)), ((-242, -115), 0, H(pelvis=1)),            # the buttock's top: pelvis
            ((-277, 138), 0, H(pelvis=.5, thigh=.5)), ((-43, 255), 0, H(thigh=1)),     # back of the buttock: a long bend
            ((70, 265), 0, H(thigh=1)), ((180, 290), 0, H(thigh=.5, calf=.5)),         # under the knee
            ((182, 205), 0, H(thigh=1)), ((-13, 43), 0, H(thigh=1)),                   # the front of the thigh: rigid
            ((-75, -3), 0, H(pelvis=.5, thigh=.5)), ((-113, -2), 0, H(pelvis=1))],     # the groin: a short bend
    'calf': [((28, 252), 0, H(calf=1)), ((173, 295), 0, H(calf=.5, thigh=.5)), ((162, 368), 0, H(calf=1)),
             ((-267, 328), 0, H(calf=1)), ((-313, 340), 0, H(calf=.5, foot=.5)), ((-300, 393), 0, H(calf=1))],
    'foot': [((-368, 393), 0, H(foot=1)), ((-292, 383), 0, H(foot=.5, calf=.5)), ((-330, 292), 0, H(foot=.5, calf=.5)),
             ((-367, 288), 0, H(foot=1))],
    'pelvis': [((-93, 5), -40, H(pelvis=1)), ((-93, 5), 0, H(pelvis=.6, thigh=.4)), ((-93, 5), 40, H(pelvis=1))],
}
def marks(g, V, nb):
    B = V[:nb]; arc = np.r_[0, np.cumsum(np.linalg.norm(np.diff(np.vstack([B, B[:1]]), axis=0), axis=1))]; L = arc[-1]
    def at(t):   # the boundary vertex at arc length t (around the loop)
        return int(np.argmin(np.minimum((arc[:-1] - t) % L, (t - arc[:-1]) % L)))
    if g in MANUAL:
        out = []
        for pt, off, w in MANUAL[g]:
            i = int(np.argmin(np.linalg.norm(B - pt, axis=1))); out.append((B[at(arc[i] + off)], w))
        return out
    if g in ('back', 'belly'):   # runs of the outline by what lies over them or which zone they are in
        q = px(B); q[:, 0] = np.clip(q[:, 0], 0, SH[1] - 1); q[:, 1] = np.clip(q[:, 1], 0, SH[0] - 1)
        hit = lambda m: m[q[:, 1], q[:, 0]]
        lab = np.array([None] * nb, object)
        if g == 'back':
            lab[hit(P['back']['zmask']['спина'])] = 'upper_back'; lab[hit(P['back']['zmask']['поясница'])] = 'lower_back'
        lab[hit(P['ribcage']['mask'])] = 'ribcage'; lab[hit(P['pelvis']['mask'] | P['leg']['mask'])] = 'pelvis'
        if g == 'back':   # every stretch of the back's outline belongs somewhere: the nearest labelled one
            k = np.nonzero(lab != None)[0]
            for i in np.nonzero(lab == None)[0]: lab[i] = lab[k[np.argmin(np.minimum(abs(k - i), nb - abs(k - i)))]]
        inset = 12.0 if g == 'back' else 0.0   # the back bends over 24 units at a zone border; the belly stretches
        start = next((i for i in range(nb) if lab[i] != lab[i - 1]), 0); out = []
        i = start
        while True:
            j = i
            while lab[(j + 1) % nb] == lab[i] and (j + 1) % nb != start: j += 1
            if lab[i] is not None:
                a, b = arc[i % nb], arc[i % nb] + (arc[j % nb] - arc[i % nb]) % L
                for t in ([a + inset, b - inset] if b - a > 2 * inset + 4 else [(a + b) / 2]):
                    out.append((B[at(t)], {lab[i]: 1}))
            i = (j + 1) % nb
            if i == start: break
        return out
    return [(B[int(k)], {RIGID[g]: 1}) for k in np.linspace(0, nb, 4, endpoint=False)]

ORDER = R['order']
OUTER_ONLY = ['belly', 'clavicle', 'back', 'ankle_joint']   # no lines of their own (the knee joint has one: Dima)
MESH = {}
for g in ORDER:
    V, tri, nb, m = mesh(P[g]['outline'][0]); M = marks(g, V, nb)
    MESH[g] = dict(V=V, tri=tri, nb=nb, marks=M)
    print(f'{g:11s} verts {len(V):5d} tris {len(tri):5d} marks {len(M):2d} bones {sorted({b for _, w in M for b in w})}')

f2 = lambda x: f'{x:.2f}'.rstrip('0').rstrip('.')
vec = lambda Q: 'PackedVector2Array(' + ', '.join(f'{f2(x)}, {f2(y)}' for x, y in Q) + ')'
def poly_node(name, V, d, color, g=None):   # no weights: doll.gd builds them from the marks (and the correctives)
    meta = []
    if g in _poses.POSE_PIECES and POSES:
        meta = ['metadata/poses = [' + ', '.join(
            f'{{"name": "{p["name"]}", "hip": {p["hip"]:.2f}, "knee": {p["knee"]:.2f}, "outline": {vec(p["outlines"][g])}}}'
            for p in POSES if g in p['outlines']) + ']']
    return '\n'.join([f'[node name="{name}" type="Polygon2D" parent="."]', f'color = Color({color})', *meta,
        'skeleton = NodePath("../Skeleton2D")', f'polygon = {vec(V)}', f'internal_vertex_count = {len(V) - d["nb"]}',
        'polygons = [' + ', '.join(f'PackedInt32Array({a}, {b}, {c})' for a, b, c in d['tri']) + ']', ''])
def marks_nodes(g):
    out = [f'[node name="Marks" type="Node2D" parent="{g}"]', '']
    for k, (p, w) in enumerate(MESH[g]['marks']):
        wd = '{' + ', '.join(f'"{b}": {float(x):.2f}' for b, x in w.items()) + '}'
        out += [f'[node name="m{k:02d}" type="Marker2D" parent="{g}/Marks"]', f'position = Vector2({f2(p[0])}, {f2(p[1])})',
                'gizmo_extents = 8.0', f'metadata/weights = {wd}', '']
    return '\n'.join(out)
FILL = '0.941, 0.827, 0.749, 1'; LINE = '0.361, 0.259, 0.204, 1'   # (240,211,191) and (92,66,52)
out = ['[gd_scene format=3]', '', '[ext_resource type="Script" path="res://debug/body_doll/doll.gd" id="1"]', '',
       '[node name="BodyDoll" type="Node2D"]', 'script = ExtResource("1")', '',
       '[node name="Skeleton2D" type="Skeleton2D" parent="."]', '']
for n, par, o, tip, half in BONES:
    po = next(b[2] for b in BONES if b[0] == par) if par else np.zeros(2); lp = o - po; v = tip - o
    out += [f'[node name="{n}" type="Bone2D" parent="Skeleton2D{"/" + bpath(par) if par else ""}"]',
            f'position = Vector2({f2(lp[0])}, {f2(lp[1])})', f'rest = Transform2D(1, 0, 0, 1, {f2(lp[0])}, {f2(lp[1])})',
            'auto_calculate_length_and_angle = false', f'length = {f2(np.linalg.norm(v))}',
            f'bone_angle = {np.degrees(np.arctan2(v[1], v[0])):.2f}'] + ([f'metadata/half_of = "{half}"'] if half else []) + ['']
    # (bone_angle is in degrees in the scene file; get_bone_angle() gives radians)
nk = NECK - RIB_J
out += [f'[node name="NeckSlotFollow" type="RemoteTransform2D" parent="Skeleton2D/{bpath("ribcage")}"]',
        f'position = Vector2({f2(nk[0])}, {f2(nk[1])})', 'remote_path = NodePath("../../../../../../NeckSlot")',
        'update_scale = false', '']
for g in OUTER_ONLY: out.append(poly_node(g + '_line', grown(MESH[g]['V'], MESH[g]['nb'], LW), MESH[g], LINE))
for g in ORDER:
    if g == 'ribcage': out += ['[node name="NeckSlot" type="Node2D" parent="."]', f'position = Vector2({f2(NECK[0])}, {f2(NECK[1])})', '']
    if g not in OUTER_ONLY: out.append(poly_node(g + '_line', grown(MESH[g]['V'], MESH[g]['nb'], LW), MESH[g], LINE))
    out.append(poly_node(g, MESH[g]['V'], MESH[g], FILL, g)); out.append(marks_nodes(g))
open(os.path.join(WORK, 'doll.tscn'), 'w').write('\n'.join(out))
print('doll.tscn', os.path.getsize(os.path.join(WORK, 'doll.tscn')) // 1024, 'KB')
