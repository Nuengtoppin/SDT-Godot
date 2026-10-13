"""Generates GDScript stubs for top-level symbol classes that only extend a ported class (art + frame scripts).

Usage: python gen_symbol_stubs.py <decompiled scripts dir> <output dir>
"""
import os
import re
import sys

BASES = {
    'CostumeElement': 'CostumeElement',
    'RigidBody': 'RigidBody',
    'Slider': 'SDTSlider',
    'obj.MenuButton': 'SDTMenuButton',
    'obj.MenuCheckbox': 'MenuCheckbox',
    'MainMenuButton': 'MainMenuButton',
}

src, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
for f in sorted(os.listdir(src)):
    if not f.endswith('.as'):
        continue
    text = open(os.path.join(src, f), encoding='utf-8', errors='replace').read()
    m = re.search(r'public (?:dynamic )?class (\w+) extends ([\w.]+)', text)
    if not m or m.group(2) not in BASES:
        continue
    name, base = m.group(1), m.group(2)
    gd_base = BASES[base]
    if name == gd_base or name in ('MenuButton', 'MenuCheckbox'):
        continue  # the ported class itself handles this symbol
    with open(os.path.join(out, name + '.gd'), 'w', encoding='utf-8', newline='\n') as fh:
        fh.write('class_name %s\nextends %s\n## Library symbol %s: artwork and frame scripts come from the SWF; behaviour '
                 'from %s.\n' % (name, gd_base, name, base))
    print(name, '->', gd_base)
