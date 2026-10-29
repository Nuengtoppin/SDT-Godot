"""Trims a converted library to some of its classes and what they use (for mods that ship a whole template).

Usage: python prune.py <library dir> <Class> [<Class> ...]

Keeps the named classes and every character they place (recursively), deletes the other characters' images and
files, and repacks hitmasks.bin with the kept masks (copied as they are: fix_hitmasks.py's geometry masks stay).
"""
import json
import os
import sys


def repack_hitmasks(lib_dir, chars):
    """Copies each kept image's mask bits into a new hitmasks.bin and updates the offsets."""
    old = open(os.path.join(lib_dir, 'hitmasks.bin'), 'rb').read()
    blob = bytearray()

    def move(entry):
        off, w, h = entry['hm']
        n = (w * h + 7) // 8
        entry['hm'] = [len(blob), w, h]
        blob.extend(old[off:off + n])

    for e in chars.values():
        if e.get('t') == 'shape' and 'hm' in e:
            move(e)
        elif e.get('t') == 'morph':
            for r in e['ratios'].values():
                if r and 'hm' in r:
                    move(r)
    with open(os.path.join(lib_dir, 'hitmasks.bin'), 'wb') as f:
        f.write(bytes(blob))


def refs(entry):
    """Character ids an entry places (sprite timelines, buttons, anything with a "c" key)."""
    out = set()

    def walk(o):
        if isinstance(o, dict):
            if 'c' in o and isinstance(o['c'], int):
                out.add(str(o['c']))
            for v in o.values():
                walk(v)
        elif isinstance(o, list):
            for v in o:
                walk(v)
    walk(entry.get('places', []))
    for k in ('records', 'states'):   # buttons
        walk(entry.get(k, []))
    return out


def files_of(entry):
    """Image names (shapes/<img>.png) and other files an entry uses."""
    imgs, files = set(), set()

    def walk(o):
        if isinstance(o, dict):
            if isinstance(o.get('img'), str):
                imgs.add(o['img'])
            if isinstance(o.get('file'), str):
                files.add(o['file'])
            for v in o.values():
                walk(v)
        elif isinstance(o, list):
            for v in o:
                walk(v)
    walk(entry)
    return imgs, files


def main():
    lib_dir, keep_classes = sys.argv[1], sys.argv[2:]
    path = os.path.join(lib_dir, 'library.json')
    lib = json.load(open(path, encoding='utf-8'))
    chars, classes = lib['chars'], lib['classes']
    missing = [c for c in keep_classes if c not in classes]
    if missing:
        sys.exit('no such classes: %s' % ', '.join(missing))
    keep = set()
    todo = [str(classes[c]) for c in keep_classes]
    while todo:
        cid = todo.pop()
        if cid in keep or cid not in chars:
            continue
        keep.add(cid)
        todo.extend(refs(chars[cid]) - keep)
    imgs, files = set(), set()
    for cid in keep:
        i, f = files_of(chars[cid])
        imgs |= i
        files |= f
    removed = 0
    for name in os.listdir(os.path.join(lib_dir, 'shapes')):
        if os.path.splitext(name)[0] not in imgs:
            os.remove(os.path.join(lib_dir, 'shapes', name))
            removed += 1
    for sub in ('bitmaps', 'fonts', 'sounds', 'binary'):
        d = os.path.join(lib_dir, sub)
        if os.path.isdir(d):
            for name in os.listdir(d):
                if '%s/%s' % (sub, name) not in files:
                    os.remove(os.path.join(d, name))
                    removed += 1
    lib['chars'] = {k: v for k, v in chars.items() if k in keep}
    lib['classes'] = {k: v for k, v in classes.items() if k in keep_classes}
    repack_hitmasks(lib_dir, lib['chars'])
    json.dump(lib, open(path, 'w', encoding='utf-8'), separators=(',', ':'))
    print('kept %d of %d characters, %d images; removed %d files' % (len(keep), len(chars), len(imgs), removed))


if __name__ == '__main__':
    main()
