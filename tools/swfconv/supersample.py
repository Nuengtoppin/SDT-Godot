"""Re-renders shape images that FFDec rasterised without anti-aliasing, supersampled.

FFDec paints gradient and bitmap fills through a clip, which Java2D does not anti-alias, so those shapes come out with
hard, stair-stepped edges (very visible on morphing body parts, whose outline sits under a gradient skin shape). This
renders the affected shapes (static shapes, morph frames and texts with any gradient / bitmap fill) at
`factor` times the library's bake scale and box-filters them back down (in premultiplied alpha), overwriting the
PNGs with images of the same size and placement.

Usage: supersample.py <file.swf> <library dir> [--factor 4] [--batch 400] [--limit N] [--only m373_0,s1042]
       [--all] [--shard i/n] [--skip-newer] [--ffdec path]
"""
import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import numpy as np
from PIL import Image

import shapes
from swfparse import SWF

DEFAULT_FFDEC = r'C:\Program Files (x86)\FFDec\ffdec.jar'
SYNTH_ID = 40000


def _fill_kinds(sh):
    fills = list(sh['fills'])
    for r in sh['records']:
        if r[0] == 'style' and r[1].get('fills') is not None:
            fills += r[1]['fills']
    return {('color' if 'color' in f else ('grad' if 'records' in f else 'bmp')) for f in fills}


def _needs_supersampling(sh, everything):
    return everything or bool(_fill_kinds(sh) - {'color'})


def _downsample(path_hi, size, k):
    """Box-filters a k-times larger render down to `size` (premultiplied alpha)."""
    a = np.asarray(Image.open(path_hi).convert('RGBA')).astype(np.float32) / 255.0
    w, h = size
    buf = np.zeros((h * k, w * k, 4), np.float32)
    hh, ww = min(h * k, a.shape[0]), min(w * k, a.shape[1])
    buf[:hh, :ww, :3] = a[:hh, :ww, :3] * a[:hh, :ww, 3:4]
    buf[:hh, :ww, 3] = a[:hh, :ww, 3]
    buf = buf.reshape(h, k, w, k, 4).mean(axis=(1, 3))
    out = np.zeros_like(buf)
    alpha = buf[:, :, 3]
    m = alpha > 1e-6
    out[m, :3] = buf[m, :3] / alpha[m, None]
    out[:, :, 3] = alpha
    return Image.fromarray(np.clip(out * 255.0 + 0.5, 0, 255).astype(np.uint8), 'RGBA')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('swf')
    ap.add_argument('lib')
    ap.add_argument('--factor', type=int, default=4)
    ap.add_argument('--batch', type=int, default=400)
    ap.add_argument('--limit', type=int, default=0)
    ap.add_argument('--shard', default='0/1', help='i/n: process every n-th image starting at i (parallel runs)')
    ap.add_argument('--skip-newer', action='store_true', help='skip images modified after the swf (already done)')
    ap.add_argument('--only', default='')
    ap.add_argument('--all', action='store_true', help='supersample every shape, not just gradient / bitmap ones')
    ap.add_argument('--ffdec', default=DEFAULT_FFDEC)
    a = ap.parse_args()

    swf = SWF(a.swf)
    lib = json.load(open(os.path.join(a.lib, 'library.json'), encoding='utf-8'))
    scale = lib.get('scale', 2)
    shape_dir = os.path.join(a.lib, 'shapes')
    only = set(x for x in a.only.split(',') if x)

    # (image name, DefineShape4 record) for everything to re-render
    jobs = []
    for cid, ch in sorted(swf.chars.items()):
        if ch['type'] == 'shape':
            img = 's%d' % cid
            if only and img not in only:
                continue
            if not os.path.exists(os.path.join(shape_dir, img + '.png')):
                continue
            sh = shapes.read_shape(swf.data, ch['pos'], ch['code'])
            if _needs_supersampling(sh, a.all or bool(only)):
                jobs.append((img, sh))
        elif ch['type'] == 'morph':
            entry = lib['chars'].get(str(cid), {})
            m = shapes.read_morph(swf.data, ch['pos'], ch['code'])
            for ratio, e in sorted(entry.get('ratios', {}).items(), key=lambda kv: int(kv[0])):
                if not e:
                    continue
                img = e['img']
                if only and img not in only:
                    continue
                st = shapes.morph_at(m, int(ratio))
                if _needs_supersampling(st, a.all or bool(only)):
                    jobs.append((img, st))
    si, sn = (int(x) for x in a.shard.split('/'))
    jobs = jobs[si::sn]
    if a.skip_newer:
        # the converter writes every image long after; a supersampled one is newer than library.json
        ref = os.path.getmtime(os.path.join(a.lib, 'library.json'))
        jobs = [j for j in jobs if os.path.getmtime(os.path.join(shape_dir, j[0] + '.png')) <= ref]
    if a.limit:
        jobs = jobs[:a.limit]
    print('images to supersample:', len(jobs), 'factor', a.factor, flush=True)

    base_tags = [shapes.tag(code, swf.data[pos:pos + ln]) for code, pos, ln in swf.tags
                 if code in (8, 6, 20, 21, 35, 36, 90)]   # bitmaps (for bitmap fills)
    zoom = scale * a.factor
    t_start = time.time()
    done = 0
    for b in range(0, len(jobs), a.batch):
        batch = jobs[b:b + a.batch]
        tmp = tempfile.mkdtemp(prefix='supersample_')
        try:
            tags = list(base_tags)
            names = {}
            for i, (img, st) in enumerate(batch):
                sid = SYNTH_ID + i
                tags.append(shapes.tag(83, shapes.write_shape4(sid, st)))
                names[sid] = img
            synth = os.path.join(tmp, 'synth.swf')
            shapes.write_swf(synth, tags)
            out = os.path.join(tmp, 'png')
            subprocess.run(['java', '-Xmx6g', '-jar', a.ffdec, '-format', 'shape:png', '-zoom', str(zoom),
                            '-export', 'shape', out, synth], check=True, stdout=subprocess.DEVNULL,
                           stderr=subprocess.DEVNULL)
            for f in os.listdir(out):
                sid = int(f.split('.')[0])
                img = names.get(sid)
                if img is None:
                    continue
                dst = os.path.join(shape_dir, img + '.png')
                size = Image.open(dst).size
                _downsample(os.path.join(out, f), size, a.factor).save(dst, optimize=False)
                done += 1
        finally:
            shutil.rmtree(tmp, ignore_errors=True)
        el = time.time() - t_start
        print('  %d / %d  (%.0f s, eta %.0f s)' % (done, len(jobs), el, el / max(done, 1) * (len(jobs) - done)),
              flush=True)
    print('supersampled', done)


if __name__ == '__main__':
    main()
