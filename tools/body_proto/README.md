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
