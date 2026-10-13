"""Shape record codec: parses DefineShape/DefineMorphShape/font glyph records and writes DefineShape4 tags.

Used to synthesise static shapes for (a) morph shapes at a given ratio and (b) static text, so that every visual
can be rasterised by the same renderer (FFDec) and positioned with known bounds.
"""
import struct

from swfparse import Bits


# ---------------------------------------------------------------- reading

def _raw_matrix(b):
    m = b.matrix()
    return [m[0], m[1], m[2], m[3], int(round(m[4] * 20)), int(round(m[5] * 20))]


def _rgb(b, alpha):
    c = list(b.bytes(4 if alpha else 3))
    if not alpha:
        c.append(255)
    return c


def read_fill_style(b, shape_ver):
    alpha = shape_ver >= 3
    t = b.u8()
    f = {'type': t}
    if t == 0x00:
        f['color'] = _rgb(b, alpha)
    elif t in (0x10, 0x12, 0x13):
        f['matrix'] = _raw_matrix(b)
        b.align()
        f['spread'] = b.ub(2)
        f['interp'] = b.ub(2)
        n = b.ub(4)
        f['records'] = [(b.u8(), _rgb(b, alpha)) for _ in range(n)]
        if t == 0x13:
            f['focal'] = b.s16()
    elif 0x40 <= t <= 0x43:
        f['bitmap'] = b.u16()
        f['matrix'] = _raw_matrix(b)
    else:
        raise ValueError('bad fill style %x' % t)
    return f


def read_fill_array(b, shape_ver):
    n = b.u8()
    if n == 0xFF and shape_ver >= 2:
        n = b.u16()
    return [read_fill_style(b, shape_ver) for _ in range(n)]


def read_line_style(b, shape_ver):
    l = {'width': b.u16()}
    if shape_ver == 4:
        l['startCap'] = b.ub(2)
        l['join'] = b.ub(2)
        has_fill = b.ub(1)
        l['noHScale'] = b.ub(1)
        l['noVScale'] = b.ub(1)
        l['pixelHinting'] = b.ub(1)
        b.ub(5)
        l['noClose'] = b.ub(1)
        l['endCap'] = b.ub(2)
        if l['join'] == 2:
            l['miter'] = b.u16()
        if has_fill:
            l['fill'] = read_fill_style(b, 4)
        else:
            l['color'] = _rgb(b, True)
    else:
        l['color'] = _rgb(b, shape_ver >= 3)
    return l


def read_line_array(b, shape_ver):
    n = b.u8()
    if n == 0xFF and shape_ver >= 2:
        n = b.u16()
    return [read_line_style(b, shape_ver) for _ in range(n)]


def read_records(b, shape_ver, fill_bits, line_bits):
    """Returns records with ABSOLUTE coordinates (twips):
       ('style', dict(move=(x,y)|None, fill0, fill1, line, fills, lines))  (None for unchanged fields)
       ('line', x, y)   ('curve', cx, cy, ax, ay)"""
    recs = []
    x = y = 0
    while True:
        if b.ub(1) == 0:
            new_styles = b.ub(1)
            ch_line = b.ub(1)
            ch_f1 = b.ub(1)
            ch_f0 = b.ub(1)
            move = b.ub(1)
            if not (new_styles or ch_line or ch_f1 or ch_f0 or move):
                break
            s = {'move': None, 'fill0': None, 'fill1': None, 'line': None, 'fills': None, 'lines': None}
            if move:
                n = b.ub(5)
                x = b.sb(n)
                y = b.sb(n)
                s['move'] = (x, y)
            if ch_f0:
                s['fill0'] = b.ub(fill_bits)
            if ch_f1:
                s['fill1'] = b.ub(fill_bits)
            if ch_line:
                s['line'] = b.ub(line_bits)
            if new_styles and shape_ver >= 2:
                s['fills'] = read_fill_array(b, shape_ver)
                s['lines'] = read_line_array(b, shape_ver)
                b.align()
                fill_bits = b.ub(4)
                line_bits = b.ub(4)
            recs.append(('style', s))
        elif b.ub(1):
            n = b.ub(4) + 2
            if b.ub(1):
                x += b.sb(n)
                y += b.sb(n)
            elif b.ub(1):
                y += b.sb(n)
            else:
                x += b.sb(n)
            recs.append(('line', x, y))
        else:
            n = b.ub(4) + 2
            cx = x + b.sb(n)
            cy = y + b.sb(n)
            x = cx + b.sb(n)
            y = cy + b.sb(n)
            recs.append(('curve', cx, cy, x, y))
    return recs


def read_shape(data, pos, code):
    """Parse a DefineShape1-4 tag body."""
    ver = {2: 1, 22: 2, 32: 3, 83: 4}[code]
    b = Bits(data, pos)
    cid = b.u16()
    bounds = b.rect()
    shape = {'id': cid, 'ver': ver, 'bounds': bounds}
    if ver == 4:
        shape['edgeBounds'] = b.rect()
        b.ub(5)
        shape['winding'] = b.ub(1)
        b.ub(2)
    shape['fills'] = read_fill_array(b, ver)
    shape['lines'] = read_line_array(b, ver)
    b.align()
    fb = b.ub(4)
    lb = b.ub(4)
    shape['records'] = read_records(b, ver, fb, lb)
    return shape


# ---- morph shapes

def _read_morph_fill(b):
    t = b.u8()
    f = {'type': t}
    if t == 0x00:
        f['color'] = (_rgb(b, True), _rgb(b, True))
    elif t in (0x10, 0x12, 0x13):
        f['matrix'] = (_raw_matrix(b), _raw_matrix(b))
        b.align()
        f['spread'] = b.ub(2)
        f['interp'] = b.ub(2)
        n = b.ub(4)
        recs = []
        for _ in range(n):
            r0 = b.u8()
            c0 = _rgb(b, True)
            r1 = b.u8()
            c1 = _rgb(b, True)
            recs.append(((r0, c0), (r1, c1)))
        f['records'] = recs
        if t == 0x13:
            f['focal'] = (b.s16(), b.s16())
    elif 0x40 <= t <= 0x43:
        f['bitmap'] = b.u16()
        f['matrix'] = (_raw_matrix(b), _raw_matrix(b))
    else:
        raise ValueError('bad morph fill %x' % t)
    return f


def _read_morph_line(b, ver):
    l = {'width': (b.u16(), b.u16())}
    if ver == 2:
        l['startCap'] = b.ub(2)
        l['join'] = b.ub(2)
        has_fill = b.ub(1)
        l['noHScale'] = b.ub(1)
        l['noVScale'] = b.ub(1)
        l['pixelHinting'] = b.ub(1)
        b.ub(5)
        l['noClose'] = b.ub(1)
        l['endCap'] = b.ub(2)
        if l['join'] == 2:
            l['miter'] = b.u16()
        if has_fill:
            l['fill'] = _read_morph_fill(b)
        else:
            l['color'] = (_rgb(b, True), _rgb(b, True))
    else:
        l['color'] = (_rgb(b, True), _rgb(b, True))
    return l


def read_morph(data, pos, code):
    ver = 1 if code == 46 else 2
    b = Bits(data, pos)
    m = {'id': b.u16(), 'ver': ver, 'bounds': (b.rect(), b.rect())}
    if ver == 2:
        m['edgeBounds'] = (b.rect(), b.rect())
        b.ub(6)
        b.ub(2)
    offset = b.u32()
    end_pos = b.pos + offset
    n = b.u8()
    if n == 0xFF:
        n = b.u16()
    m['fills'] = [_read_morph_fill(b) for _ in range(n)]
    n = b.u8()
    if n == 0xFF:
        n = b.u16()
    m['lines'] = [_read_morph_line(b, ver) for _ in range(n)]
    b.align()
    fb = b.ub(4)
    lb = b.ub(4)
    m['start'] = read_records(b, 4, fb, lb)
    b = Bits(data, end_pos)
    fb = b.ub(4)
    lb = b.ub(4)
    m['end'] = read_records(b, 4, fb, lb)
    return m


def _lerp(a, b, t):
    return a + (b - a) * t


def _lerp_color(c0, c1, t):
    return [int(round(_lerp(c0[i], c1[i], t))) for i in range(4)]


def _lerp_matrix(m0, m1, t):
    return [_lerp(m0[i], m1[i], t) for i in range(4)] + [int(round(_lerp(m0[4], m1[4], t))),
                                                          int(round(_lerp(m0[5], m1[5], t)))]


def _morph_fill_at(f, t):
    out = {'type': f['type']}
    if f['type'] == 0x00:
        out['color'] = _lerp_color(f['color'][0], f['color'][1], t)
    elif 'records' in f:
        out['matrix'] = _lerp_matrix(f['matrix'][0], f['matrix'][1], t)
        out['spread'] = f['spread']
        out['interp'] = f['interp']
        out['records'] = [(int(round(_lerp(a[0], b[0], t))), _lerp_color(a[1], b[1], t)) for a, b in f['records']]
        if 'focal' in f:
            out['focal'] = int(round(_lerp(f['focal'][0], f['focal'][1], t)))
    else:
        out['bitmap'] = f['bitmap']
        out['matrix'] = _lerp_matrix(f['matrix'][0], f['matrix'][1], t)
    return out


def _lerp_rect(r0, r1, t):
    return tuple(int(round(_lerp(r0[i], r1[i], t))) for i in range(4))


def morph_at(m, ratio):
    """Interpolate a parsed morph shape to a static shape dict (ver 4) at ratio 0..65535."""
    t = ratio / 65535.0
    fills = [_morph_fill_at(f, t) for f in m['fills']]
    lines = []
    for l in m['lines']:
        o = {k: v for k, v in l.items() if k not in ('width', 'color', 'fill')}
        o['width'] = int(round(_lerp(l['width'][0], l['width'][1], t)))
        o.setdefault('startCap', 0)
        o.setdefault('join', 0)
        o.setdefault('noHScale', 0)
        o.setdefault('noVScale', 0)
        o.setdefault('pixelHinting', 0)
        o.setdefault('noClose', 0)
        o.setdefault('endCap', 0)
        if 'fill' in l:
            o['fill'] = _morph_fill_at(l['fill'], t)
        else:
            o['color'] = _lerp_color(l['color'][0], l['color'][1], t)
        lines.append(o)
    recs = []
    end = m['end']
    ei = 0
    sx = sy = ex = ey = 0  # current pen in start / end
    for r in m['start']:
        if r[0] == 'style':
            s = dict(r[1])
            if s['move'] is not None:
                # the matching end record is the next style record carrying a move
                while ei < len(end) and end[ei][0] != 'style':
                    ei += 1
                if ei < len(end):
                    em = end[ei][1]['move'] or (ex, ey)
                    ei += 1
                else:
                    em = s['move']
                sx, sy = s['move']
                ex, ey = em
                s['move'] = (int(round(_lerp(sx, ex, t))), int(round(_lerp(sy, ey, t))))
            recs.append(('style', s))
            continue
        while ei < len(end) and end[ei][0] == 'style':
            em = end[ei][1]['move']
            if em is not None:
                ex, ey = em
            ei += 1
        e = end[ei] if ei < len(end) else ('line', ex, ey)
        ei += 1
        a = _as_curve(r, sx, sy)
        bb = _as_curve(e, ex, ey)
        sx, sy = r[-2], r[-1]
        ex, ey = e[-2], e[-1]
        if r[0] == 'line' and e[0] == 'line':
            recs.append(('line', int(round(_lerp(a[2], bb[2], t))), int(round(_lerp(a[3], bb[3], t)))))
        else:
            recs.append(('curve',) + tuple(int(round(_lerp(a[i], bb[i], t))) for i in range(4)))
    bounds = _lerp_rect(m['bounds'][0], m['bounds'][1], t)
    return {'ver': 4, 'bounds': bounds, 'edgeBounds': bounds, 'winding': 0, 'fills': fills, 'lines': lines,
            'records': recs}


def _as_curve(r, px, py):
    if r[0] == 'curve':
        return r[1:]
    return ((px + r[1]) / 2.0, (py + r[2]) / 2.0, r[1], r[2])


# ---- fonts & static text

def read_font3(data, pos, code):
    """Parse DefineFont2/3 into {'glyphs': [records], 'codes': [...], 'em': units}."""
    b = Bits(data, pos)
    fid = b.u16()
    b.ub(4)  # has layout, shift-jis, small text, ansi
    wide_offsets = b.ub(1)
    wide_codes = b.ub(1)
    b.ub(2)  # italic, bold
    b.u8()  # language
    name_len = b.u8()
    name = b.bytes(name_len).rstrip(b'\0').decode('latin-1')
    n = b.u16()
    table = b.pos
    offs = [struct.unpack_from('<I' if wide_offsets else '<H', data, table + i * (4 if wide_offsets else 2))[0]
            for i in range(n + 1)]
    glyphs = []
    for i in range(n):
        gb = Bits(data, table + offs[i])
        fbits = gb.ub(4)
        lbits = gb.ub(4)
        glyphs.append(read_records(gb, 1, fbits, lbits))
    cpos = table + offs[n] if n else table + (4 if wide_offsets else 2)
    codes = [struct.unpack_from('<H' if wide_codes else '<B', data, cpos + i * (2 if wide_codes else 1))[0]
             for i in range(n)]
    return {'id': fid, 'name': name, 'glyphs': glyphs, 'codes': codes, 'em': 20480.0 if code == 75 else 1024.0}


def read_text(data, pos, code):
    b = Bits(data, pos)
    cid = b.u16()
    bounds = b.rect()
    matrix = _raw_matrix(b)
    gbits = b.u8()
    abits = b.u8()
    alpha = code == 33
    runs = []
    font = None
    color = [0, 0, 0, 255]
    x = y = 0
    height = 0
    while True:
        flags = b.u8()
        if flags == 0:
            break
        if flags & 0x08:
            font = b.u16()
        if flags & 0x04:
            color = _rgb(b, alpha)
        if flags & 0x01:
            x = b.s16()
        if flags & 0x02:
            y = b.s16()
        if flags & 0x08:
            height = b.u16()
        n = b.u8()
        glyphs = []
        for _ in range(n):
            gi = b.ub(gbits)
            adv = b.sb(abits)
            glyphs.append((gi, adv))
        b.align()
        runs.append({'font': font, 'color': color, 'x': x, 'y': y, 'height': height, 'glyphs': glyphs})
        for gi, adv in glyphs:
            x += adv
    return {'id': cid, 'bounds': bounds, 'matrix': matrix, 'runs': runs}


def text_to_shape(text, fonts):
    """Builds a static ver-4 shape dict from a parsed DefineText using glyph outlines."""
    a, bm, c, d, tx, ty = text['matrix']
    fills = []
    color_index = {}
    recs = []
    pts = []

    def xf(px, py):
        return (int(round(a * px + c * py + tx)), int(round(bm * px + d * py + ty)))

    for run in text['runs']:
        font = fonts.get(run['font'])
        if not font:
            continue
        key = tuple(run['color'])
        if key not in color_index:
            fills.append({'type': 0, 'color': list(run['color'])})
            color_index[key] = len(fills)
        fi = color_index[key]
        scale = run['height'] / font['em']
        x = run['x']
        for gi, adv in run['glyphs']:
            if gi < len(font['glyphs']):
                for r in font['glyphs'][gi]:
                    if r[0] == 'style':
                        s = r[1]
                        ns = {'move': None, 'fill0': None, 'fill1': None, 'line': None, 'fills': None, 'lines': None}
                        if s['move'] is not None:
                            ns['move'] = xf(x + s['move'][0] * scale, run['y'] + s['move'][1] * scale)
                            pts.append(ns['move'])
                        if s['fill0'] is not None:
                            ns['fill0'] = fi if s['fill0'] else 0
                        if s['fill1'] is not None:
                            ns['fill1'] = fi if s['fill1'] else 0
                        if s['line'] is not None:
                            ns['line'] = 0
                        recs.append(('style', ns))
                    elif r[0] == 'line':
                        p = xf(x + r[1] * scale, run['y'] + r[2] * scale)
                        recs.append(('line',) + p)
                        pts.append(p)
                    else:
                        p1 = xf(x + r[1] * scale, run['y'] + r[2] * scale)
                        p2 = xf(x + r[3] * scale, run['y'] + r[4] * scale)
                        recs.append(('curve',) + p1 + p2)
                        pts.extend([p1, p2])
            x += adv
    if not pts:
        return None
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    bounds = (min(xs) - 20, max(xs) + 20, min(ys) - 20, max(ys) + 20)
    return {'ver': 4, 'bounds': bounds, 'edgeBounds': bounds, 'winding': 0, 'fills': fills, 'lines': [],
            'records': recs}


# ---------------------------------------------------------------- writing

def _sbits(*vals):
    n = 1
    for v in vals:
        v = int(v)
        need = (v.bit_length() + 1) if v >= 0 else ((~v).bit_length() + 1)
        n = max(n, need)
    return n


def _ubits(v):
    return max(1, int(v).bit_length())


class BitWriter:
    def __init__(self):
        self.out = bytearray()
        self.cur = 0
        self.n = 0

    def ub(self, v, n):
        for i in range(n - 1, -1, -1):
            self.cur = (self.cur << 1) | ((int(v) >> i) & 1)
            self.n += 1
            if self.n == 8:
                self.out.append(self.cur)
                self.cur = 0
                self.n = 0

    def sb(self, v, n):
        self.ub(int(v) & ((1 << n) - 1), n)

    def align(self):
        if self.n:
            self.out.append(self.cur << (8 - self.n))
            self.cur = 0
            self.n = 0

    def raw(self, bs):
        self.align()
        self.out += bs

    def u8(self, v):
        self.raw(struct.pack('<B', v))

    def u16(self, v):
        self.raw(struct.pack('<H', v))

    def s16(self, v):
        self.raw(struct.pack('<h', v))

    def rect(self, r):
        self.align()
        n = _sbits(*r)
        self.ub(n, 5)
        for v in r:
            self.sb(v, n)
        self.align()

    def matrix(self, m):
        self.align()
        a, b, c, d, tx, ty = m
        if a != 1.0 or d != 1.0:
            ia = int(round(a * 65536))
            id_ = int(round(d * 65536))
            n = _sbits(ia, id_)
            self.ub(1, 1)
            self.ub(n, 5)
            self.sb(ia, n)
            self.sb(id_, n)
        else:
            self.ub(0, 1)
        if b != 0.0 or c != 0.0:
            ib = int(round(b * 65536))
            ic = int(round(c * 65536))
            n = _sbits(ib, ic)
            self.ub(1, 1)
            self.ub(n, 5)
            self.sb(ib, n)
            self.sb(ic, n)
        else:
            self.ub(0, 1)
        tx = int(tx)
        ty = int(ty)
        n = _sbits(tx, ty) if (tx or ty) else 0
        self.ub(n, 5)
        if n:
            self.sb(tx, n)
            self.sb(ty, n)
        self.align()


def _write_fill(w, f):
    w.u8(f['type'])
    t = f['type']
    if t == 0:
        w.raw(bytes(f['color']))
    elif 'records' in f:
        w.matrix(f['matrix'])
        w.ub(f['spread'], 2)
        w.ub(f['interp'], 2)
        w.ub(len(f['records']), 4)
        w.align()
        for r, col in f['records']:
            w.u8(r)
            w.raw(bytes(col))
        if t == 0x13:
            w.s16(f.get('focal', 0))
    else:
        w.u16(f['bitmap'])
        w.matrix(f['matrix'])


def _write_line(w, l):
    w.u16(l['width'])
    w.ub(l.get('startCap', 0), 2)
    w.ub(l.get('join', 0), 2)
    w.ub(1 if 'fill' in l else 0, 1)
    w.ub(l.get('noHScale', 0), 1)
    w.ub(l.get('noVScale', 0), 1)
    w.ub(l.get('pixelHinting', 0), 1)
    w.ub(0, 5)
    w.ub(l.get('noClose', 0), 1)
    w.ub(l.get('endCap', 0), 2)
    w.align()
    if l.get('join', 0) == 2:
        w.u16(l.get('miter', 3 * 256))
    if 'fill' in l:
        _write_fill(w, l['fill'])
    else:
        w.raw(bytes(l['color']))


def _write_styles(w, fills, lines):
    if len(fills) >= 0xFF:
        w.u8(0xFF)
        w.u16(len(fills))
    else:
        w.u8(len(fills))
    for f in fills:
        _write_fill(w, f)
    if len(lines) >= 0xFF:
        w.u8(0xFF)
        w.u16(len(lines))
    else:
        w.u8(len(lines))
    for l in lines:
        _write_line(w, l)


def _upgrade_line(l):
    """Convert a shape1-3 line style to LINESTYLE2 form (round caps/joins, as Flash renders them)."""
    if 'startCap' in l:
        return l
    o = dict(l)
    o.update(startCap=0, join=0, noHScale=0, noVScale=0, pixelHinting=0, noClose=0, endCap=0)
    return o


def write_shape4(cid, shape):
    """Serialise a shape dict (absolute-coordinate records) to a DefineShape4 tag body."""
    w = BitWriter()
    w.u16(cid)
    w.rect(shape['bounds'])
    w.rect(shape.get('edgeBounds', shape['bounds']))
    w.ub(0, 5)
    w.ub(shape.get('winding', 0), 1)
    w.ub(0, 1)
    w.ub(1, 1)
    fills = shape['fills']
    lines = [_upgrade_line(l) for l in shape['lines']]
    _write_styles(w, fills, lines)
    fbits = _ubits(len(fills))
    lbits = _ubits(len(lines))
    w.ub(fbits, 4)
    w.ub(lbits, 4)
    x = y = 0
    for r in shape['records']:
        if r[0] == 'style':
            s = r[1]
            new_styles = s.get('fills') is not None
            w.ub(0, 1)
            w.ub(1 if new_styles else 0, 1)
            w.ub(1 if s['line'] is not None else 0, 1)
            w.ub(1 if s['fill1'] is not None else 0, 1)
            w.ub(1 if s['fill0'] is not None else 0, 1)
            w.ub(1 if s['move'] is not None else 0, 1)
            if s['move'] is not None:
                x, y = s['move']
                n = _sbits(x, y)
                w.ub(n, 5)
                w.sb(x, n)
                w.sb(y, n)
            if s['fill0'] is not None:
                w.ub(s['fill0'], fbits)
            if s['fill1'] is not None:
                w.ub(s['fill1'], fbits)
            if s['line'] is not None:
                w.ub(s['line'], lbits)
            if new_styles:
                nl = [_upgrade_line(l) for l in s['lines']]
                _write_styles(w, s['fills'], nl)
                fbits = _ubits(len(s['fills']))
                lbits = _ubits(len(nl))
                w.ub(fbits, 4)
                w.ub(lbits, 4)
        elif r[0] == 'line':
            dx = r[1] - x
            dy = r[2] - y
            x, y = r[1], r[2]
            n = max(2, _sbits(dx, dy))
            w.ub(1, 1)
            w.ub(1, 1)
            w.ub(n - 2, 4)
            w.ub(1, 1)
            w.sb(dx, n)
            w.sb(dy, n)
        else:
            cdx = r[1] - x
            cdy = r[2] - y
            adx = r[3] - r[1]
            ady = r[4] - r[2]
            x, y = r[3], r[4]
            n = max(2, _sbits(cdx, cdy, adx, ady))
            w.ub(1, 1)
            w.ub(0, 1)
            w.ub(n - 2, 4)
            w.sb(cdx, n)
            w.sb(cdy, n)
            w.sb(adx, n)
            w.sb(ady, n)
    w.ub(0, 6)
    w.align()
    return bytes(w.out)


def tag(code, body):
    if len(body) < 0x3f and code not in (6, 20, 21, 35, 36, 90):
        return struct.pack('<H', (code << 6) | len(body)) + body
    return struct.pack('<HI', (code << 6) | 0x3f, len(body)) + body


def write_swf(path, tags_bytes, rect=(0, 14000, 0, 12000), frame_rate=30.0, version=11):
    w = BitWriter()
    w.rect(rect)
    body = bytes(w.out) + struct.pack('<HH', int(frame_rate * 256), 1) + b''.join(tags_bytes) + tag(1, b'') + tag(0, b'')
    data = b'FWS' + bytes([version]) + struct.pack('<I', 8 + len(body)) + body
    with open(path, 'wb') as f:
        f.write(data)
