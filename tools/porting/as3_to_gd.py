"""Rough AS3 -> GDScript draft converter for FFDec-decompiled classes (one statement per line, braces on their own
lines). Output is a starting point for a hand-reviewed port, not a finished translation: lines it could not
convert confidently are marked with '#?'.

Usage: as3_to_gd.py <file.as> [known_gd_classes.txt] > draft.gd
"""
import re
import sys

EVENTS = {"MouseEvent", "Event", "KeyboardEvent", "FocusEvent", "TimerEvent", "IOErrorEvent", "ProgressEvent"}
MATH = {"Math.min": "min", "Math.max": "max", "Math.abs": "abs", "Math.floor": "floor", "Math.ceil": "ceil",
        "Math.round": "Maths.round", "Math.sqrt": "sqrt", "Math.sin": "sin", "Math.cos": "cos",
        "Math.atan2": "atan2", "Math.pow": "pow", "Math.random()": "randf()", "Math.PI": "PI"}


class _M:
    def __init__(self, cls, args):
        self._g = (None, cls, args)

    def group(self, i):
        return self._g[i]


def split_ternary(expr):
    """a ? b : c -> (b if a else c) for the outermost ternary at depth 0 (simple cases only)."""
    depth = 0
    q = c = -1
    instr = None
    for i, ch in enumerate(expr):
        if instr:
            if ch == instr and expr[i - 1] != "\\":
                instr = None
            continue
        if ch in "\"'":
            instr = ch
        elif ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        elif ch == "?" and depth == 0 and q < 0:
            q = i
        elif ch == ":" and depth == 0 and q >= 0:
            c = i
            break
    if q < 0 or c < 0:
        return expr
    return "(%s if %s else %s)" % (expr[q + 1:c].strip(), expr[:q].strip(), expr[c + 1:].strip())


def find_close(e, start):
    """Index of the ')' matching the '(' at e[start]."""
    depth = 0
    instr = None
    for i in range(start, len(e)):
        ch = e[i]
        if instr:
            if ch == instr and e[i - 1] != "\\":
                instr = None
            continue
        if ch in "\"'":
            instr = ch
        elif ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
            if depth == 0:
                return i
    return -1


def rewrite_calls(e, pattern, fn):
    """Rewrites every match of pattern (ending just before a '(') using fn(match, args) -> replacement."""
    out = ""
    pos = 0
    while True:
        m = re.compile(pattern).search(e, pos)
        if not m:
            return out + e[pos:]
        op = m.end()
        if op >= len(e) or e[op] != "(":
            out += e[pos:op]
            pos = op
            continue
        cl = find_close(e, op)
        if cl < 0:
            return out + e[pos:]
        out += e[pos:m.start()] + fn(m, e[op + 1:cl])
        pos = cl + 1


def receiver_start(e, end):
    """Start index of the receiver expression ending at e[end] (identifiers, dots, [..] and (..) groups)."""
    i = end
    while i > 0:
        ch = e[i - 1]
        if ch.isalnum() or ch in "_.":
            i -= 1
        elif ch in ")]":
            depth = 0
            j = i - 1
            while j >= 0:
                if e[j] in ")]":
                    depth += 1
                elif e[j] in "([":
                    depth -= 1
                    if depth == 0:
                        break
                j -= 1
            i = j
        else:
            break
    return i


def method_rewrite(e, method, fn):
    """recv.method(args) -> fn(recv, args)."""
    while True:
        m = re.search(r"\." + method + r"\(", e)
        if not m:
            return e
        op = m.end() - 1
        cl = find_close(e, op)
        if cl < 0:
            return e
        rs = receiver_start(e, m.start())
        e = e[:rs] + fn(e[rs:m.start()], e[op + 1:cl]) + e[cl + 1:]


def conv_expr(e, known):
    e = e.replace("this.", "")
    e = re.sub(r"\bnew Array\(\)", "[]", e)
    e = re.sub(r"\bnew Dictionary\(\)", "{}", e)
    e = re.sub(r"\bnew Object\(\)", "{}", e)
    e = re.sub(r"\bnew Point\(([^()]*)\)", r"Vector2(\1)", e)
    e = re.sub(r"\bnew Rectangle\(([^()]*)\)", r"Rect2(\1)", e)

    def newrep(m):
        cls = m.group(1)
        args = m.group(2)
        gd = {"Slider": "SDTSlider", "MenuButton": "SDTMenuButton"}.get(cls, cls)
        flash = {"Sprite": "FlashSprite", "MovieClip": "FlashMovieClip", "Bitmap": "FlashBitmap",
                 "BitmapData": "FlashBitmapData", "ColorTransform": "FlashColorTransform",
                 "FileReference": "FlashFileReference", "Loader": "FlashLoader", "TextField": "FlashTextField"}
        if cls in flash:
            return "%s.new(%s)" % (flash[cls], args)
        if gd in known:
            return "%s.new(%s)" % (gd, args)
        if args.strip():
            return "%s.new(%s) #?" % (gd, args)
        return 'Flash.create("%s")' % cls
    e = rewrite_calls(e, r"\bnew (\w+)", lambda m, a: newrep(_M(m.group(1), conv_expr(a, known))))
    for k, v in MATH.items():
        e = e.replace(k, v)
    for ev in EVENTS:
        e = re.sub(r"\b%s\.([A-Z_]+)\b" % ev, r"FlashEvent.\1", e)
    e = e.replace("&&", " and ").replace("||", " or ")
    e = re.sub(r"!(?!=)", " not ", e)
    e = re.sub(r"\bnot\s+not\s+", "", e)
    e = re.sub(r"(?<![.\w])u?int\(", "AS3.toInt(", e)
    e = re.sub(r"(?<![.\w])Number\(", "AS3.Number(", e)
    e = re.sub(r"(?<![.\w])isNaN\(", "is_nan(", e)
    e = e.replace(".transform.colorTransform", ".colorTransform")
    e = e.replace("TextFieldType.DYNAMIC", '"dynamic"').replace("TextFieldType.INPUT", '"input"')
    e = re.sub(r"\.shift\(\)", ".pop_front()", e)
    e = method_rewrite(e, "split", lambda r, a: "Array(%s.split_(%s))" % (r, a)).replace(".split_(", ".split(")
    e = method_rewrite(e, "join", lambda r, a: "%s.join_(PackedStringArray(%s))" % (a or '","', r)).replace(".join_(", ".join(")
    e = method_rewrite(e, "concat", lambda r, a: "(%s + %s)" % (r, a))
    e = re.sub(r"\bString\(", "str(", e)
    e = re.sub(r"\bBoolean\(", "bool(", e)
    e = re.sub(r"\bnull\b", "null", e)
    e = re.sub(r"\.push\(", ".append(", e)
    e = re.sub(r"\.indexOf\(", ".find(", e)
    e = re.sub(r"\.length\b", ".size()", e)
    e = re.sub(r"\.toLowerCase\(\)", ".to_lower()", e)
    e = re.sub(r"\.toUpperCase\(\)", ".to_upper()", e)
    e = re.sub(r"\s+as\s+\w+", "", e)
    e = re.sub(r"DisplayObject\(([^()]*)\)", r"\1", e)
    e = e.replace("Mouse.show()", "Input.mouse_mode = Input.MOUSE_MODE_VISIBLE")
    e = e.replace("Mouse.hide()", "Input.mouse_mode = Input.MOUSE_MODE_HIDDEN")
    e = re.sub(r"\.slice\(\)", ".duplicate()", e)
    e = re.sub(r"\(\s+", "(", e)
    e = re.sub(r"  +", " ", e)
    e = e.replace("( not ", "(not ")
    if "?" in e and ":" in e and not e.strip().startswith('"'):
        e = split_ternary(e)
    return e.strip()


def conv_stmt(s, known):
    s = s.rstrip(";").strip()
    m = re.fullmatch(r"var (\w+):[\w.<>*]+(?: = (.*))?", s)
    if m:
        return "var %s%s" % (m.group(1), " = " + conv_expr(m.group(2), known) if m.group(2) else "")
    m = re.fullmatch(r"(\+\+|--)([\w.\[\]]+)", s) or None
    if m:
        return "%s %s= 1" % (conv_expr(m.group(2), known), "+" if m.group(1) == "++" else "-")
    m = re.fullmatch(r"([\w.\[\]]+)(\+\+|--)", s)
    if m:
        return "%s %s= 1" % (conv_expr(m.group(1), known), "+" if m.group(2) == "++" else "-")
    if s == "break":
        return "break"
    if s.startswith("return"):
        return "return" + (" " + conv_expr(s[6:], known) if s[6:].strip() else "")
    return conv_expr(s, known)


def convert(src, known):
    lines = [l.strip() for l in src.splitlines()]
    out = []
    indent = 0
    stack = []          # kinds of blocks: 'class','func','block','switch','case'
    pending = None      # header waiting for '{'
    in_class = False
    members = []
    i = 0
    while i < len(lines):
        l = lines[i]
        i += 1
        if not l or l.startswith("import ") or l.startswith("package") or l.startswith("[Embed"):
            continue
        if l == "{":
            stack.append(pending or "block")
            if pending in ("func", "if", "loop", "switch", "case"):
                indent += 1
            pending = None
            continue
        if l in ("}", "};", "});"):
            kind = stack.pop() if stack else None
            if kind == "case":
                # closing brace of a switch whose last case has no explicit end
                indent -= 1
                kind = stack.pop() if stack else None
            if kind in ("func", "if", "loop", "switch"):
                indent -= 1
            continue
        tab = "\t" * indent
        m = re.match(r"public class (\w+)(?: extends (\w+))?", l)
        if m:
            out.append("class_name %s\nextends %s\n" % (m.group(1), m.group(2) or "RefCounted"))
            pending = "class"
            continue
        m = re.match(r"(?:public |private |protected |internal )?(?:static )?(?:const|var) (\w+):([\w.<>*]+)(?: = (.*))?;", l)
        if m and len(stack) == 2 and stack[-1] == "class":
            kw = "const" if " const " in " " + l else "var"
            val = conv_expr(m.group(3), known) if m.group(3) else None
            out.append("%s %s%s" % (kw, m.group(1), " = " + val if val else ""))
            continue
        m = re.match(r"(?:override )?(?:public |private |protected |internal )?(?:override )?(?:static )?function (get |set )?(\w+)\((.*)\)(?: : (\S+))?$", l)
        if m:
            params = []
            for p in [x.strip() for x in m.group(3).split(",") if x.strip()]:
                pm = re.match(r"(\w+):([\w.<>*]+)(?: = (.*))?", p)
                if pm:
                    default = conv_expr(pm.group(3), known) if pm.group(3) else None
                    if default is None and pm.group(2) in EVENTS:
                        default = "null"
                    params.append(pm.group(1) + (" = " + default if default else ""))
                else:
                    params.append(p + " #?")
            name = m.group(2)
            if name == stack_class_name(out):
                name = "_init"
            prefix = "#? %sproperty " % m.group(1) if m.group(1) else ""
            out.append("\n\n%sfunc %s(%s):" % (prefix, name, ", ".join(params)))
            pending = "func"
            continue
        m = re.match(r"(else if|if|while)\((.*)\)$", l)
        if m:
            kw = {"else if": "elif"}.get(m.group(1), m.group(1))
            out.append("%s%s %s:" % (tab, kw, conv_expr(m.group(2), known)))
            pending = "loop" if kw == "while" else "if"
            continue
        if l == "else":
            out.append(tab + "else:")
            pending = "if"
            continue
        m = re.match(r"for each\((?:var )?(\w+)(?::\S+)? in (.*)\)$", l)
        if m:
            out.append("%sfor %s in %s:" % (tab, m.group(1), conv_expr(m.group(2), known)))
            pending = "loop"
            continue
        m = re.match(r"for\((?:var )?(\w+)(?::\S+)? in (.*)\)$", l)
        if m:
            out.append("%sfor %s in %s: #? keys" % (tab, m.group(1), conv_expr(m.group(2), known)))
            pending = "loop"
            continue
        m = re.match(r"switch\((.*)\)$", l)
        if m:
            out.append("%smatch %s:" % (tab, conv_expr(m.group(1), known)))
            pending = "switch"
            continue
        m = re.match(r"(case (.*)|default):$", l)
        if m:
            if stack and stack[-1] == "case":
                stack.pop()
                indent -= 1
                tab = "\t" * indent
            # merge consecutive case labels
            labels = [conv_expr(m.group(2), known) if m.group(2) else "_"]
            while i < len(lines) and re.match(r"(case (.*)|default):$", lines[i]):
                mm = re.match(r"(case (.*)|default):$", lines[i])
                labels.append(conv_expr(mm.group(2), known) if mm.group(2) else "_")
                i += 1
            if "_" in labels:
                labels = ["_"]
            out.append("%s%s:" % (tab, ", ".join(labels)))
            stack.append("case")
            indent += 1
            continue
        if l == "break;" and stack and stack[-1] == "case":
            continue
        if l.startswith("super("):
            continue
        if l == "try":
            pending = "try"
            continue
        if l.startswith("catch("):
            # no exceptions in GDScript: drop the handler block
            depth = 0
            while i < len(lines):
                depth += lines[i].count("{") - lines[i].count("}")
                i += 1
                if depth <= 0:
                    break
            continue
        if l.endswith("{") or l.endswith("= {"):
            pass
        m = re.match(r"(.*)function\((.*)\)(?::\w+|:\*)?$", l)
        if m:
            params = ", ".join(re.sub(r":[\w.*]+", "", x).strip() for x in m.group(2).split(",") if x.strip())
            head = re.sub(r"(var \w+):[\w.*]+\s*=", r"\1 =", m.group(1))
            out.append(tab + conv_expr(head, known) + " func(%s):" % params)
            pending = "func"
            continue
        if re.search(r"[=(,]\s*\{?$", l) and (l.endswith("{") or l.endswith("[")):
            # multi-line object / array literal: gather until the matching close
            buf = [l]
            depth = l.count("{") + l.count("[") - l.count("}") - l.count("]")
            while depth > 0 and i < len(lines):
                buf.append(lines[i])
                depth += lines[i].count("{") + lines[i].count("[") - lines[i].count("}") - lines[i].count("]")
                i += 1
            l = " ".join(buf)
        out.append(tab + conv_stmt(l, known))
    text = "\n".join(out)
    text = re.sub(r":\n(\t*)(\n|$)", r":\n\1\tpass\n", text)
    return text


def stack_class_name(out):
    for l in out:
        m = re.match(r"class_name (\w+)", l)
        if m:
            return m.group(1)
    return None


if __name__ == "__main__":
    known = set()
    if len(sys.argv) > 2:
        known = set(open(sys.argv[2]).read().split())
    sys.stdout.reconfigure(encoding="utf-8", newline="\n")
    print(convert(open(sys.argv[1], encoding="utf-8").read(), known))
