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
