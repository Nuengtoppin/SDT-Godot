# Body mesh prototype (outside the game)

Reads Dima's body-zones template (an Animate .fla with the symbol `Templates/Body/Body Template - копия`: zones as
layers - ribcage, pelvis bone, seat bone, waist, belly, back, buttock, thigh...), builds two meshes (torso, right
thigh with the buttock), weights them to the bones from the zones (rigid zones: one bone; soft ones: Laplace on a
regular grid inside the outline) and renders a strip of poses with linear blend skinning. A prototype to judge the
method and the zones; the game version will use Godot's Skeleton2D / Polygon2D.

Template space = the game's torso space minus (-120.2, 453.15). Bone points (template space): hip (-240.8, 3.85),
lumbar (-48.8, -113.15), thoracic (64.2, -273.15), neck base (119.2, -453.15), knee (160.3, 291.1).

    python3 -I unfla.py <template.fla> <dir>     # the .fla is a zip with a broken directory: read via libarchive
    python3 zones.py <dir>                        # zones and references -> $BODY_WORK/body_items.pkl
    python3 masks.py                              # outlines -> $BODY_WORK/proto_masks.npz
    python3 frames.py                             # meshes, weights, poses -> $BODY_WORK/proto_frames.png

Needs numpy, scipy, opencv, pillow, matplotlib and libarchive. The template itself is never committed.

## Dima's three assemblies (3 Nov)

    python3 assemblies.py          # torso / pelvis junction / near leg, each from its layers (top first), clean outlines
    python3 assemblies_render.py   # each alone, together (torso < pelvis < leg), and a volume test: a dome per assembly
                                   # plus a small one per muscle group -> normals -> light (sharp shadow + soft)

Torso: ribcage, back clavicle, abs, belly, lower back, back. Pelvis junction: the pelvis waist (V), pubis, vagina,
anus - it closes the torso's open bottom and shows when the leg moves away. Near leg: buttock and the thigh's parts.
Pelvis bone and seat bone are inner forms (colliders), not drawn.

## Pieces with smooth outlines (3 Nov)

    python3 pieces.py          # clavicle < trunk (back + belly) < ribcage < pelvis junction < leg; smooth outlines
    python3 pieces_render.py   # muscle groups, the pieces' outlines (inner lines where an upper piece overlaps), volume

The torso splits into back (lower back + back), belly (belly + abs) and ribcage (ribcage + back clavicle; it also takes
the belly's sliver along its front). Cut-out style: the lower pieces reach under the upper ones, all within the
torso's one smooth outline, so there are no gaps; an upper piece's outline shows as an inner line (the ribcage's
bottom, the waist, the V of the pelvis junction, the buttock).

From the vanilla template only the outer edges of the belly and the back; nothing that would belong to the ribcage
outside Dima's ribcage. The ribcage and the clavicle are Dima's own (lightly smoothed: the clavicle traces the vanilla
shoulder's bump and keeps its notch), the clavicle under the ribcage as in his file. Back and belly are one piece (no
seam between them; their groups stay inside for weights and morphs). The pelvis junction and the leg are Dima's own.

## The doll (BODY_41, Dima's scheme, 3 Nov)

    python3 pieces.py   # now: belly + abs (underlay) < clavicle < back < ribcage < pelvis junction < leg
    python3 doll.py     # -> $BODY_WORK/doll.tscn; copy it to game/debug/body_doll/ (gitignored: it holds outlines)

Pieces turn on bones instead of bending; only the back bends, by its two zones. Bones from Dima's sketch (template
space): pelvis at the hip (-221.6, -2.3) -> lower back pivot (-152.4, -68.0) -> back pivot (-79.5, -146.3) ->
ribcage pivot (-25.0, -211.7) -> the neck base (119.2, -453.15); thigh at the hip -> the knee (160.3, 291.1).
Weights: clavicle and ribcage on the ribcage, pelvis junction on the pelvis, leg on the thigh (rigid until Dima's
drawn leg poses); belly by Laplace between the ribcage (A) and the pelvis (B, the pubis); back by Laplace with the
lower back's and the back's zones (eroded 10) on their bones, what lies under the pelvis on the pelvis and under the
ribcage on the ribcage. Belly, clavicle and back draw only the body's outer outline (their dark copies sit under
all fills); ribcage, pelvis and leg keep theirs as inner lines. NeckSlot follows the ribcage (RemoteTransform2D) and
draws between the back and the ribcage. In the editor rotate the Bone2D nodes; run the scene (F6) to drag the rings.

### The lower leg (BODY_42)

Dima's template now also has the calf (икра, нога), the knee (сустав колена, колено), the ankle bone (чашечка стопы),
the ankle link (связка стопы\нога) and the foot (стопа, пятка); pieces.py makes each its own piece, in his layer
order: thigh < calf < ankle cap < knee joint < kneecap < ankle link < foot (toes later). Bones: calf at the knee
(189.9, 285.0) - the anatomical axis, inside his knee joint - to the ankle (-304.5, 349.0), the middle of his ankle
bone; foot from the ankle to its tip (-527.0, 359.5). knee_auto and ankle_auto (metadata half_of) carry the joint
pieces and turn half as much as the calf / the foot - doll.gd does it, also in the editor (it is a tool script).
The joints draw only the body's outer outline, so they hide the seams; calf, foot and the cyan caps keep theirs.

### Marks: where the outline bends (BODY_43)

Weights are no longer computed in Python. Each piece has `Marks` (Marker2D children on its outline) with metadata
`weights`, e.g. `{"pelvis": 0.5, "thigh": 0.5}`. Along the outline the weights go over linearly from mark to mark
(same weights on both = rigid, different = a bend); the inside follows (a guess from the outline, then smoothing).
doll.gd builds the weights (`Rebuild weights` button on the BodyDoll node in the editor; also on load when a piece
has none); `game/debug/body_doll/bake.gd` does it headless and saves the scene:

    godot --headless --path game --script res://debug/body_doll/bake.gd

The marks doll.py places: Dima's (3 Nov) on the leg - buttock top on the pelvis, a long bend down the back of the
buttock, a short one at the groin - and ours: under the knee (thigh and calf), the instep (calf and foot), the
crotch of the pelvis junction toward the thigh; on the back and the belly they come from the zones (the back
bends over 24 units at each zone border, the belly stretches between the ribcage and the pelvis); other pieces get
four rigid marks to start from. M (running) shows the marks on the posed body: green = a bend, grey = rigid.

### Drawn leg poses (BODY_44)

Dima drew the leg (thigh, knee, calf; the foot not yet) in two more poses, in copies of the template with the same
layers. Build each copy's pieces in its own work dir, then pass them to doll.py:

    BODY_WORK=poses/T3 python3 zones.py <template 3 unpacked> && BODY_WORK=poses/T3 python3 pieces.py   # same for T4
    BODY_POSES=poses/T3,poses/T4 python3 doll.py

poses.py fits the rest thigh's far part and the rest calf onto each drawing (rigid: rms 1-4 units), which gives the
pose's hip and knee angles, and corrects the hip and knee points to the ones the drawings turn around (least
squares). The scene gets each pose piece's drawn outline (metadata `poses`); doll.gd matches the piece's outline to
it (marks as anchors, then by length), keeps the difference in rest space (`pose_deltas`) and, running, mixes rest
and the drawn poses by how near the thigh's and calf's angles are (1 / distance squared). pieces.py grows its
raster grid when a template reaches past the old box (the grid is stored in pieces.pkl).
