"""Round-trip test: re-encode every DefineShape as DefineShape4, rasterise both with FFDec and compare pixels."""
import os
import subprocess
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from swfparse import SWF  # noqa: E402
import shapes  # noqa: E402

FFDEC = r'C:\Program Files (x86)\FFDec\ffdec.jar'
src, work = sys.argv[1], sys.argv[2]
os.makedirs(work, exist_ok=True)
s = SWF(src)
tags = []
for code, pos, ln in s.tags:
    if code in (8, 6, 20, 21, 35, 36, 90):
        tags.append(shapes.tag(code, s.data[pos:pos + ln]))
ids = []
for cid, ch in sorted(s.chars.items()):
    if ch['type'] != 'shape':
        continue
    sh = shapes.read_shape(s.data, ch['pos'], ch['code'])
    tags.append(shapes.tag(83, shapes.write_shape4(cid, sh)))
    ids.append(cid)
out_swf = os.path.join(work, 'roundtrip.swf')
shapes.write_swf(out_swf, tags)
for name, swf in (('orig', src), ('rt', out_swf)):
    d = os.path.join(work, name)
    if not os.path.isdir(d):
        subprocess.run(['java', '-jar', FFDEC, '-format', 'shape:png', '-zoom', '2', '-export', 'shape', d, swf],
                       check=True, stdout=subprocess.DEVNULL)
bad = 0
for cid in ids:
    a = os.path.join(work, 'orig', '%d.png' % cid)
    b = os.path.join(work, 'rt', '%d.png' % cid)
    if not os.path.exists(b):
        print('missing', cid)
        bad += 1
        continue
    ia = np.asarray(Image.open(a).convert('RGBA'), dtype=np.int16)
    ib = np.asarray(Image.open(b).convert('RGBA'), dtype=np.int16)
    if ia.shape != ib.shape:
        print('size', cid, ia.shape, ib.shape)
        bad += 1
        continue
    diff = np.abs(ia - ib).max()
    if diff > 8:
        print('diff', cid, diff, (np.abs(ia - ib) > 8).sum())
        bad += 1
print('checked', len(ids), 'bad', bad)
