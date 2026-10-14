"""Godot 4 GDScript does not call the parent's _init implicitly when a subclass defines its own _init (AS3 does
call super() implicitly). For every top-level _init in a class whose ancestors (script classes) define _init,
makes sure the body starts with super(...); where no ancestor defines _init, removes a bare `super()` (GDScript
rejects it). Prints changed files and parents whose _init has required parameters (review those by hand).

Usage: add_super_init.py <game dir>"""
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
files = [f for f in root.rglob("*.gd") if ".godot" not in f.parts]
info = {}
for f in files:
    t = f.read_text(encoding="utf-8")
    cn = re.search(r"^class_name (\w+)", t, re.M)
    ex = re.search(r"^extends (\w+)", t, re.M)
    init = re.search(r"^func _init\((.*?)\)", t, re.M)
    if cn:
        info[cn.group(1)] = {"parent": ex.group(1) if ex else None, "init": init is not None,
                             "required": bool(init and init.group(1).strip()
                                              and any("=" not in p for p in init.group(1).split(",")))}


def ancestor_init(parent):
    seen = set()
    while parent in info and parent not in seen:
        seen.add(parent)
        if info[parent]["init"]:
            return parent
        parent = info[parent]["parent"]
    return None


changed = []
for f in files:
    t = f.read_text(encoding="utf-8")
    ex = re.search(r"^extends (\w+)", t, re.M)
    if not ex:
        continue
    anc = ancestor_init(ex.group(1))
    lines = t.split("\n")
    out = []
    i = 0
    did = False
    while i < len(lines):
        out.append(lines[i])
        if re.match(r"^func _init\(", lines[i]):
            while not out[-1].rstrip().endswith(":") and i + 1 < len(lines):
                i += 1
                out.append(lines[i])
            j = i + 1
            while j < len(lines) and lines[j].strip() == "":
                j += 1
            first = lines[j].strip() if j < len(lines) else ""
            if anc and not first.startswith("super("):
                out.append("\tsuper()")
                did = True
                if info[anc]["required"]:
                    print("REVIEW: %s: %s._init needs arguments" % (f, anc))
            elif not anc and first == "super()":
                i = j  # drop the bare super() line
                did = True
        i += 1
    if did:
        f.write_text("\n".join(out), encoding="utf-8", newline="\n")
        changed.append(str(f))
print("\n".join(changed))
print(len(changed), "files changed")
