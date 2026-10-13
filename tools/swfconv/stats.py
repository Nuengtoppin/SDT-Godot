import collections
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from swfparse import SWF, TAG_NAMES  # noqa: E402

s = SWF(sys.argv[1])
print('version', s.version, 'rect', s.rect, 'fps', s.frame_rate, 'frames', s.frame_count)
print(collections.Counter(TAG_NAMES.get(t[0], t[0]) for t in s.tags).most_common())
print(collections.Counter(v['type'] for v in s.chars.values()))
print('symbol classes', len(s.symbol_class), 'scene labels', s.scene_labels)
sub = collections.Counter()
blends = collections.Counter()
filt = collections.Counter()
clip = named = frames_total = 0
ratios = set()
multi = 0
for cid, ch in s.chars.items():
    if ch['type'] != 'sprite':
        continue
    for code, _, _ in ch['tags']:
        sub[TAG_NAMES.get(code, code)] += 1
    frames, labels = s.timeline(cid)
    frames_total += len(frames)
    if len(frames) > 1:
        multi += 1
    for f in frames:
        for op in f:
            if op['op'] != 'place':
                continue
            if 'blend' in op:
                blends[op['blend']] += 1
            for ff in op.get('filters', []):
                filt[ff['type']] += 1
            clip += 'clipDepth' in op
            named += 'name' in op
            if 'ratio' in op:
                ratios.add((op.get('id'), op['ratio']))
print('sprite subtags', sub.most_common())
print('blends', blends, 'filters', filt, 'clips', clip, 'named', named)
print('sprite frames total', frames_total, 'multi-frame sprites', multi)
print('distinct ratio placements', len(ratios))
