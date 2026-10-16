"""Converts the chars/*.as character presets (data + generateElements) to GDScript.

Handles only the constructs those files use; output is reviewed by hand.
Usage: python port_chars.py <chars dir> <out dir> <gd class names file>
"""
import os
import re
import sys

src, out, gd_names_file = sys.argv[1], sys.argv[2], sys.argv[3]
GD = set(open(gd_names_file).read().split())


def convert_expr(e):
    e = re.sub(r'new Point\(', 'Vector2(', e)

    def new_repl(m):
        cls = m.group(1)
        if cls in GD:
            return '%s.new(' % cls
        return 'Flash.create("%s"' % cls + ('' if m.group(2) == ')' else ', ')
    e = re.sub(r'new (\w+)\((\))?', lambda m: (('%s.new()' % m.group(1)) if m.group(1) in GD else 'Flash.create("%s")' % m.group(1)) if m.group(2) else (('%s.new(' % m.group(1)) if m.group(1) in GD else 'Flash.create("%s", ' % m.group(1)), e)
    e = e.replace('this.', '')
    e = re.sub(r'\.rotation\b', '.rotation_degrees', e)
    e = e.replace('Her.NORMAL_MOOD', 'Her.NORMAL_MOOD')
    return e


for f in sorted(os.listdir(src)):
    if not f.endswith('.as') or f == 'Character.as':
        continue
    name = f[:-3]
    text = open(os.path.join(src, f), encoding='utf-8').read()
    body_lines = []
    lines = text.splitlines()
    i = 0
    mode = None
    depth = 0
    out_lines = ['class_name %s' % name, 'extends Character', '## Port of chars.%s (character preset).' % name, '']
    while i < len(lines):
        line = lines[i].strip()
        i += 1
        m = re.match(r'public function %s\(\)' % name, line)
        if m:
            out_lines.append('func _init() -> void:')
            mode = 'func'
            continue
        m = re.match(r'override public function generateElements\(\) : Array', line)
        if m:
            out_lines.append('')
            out_lines.append('')
            out_lines.append('func generateElements() -> Array:')
            mode = 'func'
            continue
        if mode != 'func':
            continue
        if line == '{':
            depth += 1
            continue
        if line == '}':
            depth -= 1
            if depth == 0:
                mode = None
            continue
        if line in ('super();',) or not line:
            continue
        # gather multi-line statements (object literals)
        stmt = line
        while not stmt.endswith(';') and i < len(lines):
            stmt += ' ' + lines[i].strip()
            i += 1
        stmt = stmt.rstrip(';')
        stmt = re.sub(r'\{\s+', '{', stmt)
        stmt = re.sub(r'\s+\}', '}', stmt)
        stmt = re.sub(r'"(\w+)":', r'"\1": ', stmt)
        # (_locN_ = new X(...)).call(...)
        m = re.match(r'\((_loc\d+_) = (.*?)\)\.(.*)$', stmt)
        if m:
            out_lines.append('\tvar %s = %s' % (m.group(1), convert_expr(m.group(2))))
            out_lines.append('\t%s.%s' % (m.group(1), convert_expr(m.group(3))))
            continue
        m = re.match(r'var (_loc\d+_):[\w*]+ = (.*)$', stmt)
        if m:
            out_lines.append('\tvar %s = %s' % (m.group(1), convert_expr(m.group(2))))
            continue
        m = re.match(r'var (_loc\d+_):[\w*]+$', stmt)
        if m:
            out_lines.append('\tvar %s' % m.group(1))
            continue
        out_lines.append('\t' + convert_expr(stmt))
    code = '\n'.join(out_lines) + '\n'
    # A later "(x = ...)" after "var x" declaration: drop duplicate var keyword
    seen = set()
    fixed = []
    for l in code.splitlines():
        m = re.match(r'\tvar (_loc\d+_)( = .*)?$', l)
        if m:
            if m.group(1) in seen:
                if m.group(2):
                    l = '\t%s%s' % (m.group(1), m.group(2))
                else:
                    continue
            seen.add(m.group(1))
        if re.match(r'func ', l):
            seen = set()
        fixed.append(l)
    open(os.path.join(out, name + '.gd'), 'w', encoding='utf-8', newline='\n').write('\n'.join(fixed) + '\n')
    print('wrote', name)
