"""Surveys a folder of SDT / Loader mod SWFs: how much ActionScript bytecode vs artwork each one contains.
Usage: survey_mods.py <mods dir>"""
import os
import sys
import zlib

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "swfconv"))


def tags(path):
    data = open(path, "rb").read()
    sig = data[:3]
    if sig == b"CWS":
        data = data[:8] + zlib.decompress(data[8:])
    elif sig == b"ZWS":
        import lzma
        # LZMA SWF: 4 bytes compressed length, 5 bytes props, then raw lzma
        props = data[12:17]
        raw = lzma.LZMADecompressor(lzma.FORMAT_RAW, filters=[lzma._decode_filter_properties(lzma.FILTER_LZMA1, props)])
        data = data[:8] + raw.decompress(data[17:])
    elif sig != b"FWS":
        return None
    nbits = data[8] >> 3
    pos = 8 + (5 + nbits * 4 + 7) // 8 + 4
    out = []
    while pos + 2 <= len(data):
        h = int.from_bytes(data[pos:pos + 2], "little")
        code, ln = h >> 6, h & 0x3F
        pos += 2
        if ln == 0x3F:
            ln = int.from_bytes(data[pos:pos + 4], "little")
            pos += 4
        out.append((code, ln))
        pos += ln
        if code == 0:
            break
    return out


SHAPES = {2, 22, 32, 83, 46, 84}
BITMAPS = {6, 20, 21, 35, 36, 90}
SOUNDS = {14}
ABC = {72, 82}

root = sys.argv[1]
rows = []
for dp, _, fs in os.walk(root):
    for f in fs:
        if f.lower().endswith(".swf"):
            p = os.path.join(dp, f)
            try:
                t = tags(p)
            except Exception as e:
                t = None
            if t is None:
                continue
            abc = sum(l for c, l in t if c in ABC)
            shapes = sum(1 for c, l in t if c in SHAPES)
            bmps = sum(1 for c, l in t if c in BITMAPS)
            snds = sum(1 for c, l in t if c in SOUNDS)
            rows.append((abc, shapes, bmps, snds, os.path.relpath(p, root)))
rows.sort()
buckets = {"no code": 0, "<4KB code": 0, "4-40KB code": 0, ">40KB code": 0}
for abc, s, b, n, p in rows:
    k = "no code" if abc == 0 else "<4KB code" if abc < 4096 else "4-40KB code" if abc < 40960 else ">40KB code"
    buckets[k] += 1
print(buckets)
for r in rows[-25:]:
    print(r)
art_small = [r for r in rows if r[0] < 4096 and (r[1] or r[2])]
print("art with little/no code:", len(art_small), "of", len(rows))
