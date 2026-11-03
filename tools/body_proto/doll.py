"""The body doll (Dima, 3 Nov): the BODY_40 pieces as a Godot scene - pieces turn on bones, only the back bends.

Pieces, bottom first: belly + abs (an underlay: its top holds to the ribcage, its bottom to the pubis, the middle
stretches), clavicle, back (lower back and back, each on its own bone, soft between them), the neck slot, ribcage,
pelvis junction, buttock + thigh. Belly, clavicle and back get only the outer outline (their outlines sit under all
fills); ribcage, pelvis and leg keep theirs as inner lines (the ribcage's bottom, the pelvis V, the buttock).

Bones (template space; Dima's points from his sketch, the neck base ours, the knee and ankle in his joint pieces):
  pelvis      at the hip (it tilts around the hip, as in body-her) -> the lower back's pivot
  lower_back  -> upper_back -> ribcage -> the neck base
  thigh at the hip -> calf at the knee -> foot at the ankle; kneecap on the thigh; ankle_auto carries the ankle piece and
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
# the thigh as keyforms (thigh_keys.py, BODY_THIGH = its pickle): Dima's drawings are the shapes, the doll
# interpolates them by the hip angle; their hip point wins (it is the newest fit)
KEYS = pickle.load(open(os.environ['BODY_THIGH'], 'rb')) if os.environ.get('BODY_THIGH') else None
KEY_PIECES = ['leg'] if KEYS else []   # the kneecap: its newest drawing, on its own bone
# the calf as keyforms too (calf_keys.py, BODY_CALF): squashed against the thigh at rest, its unfolded form past -45
CALF = pickle.load(open(os.environ['BODY_CALF'], 'rb')) if os.environ.get('BODY_CALF') else None
if CALF:   # its knee point wins over the one from the old poses (the calf turns around it in the drawings)
    KEY_PIECES += ['calf'] + (['knee_cap'] if 'cap' in CALF else []); print('calf keyforms at knee', [round(a, 1) for a in CALF['angles']], ' knee', KNEE.round(1), '->', np.round(CALF['pivot'], 1))
    KNEE = np.array(CALF['pivot'])
    if 'cap' in CALF: CAP_C = CALF['cap'][int(np.argmin(np.abs(CALF['cap_angles'])))].mean(0)
# the foot as keyforms (foot_keys.py, BODY_FOOT): three drawings in the calf's frame, mixed around the ankle by the
# foot bone's angle; the ankle link with them (no line of its own: it merges with the shin); the ankle bone keeps
# one shape on the calf, drawn in front of everything; the ankle is the point the drawings turn around
FOOT = pickle.load(open(os.environ['BODY_FOOT'], 'rb')) if os.environ.get('BODY_FOOT') else None
if FOOT:
    KEY_PIECES += ['foot', 'ankle_joint']
    print('foot keyforms at', [round(a, 1) for a in FOOT['angles']], ' ankle', ANKLE.round(1), '->', np.round(FOOT['pivot'], 1))
    ANKLE = np.array(FOOT['pivot'])
def keyform(g):   # (angles, shapes, pivot, driver bone, carrier bone, around the pivot?)
    if g == 'foot': return FOOT['angles'], FOOT['foot'], ANKLE, 'foot', 'calf', True
    if g == 'ankle_joint': return FOOT['angles'], FOOT['link'], ANKLE, 'foot', 'calf', True
    if g == 'leg': return KEYS['angles'], KEYS['leg'], HIP, 'thigh', 'pelvis', True
    # the kneecap: Dima's two drawings of it (calf pressed / unfolded) in the thigh's frame; between them it slides
    # around the knee on the knee's front, picked by the calf's angle; its own bone adds a small turn of its own
    if g == 'knee_cap': return CALF['cap_angles'], CALF['cap'], KNEE, 'calf', 'kneecap', True
    return CALF['angles'], CALF['calf'], KNEE, 'calf', 'calf', False
if KEYS:
    print('thigh keyforms at hip', [round(a, 1) for a in KEYS['angles']], ' hip', HIP.round(1), '->', np.round(KEYS['hip'], 1))
    HIP = np.array(KEYS['hip'])
# the pelvis turns around its own axis (Dima, 3 Nov: the middle of the pelvis junction for now) and carries the hip
# with it; the thigh turns within its limits, and what it would turn past them goes to the pelvis (doll.gd)
PELVIS_AX = np.array([-163.8, -50.5])
CAP_C = np.array([195.3, 320.3])   # the kneecap's middle (its own axis); from the drawing when there is one
# name, parent, origin, tip, metadata: limits (degrees from rest), overflow_to, follow + ratio (turns with another
# bone by a share: the joint pieces), see doll.gd
BONES = [('pelvis', None, PELVIS_AX, PELVIS_J, {'limits': (-25, 25), 'keep_upright': 'lower_back'}),
         ('lower_back', 'pelvis', PELVIS_J, LUMBAR_J, {}),
         ('upper_back', 'lower_back', LUMBAR_J, RIB_J, {}), ('ribcage', 'upper_back', RIB_J, NECK, {}),
         ('thigh', 'pelvis', HIP, KNEE, {'limits': (-45, 115), 'overflow_to': 'pelvis'}),
         ('calf', 'thigh', KNEE, ANKLE, {'limits': (-150, 5)}),
         ('kneecap', 'thigh', CAP_C, CAP_C + (CAP_C - KNEE) / max(np.linalg.norm(CAP_C - KNEE), 1) * 30, {'limits': (-25, 25)}),
         ('foot', 'calf', ANKLE, TOE, {'limits': (-85, 10)})] + ([] if FOOT else [
         ('ankle_auto', 'calf', ANKLE, ANKLE + (TOE - ANKLE) * 0.25, {'follow': 'foot', 'ratio': 0.5})])
BI = {b[0]: i for i, b in enumerate(BONES)}
def bpath(n):
    out = [];
    while n: out.append(n); n = next(b[1] for b in BONES if b[0] == n)
    return '/'.join(reversed(out))
LW = 2.4   # outline width, template units (as BODY_27)

def outline_of(outline, bstep=6.0):
    """The piece's smooth outline resampled evenly. The doll draws a piece as this loop only (triangulated each
    frame), so there is no inner mesh to fold; its outline is a Line2D along the same loop."""
    c = np.vstack([outline, outline[:1]]); seg = np.r_[0, np.cumsum(np.linalg.norm(np.diff(c, axis=0), axis=1))]
    t = np.linspace(0, seg[-1], int(seg[-1] / bstep), endpoint=False)
    return np.c_[np.interp(t, seg, c[:, 0]), np.interp(t, seg, c[:, 1])]

# --- marks: points on each piece's outline, each with the bones' weights there. Along the outline the weights go
# over linearly from mark to mark: two neighbours with the same weights make a rigid stretch, different ones a bend;
# the inside follows the outline. doll.gd turns the marks into the mesh weights (in the editor: a button), so Dima
# moves marks or edits their weights and rebuilds. Placed here: the bends Dima marked on 3 Nov and ours (under the
# knee, the instep, the groin); the crease side short, the stretch side long. Where Dima drew the leg in other
# poses (BODY_44) his drawings keep the calf and the pelvis junction rigid, so they no longer mix bones there.
RIGID = {'clavicle': 'ribcage', 'ribcage': 'ribcage', 'calf': 'calf', 'ankle_cap': 'calf', 'knee_joint': 'knee_auto',
         'knee_cap': 'kneecap', 'ankle_joint': 'ankle_auto', 'foot': 'foot', 'pelvis': 'pelvis', 'leg': 'thigh'}
H = lambda **w: w
MANUAL = {   # (point near the outline, shift along it in units, weights)
    'leg': [((-187, -143), 0, H(pelvis=1)), ((-242, -115), 0, H(pelvis=1)),            # the buttock's top: pelvis
            ((-277, 138), 0, H(pelvis=.5, thigh=.5)), ((-43, 255), 0, H(thigh=1)),     # back of the buttock: a long bend
            ((70, 265), 0, H(thigh=1)),                                                # (the knee joint covers the knee)
            ((182, 205), 0, H(thigh=1)), ((-13, 43), 0, H(thigh=1)),                   # the front of the thigh: rigid
            ((-75, -3), 0, H(pelvis=.5, thigh=.5)), ((-113, -2), 0, H(pelvis=1))],     # the groin: a short bend
    'calf': [((28, 252), 0, H(calf=1)), ((162, 368), 0, H(calf=1)), ((-267, 328), 0, H(calf=1)),   # rigid, as drawn
             ((-300, 393), 0, H(calf=1))],
    'foot': [((-368, 393), 0, H(foot=1)), ((-292, 383), 0, H(foot=.5, calf=.5)), ((-330, 292), 0, H(foot=.5, calf=.5)),
             ((-367, 288), 0, H(foot=1))],
    'pelvis': [((-93, 5), -40, H(pelvis=1)), ((-93, 5), 40, H(pelvis=1))],   # rigid: the drawn poses keep it
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

ORDER = list(R['order'])
if FOOT and 'ankle_cap' in ORDER:   # Dima: the ankle bone in front of everything; the ankle link over the foot,
    ORDER.remove('ankle_cap'); ORDER.append('ankle_cap')   # with no line of its own, bridges heel and shin smoothly
    if 'ankle_joint' in ORDER and 'foot' in ORDER:
        ORDER.remove('ankle_joint'); ORDER.insert(ORDER.index('foot') + 1, 'ankle_joint')
OUTER_ONLY = ['belly', 'clavicle', 'back', 'ankle_joint']   # no lines of their own (the knee joint has one: Dima)
# the lower leg as one silhouette (Dima: the heel tore off the shin, ragged spots under it): calf, ankle link and
# foot draw without lines of their own; under them a "bridge" - their union, small bumps opened away and gaps
# under the heel closed (doll.gd, each frame) - carries the fill between them and the one outline
BRIDGE = ['calf', 'ankle_joint', 'foot'] if FOOT else []
NO_LINE = BRIDGE
MESH = {}
for g in ORDER:
    if g in KEY_PIECES:   # the rest drawing (hip 0) is the piece's outline; no marks: the keyforms shape it
        ang, shp = keyform(g)[:2]; V = shp[int(np.argmin(np.abs(ang)))]; MESH[g] = dict(V=V, nb=len(V), marks=[])
        print(f'{g:11s} keyforms {len(shp)} x {len(V)} points'); continue
    src = KEYS['knee_cap'][int(np.argmin(np.abs(KEYS['angles'])))] if (KEYS and g == 'knee_cap') else \
          FOOT['cap'] if (FOOT and g == 'ankle_cap') else P[g]['outline'][0]
    V = outline_of(src); M = marks(g, V, len(V))
    MESH[g] = dict(V=V, nb=len(V), marks=M)
    print(f'{g:11s} outline points {len(V):4d} marks {len(M):2d} bones {sorted({b for _, w in M for b in w})}')

f2 = lambda x: f'{x:.2f}'.rstrip('0').rstrip('.')
vec = lambda Q: 'PackedVector2Array(' + ', '.join(f'{f2(x)}, {f2(y)}' for x, y in Q) + ')'
def poly_node(name, V, color, g=None):   # no weights: doll.gd builds them from the marks (and the correctives)
    meta = []
    if g in KEY_PIECES:
        ang, shp, piv, drv, car, polar = keyform(g)
        meta = ['metadata/keyforms = {"pivot": Vector2(%s, %s), "angles": PackedFloat32Array(%s), "shapes": [%s], '
                '"driver": "%s", "carrier": "%s", "around": %s}' % (f2(piv[0]), f2(piv[1]), ', '.join(f'{a:.2f}' for a in ang),
                ', '.join(vec(k) for k in shp), drv, car, 'true' if polar else 'false')]
    elif g in _poses.POSE_PIECES and POSES:
        meta = ['metadata/poses = [' + ', '.join(
            f'{{"name": "{p["name"]}", "hip": {p["hip"]:.2f}, "knee": {p["knee"]:.2f}, "outline": {vec(p["outlines"][g])}}}'
            for p in POSES if g in p['outlines']) + ']']
    return '\n'.join([f'[node name="{name}" type="Polygon2D" parent="."]', f'color = Color({color})', *meta,
                      f'polygon = {vec(V)}', ''])
def line_node(name, V, color):   # the outline: a closed stroke 2 x LW wide under the fill, so LW shows outside it
    return '\n'.join([f'[node name="{name}" type="Line2D" parent="."]', f'points = {vec(V)}', 'closed = true',
                      f'width = {2 * LW}', f'default_color = Color({color})', 'joint_mode = 2', 'antialiased = true', ''])
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
def _meta(m):
    out = []
    for k, v in m.items():
        if isinstance(v, tuple): out.append(f'metadata/{k} = Vector2({v[0]}, {v[1]})')
        elif isinstance(v, str): out.append(f'metadata/{k} = "{v}"')
        else: out.append(f'metadata/{k} = {v}')
    return out
for n, par, o, tip, meta in BONES:
    po = next(b[2] for b in BONES if b[0] == par) if par else np.zeros(2); lp = o - po; v = tip - o
    out += [f'[node name="{n}" type="Bone2D" parent="Skeleton2D{"/" + bpath(par) if par else ""}"]',
            f'position = Vector2({f2(lp[0])}, {f2(lp[1])})', f'rest = Transform2D(1, 0, 0, 1, {f2(lp[0])}, {f2(lp[1])})',
            'auto_calculate_length_and_angle = false', f'length = {f2(np.linalg.norm(v))}',
            f'bone_angle = {np.degrees(np.arctan2(v[1], v[0])):.2f}'] + _meta(meta) + ['']
    # (bone_angle is in degrees in the scene file; get_bone_angle() gives radians)
nk = NECK - RIB_J
out += [f'[node name="NeckSlotFollow" type="RemoteTransform2D" parent="Skeleton2D/{bpath("ribcage")}"]',
        f'position = Vector2({f2(nk[0])}, {f2(nk[1])})', 'remote_path = NodePath("../../../../../../NeckSlot")',
        'update_scale = false', '']
for g in OUTER_ONLY:
    if g not in NO_LINE: out.append(line_node(g + '_line', MESH[g]['V'], LINE))
for g in ORDER:
    if g == 'ribcage': out += ['[node name="NeckSlot" type="Node2D" parent="."]', f'position = Vector2({f2(NECK[0])}, {f2(NECK[1])})', '']
    if BRIDGE and g == BRIDGE[0]:
        out.append(line_node('lower_bridge_line', MESH[g]['V'], LINE))
        out.append('\n'.join(['[node name="lower_bridge" type="Polygon2D" parent="."]', f'color = Color({FILL})',
            'metadata/bridge = {"parts": PackedStringArray(%s), "open": 4.0, "close": 14.0}' % ', '.join(f'"{b}"' for b in BRIDGE),
            f'polygon = {vec(MESH[g]["V"])}', '']))
    if g not in OUTER_ONLY and g not in NO_LINE: out.append(line_node(g + '_line', MESH[g]['V'], LINE))
    out.append(poly_node(g, MESH[g]['V'], FILL, g))
    if g not in KEY_PIECES: out.append(marks_nodes(g))
open(os.path.join(WORK, 'doll.tscn'), 'w').write('\n'.join(out))
print('doll.tscn', os.path.getsize(os.path.join(WORK, 'doll.tscn')) // 1024, 'KB')
