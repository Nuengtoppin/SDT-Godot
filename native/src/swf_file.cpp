// SWF reading and shape rasterisation for runtime mod conversion. Ports tools/swfconv (swfparse.py, shapes.py) and
// replaces FFDec's renderer with an exact-area anti-aliased scanline rasteriser.

#include "swf_file.h"

#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include <algorithm>
#include <cmath>
#include <cstring>
#include <functional>

using namespace godot;

namespace swf {

// ------------------------------------------------------------------------------------------------ bit reader

struct Bits {
	const uint8_t *d;
	size_t size;
	size_t pos;
	int bitpos = 0;
	bool overflow = false;

	Bits(const uint8_t *p_d, size_t p_size, size_t p_pos) :
			d(p_d), size(p_size), pos(p_pos) {}

	void align() {
		if (bitpos) {
			bitpos = 0;
			pos++;
		}
	}
	uint32_t ub(int n) {
		uint32_t v = 0;
		for (int i = 0; i < n; i++) {
			if (pos >= size) {
				overflow = true;
				return v;
			}
			uint32_t bit = (d[pos] >> (7 - bitpos)) & 1;
			v = (v << 1) | bit;
			if (++bitpos == 8) {
				bitpos = 0;
				pos++;
			}
		}
		return v;
	}
	int32_t sb(int n) {
		if (n == 0) {
			return 0;
		}
		uint32_t v = ub(n);
		if (v & (1u << (n - 1))) {
			return (int32_t)(v | (~0u << n));
		}
		return (int32_t)v;
	}
	double fb(int n) { return sb(n) / 65536.0; }
	uint8_t u8() {
		align();
		if (pos >= size) {
			overflow = true;
			return 0;
		}
		return d[pos++];
	}
	uint16_t u16() {
		uint16_t lo = u8();
		uint16_t hi = u8();
		return lo | (hi << 8);
	}
	int16_t s16() { return (int16_t)u16(); }
	uint32_t u32() {
		uint32_t v = u16();
		return v | ((uint32_t)u16() << 16);
	}
	double fixed8() { return s16() / 256.0; }
	double fixed() { return (int32_t)u32() / 65536.0; }
	float float32() {
		uint32_t v = u32();
		float f;
		memcpy(&f, &v, 4);
		return f;
	}
	String string() {
		align();
		size_t e = pos;
		while (e < size && d[e] != 0) {
			e++;
		}
		String s = String::utf8((const char *)d + pos, (int)(e - pos));
		pos = std::min(e + 1, size);
		return s;
	}
	void rect(int32_t r[4]) {
		align();
		int n = ub(5);
		for (int i = 0; i < 4; i++) {
			r[i] = sb(n);
		}
		align();
	}
	// [a, b, c, d, tx, ty] with tx/ty in twips
	void matrix(double m[6]) {
		align();
		m[0] = m[3] = 1.0;
		m[1] = m[2] = 0.0;
		if (ub(1)) {
			int n = ub(5);
			m[0] = fb(n);
			m[3] = fb(n);
		}
		if (ub(1)) {
			int n = ub(5);
			m[1] = fb(n);
			m[2] = fb(n);
		}
		int n = ub(5);
		m[4] = sb(n);
		m[5] = sb(n);
		align();
	}
	// [rMult, gMult, bMult, aMult, rAdd, gAdd, bAdd, aAdd] (multipliers as fractions)
	Array cxform(bool alpha) {
		align();
		bool has_add = ub(1);
		bool has_mult = ub(1);
		int n = ub(4);
		int mult[4] = { 256, 256, 256, 256 };
		int add[4] = { 0, 0, 0, 0 };
		int cnt = alpha ? 4 : 3;
		if (has_mult) {
			for (int i = 0; i < cnt; i++) {
				mult[i] = sb(n);
			}
		}
		if (has_add) {
			for (int i = 0; i < cnt; i++) {
				add[i] = sb(n);
			}
		}
		align();
		Array a;
		for (int i = 0; i < 4; i++) {
			a.push_back(mult[i] / 256.0);
		}
		for (int i = 0; i < 4; i++) {
			a.push_back(add[i]);
		}
		return a;
	}
};

std::vector<Tag> read_tags(const uint8_t *d, size_t size, size_t pos, size_t end) {
	std::vector<Tag> out;
	while (pos + 2 <= end) {
		uint16_t cl = d[pos] | (d[pos + 1] << 8);
		pos += 2;
		int code = cl >> 6;
		size_t ln = cl & 0x3f;
		if (ln == 0x3f) {
			if (pos + 4 > end) {
				break;
			}
			ln = d[pos] | (d[pos + 1] << 8) | (d[pos + 2] << 16) | ((size_t)d[pos + 3] << 24);
			pos += 4;
		}
		if (pos + ln > size) {
			break;
		}
		out.push_back({ code, pos, ln });
		pos += ln;
		if (code == 0) {
			break;
		}
	}
	return out;
}

// ------------------------------------------------------------------------------------------------ shapes

struct RGBA {
	uint8_t r = 0, g = 0, b = 0, a = 255;
};

struct GradRec {
	int ratio;
	RGBA c;
};

struct Fill {
	int type = 0;
	RGBA color;
	double m[6] = { 1, 0, 0, 1, 0, 0 };
	int spread = 0, interp = 0;
	std::vector<GradRec> recs;
	double focal = 0; // -1..1
	int bitmap = 0;
};

struct LineStyle {
	int width = 0;
	int start_cap = 0, end_cap = 0, join = 0; // caps: 0 round, 1 none, 2 square; join: 0 round, 1 bevel, 2 miter
	double miter = 3.0;
	bool no_close = false;
	bool has_fill = false;
	RGBA color;
	Fill fill;
};

struct Rec {
	enum Type { STYLE, LINE, CURVE } type = LINE;
	// STYLE
	bool has_move = false;
	int32_t mx = 0, my = 0;
	int fill0 = -1, fill1 = -1, line = -1; // -1 = unchanged
	bool new_styles = false;
	std::vector<Fill> fills;
	std::vector<LineStyle> lines;
	// LINE / CURVE (absolute twips)
	int32_t cx = 0, cy = 0, x = 0, y = 0;
};

struct Shape {
	int32_t bounds[4] = { 0, 0, 0, 0 }; // xmin, xmax, ymin, ymax
	std::vector<Fill> fills;
	std::vector<LineStyle> lines;
	std::vector<Rec> recs;
};

RGBA read_rgb(Bits &b, bool alpha) {
	RGBA c;
	c.r = b.u8();
	c.g = b.u8();
	c.b = b.u8();
	c.a = alpha ? b.u8() : 255;
	return c;
}

void read_fill(Bits &b, int ver, Fill &f) {
	bool alpha = ver >= 3;
	f.type = b.u8();
	if (f.type == 0x00) {
		f.color = read_rgb(b, alpha);
	} else if (f.type == 0x10 || f.type == 0x12 || f.type == 0x13) {
		b.matrix(f.m);
		b.align();
		f.spread = b.ub(2);
		f.interp = b.ub(2);
		int n = b.ub(4);
		for (int i = 0; i < n; i++) {
			GradRec r;
			r.ratio = b.u8();
			r.c = read_rgb(b, alpha);
			f.recs.push_back(r);
		}
		if (f.type == 0x13) {
			f.focal = b.s16() / 256.0;
		}
	} else if (f.type >= 0x40 && f.type <= 0x43) {
		f.bitmap = b.u16();
		b.matrix(f.m);
	} else {
		b.overflow = true;
	}
}

void read_fills(Bits &b, int ver, std::vector<Fill> &out) {
	int n = b.u8();
	if (n == 0xff && ver >= 2) {
		n = b.u16();
	}
	for (int i = 0; i < n && !b.overflow; i++) {
		Fill f;
		read_fill(b, ver, f);
		out.push_back(f);
	}
}

void read_line(Bits &b, int ver, LineStyle &l) {
	l.width = b.u16();
	if (ver == 4) {
		l.start_cap = b.ub(2);
		l.join = b.ub(2);
		bool has_fill = b.ub(1);
		b.ub(3); // noHScale, noVScale, pixelHinting
		b.ub(5);
		l.no_close = b.ub(1);
		l.end_cap = b.ub(2);
		if (l.join == 2) {
			l.miter = b.u16() / 256.0;
		}
		if (has_fill) {
			l.has_fill = true;
			read_fill(b, 4, l.fill);
		} else {
			l.color = read_rgb(b, true);
		}
	} else {
		l.color = read_rgb(b, ver >= 3);
	}
}

void read_lines(Bits &b, int ver, std::vector<LineStyle> &out) {
	int n = b.u8();
	if (n == 0xff && ver >= 2) {
		n = b.u16();
	}
	for (int i = 0; i < n && !b.overflow; i++) {
		LineStyle l;
		read_line(b, ver, l);
		out.push_back(l);
	}
}

void read_records(Bits &b, int ver, int fill_bits, int line_bits, std::vector<Rec> &out) {
	int32_t x = 0, y = 0;
	while (!b.overflow) {
		if (b.ub(1) == 0) {
			bool new_styles = b.ub(1);
			bool ch_line = b.ub(1);
			bool ch_f1 = b.ub(1);
			bool ch_f0 = b.ub(1);
			bool move = b.ub(1);
			if (!(new_styles || ch_line || ch_f1 || ch_f0 || move)) {
				break;
			}
			Rec r;
			r.type = Rec::STYLE;
			if (move) {
				int n = b.ub(5);
				x = b.sb(n);
				y = b.sb(n);
				r.has_move = true;
				r.mx = x;
				r.my = y;
			}
			if (ch_f0) {
				r.fill0 = b.ub(fill_bits);
			}
			if (ch_f1) {
				r.fill1 = b.ub(fill_bits);
			}
			if (ch_line) {
				r.line = b.ub(line_bits);
			}
			if (new_styles && ver >= 2) {
				r.new_styles = true;
				read_fills(b, ver, r.fills);
				read_lines(b, ver, r.lines);
				b.align();
				fill_bits = b.ub(4);
				line_bits = b.ub(4);
			}
			out.push_back(std::move(r));
		} else if (b.ub(1)) {
			int n = b.ub(4) + 2;
			if (b.ub(1)) {
				x += b.sb(n);
				y += b.sb(n);
			} else if (b.ub(1)) {
				y += b.sb(n);
			} else {
				x += b.sb(n);
			}
			Rec r;
			r.type = Rec::LINE;
			r.x = x;
			r.y = y;
			out.push_back(r);
		} else {
			int n = b.ub(4) + 2;
			Rec r;
			r.type = Rec::CURVE;
			r.cx = x + b.sb(n);
			r.cy = y + b.sb(n);
			x = r.cx + b.sb(n);
			y = r.cy + b.sb(n);
			r.x = x;
			r.y = y;
			out.push_back(r);
		}
	}
}

bool read_shape(const uint8_t *d, size_t size, size_t pos, int code, Shape &s) {
	int ver = code == 2 ? 1 : code == 22 ? 2 : code == 32 ? 3 : 4;
	Bits b(d, size, pos);
	b.u16();
	b.rect(s.bounds);
	if (ver == 4) {
		int32_t eb[4];
		b.rect(eb);
		b.ub(8);
	}
	read_fills(b, ver, s.fills);
	read_lines(b, ver, s.lines);
	b.align();
	int fb = b.ub(4), lb = b.ub(4);
	read_records(b, ver, fb, lb, s.recs);
	return !b.overflow || !s.recs.empty();
}

// ---- morph shapes

struct MorphFill {
	Fill a, b;
};
struct MorphLine {
	LineStyle a, b;
};
struct Morph {
	int32_t bounds[2][4];
	std::vector<MorphFill> fills;
	std::vector<MorphLine> lines;
	std::vector<Rec> start, end;
};

void read_morph_fill(Bits &b, MorphFill &f) {
	int t = b.u8();
	f.a.type = f.b.type = t;
	if (t == 0x00) {
		f.a.color = read_rgb(b, true);
		f.b.color = read_rgb(b, true);
	} else if (t == 0x10 || t == 0x12 || t == 0x13) {
		b.matrix(f.a.m);
		b.matrix(f.b.m);
		b.align();
		f.a.spread = f.b.spread = b.ub(2);
		f.a.interp = f.b.interp = b.ub(2);
		int n = b.ub(4);
		for (int i = 0; i < n; i++) {
			GradRec r0, r1;
			r0.ratio = b.u8();
			r0.c = read_rgb(b, true);
			r1.ratio = b.u8();
			r1.c = read_rgb(b, true);
			f.a.recs.push_back(r0);
			f.b.recs.push_back(r1);
		}
		if (t == 0x13) {
			f.a.focal = b.s16() / 256.0;
			f.b.focal = b.s16() / 256.0;
		}
	} else if (t >= 0x40 && t <= 0x43) {
		f.a.bitmap = f.b.bitmap = b.u16();
		b.matrix(f.a.m);
		b.matrix(f.b.m);
	} else {
		b.overflow = true;
	}
}

void read_morph_line(Bits &b, int ver, MorphLine &l) {
	l.a.width = b.u16();
	l.b.width = b.u16();
	if (ver == 2) {
		int sc = b.ub(2), jn = b.ub(2);
		bool has_fill = b.ub(1);
		b.ub(3);
		b.ub(5);
		bool nc = b.ub(1);
		int ec = b.ub(2);
		double miter = 3.0;
		if (jn == 2) {
			miter = b.u16() / 256.0;
		}
		for (LineStyle *x : { &l.a, &l.b }) {
			x->start_cap = sc;
			x->join = jn;
			x->no_close = nc;
			x->end_cap = ec;
			x->miter = miter;
		}
		if (has_fill) {
			MorphFill mf;
			read_morph_fill(b, mf);
			l.a.has_fill = l.b.has_fill = true;
			l.a.fill = mf.a;
			l.b.fill = mf.b;
		} else {
			l.a.color = read_rgb(b, true);
			l.b.color = read_rgb(b, true);
		}
	} else {
		l.a.color = read_rgb(b, true);
		l.b.color = read_rgb(b, true);
	}
}

bool read_morph(const uint8_t *d, size_t size, size_t pos, int code, Morph &m) {
	int ver = code == 46 ? 1 : 2;
	Bits b(d, size, pos);
	b.u16();
	b.rect(m.bounds[0]);
	b.rect(m.bounds[1]);
	if (ver == 2) {
		int32_t eb[4];
		b.rect(eb);
		b.rect(eb);
		b.ub(8);
	}
	uint32_t offset = b.u32();
	size_t end_pos = b.pos + offset;
	int n = b.u8();
	if (n == 0xff) {
		n = b.u16();
	}
	for (int i = 0; i < n && !b.overflow; i++) {
		MorphFill f;
		read_morph_fill(b, f);
		m.fills.push_back(f);
	}
	n = b.u8();
	if (n == 0xff) {
		n = b.u16();
	}
	for (int i = 0; i < n && !b.overflow; i++) {
		MorphLine l;
		read_morph_line(b, ver, l);
		m.lines.push_back(l);
	}
	b.align();
	int fb = b.ub(4), lb = b.ub(4);
	read_records(b, 4, fb, lb, m.start);
	if (end_pos >= size) {
		return false;
	}
	Bits e(d, size, end_pos);
	fb = e.ub(4);
	lb = e.ub(4);
	read_records(e, 4, fb, lb, m.end);
	return true;
}

double lerp(double a, double b, double t) { return a + (b - a) * t; }
int32_t lerpi(double a, double b, double t) { return (int32_t)std::lround(lerp(a, b, t)); }
RGBA lerp_color(RGBA a, RGBA b, double t) {
	RGBA c;
	c.r = (uint8_t)lerpi(a.r, b.r, t);
	c.g = (uint8_t)lerpi(a.g, b.g, t);
	c.b = (uint8_t)lerpi(a.b, b.b, t);
	c.a = (uint8_t)lerpi(a.a, b.a, t);
	return c;
}
void lerp_matrix(const double *a, const double *b, double t, double *out) {
	for (int i = 0; i < 4; i++) {
		out[i] = lerp(a[i], b[i], t);
	}
	out[4] = lerpi(a[4], b[4], t);
	out[5] = lerpi(a[5], b[5], t);
}
Fill lerp_fill(const Fill &a, const Fill &b, double t) {
	Fill f = a;
	if (a.type == 0x00) {
		f.color = lerp_color(a.color, b.color, t);
	} else {
		lerp_matrix(a.m, b.m, t, f.m);
		for (size_t i = 0; i < f.recs.size() && i < b.recs.size(); i++) {
			f.recs[i].ratio = lerpi(a.recs[i].ratio, b.recs[i].ratio, t);
			f.recs[i].c = lerp_color(a.recs[i].c, b.recs[i].c, t);
		}
		f.focal = lerp(a.focal, b.focal, t);
	}
	return f;
}

// Absolute curve form of a record: (cx, cy, x, y)
void as_curve(const Rec &r, double px, double py, double out[4]) {
	if (r.type == Rec::CURVE) {
		out[0] = r.cx;
		out[1] = r.cy;
	} else {
		out[0] = (px + r.x) / 2.0;
		out[1] = (py + r.y) / 2.0;
	}
	out[2] = r.x;
	out[3] = r.y;
}

// shapes.morph_at
void morph_at(const Morph &m, int ratio, Shape &s) {
	double t = ratio / 65535.0;
	for (const MorphFill &f : m.fills) {
		s.fills.push_back(lerp_fill(f.a, f.b, t));
	}
	for (const MorphLine &l : m.lines) {
		LineStyle o = l.a;
		o.width = lerpi(l.a.width, l.b.width, t);
		if (l.a.has_fill) {
			o.fill = lerp_fill(l.a.fill, l.b.fill, t);
		} else {
			o.color = lerp_color(l.a.color, l.b.color, t);
		}
		s.lines.push_back(o);
	}
	const std::vector<Rec> &end = m.end;
	size_t ei = 0;
	double sx = 0, sy = 0, ex = 0, ey = 0;
	for (const Rec &r : m.start) {
		if (r.type == Rec::STYLE) {
			Rec st = r;
			if (r.has_move) {
				while (ei < end.size() && end[ei].type != Rec::STYLE) {
					ei++;
				}
				double emx, emy;
				if (ei < end.size()) {
					if (end[ei].has_move) {
						emx = end[ei].mx;
						emy = end[ei].my;
					} else {
						emx = ex;
						emy = ey;
					}
					ei++;
				} else {
					emx = r.mx;
					emy = r.my;
				}
				sx = r.mx;
				sy = r.my;
				ex = emx;
				ey = emy;
				st.mx = lerpi(sx, ex, t);
				st.my = lerpi(sy, ey, t);
			}
			s.recs.push_back(std::move(st));
			continue;
		}
		while (ei < end.size() && end[ei].type == Rec::STYLE) {
			if (end[ei].has_move) {
				ex = end[ei].mx;
				ey = end[ei].my;
			}
			ei++;
		}
		Rec e;
		if (ei < end.size()) {
			e = end[ei];
		} else {
			e.type = Rec::LINE;
			e.x = (int32_t)ex;
			e.y = (int32_t)ey;
		}
		ei++;
		double a[4], bb[4];
		as_curve(r, sx, sy, a);
		as_curve(e, ex, ey, bb);
		sx = r.x;
		sy = r.y;
		ex = e.x;
		ey = e.y;
		Rec o;
		if (r.type == Rec::LINE && e.type == Rec::LINE) {
			o.type = Rec::LINE;
			o.x = lerpi(a[2], bb[2], t);
			o.y = lerpi(a[3], bb[3], t);
		} else {
			o.type = Rec::CURVE;
			o.cx = lerpi(a[0], bb[0], t);
			o.cy = lerpi(a[1], bb[1], t);
			o.x = lerpi(a[2], bb[2], t);
			o.y = lerpi(a[3], bb[3], t);
		}
		s.recs.push_back(o);
	}
	for (int i = 0; i < 4; i++) {
		s.bounds[i] = lerpi(m.bounds[0][i], m.bounds[1][i], t);
	}
}

// ---- fonts & static text

struct Font {
	std::vector<std::vector<Rec>> glyphs;
	double em = 1024.0;
};

bool read_font(const uint8_t *d, size_t size, size_t pos, int code, Font &f) {
	Bits b(d, size, pos);
	b.u16();
	b.ub(4);
	bool wide_offsets = b.ub(1);
	bool wide_codes = b.ub(1);
	b.ub(2);
	b.u8();
	int name_len = b.u8();
	b.pos += name_len;
	int n = b.u16();
	size_t table = b.pos;
	f.em = code == 75 ? 20480.0 : 1024.0;
	auto off = [&](int i) -> size_t {
		size_t p = table + (size_t)i * (wide_offsets ? 4 : 2);
		if (p + (wide_offsets ? 4 : 2) > size) {
			return 0;
		}
		return wide_offsets ? (d[p] | (d[p + 1] << 8) | (d[p + 2] << 16) | ((size_t)d[p + 3] << 24)) : (d[p] | (d[p + 1] << 8));
	};
	for (int i = 0; i < n; i++) {
		Bits gb(d, size, table + off(i));
		int fbits = gb.ub(4), lbits = gb.ub(4);
		std::vector<Rec> recs;
		read_records(gb, 1, fbits, lbits, recs);
		f.glyphs.push_back(std::move(recs));
	}
	(void)wide_codes;
	return true;
}

// shapes.read_text + text_to_shape
bool text_shape(const uint8_t *d, size_t size, size_t pos, int code, const std::function<std::shared_ptr<Font>(int)> &fonts,
		Shape &s) {
	Bits b(d, size, pos);
	b.u16();
	int32_t bounds[4];
	b.rect(bounds);
	double m[6];
	b.matrix(m);
	int gbits = b.u8(), abits = b.u8();
	bool alpha = code == 33;
	int font = -1;
	RGBA color;
	color.r = color.g = color.b = 0;
	int32_t x = 0, y = 0;
	int height = 0;
	std::vector<std::pair<RGBA, int>> color_index;
	bool any = false;
	int32_t lo[2] = { INT32_MAX, INT32_MAX }, hi[2] = { INT32_MIN, INT32_MIN };
	auto xf = [&](double px, double py, int32_t &ox, int32_t &oy) {
		ox = (int32_t)std::lround(m[0] * px + m[2] * py + m[4]);
		oy = (int32_t)std::lround(m[1] * px + m[3] * py + m[5]);
		lo[0] = std::min(lo[0], ox);
		lo[1] = std::min(lo[1], oy);
		hi[0] = std::max(hi[0], ox);
		hi[1] = std::max(hi[1], oy);
		any = true;
	};
	while (!b.overflow) {
		int flags = b.u8();
		if (flags == 0) {
			break;
		}
		if (flags & 0x08) {
			font = b.u16();
		}
		if (flags & 0x04) {
			color = read_rgb(b, alpha);
		}
		if (flags & 0x01) {
			x = b.s16();
		}
		if (flags & 0x02) {
			y = b.s16();
		}
		if (flags & 0x08) {
			height = b.u16();
		}
		int n = b.u8();
		std::shared_ptr<Font> f = fonts(font);
		int fi = 0;
		if (f) {
			for (size_t k = 0; k < color_index.size(); k++) {
				RGBA c = color_index[k].first;
				if (c.r == color.r && c.g == color.g && c.b == color.b && c.a == color.a) {
					fi = color_index[k].second;
				}
			}
			if (fi == 0) {
				Fill fl;
				fl.color = color;
				s.fills.push_back(fl);
				fi = (int)s.fills.size();
				color_index.push_back({ color, fi });
			}
		}
		double scale = f ? height / f->em : 0;
		for (int i = 0; i < n; i++) {
			int gi = b.ub(gbits);
			int adv = b.sb(abits);
			if (f && gi < (int)f->glyphs.size()) {
				for (const Rec &r : f->glyphs[gi]) {
					Rec o;
					o.type = r.type;
					if (r.type == Rec::STYLE) {
						if (r.has_move) {
							o.has_move = true;
							xf(x + r.mx * scale, y + r.my * scale, o.mx, o.my);
						}
						if (r.fill0 >= 0) {
							o.fill0 = r.fill0 ? fi : 0;
						}
						if (r.fill1 >= 0) {
							o.fill1 = r.fill1 ? fi : 0;
						}
						if (r.line >= 0) {
							o.line = 0;
						}
					} else if (r.type == Rec::LINE) {
						xf(x + r.x * scale, y + r.y * scale, o.x, o.y);
					} else {
						xf(x + r.cx * scale, y + r.cy * scale, o.cx, o.cy);
						xf(x + r.x * scale, y + r.y * scale, o.x, o.y);
					}
					s.recs.push_back(o);
				}
			}
			x += adv;
		}
		b.align();
	}
	if (!any) {
		return false;
	}
	s.bounds[0] = lo[0] - 20;
	s.bounds[1] = hi[0] + 20;
	s.bounds[2] = lo[1] - 20;
	s.bounds[3] = hi[1] + 20;
	return true;
}

// ------------------------------------------------------------------------------------------------ rasteriser

struct P {
	double x, y;
};

// Exact-area coverage accumulation (as in font rasterisers): edges add signed area / cover to an accumulation
// buffer; a running sum per row gives the coverage of each pixel. Regions must have consistent orientation.
struct Accum {
	int w, h;
	std::vector<float> a;
	int y_min, y_max; // touched rows
	Accum(int p_w, int p_h) :
			w(p_w), h(p_h), a((size_t)(p_w + 2) * p_h, 0.0f), y_min(p_h), y_max(-1) {}
	void clear() {
		if (y_max >= y_min) {
			std::fill(a.begin() + (size_t)y_min * (w + 2), a.begin() + (size_t)(y_max + 1) * (w + 2), 0.0f);
		}
		y_min = h;
		y_max = -1;
	}
	void line(P p0, P p1) {
		if (std::abs(p0.y - p1.y) < 1e-9) {
			return;
		}
		double dir = 1.0;
		if (p0.y > p1.y) {
			std::swap(p0, p1);
			dir = -1.0;
		}
		// clamp x into the buffer (contributions left of the image affect the whole row, right of it nothing)
		p0.x = std::clamp(p0.x, 0.0, (double)w);
		p1.x = std::clamp(p1.x, 0.0, (double)w);
		double dxdy = (p1.x - p0.x) / (p1.y - p0.y);
		double x = p0.x;
		int y0 = (int)std::max(0.0, std::floor(p0.y));
		if (p0.y < 0.0) {
			x -= p0.y * dxdy;
		}
		int y1 = std::min(h, (int)std::ceil(p1.y));
		if (y0 < y1) {
			y_min = std::min(y_min, y0);
			y_max = std::max(y_max, y1 - 1);
		}
		for (int y = y0; y < y1; y++) {
			float *row = a.data() + (size_t)y * (w + 2);
			double dy = std::min((double)(y + 1), p1.y) - std::max((double)y, p0.y);
			double xnext = x + dxdy * dy;
			// floating-point drift must never leave the row (writes at -1 / past w + 1 would corrupt memory)
			x = std::clamp(x, 0.0, (double)w);
			xnext = std::clamp(xnext, 0.0, (double)w);
			double d = dy * dir;
			double xa = std::min(x, xnext), xb = std::max(x, xnext);
			double xa_floor = std::floor(xa);
			int xai = (int)xa_floor;
			double xb_ceil = std::ceil(xb);
			int xbi = (int)xb_ceil;
			if (xbi <= xai + 1) {
				double xmf = 0.5 * (x + xnext) - xa_floor;
				row[xai] += (float)(d - d * xmf);
				row[xai + 1] += (float)(d * xmf);
			} else {
				double s = 1.0 / (xb - xa);
				double x0f = xa - xa_floor;
				double a0 = 0.5 * s * (1.0 - x0f) * (1.0 - x0f);
				double x1f = xb - xb_ceil + 1.0;
				double am = 0.5 * s * x1f * x1f;
				row[xai] += (float)(d * a0);
				if (xbi == xai + 2) {
					row[xai + 1] += (float)(d * (1.0 - a0 - am));
				} else {
					double a1 = s * (1.5 - x0f);
					row[xai + 1] += (float)(d * (a1 - a0));
					for (int xi = xai + 2; xi < xbi - 1; xi++) {
						row[xi] += (float)(d * s);
					}
					double a2 = a1 + (xbi - xai - 3) * s;
					row[xbi - 1] += (float)(d * (1.0 - a2 - am));
				}
				row[xbi] += (float)(d * am);
			}
			x = xnext;
		}
	}
	void polygon(const std::vector<P> &pts) {
		size_t n = pts.size();
		for (size_t i = 0; i < n; i++) {
			line(pts[i], pts[(i + 1) % n]);
		}
	}
};

struct Paint {
	// premultiplied colour lookup for gradients / solid colours, bitmap sampler otherwise
	int kind = 0; // 0 solid, 1 linear, 2 radial, 3 focal, 4 bitmap
	float solid[4];
	float lut[256][4];
	double inv[6]; // shape twips -> gradient / bitmap space
	int spread = 0;
	double focal = 0;
	Ref<Image> bmp;
	const uint8_t *bmp_data = nullptr;
	int bw = 0, bh = 0;
	bool repeat = false, smooth = true;
};

void invert(const double m[6], double out[6]) {
	double det = m[0] * m[3] - m[1] * m[2];
	if (std::abs(det) < 1e-12) {
		det = det < 0 ? -1e-12 : 1e-12;
	}
	out[0] = m[3] / det;
	out[1] = -m[1] / det;
	out[2] = -m[2] / det;
	out[3] = m[0] / det;
	out[4] = -(out[0] * m[4] + out[2] * m[5]);
	out[5] = -(out[1] * m[4] + out[3] * m[5]);
}

double srgb_to_linear(double c) { return c <= 0.04045 ? c / 12.92 : std::pow((c + 0.055) / 1.055, 2.4); }
double linear_to_srgb(double c) { return c <= 0.0031308 ? c * 12.92 : 1.055 * std::pow(c, 1.0 / 2.4) - 0.055; }

void make_paint(const Fill &f, Paint &p, const std::function<Ref<Image>(int)> &bitmaps) {
	if (f.type == 0x00) {
		p.kind = 0;
		float a = f.color.a / 255.0f;
		p.solid[0] = f.color.r / 255.0f * a;
		p.solid[1] = f.color.g / 255.0f * a;
		p.solid[2] = f.color.b / 255.0f * a;
		p.solid[3] = a;
		return;
	}
	if (f.type >= 0x40) {
		p.kind = 4;
		p.repeat = f.type == 0x40 || f.type == 0x42;
		p.smooth = f.type == 0x40 || f.type == 0x41;
		p.bmp = bitmaps(f.bitmap);
		invert(f.m, p.inv);
		if (p.bmp.is_valid() && !p.bmp->is_empty()) {
			p.bw = p.bmp->get_width();
			p.bh = p.bmp->get_height();
		} else {
			p.kind = 0;
			p.solid[0] = p.solid[1] = p.solid[2] = p.solid[3] = 0;
		}
		return;
	}
	p.kind = f.type == 0x10 ? 1 : f.type == 0x12 ? 2 : 3;
	p.spread = f.spread;
	p.focal = std::clamp(f.focal, -0.98, 0.98);
	invert(f.m, p.inv);
	// 256-entry ramp, interpolated in sRGB or linear RGB, non-premultiplied, then premultiplied
	const std::vector<GradRec> &r = f.recs;
	for (int i = 0; i < 256; i++) {
		double c[4];
		if (r.empty()) {
			c[0] = c[1] = c[2] = c[3] = 0;
		} else if (i <= r.front().ratio) {
			RGBA k = r.front().c;
			c[0] = k.r / 255.0;
			c[1] = k.g / 255.0;
			c[2] = k.b / 255.0;
			c[3] = k.a / 255.0;
		} else if (i >= r.back().ratio) {
			RGBA k = r.back().c;
			c[0] = k.r / 255.0;
			c[1] = k.g / 255.0;
			c[2] = k.b / 255.0;
			c[3] = k.a / 255.0;
		} else {
			size_t k = 1;
			while (k < r.size() && r[k].ratio < i) {
				k++;
			}
			const GradRec &g0 = r[k - 1], &g1 = r[k];
			double t = g1.ratio == g0.ratio ? 0.0 : (double)(i - g0.ratio) / (g1.ratio - g0.ratio);
			double a0[3] = { g0.c.r / 255.0, g0.c.g / 255.0, g0.c.b / 255.0 };
			double a1[3] = { g1.c.r / 255.0, g1.c.g / 255.0, g1.c.b / 255.0 };
			for (int ch = 0; ch < 3; ch++) {
				if (f.interp == 1) {
					c[ch] = linear_to_srgb(lerp(srgb_to_linear(a0[ch]), srgb_to_linear(a1[ch]), t));
				} else {
					c[ch] = lerp(a0[ch], a1[ch], t);
				}
			}
			c[3] = lerp(g0.c.a / 255.0, g1.c.a / 255.0, t);
		}
		p.lut[i][0] = (float)(c[0] * c[3]);
		p.lut[i][1] = (float)(c[1] * c[3]);
		p.lut[i][2] = (float)(c[2] * c[3]);
		p.lut[i][3] = (float)c[3];
	}
}

inline void sample_bitmap(const Paint &p, const uint8_t *px, double u, double v, float out[4]) {
	auto fetch = [&](int x, int y, float c[4]) {
		if (p.repeat) {
			x = ((x % p.bw) + p.bw) % p.bw;
			y = ((y % p.bh) + p.bh) % p.bh;
		} else {
			x = std::clamp(x, 0, p.bw - 1);
			y = std::clamp(y, 0, p.bh - 1);
		}
		const uint8_t *q = px + ((size_t)y * p.bw + x) * 4;
		float a = q[3] / 255.0f;
		c[0] = q[0] / 255.0f * a;
		c[1] = q[1] / 255.0f * a;
		c[2] = q[2] / 255.0f * a;
		c[3] = a;
	};
	if (!p.smooth) {
		fetch((int)std::floor(u), (int)std::floor(v), out);
		return;
	}
	double fu = u - 0.5, fv = v - 0.5;
	int x0 = (int)std::floor(fu), y0 = (int)std::floor(fv);
	float tx = (float)(fu - x0), ty = (float)(fv - y0);
	float c00[4], c10[4], c01[4], c11[4];
	fetch(x0, y0, c00);
	fetch(x0 + 1, y0, c10);
	fetch(x0, y0 + 1, c01);
	fetch(x0 + 1, y0 + 1, c11);
	for (int i = 0; i < 4; i++) {
		out[i] = (c00[i] * (1 - tx) + c10[i] * tx) * (1 - ty) + (c01[i] * (1 - tx) + c11[i] * tx) * ty;
	}
}

inline void paint_at(const Paint &p, const uint8_t *bmp, double sx, double sy, float out[4]) {
	if (p.kind == 0) {
		memcpy(out, p.solid, sizeof(float) * 4);
		return;
	}
	double gx = p.inv[0] * sx + p.inv[2] * sy + p.inv[4];
	double gy = p.inv[1] * sx + p.inv[3] * sy + p.inv[5];
	if (p.kind == 4) {
		sample_bitmap(p, bmp, gx, gy, out);
		return;
	}
	double t;
	if (p.kind == 1) {
		t = (gx + 16384.0) / 32768.0;
	} else if (p.kind == 2) {
		t = std::sqrt(gx * gx + gy * gy) / 16384.0;
	} else {
		// focal radial gradient: unit circle, focal point at (focal, 0)
		double x = gx / 16384.0, y = gy / 16384.0, f = p.focal;
		double dx = x - f, dy = y;
		double len = std::sqrt(dx * dx + dy * dy);
		if (len < 1e-9) {
			t = 0;
		} else {
			double ux = dx / len;
			double b = f * ux;
			double s = -b + std::sqrt(std::max(0.0, b * b - (f * f - 1.0)));
			t = len / std::max(s, 1e-9);
		}
	}
	if (p.spread == 1) { // reflect
		t = std::fmod(std::abs(t), 2.0);
		if (t > 1.0) {
			t = 2.0 - t;
		}
	} else if (p.spread == 2) { // repeat
		t = t - std::floor(t);
	}
	int i = std::clamp((int)(t * 255.0 + 0.5), 0, 255);
	memcpy(out, p.lut[i], sizeof(float) * 4);
}

struct Raster {
	int w, h;
	double scale;
	double ox, oy; // twips at pixel 0,0
	std::vector<float> img; // premultiplied RGBA
	std::vector<float> geo; // union coverage of all geometry (for hit masks)
	std::vector<float> layer; // fills of one style group, summed (they never overlap)
	std::vector<float> layer_geo;
	int layer_y0, layer_y1;
	Accum acc;
	Raster(int p_w, int p_h, double p_scale, double p_ox, double p_oy) :
			w(p_w), h(p_h), scale(p_scale), ox(p_ox), oy(p_oy), img((size_t)p_w * p_h * 4, 0.0f), geo((size_t)p_w * p_h, 0.0f),
			layer((size_t)p_w * p_h * 4, 0.0f), layer_geo((size_t)p_w * p_h, 0.0f), layer_y0(p_h), layer_y1(-1), acc(p_w, p_h) {}

	P px(double tx, double ty) const { return { (tx - ox) / 20.0 * scale, (ty - oy) / 20.0 * scale }; }

	// Adds the accumulated coverage x paint to the group layer: adjacent fills of a shape share edges, and adding their
	// partial coverages (instead of compositing each over the other) avoids seams along those edges.
	void fill_layer(const Paint &p) {
		PackedByteArray keep;
		const uint8_t *bmp = nullptr;
		if (p.bmp.is_valid()) {
			keep = p.bmp->get_data();
			bmp = keep.ptr();
		}
		for (int y = acc.y_min; y <= acc.y_max; y++) {
			float *row = acc.a.data() + (size_t)y * (w + 2);
			float s = 0;
			for (int x = 0; x < w; x++) {
				s += row[x];
				float cov = std::min(1.0f, std::abs(s));
				if (cov <= 1e-4f) {
					continue;
				}
				float c[4];
				double sx = ox + (x + 0.5) / scale * 20.0, sy = oy + (y + 0.5) / scale * 20.0;
				paint_at(p, bmp, sx, sy, c);
				float *d = layer.data() + ((size_t)y * w + x) * 4;
				for (int i = 0; i < 4; i++) {
					d[i] += c[i] * cov;
				}
				layer_geo[(size_t)y * w + x] += cov;
			}
		}
		if (acc.y_max >= acc.y_min) {
			layer_y0 = std::min(layer_y0, acc.y_min);
			layer_y1 = std::max(layer_y1, acc.y_max);
		}
		acc.clear();
	}

	// composites the group layer over the image and clears it
	void flush_layer() {
		for (int y = layer_y0; y <= layer_y1; y++) {
			for (int x = 0; x < w; x++) {
				size_t i = (size_t)y * w + x;
				float *l = layer.data() + i * 4;
				float a = std::min(1.0f, l[3]);
				if (a > 1e-6f) {
					float k = l[3] > 1.0f ? 1.0f / l[3] : 1.0f;
					float *d = img.data() + i * 4;
					for (int ch = 0; ch < 4; ch++) {
						d[ch] = l[ch] * k + d[ch] * (1.0f - a);
					}
				}
				float gc = std::min(1.0f, layer_geo[i]);
				geo[i] = gc + geo[i] * (1.0f - gc);
				l[0] = l[1] = l[2] = l[3] = 0.0f;
				layer_geo[i] = 0.0f;
			}
		}
		layer_y0 = h;
		layer_y1 = -1;
	}

	// composite the accumulated coverage with a paint, then clear the accumulator
	void fill(const Paint &p) {
		const uint8_t *bmp = p.bmp.is_valid() ? p.bmp->get_data().ptr() : nullptr;
		PackedByteArray keep;
		if (p.bmp.is_valid()) {
			keep = p.bmp->get_data();
			bmp = keep.ptr();
		}
		for (int y = acc.y_min; y <= acc.y_max; y++) {
			float *row = acc.a.data() + (size_t)y * (w + 2);
			float s = 0;
			for (int x = 0; x < w; x++) {
				s += row[x];
				float cov = std::min(1.0f, std::abs(s));
				if (cov <= 1e-4f) {
					continue;
				}
				float c[4];
				double sx = ox + (x + 0.5) / scale * 20.0, sy = oy + (y + 0.5) / scale * 20.0;
				paint_at(p, bmp, sx, sy, c);
				float *d = img.data() + ((size_t)y * w + x) * 4;
				float k = 1.0f - c[3] * cov;
				for (int i = 0; i < 4; i++) {
					d[i] = c[i] * cov + d[i] * k;
				}
				float &g = geo[(size_t)y * w + x];
				g = cov + g * (1.0f - cov);
			}
		}
		acc.clear();
	}
};

// Flattens a quadratic curve to points (excluding p0) with ~0.05 px tolerance.
void flatten(P p0, P c, P p1, std::vector<P> &out) {
	double dx = p0.x - 2 * c.x + p1.x, dy = p0.y - 2 * c.y + p1.y;
	double dd = std::sqrt(dx * dx + dy * dy);
	int n = std::clamp((int)std::ceil(std::sqrt(dd / (8.0 * 0.05))), 1, 100);
	for (int i = 1; i <= n; i++) {
		double t = (double)i / n, u = 1 - t;
		out.push_back({ u * u * p0.x + 2 * u * t * c.x + t * t * p1.x, u * u * p0.y + 2 * u * t * c.y + t * t * p1.y });
	}
}

struct Segment {
	P a, b;
};

struct Group {
	std::vector<Fill> fills;
	std::vector<LineStyle> lines;
	std::map<int, std::vector<Segment>> fill_edges;           // fill index (1-based) -> oriented edges
	std::map<int, std::vector<std::vector<P>>> line_paths;   // line index (1-based) -> polylines
};

void add_round(std::vector<P> &poly, P c, double r, int segs) {
	poly.clear();
	for (int i = 0; i < segs; i++) {
		double a = 2 * 3.14159265358979323846 * i / segs;
		poly.push_back({ c.x + std::cos(a) * r, c.y + std::sin(a) * r });
	}
}

// Ensures a polygon is counter-clockwise (positive area) so stroke pieces union under the coverage rule.
void orient(std::vector<P> &poly) {
	double area = 0;
	for (size_t i = 0; i < poly.size(); i++) {
		const P &a = poly[i], &b = poly[(i + 1) % poly.size()];
		area += a.x * b.y - b.x * a.y;
	}
	if (area < 0) {
		std::reverse(poly.begin(), poly.end());
	}
}

void stroke(Raster &r, const std::vector<P> &pts, const LineStyle &ls, double width_px) {
	double hw = std::max(width_px, 1.0) / 2.0;
	int segs = std::clamp((int)std::ceil(hw * 4), 8, 64);
	std::vector<P> poly;
	size_t n = pts.size();
	if (n == 0) {
		return;
	}
	bool closed = n > 2 && std::abs(pts[0].x - pts[n - 1].x) < 1e-6 && std::abs(pts[0].y - pts[n - 1].y) < 1e-6;
	for (size_t i = 0; i + 1 < n; i++) {
		P a = pts[i], b = pts[i + 1];
		double dx = b.x - a.x, dy = b.y - a.y;
		double len = std::sqrt(dx * dx + dy * dy);
		if (len < 1e-9) {
			continue;
		}
		double nx = -dy / len * hw, ny = dx / len * hw;
		poly = { { a.x + nx, a.y + ny }, { b.x + nx, b.y + ny }, { b.x - nx, b.y - ny }, { a.x - nx, a.y - ny } };
		orient(poly);
		r.acc.polygon(poly);
	}
	// joins (round joins as discs; bevel / miter approximated by discs too for robustness)
	for (size_t i = 1; i + 1 < n; i++) {
		if (ls.join == 0 || true) {
			add_round(poly, pts[i], hw, segs);
			r.acc.polygon(poly);
		}
	}
	if (closed) {
		add_round(poly, pts[0], hw, segs);
		r.acc.polygon(poly);
		return;
	}
	// caps: round (0) and square (2); none (1) adds nothing
	for (int end = 0; end < 2; end++) {
		int cap = end == 0 ? ls.start_cap : ls.end_cap;
		P p = end == 0 ? pts[0] : pts[n - 1];
		P q = end == 0 ? (n > 1 ? pts[1] : pts[0]) : (n > 1 ? pts[n - 2] : pts[0]);
		if (cap == 0) {
			add_round(poly, p, hw, segs);
			r.acc.polygon(poly);
		} else if (cap == 2) {
			double dx = p.x - q.x, dy = p.y - q.y;
			double len = std::sqrt(dx * dx + dy * dy);
			if (len < 1e-9) {
				continue;
			}
			dx /= len;
			dy /= len;
			double nx = -dy * hw, ny = dx * hw;
			poly = { { p.x + nx, p.y + ny }, { p.x + nx + dx * hw, p.y + ny + dy * hw }, { p.x - nx + dx * hw, p.y - ny + dy * hw },
				{ p.x - nx, p.y - ny } };
			orient(poly);
			r.acc.polygon(poly);
		}
	}
}

// Rasterises a shape: fills of each style group in index order, then its lines (Flash order).
void rasterize(const Shape &s, Raster &r, const std::function<Ref<Image>(int)> &bitmaps) {
	std::vector<Group> groups(1);
	groups[0].fills = s.fills;
	groups[0].lines = s.lines;
	int f0 = 0, f1 = 0, ln = 0;
	double x = 0, y = 0;
	std::vector<P> *cur_line = nullptr;
	auto edge = [&](P a, P b) {
		Group &g = groups.back();
		if (f1 > 0) {
			g.fill_edges[f1].push_back({ a, b });
		}
		if (f0 > 0) {
			g.fill_edges[f0].push_back({ b, a });
		}
	};
	std::vector<P> flat;
	for (const Rec &rec : s.recs) {
		if (rec.type == Rec::STYLE) {
			if (rec.new_styles) {
				groups.push_back(Group());
				groups.back().fills = rec.fills;
				groups.back().lines = rec.lines;
				f0 = f1 = ln = 0;
			}
			if (rec.fill0 >= 0) {
				f0 = rec.fill0;
			}
			if (rec.fill1 >= 0) {
				f1 = rec.fill1;
			}
			if (rec.line >= 0) {
				ln = rec.line;
			}
			if (rec.has_move) {
				x = rec.mx;
				y = rec.my;
			}
			cur_line = nullptr;
			continue;
		}
		P a = r.px(x, y);
		flat.clear();
		if (rec.type == Rec::LINE) {
			flat.push_back(r.px(rec.x, rec.y));
		} else {
			flatten(a, r.px(rec.cx, rec.cy), r.px(rec.x, rec.y), flat);
		}
		P prev = a;
		for (const P &q : flat) {
			edge(prev, q);
			prev = q;
		}
		if (ln > 0) {
			Group &g = groups.back();
			if (cur_line == nullptr) {
				g.line_paths[ln].push_back({ a });
				cur_line = &g.line_paths[ln].back();
			}
			cur_line->insert(cur_line->end(), flat.begin(), flat.end());
		} else {
			cur_line = nullptr;
		}
		x = rec.x;
		y = rec.y;
	}
	for (Group &g : groups) {
		for (auto &kv : g.fill_edges) {
			int idx = kv.first;
			if (idx < 1 || idx > (int)g.fills.size()) {
				continue;
			}
			for (const Segment &e : kv.second) {
				r.acc.line(e.a, e.b);
			}
			Paint p;
			make_paint(g.fills[idx - 1], p, bitmaps);
			r.fill_layer(p);
		}
		r.flush_layer();
		for (auto &kv : g.line_paths) {
			int idx = kv.first;
			if (idx < 1 || idx > (int)g.lines.size()) {
				continue;
			}
			const LineStyle &ls = g.lines[idx - 1];
			double wpx = ls.width / 20.0 * r.scale;
			if (ls.width == 0) {
				wpx = 1.0;
			}
			for (const std::vector<P> &path : kv.second) {
				stroke(r, path, ls, wpx);
			}
			Paint p;
			if (ls.has_fill) {
				make_paint(ls.fill, p, bitmaps);
			} else {
				Fill f;
				f.color = ls.color;
				make_paint(f, p, bitmaps);
			}
			r.fill(p);
		}
	}
}

} // namespace swf

using namespace swf;

// ------------------------------------------------------------------------------------------------ SWFFile

void SWFFile::_bind_methods() {
	ClassDB::bind_method(D_METHOD("open", "bytes"), &SWFFile::open);
	ClassDB::bind_method(D_METHOD("get_info"), &SWFFile::get_info);
	ClassDB::bind_method(D_METHOD("get_characters"), &SWFFile::get_characters);
	ClassDB::bind_method(D_METHOD("get_symbol_classes"), &SWFFile::get_symbol_classes);
	ClassDB::bind_method(D_METHOD("get_exports"), &SWFFile::get_exports);
	ClassDB::bind_method(D_METHOD("get_scaling_grids"), &SWFFile::get_scaling_grids);
	ClassDB::bind_method(D_METHOD("get_scenes"), &SWFFile::get_scenes);
	ClassDB::bind_method(D_METHOD("get_timeline", "id"), &SWFFile::get_timeline);
	ClassDB::bind_method(D_METHOD("get_abc_blocks"), &SWFFile::get_abc_blocks);
	ClassDB::bind_method(D_METHOD("render", "id", "ratio", "scale"), &SWFFile::render);
	ClassDB::bind_method(D_METHOD("get_bitmap", "id"), &SWFFile::get_bitmap);
	ClassDB::bind_method(D_METHOD("get_sound", "id"), &SWFFile::get_sound);
	ClassDB::bind_method(D_METHOD("get_edit_text", "id"), &SWFFile::get_edit_text);
	ClassDB::bind_method(D_METHOD("get_binary", "id"), &SWFFile::get_binary);
}

Error SWFFile::open(const PackedByteArray &p_bytes) {
	if (p_bytes.size() < 8) {
		return ERR_FILE_CORRUPT;
	}
	const uint8_t *b = p_bytes.ptr();
	uint32_t file_len = b[4] | (b[5] << 8) | (b[6] << 16) | ((uint32_t)b[7] << 24);
	if (b[0] == 'C' && b[1] == 'W' && b[2] == 'S') {
		PackedByteArray body = p_bytes.slice(8);
		PackedByteArray dec = body.decompress(file_len - 8, FileAccess::COMPRESSION_DEFLATE);
		if (dec.size() == 0) {
			dec = body.decompress_dynamic(-1, FileAccess::COMPRESSION_DEFLATE);
		}
		if (dec.size() == 0) {
			return ERR_FILE_CORRUPT;
		}
		data.assign(b, b + 8);
		data.insert(data.end(), dec.ptr(), dec.ptr() + dec.size());
	} else if (b[0] == 'F' && b[1] == 'W' && b[2] == 'S') {
		data.assign(b, b + p_bytes.size());
	} else {
		return ERR_FILE_UNRECOGNIZED; // LZMA ("ZWS") SWFs are not supported
	}
	version = data[3];
	Bits bits(data.data(), data.size(), 8);
	int32_t r[4];
	bits.rect(r);
	width = (r[1] - r[0]) / 20.0;
	height = (r[3] - r[2]) / 20.0;
	fps = bits.u16() / 256.0;
	frame_count = bits.u16();
	tags = read_tags(data.data(), data.size(), bits.pos, data.size());
	index_tags();
	return OK;
}

void SWFFile::index_tags() {
	const uint8_t *d = data.data();
	size_t size = data.size();
	auto u16at = [&](size_t p) -> int { return p + 2 <= size ? (d[p] | (d[p + 1] << 8)) : 0; };
	for (const Tag &t : tags) {
		Char c;
		c.code = t.code;
		c.pos = t.pos;
		c.len = t.len;
		int id = -1;
		switch (t.code) {
			case 2:
			case 22:
			case 32:
			case 83:
				c.type = "shape";
				id = u16at(t.pos);
				break;
			case 46:
			case 84:
				c.type = "morph";
				id = u16at(t.pos);
				break;
			case 39:
				c.type = "sprite";
				id = u16at(t.pos);
				c.frame_count = u16at(t.pos + 2);
				c.sprite_tags = read_tags(d, size, t.pos + 4, t.pos + t.len);
				break;
			case 6:
			case 20:
			case 21:
			case 35:
			case 36:
			case 90:
				c.type = "bitmap";
				id = u16at(t.pos);
				break;
			case 11:
			case 33:
				c.type = "text";
				id = u16at(t.pos);
				break;
			case 7:
			case 34:
				c.type = "button";
				id = u16at(t.pos);
				break;
			case 14:
				c.type = "sound";
				id = u16at(t.pos);
				break;
			case 87:
				c.type = "binary";
				id = u16at(t.pos);
				break;
			case 37:
				c.type = "edittext";
				id = u16at(t.pos);
				break;
			case 10:
			case 48:
			case 75:
			case 91:
				c.type = "font";
				id = u16at(t.pos);
				break;
			case 8:
				jpeg_tables.assign(d + t.pos, d + t.pos + t.len);
				break;
			case 76:
			case 56: {
				Bits b(d, size, t.pos);
				int n = b.u16();
				for (int i = 0; i < n && !b.overflow; i++) {
					int cid = b.u16();
					String name = b.string();
					(t.code == 76 ? symbol_classes : exports)[cid] = name;
				}
				break;
			}
			case 78: {
				Bits b(d, size, t.pos);
				int cid = b.u16();
				int32_t g[4];
				b.rect(g);
				Array a;
				a.push_back(g[0] / 20.0);
				a.push_back(g[2] / 20.0);
				a.push_back((g[1] - g[0]) / 20.0);
				a.push_back((g[3] - g[2]) / 20.0);
				scaling_grids[cid] = a;
				break;
			}
			case 86: {
				Bits b(d, size, t.pos);
				auto eu32 = [&]() -> uint32_t {
					uint32_t v = 0;
					int shift = 0;
					while (!b.overflow) {
						uint8_t byte = b.u8();
						v |= (uint32_t)(byte & 0x7f) << shift;
						shift += 7;
						if (!(byte & 0x80) || shift > 28) {
							break;
						}
					}
					return v;
				};
				uint32_t ns = eu32();
				for (uint32_t i = 0; i < ns && !b.overflow; i++) {
					Array e;
					e.push_back((int64_t)eu32());
					e.push_back(b.string());
					scene_labels.push_back(e);
				}
				break;
			}
			default:
				break;
		}
		if (id >= 0 && !c.type.is_empty()) {
			chars[id] = std::move(c);
		}
	}
}

Dictionary SWFFile::get_info() const {
	Dictionary d;
	d["version"] = version;
	d["width"] = width;
	d["height"] = height;
	d["fps"] = fps;
	d["frame_count"] = frame_count;
	return d;
}

Dictionary SWFFile::get_characters() const {
	Dictionary out;
	const uint8_t *d = data.data();
	for (const auto &kv : chars) {
		Dictionary e;
		e["type"] = kv.second.type;
		e["code"] = kv.second.code;
		if (kv.second.type == "sprite") {
			e["frameCount"] = kv.second.frame_count;
		} else if (kv.second.type == "shape" || kv.second.type == "morph" || kv.second.type == "text") {
			Bits b(d, data.size(), kv.second.pos + 2);
			int32_t r[4];
			b.rect(r);
			Array a;
			for (int i = 0; i < 4; i++) {
				a.push_back(r[i]);
			}
			e["bounds"] = a;
		}
		out[kv.first] = e;
	}
	return out;
}

static Array filters_from(Bits &b) {
	Array out;
	int n = b.u8();
	auto color4 = [&]() {
		Array c;
		for (int i = 0; i < 4; i++) {
			c.push_back(b.u8());
		}
		return c;
	};
	for (int i = 0; i < n && !b.overflow; i++) {
		int fid = b.u8();
		Dictionary f;
		auto shadow_common = [&]() {
			f["inner"] = (int)b.ub(1);
			f["knockout"] = (int)b.ub(1);
			f["compositeSource"] = (int)b.ub(1);
		};
		if (fid == 0) {
			f["type"] = "DropShadow";
			f["color"] = color4();
			f["blurX"] = b.fixed();
			f["blurY"] = b.fixed();
			f["angle"] = b.fixed();
			f["distance"] = b.fixed();
			f["strength"] = b.fixed8();
			shadow_common();
			f["passes"] = (int)b.ub(5);
		} else if (fid == 1) {
			f["type"] = "Blur";
			f["blurX"] = b.fixed();
			f["blurY"] = b.fixed();
			f["passes"] = (int)b.ub(5);
			b.ub(3);
		} else if (fid == 2) {
			f["type"] = "Glow";
			f["color"] = color4();
			f["blurX"] = b.fixed();
			f["blurY"] = b.fixed();
			f["strength"] = b.fixed8();
			shadow_common();
			f["passes"] = (int)b.ub(5);
		} else if (fid == 3) {
			f["type"] = "Bevel";
			f["shadowColor"] = color4();
			f["highlightColor"] = color4();
			f["blurX"] = b.fixed();
			f["blurY"] = b.fixed();
			f["angle"] = b.fixed();
			f["distance"] = b.fixed();
			f["strength"] = b.fixed8();
			shadow_common();
			f["onTop"] = (int)b.ub(1);
			f["passes"] = (int)b.ub(4);
		} else if (fid == 4 || fid == 7) {
			int nc = b.u8();
			Array cols, ratios;
			for (int k = 0; k < nc; k++) {
				cols.push_back(color4());
			}
			for (int k = 0; k < nc; k++) {
				ratios.push_back(b.u8());
			}
			f["type"] = fid == 4 ? "GradientGlow" : "GradientBevel";
			f["colors"] = cols;
			f["ratios"] = ratios;
			f["blurX"] = b.fixed();
			f["blurY"] = b.fixed();
			f["angle"] = b.fixed();
			f["distance"] = b.fixed();
			f["strength"] = b.fixed8();
			shadow_common();
			f["onTop"] = (int)b.ub(1);
			f["passes"] = (int)b.ub(4);
		} else if (fid == 5) {
			int mx = b.u8(), my = b.u8();
			f["type"] = "Convolution";
			f["matrixX"] = mx;
			f["matrixY"] = my;
			f["divisor"] = b.float32();
			f["bias"] = b.float32();
			Array m;
			for (int k = 0; k < mx * my; k++) {
				m.push_back(b.float32());
			}
			f["matrix"] = m;
			f["color"] = color4();
			b.ub(6);
			f["clamp"] = (int)b.ub(1);
			f["preserveAlpha"] = (int)b.ub(1);
		} else if (fid == 6) {
			f["type"] = "ColorMatrix";
			Array m;
			for (int k = 0; k < 20; k++) {
				m.push_back(b.float32());
			}
			f["matrix"] = m;
		} else {
			break;
		}
		out.push_back(f);
	}
	return out;
}

static const char *BLEND_MODES[] = { "normal", "normal", "layer", "multiply", "screen", "lighten", "darken", "difference",
	"add", "subtract", "invert", "alpha", "erase", "overlay", "hardlight" };

static Dictionary parse_place(const uint8_t *d, size_t size, const Tag &t) {
	Bits b(d, size, t.pos);
	Dictionary p;
	p["op"] = "place";
	auto mat = [&]() {
		double m[6];
		b.matrix(m);
		Array a;
		for (int i = 0; i < 4; i++) {
			a.push_back(m[i]);
		}
		a.push_back(m[4] / 20.0);
		a.push_back(m[5] / 20.0);
		return a;
	};
	if (t.code == 4) {
		p["id"] = b.u16();
		p["depth"] = b.u16();
		p["matrix"] = mat();
		if (b.pos < t.pos + t.len) {
			p["cxform"] = b.cxform(false);
		}
		p["move"] = false;
		return p;
	}
	int flags = b.u8();
	int flags2 = t.code == 70 ? b.u8() : 0;
	p["move"] = (flags & 0x01) != 0;
	p["depth"] = b.u16();
	if (t.code == 70 && ((flags2 & 0x08) || ((flags2 & 0x10) && (flags & 0x02)))) {
		p["className"] = b.string();
	}
	if (flags & 0x02) {
		p["id"] = b.u16();
	}
	if (flags & 0x04) {
		p["matrix"] = mat();
	}
	if (flags & 0x08) {
		p["cxform"] = b.cxform(true);
	}
	if (flags & 0x10) {
		p["ratio"] = b.u16();
	}
	if (flags & 0x20) {
		p["name"] = b.string();
	}
	if (flags & 0x40) {
		p["clipDepth"] = b.u16();
	}
	if (t.code == 70) {
		if (flags2 & 0x01) {
			p["filters"] = filters_from(b);
		}
		if (flags2 & 0x02) {
			int bm = b.u8();
			p["blend"] = bm >= 0 && bm < 15 ? BLEND_MODES[bm] : "normal";
		}
		if (flags2 & 0x04) {
			p["cacheAsBitmap"] = b.u8();
		}
		if (flags2 & 0x20) {
			p["visible"] = b.u8();
		}
		if (flags2 & 0x40) {
			Array c;
			for (int i = 0; i < 4; i++) {
				c.push_back(b.u8());
			}
			p["bgColor"] = c;
		}
	}
	if (flags & 0x80) {
		p["hasClipActions"] = true;
	}
	return p;
}

Array SWFFile::get_timeline(int p_id) const {
	const std::vector<Tag> *tl = &tags;
	if (p_id >= 0) {
		auto it = chars.find(p_id);
		if (it == chars.end()) {
			return Array();
		}
		tl = &it->second.sprite_tags;
	}
	const uint8_t *d = data.data();
	size_t size = data.size();
	Array frames, cur;
	Dictionary labels;
	for (const Tag &t : *tl) {
		if (t.code == 1) {
			frames.push_back(cur);
			cur = Array();
		} else if (t.code == 4 || t.code == 26 || t.code == 70) {
			cur.push_back(parse_place(d, size, t));
		} else if (t.code == 5 || t.code == 28) {
			Dictionary op;
			op["op"] = "remove";
			size_t p = t.pos + (t.code == 5 ? 2 : 0);
			op["depth"] = p + 2 <= size ? (d[p] | (d[p + 1] << 8)) : 0;
			cur.push_back(op);
		} else if (t.code == 43) {
			Bits b(d, size, t.pos);
			labels[b.string()] = frames.size();
		} else if (t.code == 15) {
			Dictionary op;
			op["op"] = "sound";
			op["id"] = d[t.pos] | (d[t.pos + 1] << 8);
			cur.push_back(op);
		}
	}
	if (!cur.is_empty()) {
		frames.push_back(cur);
	}
	Array out;
	out.push_back(frames);
	out.push_back(labels);
	return out;
}

Array SWFFile::get_abc_blocks() const {
	Array out;
	const uint8_t *d = data.data();
	for (const Tag &t : tags) {
		if (t.code == 82) {
			size_t p = t.pos + 4; // flags
			while (p < t.pos + t.len && d[p] != 0) {
				p++; // name
			}
			p++;
			PackedByteArray abc;
			if (p < t.pos + t.len) {
				abc.resize((int64_t)(t.pos + t.len - p));
				memcpy(abc.ptrw(), d + p, t.pos + t.len - p);
			}
			out.push_back(abc);
		} else if (t.code == 72) { // DoABC1 (no header)
			PackedByteArray abc;
			abc.resize((int64_t)t.len);
			memcpy(abc.ptrw(), d + t.pos, t.len);
			out.push_back(abc);
		}
	}
	return out;
}

std::shared_ptr<Font> SWFFile::font(int id) {
	auto it = font_cache.find(id);
	if (it != font_cache.end()) {
		return it->second;
	}
	std::shared_ptr<Font> f;
	auto ch = chars.find(id);
	if (ch != chars.end() && (ch->second.code == 48 || ch->second.code == 75)) {
		f = std::make_shared<Font>();
		read_font(data.data(), data.size(), ch->second.pos, ch->second.code, *f);
	}
	font_cache[id] = f;
	return f;
}

bool SWFFile::shape_for(int id, int ratio, Shape &out) {
	auto it = chars.find(id);
	if (it == chars.end()) {
		return false;
	}
	const Char &c = it->second;
	if (c.type == "shape") {
		return read_shape(data.data(), data.size(), c.pos, c.code, out);
	}
	if (c.type == "morph") {
		Morph m;
		if (!read_morph(data.data(), data.size(), c.pos, c.code, m)) {
			return false;
		}
		morph_at(m, std::max(ratio, 0), out);
		return true;
	}
	if (c.type == "text") {
		return text_shape(data.data(), data.size(), c.pos, c.code, [this](int fid) { return font(fid); }, out);
	}
	return false;
}

Dictionary SWFFile::render(int p_id, int p_ratio, double p_scale) {
	Shape s;
	if (!shape_for(p_id, p_ratio, s)) {
		return Dictionary();
	}
	double ox = s.bounds[0], oy = s.bounds[2];
	double bw = (s.bounds[1] - s.bounds[0]) / 20.0, bh = (s.bounds[3] - s.bounds[2]) / 20.0;
	int w = std::max(1, (int)std::ceil(bw * p_scale - 1e-9));
	int h = std::max(1, (int)std::ceil(bh * p_scale - 1e-9));
	if (bw <= 0 || bh <= 0 || w > 8192 || h > 8192) {
		return Dictionary();
	}
	Raster r(w, h, p_scale, ox, oy);
	rasterize(s, r, [this](int bid) { return get_bitmap(bid); });

	PackedByteArray px;
	px.resize((int64_t)w * h * 4);
	uint8_t *o = px.ptrw();
	bool empty = true;
	for (size_t i = 0; i < (size_t)w * h; i++) {
		const float *c = r.img.data() + i * 4;
		float a = c[3];
		if (a > 1e-6f) {
			empty = false;
			o[i * 4 + 0] = (uint8_t)std::clamp((int)(c[0] / a * 255.0f + 0.5f), 0, 255);
			o[i * 4 + 1] = (uint8_t)std::clamp((int)(c[1] / a * 255.0f + 0.5f), 0, 255);
			o[i * 4 + 2] = (uint8_t)std::clamp((int)(c[2] / a * 255.0f + 0.5f), 0, 255);
			o[i * 4 + 3] = (uint8_t)std::clamp((int)(a * 255.0f + 0.5f), 0, 255);
		} else {
			o[i * 4 + 0] = o[i * 4 + 1] = o[i * 4 + 2] = o[i * 4 + 3] = 0;
		}
	}
	// 1x hit mask from the geometry (transparent fills included, as Flash hit-tests geometry)
	int s_int = std::max(1, (int)std::lround(p_scale));
	int hw = std::max(1, (int)std::ceil(w / p_scale - 1e-9));
	int hh = std::max(1, (int)std::ceil(h / p_scale - 1e-9));
	PackedByteArray hit;
	hit.resize(((int64_t)hw * hh + 7) / 8);
	memset(hit.ptrw(), 0, hit.size());
	uint8_t *hb = hit.ptrw();
	for (int y = 0; y < hh; y++) {
		for (int x = 0; x < hw; x++) {
			float sum = 0;
			for (int sy = 0; sy < s_int; sy++) {
				for (int sx = 0; sx < s_int; sx++) {
					int px_ = x * s_int + sx, py_ = y * s_int + sy;
					if (px_ < w && py_ < h) {
						sum += r.geo[(size_t)py_ * w + px_];
					}
				}
			}
			if (sum / (s_int * s_int) >= 0.5f) {
				int bit = y * hw + x;
				hb[bit >> 3] |= (uint8_t)(1 << (bit & 7));
			}
		}
	}
	Dictionary out;
	out["image"] = Image::create_from_data(w, h, false, Image::FORMAT_RGBA8, px);
	out["x"] = ox / 20.0;
	out["y"] = oy / 20.0;
	out["w"] = bw;
	out["h"] = bh;
	out["hit"] = hit;
	out["hw"] = hw;
	out["hh"] = hh;
	out["empty"] = empty;
	return out;
}

// ---- bitmaps

static PackedByteArray strip_jpeg_header(const uint8_t *p, size_t n) {
	// Some encoders prefix JPEG data with an extra EOI+SOI pair (FF D9 FF D8); Godot's decoder dislikes it.
	PackedByteArray out;
	size_t start = 0;
	if (n >= 4 && p[0] == 0xFF && p[1] == 0xD9 && p[2] == 0xFF && p[3] == 0xD8) {
		start = 4;
	}
	out.resize((int64_t)(n - start));
	memcpy(out.ptrw(), p + start, n - start);
	return out;
}

Ref<Image> SWFFile::decode_bitmap(int id) {
	auto it = chars.find(id);
	if (it == chars.end() || it->second.type != "bitmap") {
		return Ref<Image>();
	}
	const Char &c = it->second;
	const uint8_t *d = data.data() + c.pos + 2;
	size_t n = c.len - 2;
	Ref<Image> img;
	if (c.code == 6 || c.code == 21 || c.code == 35 || c.code == 90) {
		size_t jpeg_len = n;
		size_t alpha_off = 0;
		if (c.code == 35 || c.code == 90) {
			jpeg_len = d[0] | (d[1] << 8) | (d[2] << 16) | ((size_t)d[3] << 24);
			d += 4;
			n -= 4;
			if (c.code == 90) {
				d += 2; // deblocking
				n -= 2;
			}
			alpha_off = jpeg_len;
		}
		PackedByteArray jpg;
		if (c.code == 6 && !jpeg_tables.empty()) {
			// tables + image data (drop the tables' EOI and the image's SOI)
			std::vector<uint8_t> merged(jpeg_tables.begin(), jpeg_tables.end());
			if (merged.size() >= 2) {
				merged.resize(merged.size() - 2);
			}
			merged.insert(merged.end(), d + 2, d + jpeg_len);
			jpg = strip_jpeg_header(merged.data(), merged.size());
		} else {
			jpg = strip_jpeg_header(d, std::min(jpeg_len, n));
		}
		img.instantiate();
		Error e = ERR_FILE_CORRUPT;
		if (jpg.size() > 8 && jpg[0] == 0x89 && jpg[1] == 'P') {
			e = img->load_png_from_buffer(jpg);
		} else if (jpg.size() > 6 && jpg[0] == 'G' && jpg[1] == 'I') {
			e = ERR_FILE_UNRECOGNIZED;
		} else {
			e = img->load_jpg_from_buffer(jpg);
		}
		if (e != OK) {
			return Ref<Image>();
		}
		img->convert(Image::FORMAT_RGBA8);
		if (alpha_off && alpha_off < n) {
			PackedByteArray za;
			za.resize((int64_t)(n - alpha_off));
			memcpy(za.ptrw(), d + alpha_off, n - alpha_off);
			int64_t npx = (int64_t)img->get_width() * img->get_height();
			PackedByteArray alpha = za.decompress(npx, FileAccess::COMPRESSION_DEFLATE);
			if (alpha.size() == npx) {
				PackedByteArray px = img->get_data();
				uint8_t *q = px.ptrw();
				for (int64_t i = 0; i < npx; i++) {
					// JPEG3 colour data is premultiplied by the alpha channel
					uint8_t a = alpha[i];
					q[i * 4 + 3] = a;
					if (a > 0 && a < 255) {
						for (int ch = 0; ch < 3; ch++) {
							q[i * 4 + ch] = (uint8_t)std::min(255, q[i * 4 + ch] * 255 / a);
						}
					}
				}
				img = Image::create_from_data(img->get_width(), img->get_height(), false, Image::FORMAT_RGBA8, px);
			}
		}
		return img;
	}
	// DefineBitsLossless (20) / Lossless2 (36)
	bool alpha = c.code == 36;
	int fmt = d[0];
	int w = d[1] | (d[2] << 8);
	int h = d[3] | (d[4] << 8);
	size_t off = 5;
	int table_size = 0;
	if (fmt == 3) {
		table_size = d[5] + 1;
		off = 6;
	}
	PackedByteArray z;
	z.resize((int64_t)(n - off));
	memcpy(z.ptrw(), d + off, n - off);
	PackedByteArray raw = z.decompress_dynamic(-1, FileAccess::COMPRESSION_DEFLATE);
	if (raw.size() == 0 || w <= 0 || h <= 0) {
		return Ref<Image>();
	}
	const uint8_t *r = raw.ptr();
	size_t rs = raw.size();
	PackedByteArray px;
	px.resize((int64_t)w * h * 4);
	uint8_t *q = px.ptrw();
	auto put = [&](int i, int R, int G, int B, int A) {
		q[i * 4 + 0] = (uint8_t)R;
		q[i * 4 + 1] = (uint8_t)G;
		q[i * 4 + 2] = (uint8_t)B;
		q[i * 4 + 3] = (uint8_t)A;
	};
	if (fmt == 3) {
		int entry = alpha ? 4 : 3;
		int row = (w + 3) & ~3;
		size_t pix0 = (size_t)table_size * entry;
		for (int y = 0; y < h; y++) {
			for (int x = 0; x < w; x++) {
				size_t pi = pix0 + (size_t)y * row + x;
				int idx = pi < rs ? r[pi] : 0;
				size_t ci = (size_t)idx * entry;
				if (idx >= table_size || ci + entry > rs) {
					put(y * w + x, 0, 0, 0, 0);
					continue;
				}
				int A = alpha ? r[ci + 3] : 255;
				int R = r[ci], G = r[ci + 1], B = r[ci + 2];
				if (alpha && A > 0 && A < 255) {
					R = std::min(255, R * 255 / A);
					G = std::min(255, G * 255 / A);
					B = std::min(255, B * 255 / A);
				}
				put(y * w + x, R, G, B, A);
			}
		}
	} else if (fmt == 4) {
		int row = (w * 2 + 3) & ~3;
		for (int y = 0; y < h; y++) {
			for (int x = 0; x < w; x++) {
				size_t pi = (size_t)y * row + x * 2;
				int v = pi + 1 < rs ? (r[pi] << 8 | r[pi + 1]) : 0;
				put(y * w + x, ((v >> 10) & 31) * 255 / 31, ((v >> 5) & 31) * 255 / 31, (v & 31) * 255 / 31, 255);
			}
		}
	} else if (fmt == 5) {
		for (int i = 0; i < w * h; i++) {
			size_t pi = (size_t)i * 4;
			if (pi + 3 >= rs) {
				put(i, 0, 0, 0, 0);
				continue;
			}
			int A = alpha ? r[pi] : 255;
			int R = r[pi + 1], G = r[pi + 2], B = r[pi + 3];
			if (alpha && A > 0 && A < 255) {
				R = std::min(255, R * 255 / A);
				G = std::min(255, G * 255 / A);
				B = std::min(255, B * 255 / A);
			}
			put(i, R, G, B, A);
		}
	} else {
		return Ref<Image>();
	}
	return Image::create_from_data(w, h, false, Image::FORMAT_RGBA8, px);
}

Ref<Image> SWFFile::get_bitmap(int p_id) {
	auto it = bitmap_cache.find(p_id);
	if (it != bitmap_cache.end()) {
		return it->second;
	}
	Ref<Image> img = decode_bitmap(p_id);
	bitmap_cache[p_id] = img;
	return img;
}

Dictionary SWFFile::get_sound(int p_id) const {
	Dictionary out;
	auto it = chars.find(p_id);
	if (it == chars.end() || it->second.type != "sound") {
		return out;
	}
	const uint8_t *d = data.data() + it->second.pos + 2;
	size_t n = it->second.len - 2;
	int flags = d[0];
	out["format"] = flags >> 4;
	out["rate"] = (flags >> 2) & 3;
	out["16bit"] = (flags >> 1) & 1;
	out["stereo"] = flags & 1;
	out["samples"] = (int64_t)(d[1] | (d[2] << 8) | (d[3] << 16) | ((uint32_t)d[4] << 24));
	size_t start = 5 + ((flags >> 4) == 2 ? 2 : 0); // MP3: skip SeekSamples
	PackedByteArray bytes;
	if (start < n) {
		bytes.resize((int64_t)(n - start));
		memcpy(bytes.ptrw(), d + start, n - start);
	}
	out["data"] = bytes;
	return out;
}

Dictionary SWFFile::get_edit_text(int p_id) const {
	Dictionary e;
	auto it = chars.find(p_id);
	if (it == chars.end() || it->second.type != "edittext") {
		return e;
	}
	Bits b(data.data(), data.size(), it->second.pos);
	b.u16();
	int32_t r[4];
	b.rect(r);
	bool has_text = b.ub(1), word_wrap = b.ub(1), multiline = b.ub(1), password = b.ub(1), read_only = b.ub(1);
	bool has_color = b.ub(1), has_max = b.ub(1), has_font = b.ub(1), has_font_class = b.ub(1), auto_size = b.ub(1);
	bool has_layout = b.ub(1), no_select = b.ub(1), border = b.ub(1), was_static = b.ub(1), html = b.ub(1),
		 use_outlines = b.ub(1);
	e["t"] = "edittext";
	e["x"] = r[0] / 20.0;
	e["y"] = r[2] / 20.0;
	e["w"] = (r[1] - r[0]) / 20.0;
	e["h"] = (r[3] - r[2]) / 20.0;
	e["wordWrap"] = (int)word_wrap;
	e["multiline"] = (int)multiline;
	e["password"] = (int)password;
	e["readOnly"] = (int)read_only;
	e["autoSize"] = (int)auto_size;
	e["selectable"] = no_select ? 0 : 1;
	e["border"] = (int)border;
	e["html"] = (int)html;
	e["useOutlines"] = (int)use_outlines;
	e["wasStatic"] = (int)was_static;
	if (has_font) {
		e["font"] = b.u16();
	}
	if (has_font_class) {
		e["fontClass"] = b.string();
	}
	if (has_font || has_font_class) {
		e["fontHeight"] = b.u16() / 20.0;
	}
	if (has_color) {
		Array c;
		for (int i = 0; i < 4; i++) {
			c.push_back(b.u8());
		}
		e["color"] = c;
	}
	if (has_max) {
		e["maxLength"] = b.u16();
	}
	if (has_layout) {
		static const char *aligns[] = { "left", "right", "center", "justify" };
		e["align"] = aligns[b.u8() & 3];
		e["leftMargin"] = b.u16() / 20.0;
		e["rightMargin"] = b.u16() / 20.0;
		e["indent"] = b.u16() / 20.0;
		e["leading"] = b.s16() / 20.0;
	}
	e["variable"] = b.string();
	if (has_text) {
		e["text"] = b.string();
	}
	return e;
}

PackedByteArray SWFFile::get_binary(int p_id) const {
	PackedByteArray out;
	auto it = chars.find(p_id);
	if (it == chars.end() || it->second.type != "binary" || it->second.len < 6) {
		return out;
	}
	size_t n = it->second.len - 6;
	out.resize((int64_t)n);
	memcpy(out.ptrw(), data.data() + it->second.pos + 6, n);
	return out;
}
