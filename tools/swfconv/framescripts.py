"""Extracts simple timeline frame scripts (stop/play/gotoAndStop/gotoAndPlay) from FFDec-decompiled AS3.

Frame scripts are registered in class constructors via addFrameScript(index, this.frameN, ...). Only bodies made of
the four timeline-control calls are converted to data; anything else is reported so it can be ported by hand.
"""
import os
import re

ADD_RE = re.compile(r'addFrameScript\(([^;]*)\);')
PAIR_RE = re.compile(r'(\d+)\s*,\s*this\.(\w+)')
STMT_RE = re.compile(r'^(stop|play)\(\)$|^(gotoAndStop|gotoAndPlay)\(("([^"]*)"|\d+)\)$')


def _function_body(src, name):
    m = re.search(r'function\s+%s\s*\(\s*\)\s*:\s*\*\s*\{' % re.escape(name), src)
    if not m:
        return None
    i = m.end()
    depth = 1
    start = i
    while depth and i < len(src):
        if src[i] == '{':
            depth += 1
        elif src[i] == '}':
            depth -= 1
        i += 1
    return src[start:i - 1]


def extract(scripts_dir):
    """Returns ({fully.qualified.Class: {frameIndex: [[op, arg], ...]}}, [warnings])."""
    out = {}
    warnings = []
    for root, _, files in os.walk(scripts_dir):
        for f in files:
            if not f.endswith('.as'):
                continue
            path = os.path.join(root, f)
            src = open(path, encoding='utf-8', errors='replace').read()
            calls = ADD_RE.findall(src)
            if not calls:
                continue
            rel = os.path.relpath(path, scripts_dir)[:-3].replace(os.sep, '.')
            scripts = {}
            for call in calls:
                for idx, fn in PAIR_RE.findall(call):
                    body = _function_body(src, fn)
                    if body is None:
                        warnings.append('%s: no body for %s' % (rel, fn))
                        continue
                    ops = []
                    for stmt in [s.strip() for s in body.split(';')]:
                        if not stmt:
                            continue
                        m = STMT_RE.match(stmt)
                        if not m:
                            warnings.append('%s.%s: unsupported statement %r' % (rel, fn, stmt))
                            continue
                        if m.group(1):
                            ops.append([m.group(1)])
                        else:
                            arg = m.group(4) if m.group(4) is not None else int(m.group(3))
                            ops.append([m.group(2), arg])
                    scripts[int(idx)] = ops
            out[rel] = scripts
    return out, warnings
