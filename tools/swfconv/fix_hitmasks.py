"""Rebuilds hit masks for shapes that have transparent or semi-transparent fills / lines.

Flash hit-tests vector geometry, so a fill with alpha 0 (commonly used as an invisible button hit area) still
catches the mouse. convert.py derived hit masks from the rendered alpha, which loses those areas. This renders an
opaque copy of every such shape (same geometry, all colours alpha 255) with FFDec at the library's bake scale and
rewrites its mask in hitmasks.bin in place (same dimensions), updating library.json only if dimensions differ.

Usage: fix_hitmasks.py <file.swf> <library dir> [--ffdec path]
"""
import argparse
import copy
import json
import os
import shutil
import subprocess
import tempfile

import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import numpy as np
from PIL import Image

import shapes
from swfparse import SWF, SHAPE_TAGS

DEFAULT_FFDEC = r'C:\Program Files (x86)\FFDec\ffdec.jar'


def _has_transparency(shape):
    def fill_alpha(f):
        if 'color' in f:
            return f['color'][3] < 255
        if 'records' in f:
            return any(c[3] < 255 for _, c in f['records'])
        return False

    styles_f = list(shape['fills'])
    styles_l = list(shape['lines'])
    for r in shape['records']:
        if r[0] == 'style' and r[1].get('fills') is not None:
            styles_f += r[1]['fills']
            styles_l += r[1]['lines']
    if any(fill_alpha(f) for f in styles_f):
        return True
    for l in styles_l:
        if 'color' in l and l['color'][3] < 255:
            return True
        if 'fill' in l and fill_alpha(l['fill']):
            return True
    return False


def _opaque(shape):
    s = copy.deepcopy(shape)

    def fix_fill(f):
        if 'color' in f:
            f['color'] = list(f['color'][:3]) + [255]
        if 'records' in f:
            f['records'] = [(r, list(c[:3]) + [255]) for r, c in f['records']]

    def fix_styles(fills, lines):
        for f in fills:
            fix_fill(f)
        for l in lines:
            if 'color' in l:
                l['color'] = list(l['color'][:3]) + [255]
            if 'fill' in l:
                fix_fill(l['fill'])

    fix_styles(s['fills'], s['lines'])
    for r in s['records']:
        if r[0] == 'style' and r[1].get('fills') is not None:
            fix_styles(r[1]['fills'], r[1]['lines'])
    return s


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('swf')
    ap.add_argument('lib')
    ap.add_argument('--ffdec', default=DEFAULT_FFDEC)
    a = ap.parse_args()
    swf = SWF(a.swf)
    lib_json = os.path.join(a.lib, 'library.json')
    lib = json.load(open(lib_json, encoding='utf-8'))
    scale = lib.get('scale', 2)
    chars = lib['chars']
    todo = {}
    for cid, ch in swf.chars.items():
        if ch['type'] != 'shape' or str(cid) not in chars or 'hm' not in chars[str(cid)]:
            continue
        sh = shapes.read_shape(swf.data, ch['pos'], ch['code'])
        if _has_transparency(sh):
            todo[cid] = sh
    print('shapes with transparency:', len(todo))
    if not todo:
        return
    tmp = tempfile.mkdtemp(prefix='hitfix_')
    try:
        tags = [shapes.tag(code, swf.data[pos:pos + ln]) for code, pos, ln in swf.tags if code in (8, 6, 20, 21, 35, 36, 90)]
        tags += [shapes.tag(83, shapes.write_shape4(cid, _opaque(sh))) for cid, sh in todo.items()]
        synth = os.path.join(tmp, 'opaque.swf')
        shapes.write_swf(synth, tags)
        out = os.path.join(tmp, 'png')
        subprocess.run(['java', '-jar', a.ffdec, '-format', 'shape:png', '-zoom', str(scale), '-export', 'shape', out,
                        synth], check=True, stdout=subprocess.DEVNULL)
        blob = bytearray(open(os.path.join(a.lib, 'hitmasks.bin'), 'rb').read())
        s = int(round(scale))
        changed = appended = 0
        for f in os.listdir(out):
            cid = int(f.split('.')[0])
            entry = chars[str(cid)]
            alpha = np.asarray(Image.open(os.path.join(out, f)).convert('RGBA'))[:, :, 3].astype(np.float32) / 255.0
            off, w, h = entry['hm']
            hh = max(1, int(np.ceil(alpha.shape[0] / scale)))
            ww = max(1, int(np.ceil(alpha.shape[1] / scale)))
            padded = np.zeros((hh * s, ww * s), np.float32)
            padded[:min(alpha.shape[0], hh * s), :min(alpha.shape[1], ww * s)] = alpha[:hh * s, :ww * s]
            cov = padded.reshape(hh, s, ww, s).mean(axis=(1, 3))
            bits = np.packbits((cov >= 0.5).astype(np.uint8), axis=None, bitorder='little').tobytes()
            if (ww, hh) == (w, h):
                blob[off:off + len(bits)] = bits
            else:
                entry['hm'] = [len(blob), ww, hh]
                blob.extend(bits)
                appended += 1
            changed += 1
        open(os.path.join(a.lib, 'hitmasks.bin'), 'wb').write(bytes(blob))
        if appended:
            with open(lib_json, 'w', encoding='utf-8') as fh:
                json.dump(lib, fh, separators=(',', ':'))
        print('masks rebuilt:', changed, 'resized:', appended)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


if __name__ == '__main__':
    main()
