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
from body_mesh import harmonic_grid, G, X0, Y0
WORK = os.environ.get('BODY_WORK', 'body_proto_out')
R = pickle.load(open(os.path.join(WORK, 'pieces.pkl'), 'rb')); P = R['pieces']
SH = P['back']['mask'].shape
px = lambda Q: np.round((np.asarray(Q) - [X0, Y0]) * G).astype(np.int32)

HIP = np.array([-221.6, -2.3]); PELVIS_J = np.array([-152.4, -68.0]); LUMBAR_J = np.array([-79.5, -146.3])
RIB_J = np.array([-25.0, -211.7]); NECK = np.array([119.2, -453.15])
# the knee: the anatomical axis (thigh (387, 280) in the game = the vanilla calf point (160.3, 291.1) + (29.6, -6.1)),
# inside Dima's knee joint; the ankle: the middle of his ankle bone (the cyan cap); the foot's tip: its far end
KNEE = np.array([189.9, 285.0]); ANKLE = np.array([-304.5, 349.0]); TOE = np.array([-527.0, 359.5])
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

def weights(g, V, m):
    W = np.zeros((len(V), len(BONES)))
    one = {'clavicle': 'ribcage', 'ribcage': 'ribcage', 'pelvis': 'pelvis', 'leg': 'thigh', 'calf': 'calf',
           'ankle_cap': 'calf', 'knee_joint': 'knee_auto', 'knee_cap': 'knee_auto', 'ankle_joint': 'ankle_auto',
           'foot': 'foot'}
    if g in one: W[:, BI[one[g]]] = 1; return W
    zm = lambda n: P[g]['zmask'][n] & m
    core = lambda z: cv2.erode(z.astype(np.uint8), np.ones((int(10 * G),) * 2, np.uint8)).astype(bool)
    if g == 'belly':      # top on the ribcage (A), bottom on the pubis (B), the middle stretches between them
        fixed = [('pelvis', m & P['pelvis']['mask']), ('ribcage', m & P['ribcage']['mask'])]
    elif g == 'back':     # the lower back and the back each on its bone, soft at the border between them
        fixed = [('pelvis', m & P['pelvis']['mask']), ('ribcage', m & P['ribcage']['mask']),
                 ('lower_back', core(zm('поясница'))), ('upper_back', core(zm('спина')))]
    w = harmonic_grid(m, [f for _, f in fixed])(V)
    for i, (b, _) in enumerate(fixed): W[:, BI[b]] = w[:, i]
    return W

ORDER = R['order']
OUTER_ONLY = ['belly', 'clavicle', 'back', 'knee_joint', 'ankle_joint']   # joints hide the seams, so no lines of their own
MESH = {}
for g in ORDER:
    V, tri, nb, m = mesh(P[g]['outline'][0]); W = weights(g, V, m)
    MESH[g] = dict(V=V, tri=tri, nb=nb, W=W)
    used = [BONES[i][0] for i in range(len(BONES)) if W[:, i].max() > 1e-4]
    print(f'{g:9s} verts {len(V):5d} tris {len(tri):5d} bones {used} sums {W.sum(1).min():.3f}..{W.sum(1).max():.3f}')

f2 = lambda x: f'{x:.2f}'.rstrip('0').rstrip('.')
vec = lambda Q: 'PackedVector2Array(' + ', '.join(f'{f2(x)}, {f2(y)}' for x, y in Q) + ')'
def poly_node(name, V, d, color):
    nb = d['nb']; Wt = d['W']; bones = []
    for i, b in enumerate(BONES):
        if Wt[:, i].max() > 1e-4:
            bones.append(f'NodePath("{bpath(b[0])}"), PackedFloat32Array(' + ', '.join(f2(w) for w in Wt[:, i]) + ')')
    return '\n'.join([f'[node name="{name}" type="Polygon2D" parent="."]', f'color = Color({color})',
        'skeleton = NodePath("../Skeleton2D")', f'polygon = {vec(V)}', f'internal_vertex_count = {len(V) - nb}',
        'polygons = [' + ', '.join(f'PackedInt32Array({a}, {b}, {c})' for a, b, c in d['tri']) + ']',
        'bones = [' + ', '.join(bones) + ']', ''])
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
    out.append(poly_node(g, MESH[g]['V'], MESH[g], FILL))
open(os.path.join(WORK, 'doll.tscn'), 'w').write('\n'.join(out))
print('doll.tscn', os.path.getsize(os.path.join(WORK, 'doll.tscn')) // 1024, 'KB')
