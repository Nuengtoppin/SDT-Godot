"""Disassembles an Adobe Pixel Bender bytecode (.pbj) file into readable pseudo-assembly.
Used once to port DT_HighlightFilter (binary/180.bin) to a Godot shader."""
import struct
import sys

OPS = {0x01: "add", 0x02: "sub", 0x03: "mul", 0x04: "rcp", 0x05: "div", 0x06: "atan2", 0x07: "pow", 0x08: "mod",
       0x09: "min", 0x0A: "max", 0x0B: "step", 0x0C: "sin", 0x0D: "cos", 0x0E: "tan", 0x0F: "asin", 0x10: "acos",
       0x11: "atan", 0x12: "exp", 0x13: "exp2", 0x14: "log", 0x15: "log2", 0x16: "sqrt", 0x17: "rsqrt", 0x18: "abs",
       0x19: "sign", 0x1A: "floor", 0x1B: "ceil", 0x1C: "fract", 0x1D: "mov", 0x1E: "ftoi", 0x1F: "itof",
       0x20: "matmatmul", 0x21: "vecmatmul", 0x22: "matvecmul", 0x23: "normalize", 0x24: "length",
       0x25: "distance", 0x26: "dot", 0x27: "cross", 0x28: "eq", 0x29: "ne", 0x2A: "lt", 0x2B: "le", 0x2C: "not",
       0x2D: "and", 0x2E: "or", 0x2F: "xor", 0x30: "sampleNearest", 0x31: "sampleLinear", 0x32: "load",
       0x33: "loop", 0x34: "if", 0x35: "else", 0x36: "endif", 0x37: "ftob", 0x38: "btof", 0x39: "itob",
       0x3A: "btoi", 0x3B: "smoothstep", 0x3C: "select"}
TYPES = {1: "float", 2: "float2", 3: "float3", 4: "float4", 5: "float2x2", 6: "float3x3", 7: "float4x4",
         8: "int", 9: "int2", 10: "int3", 11: "int4", 12: "string"}
COMP = "xyzw"


def reg(r):
    return ("i%d" % (r & 0x7FFF)) if r & 0x8000 else ("f%d" % r)


def mask_str(m):
    return "".join(c for i, c in enumerate(COMP) if m & (8 >> i))


def swz(s, n):
    return "".join(COMP[(s >> (6 - 2 * i)) & 3] for i in range(n))


def cstr(b, p):
    e = b.index(0, p)
    return b[p:e].decode("latin1"), e + 1


def value(b, p, t):
    n = {1: 1, 2: 2, 3: 3, 4: 4, 5: 4, 6: 9, 7: 16}.get(t)
    if n:
        return list(struct.unpack(">%df" % n, b[p:p + 4 * n])), p + 4 * n
    if t in (8, 9, 10, 11):
        n = t - 7
        return list(struct.unpack(">%dH" % n, b[p:p + 2 * n])), p + 2 * n
    if t == 12:
        return cstr(b, p)
    raise ValueError(t)


def main(path):
    b = open(path, "rb").read()
    p = 0
    while p < len(b):
        op = b[p]
        p += 1
        if op == 0xA5:
            print("version", struct.unpack("<I", b[p:p + 4])[0]); p += 4
        elif op == 0xA4:
            n = struct.unpack("<H", b[p:p + 2])[0]; print("kernel", b[p + 2:p + 2 + n].decode()); p += 2 + n
        elif op in (0xA0, 0xA2):
            t = b[p]; p += 1
            k, p = cstr(b, p)
            v, p = value(b, p, t)
            print("  meta", k, v)
        elif op == 0xA1:
            q = b[p]; t = b[p + 1]; r = struct.unpack("<H", b[p + 2:p + 4])[0]; m = b[p + 4]; p += 5
            n, p = cstr(b, p)
            print("param %s %s %s %s.%s" % ("out" if q == 2 else "in", TYPES.get(t), n, reg(r), mask_str(m)))
        elif op == 0xA3:
            idx = b[p]; ch = b[p + 1]; p += 2
            n, p = cstr(b, p)
            print("texture", idx, ch, n)
        elif op == 0x32:
            dst, m = struct.unpack("<HB", b[p:p + 3])
            raw = b[p + 3:p + 7]
            v = struct.unpack(">f", raw)[0] if not dst & 0x8000 else struct.unpack(">i", raw)[0]
            print("  load %s.%s = %r" % (reg(dst), mask_str(m >> 4), v)); p += 7
        elif op in (0x30, 0x31):
            dst, m, src, s, tex = struct.unpack("<HBHBB", b[p:p + 7]); p += 7
            print("  %s %s.%s = tex%d(%s.%s)" % (OPS[op], reg(dst), mask_str(m >> 4), tex, reg(src), swz(s, 2)))
        elif op == 0x34:
            src = struct.unpack("<H", b[p + 3:p + 5])[0]; p += 7
            print("  if", reg(src))
        elif op in (0x35, 0x36):
            p += 7; print(" ", OPS[op])
        elif op in OPS:
            dst, m, src, s, _ = struct.unpack("<HBHBB", b[p:p + 7]); p += 7
            n = (m & 3) + 1
            print("  %s %s.%s, %s.%s" % (OPS[op], reg(dst), mask_str(m >> 4), reg(src), swz(s, n)))
        else:
            print("?? op %02x at %d" % (op, p - 1)); break


if __name__ == "__main__":
    main(sys.argv[1])
