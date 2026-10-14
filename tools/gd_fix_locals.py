"""Post-pass for as3_to_gd.py output: AS3 hoists local variables, so the decompiler declares them at the top of a
function and may declare them again later; GDScript rejects redeclaration and `for x in` over a declared x.
Per function: drops `var x = null` lines for names used as for-loop variables, and turns later re-declarations
into plain assignments. Rewrites the file in place."""
import re
import sys

path = sys.argv[1]
lines = open(path, encoding="utf-8").read().split("\n")
out = []
func_start = None


def fix_function(body):
    loopvars = set(re.findall(r"^\s*for (\w+) in ", "\n".join(body), re.M))
    seen = set()
    res = []
    for l in body:
        m = re.match(r"^(\s*)var (\w+)(\s*(?::[^=]*)?)(=.*)?$", l)
        if m and m.group(1):
            name = m.group(2)
            if name in loopvars and (m.group(4) is None or m.group(4).strip() in ("= null", "=null")):
                continue
            if name in seen:
                if m.group(4):
                    res.append("%s%s %s" % (m.group(1), name, m.group(4)))
                continue
            seen.add(name)
        res.append(l)
    return res


body = []
for l in lines:
    if re.match(r"^(static )?func ", l):
        out.extend(fix_function(body))
        body = [l]
    elif body and (l.startswith("\t") or l.strip() == ""):
        body.append(l)
    else:
        out.extend(fix_function(body))
        body = []
        out.append(l)
out.extend(fix_function(body))
open(path, "w", encoding="utf-8", newline="\n").write("\n".join(out))
print("ok")
