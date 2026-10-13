"""Minimal SWF parser: extracts the display-list data needed to rebuild Flash timelines in Godot."""
import struct
import zlib

TAG_NAMES = {0: 'End', 1: 'ShowFrame', 2: 'DefineShape', 4: 'PlaceObject', 5: 'RemoveObject', 6: 'DefineBits',
             7: 'DefineButton', 8: 'JPEGTables', 9: 'SetBackgroundColor', 10: 'DefineFont', 11: 'DefineText',
             12: 'DoAction', 13: 'DefineFontInfo', 14: 'DefineSound', 15: 'StartSound', 17: 'DefineButtonSound',
             18: 'SoundStreamHead', 19: 'SoundStreamBlock', 20: 'DefineBitsLossless', 21: 'DefineBitsJPEG2',
             22: 'DefineShape2', 24: 'Protect', 26: 'PlaceObject2', 28: 'RemoveObject2', 32: 'DefineShape3',
             33: 'DefineText2', 34: 'DefineButton2', 35: 'DefineBitsJPEG3', 36: 'DefineBitsLossless2',
             37: 'DefineEditText', 39: 'DefineSprite', 41: 'ProductInfo', 43: 'FrameLabel', 45: 'SoundStreamHead2',
             46: 'DefineMorphShape', 48: 'DefineFont2', 56: 'ExportAssets', 57: 'ImportAssets', 58: 'EnableDebugger',
             59: 'DoInitAction', 62: 'DefineFontInfo2', 64: 'EnableDebugger2', 65: 'ScriptLimits', 66: 'SetTabIndex',
             69: 'FileAttributes', 70: 'PlaceObject3', 71: 'ImportAssets2', 73: 'DefineFontAlignZones',
             74: 'CSMTextSettings', 75: 'DefineFont3', 76: 'SymbolClass', 77: 'Metadata', 78: 'DefineScalingGrid',
             82: 'DoABC', 83: 'DefineShape4', 84: 'DefineMorphShape2', 86: 'DefineSceneAndFrameLabelData',
             87: 'DefineBinaryData', 88: 'DefineFontName', 89: 'StartSound2', 90: 'DefineBitsJPEG4', 91: 'DefineFont4'}

SHAPE_TAGS = {2: 1, 22: 2, 32: 3, 83: 4}
MORPH_TAGS = {46: 1, 84: 2}
BITMAP_TAGS = {6, 20, 21, 35, 36, 90}

BLEND_MODES = {0: 'normal', 1: 'normal', 2: 'layer', 3: 'multiply', 4: 'screen', 5: 'lighten', 6: 'darken',
               7: 'difference', 8: 'add', 9: 'subtract', 10: 'invert', 11: 'alpha', 12: 'erase', 13: 'overlay',
               14: 'hardlight'}


class Bits:
    def __init__(self, data, pos=0):
        self.d = data
        self.pos = pos
        self.bitpos = 0

    def align(self):
        if self.bitpos:
            self.bitpos = 0
            self.pos += 1

    def ub(self, n):
        v = 0
        for _ in range(n):
            bit = (self.d[self.pos] >> (7 - self.bitpos)) & 1
            v = (v << 1) | bit
            self.bitpos += 1
            if self.bitpos == 8:
                self.bitpos = 0
                self.pos += 1
        return v

    def sb(self, n):
        if n == 0:
            return 0
        v = self.ub(n)
        if v & (1 << (n - 1)):
            v -= 1 << n
        return v

    def fb(self, n):
        return self.sb(n) / 65536.0

    def u8(self):
        self.align()
        v = self.d[self.pos]
        self.pos += 1
        return v

    def u16(self):
        self.align()
        v = struct.unpack_from('<H', self.d, self.pos)[0]
        self.pos += 2
        return v

    def s16(self):
        self.align()
        v = struct.unpack_from('<h', self.d, self.pos)[0]
        self.pos += 2
        return v

    def u32(self):
        self.align()
        v = struct.unpack_from('<I', self.d, self.pos)[0]
        self.pos += 4
        return v

    def fixed8(self):
        return self.s16() / 256.0

    def fixed(self):
        self.align()
        v = struct.unpack_from('<i', self.d, self.pos)[0]
        self.pos += 4
        return v / 65536.0

    def float32(self):
        self.align()
        v = struct.unpack_from('<f', self.d, self.pos)[0]
        self.pos += 4
        return v

    def string(self):
        self.align()
        e = self.d.index(b'\0', self.pos)
        s = self.d[self.pos:e]
        self.pos = e + 1
        try:
            return s.decode('utf-8')
        except UnicodeDecodeError:
            return s.decode('latin-1')

    def bytes(self, n):
        self.align()
        v = self.d[self.pos:self.pos + n]
        self.pos += n
        return v

    def rect(self):
        """Returns (xmin, xmax, ymin, ymax) in twips."""
        self.align()
        n = self.ub(5)
        r = (self.sb(n), self.sb(n), self.sb(n), self.sb(n))
        self.align()
        return r

    def matrix(self):
        """Flash matrix [a, b, c, d, tx, ty] with tx/ty in pixels: x' = a*x + c*y + tx, y' = b*x + d*y + ty."""
        self.align()
        a = d = 1.0
        b = c = 0.0
        if self.ub(1):
            n = self.ub(5)
            a = self.fb(n)
            d = self.fb(n)
        if self.ub(1):
            n = self.ub(5)
            b = self.fb(n)
            c = self.fb(n)
        n = self.ub(5)
        tx = self.sb(n)
        ty = self.sb(n)
        self.align()
        return [a, b, c, d, tx / 20.0, ty / 20.0]

    def cxform(self, alpha):
        """Returns [rMult, gMult, bMult, aMult, rAdd, gAdd, bAdd, aAdd]; multipliers as fractions, offsets 0..255."""
        self.align()
        has_add = self.ub(1)
        has_mult = self.ub(1)
        n = self.ub(4)
        mult = [256, 256, 256, 256]
        add = [0, 0, 0, 0]
        cnt = 4 if alpha else 3
        if has_mult:
            for i in range(cnt):
                mult[i] = self.sb(n)
        if has_add:
            for i in range(cnt):
                add[i] = self.sb(n)
        self.align()
        return [m / 256.0 for m in mult] + add


def read_tags(data, pos, end):
    tags = []
    while pos < end:
        code_len = struct.unpack_from('<H', data, pos)[0]
        pos += 2
        code = code_len >> 6
        ln = code_len & 0x3f
        if ln == 0x3f:
            ln = struct.unpack_from('<I', data, pos)[0]
            pos += 4
        tags.append((code, pos, ln))
        pos += ln
        if code == 0:
            break
    return tags


def _shadow_common(b, f):
    f['inner'] = b.ub(1)
    f['knockout'] = b.ub(1)
    f['compositeSource'] = b.ub(1)


def parse_filters(b):
    filters = []
    for _ in range(b.u8()):
        fid = b.u8()
        if fid == 0:
            col = list(b.bytes(4))
            f = {'type': 'DropShadow', 'color': col, 'blurX': b.fixed(), 'blurY': b.fixed(), 'angle': b.fixed(),
                 'distance': b.fixed(), 'strength': b.fixed8()}
            _shadow_common(b, f)
            f['passes'] = b.ub(5)
        elif fid == 1:
            f = {'type': 'Blur', 'blurX': b.fixed(), 'blurY': b.fixed(), 'passes': b.ub(5)}
            b.ub(3)
        elif fid == 2:
            col = list(b.bytes(4))
            f = {'type': 'Glow', 'color': col, 'blurX': b.fixed(), 'blurY': b.fixed(), 'strength': b.fixed8()}
            _shadow_common(b, f)
            f['passes'] = b.ub(5)
        elif fid == 3:
            c1 = list(b.bytes(4))
            c2 = list(b.bytes(4))
            f = {'type': 'Bevel', 'shadowColor': c1, 'highlightColor': c2, 'blurX': b.fixed(), 'blurY': b.fixed(),
                 'angle': b.fixed(), 'distance': b.fixed(), 'strength': b.fixed8()}
            _shadow_common(b, f)
            f['onTop'] = b.ub(1)
            f['passes'] = b.ub(4)
        elif fid in (4, 7):
            nc = b.u8()
            cols = [list(b.bytes(4)) for _ in range(nc)]
            ratios = [b.u8() for _ in range(nc)]
            f = {'type': 'GradientGlow' if fid == 4 else 'GradientBevel', 'colors': cols, 'ratios': ratios,
                 'blurX': b.fixed(), 'blurY': b.fixed(), 'angle': b.fixed(), 'distance': b.fixed(),
                 'strength': b.fixed8()}
            _shadow_common(b, f)
            f['onTop'] = b.ub(1)
            f['passes'] = b.ub(4)
        elif fid == 5:
            mx = b.u8()
            my = b.u8()
            div = b.float32()
            bias = b.float32()
            m = [b.float32() for _ in range(mx * my)]
            col = list(b.bytes(4))
            b.ub(6)
            f = {'type': 'Convolution', 'matrixX': mx, 'matrixY': my, 'divisor': div, 'bias': bias, 'matrix': m,
                 'color': col, 'clamp': b.ub(1), 'preserveAlpha': b.ub(1)}
        elif fid == 6:
            f = {'type': 'ColorMatrix', 'matrix': [b.float32() for _ in range(20)]}
        else:
            raise ValueError('unknown filter %d' % fid)
        filters.append(f)
    return filters


def parse_place(code, data, pos, ln):
    b = Bits(data, pos)
    p = {'op': 'place'}
    if code == 4:
        p['id'] = b.u16()
        p['depth'] = b.u16()
        p['matrix'] = b.matrix()
        if b.pos < pos + ln:
            p['cxform'] = b.cxform(False)
        p['move'] = False
        return p
    flags = b.u8()
    flags2 = b.u8() if code == 70 else 0
    p['move'] = bool(flags & 0x01)
    p['depth'] = b.u16()
    if code == 70 and (flags2 & 0x08 or (flags2 & 0x10 and flags & 0x02)):
        p['className'] = b.string()
    if flags & 0x02:
        p['id'] = b.u16()
    if flags & 0x04:
        p['matrix'] = b.matrix()
    if flags & 0x08:
        p['cxform'] = b.cxform(True)
    if flags & 0x10:
        p['ratio'] = b.u16()
    if flags & 0x20:
        p['name'] = b.string()
    if flags & 0x40:
        p['clipDepth'] = b.u16()
    if code == 70:
        if flags2 & 0x01:
            p['filters'] = parse_filters(b)
        if flags2 & 0x02:
            p['blend'] = BLEND_MODES.get(b.u8(), 'normal')
        if flags2 & 0x04:
            p['cacheAsBitmap'] = b.u8()
        if flags2 & 0x20:
            p['visible'] = b.u8()
        if flags2 & 0x40:
            p['bgColor'] = list(b.bytes(4))
    if flags & 0x80:
        p['hasClipActions'] = True
    return p


def parse_timeline(data, tags):
    """Returns (frames, labels): frames is a list of op lists (one per frame), labels maps name -> 0-based frame."""
    frames = []
    cur = []
    labels = {}
    for code, pos, ln in tags:
        if code == 1:
            frames.append(cur)
            cur = []
        elif code in (4, 26, 70):
            cur.append(parse_place(code, data, pos, ln))
        elif code == 5:
            _, depth = struct.unpack_from('<HH', data, pos)
            cur.append({'op': 'remove', 'depth': depth})
        elif code == 28:
            depth = struct.unpack_from('<H', data, pos)[0]
            cur.append({'op': 'remove', 'depth': depth})
        elif code == 43:
            labels[Bits(data, pos).string()] = len(frames)
        elif code == 15:
            cur.append({'op': 'sound', 'id': struct.unpack_from('<H', data, pos)[0]})
    if cur:
        frames.append(cur)
    return frames, labels


class SWF:
    def __init__(self, path):
        raw = open(path, 'rb').read()
        sig = raw[:3]
        if sig == b'CWS':
            raw = raw[:8] + zlib.decompress(raw[8:])
        elif sig == b'ZWS':
            import lzma
            props = raw[12:17]
            filt = lzma._decode_filter_properties(lzma.FILTER_LZMA1, props)
            dec = lzma.LZMADecompressor(lzma.FORMAT_RAW, filters=[filt])
            raw = b'FWS' + raw[3:8] + dec.decompress(raw[17:])
        elif sig != b'FWS':
            raise ValueError('not a swf: %s' % path)
        self.data = raw
        self.version = raw[3]
        b = Bits(raw, 8)
        self.rect = b.rect()
        self.frame_rate = b.u16() / 256.0
        self.frame_count = b.u16()
        self.tags = read_tags(raw, b.pos, len(raw))
        self.chars = {}
        self.symbol_class = {}
        self.exports = {}
        self.scene_labels = None
        self.scaling_grids = {}
        self._index()

    def _index(self):
        d = self.data
        simple = {7: 'button', 34: 'button', 14: 'sound', 87: 'binary', 37: 'edittext',
                  10: 'font', 48: 'font', 75: 'font', 91: 'font'}
        for code, pos, ln in self.tags:
            entry = {'code': code, 'pos': pos, 'len': ln}
            if code in SHAPE_TAGS:
                cid = struct.unpack_from('<H', d, pos)[0]
                entry.update(type='shape', bounds=Bits(d, pos + 2).rect())
            elif code in MORPH_TAGS:
                cid = struct.unpack_from('<H', d, pos)[0]
                b = Bits(d, pos + 2)
                entry.update(type='morph', bounds=b.rect(), endBounds=b.rect())
            elif code == 39:
                cid, fc = struct.unpack_from('<HH', d, pos)
                entry.update(type='sprite', frameCount=fc, tags=read_tags(d, pos + 4, pos + ln))
            elif code in BITMAP_TAGS:
                cid = struct.unpack_from('<H', d, pos)[0]
                entry.update(type='bitmap')
            elif code in (11, 33):
                cid = struct.unpack_from('<H', d, pos)[0]
                b = Bits(d, pos + 2)
                entry.update(type='text', bounds=b.rect(), textMatrix=b.matrix())
            elif code in simple:
                cid = struct.unpack_from('<H', d, pos)[0]
                entry.update(type=simple[code])
            elif code in (76, 56):
                b = Bits(d, pos)
                for _ in range(b.u16()):
                    cid = b.u16()
                    (self.symbol_class if code == 76 else self.exports)[cid] = b.string()
                continue
            elif code == 78:
                cid = struct.unpack_from('<H', d, pos)[0]
                self.scaling_grids[cid] = Bits(d, pos + 2).rect()
                continue
            elif code == 86:
                self.scene_labels = self._scene_labels(Bits(d, pos))
                continue
            else:
                continue
            self.chars[cid] = entry

    @staticmethod
    def _scene_labels(b):
        def eu32():
            v = 0
            shift = 0
            while True:
                byte = b.u8()
                v |= (byte & 0x7f) << shift
                shift += 7
                if not byte & 0x80:
                    return v
        scenes = [(eu32(), b.string()) for _ in range(eu32())]
        labels = [(eu32(), b.string()) for _ in range(eu32())]
        return {'scenes': scenes, 'labels': labels}

    def timeline(self, cid=None):
        if cid is None:
            return parse_timeline(self.data, self.tags)
        return parse_timeline(self.data, self.chars[cid]['tags'])
