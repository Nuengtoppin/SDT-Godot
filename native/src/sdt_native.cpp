#include "sdt_native.h"

#include <godot_cpp/classes/geometry2d.hpp>
#include <godot_cpp/classes/node2d.hpp>
#include <godot_cpp/classes/script.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_color_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/transform2d.hpp>

#include <algorithm>
#include <unordered_map>
#include <cstring>
#include <cmath>
#include <vector>

void SDTNative::_bind_methods() {
	ClassDB::bind_static_method("SDTNative",
			D_METHOD("build_strand", "pos", "thickness", "density", "has_stored", "stored", "rgb", "alpha",
					"max_interp_dist"),
			&SDTNative::build_strand);
	ClassDB::bind_static_method("SDTNative", D_METHOD("hit_shape", "obj", "point", "hb_gen"), &SDTNative::hit_shape);
}

namespace {

// obj.Line: segment p1-p2 with implicit equation A x + B y = C.
struct Line {
	Vector2 p1, p2;
	double A() const { return p2.y - p1.y; }
	double B() const { return p1.x - p2.x; }
	double C() const { return (double)(p2.y - p1.y) * p1.x + (double)(p1.x - p2.x) * p1.y; }
};

// Maths.normal: projection of c onto the line through a and b.
Vector2 maths_normal(Vector2 a, Vector2 b, Vector2 c) {
	Vector2 ab(b.x - a.x, b.y - a.y);
	Vector2 ac(c.x - a.x, c.y - a.y);
	double t = ((double)ab.x * ac.x + (double)ab.y * ac.y) / ((double)ab.x * ab.x + (double)ab.y * ab.y);
	return Vector2(a.x + ab.x * t, a.y + ab.y * t);
}

// Strand._interPoint: control point where adjacent offset lines meet, clamped towards the midpoint.
Vector2 inter_point(const Line &l1, const Line &l2, Vector2 mid, Vector2 o1, Vector2 o2, double max_interp_dist) {
	double d = l1.A() * l2.B() - l2.A() * l1.B();
	if (d == 0) {
		return o1 + (o2 - o1) / 2.0;
	}
	double ix = (l2.B() * l1.C() - l1.B() * l2.C()) / d;
	double iy = (l1.A() * l2.C() - l2.A() * l1.C()) / d;
	Vector2 dv(ix - mid.x, iy - mid.y);
	double d2 = (double)dv.x * dv.x + (double)dv.y * dv.y;
	if (d2 > max_interp_dist) {
		dv *= max_interp_dist / d2;
		return mid + dv;
	}
	return Vector2(ix, iy);
}

// FlashGraphics path building (moveTo / lineTo / curveTo with the same flattening).
struct Path {
	std::vector<Vector2> pts;
	Vector2 pen;
	void move_to(Vector2 p) {
		pts.clear();
		pts.push_back(p);
		pen = p;
	}
	void line_to(Vector2 p) {
		pts.push_back(p);
		pen = p;
	}
	void curve_to(Vector2 c, Vector2 p1) {
		Vector2 p0 = pen;
		int n = std::clamp((int)((p0.distance_to(c) + c.distance_to(p1)) / 3.0f), 2, 24);
		float inv = 1.0f / n;
		for (int i = 0; i < n; i++) {
			float t = (i + 1) * inv;
			float u = 1.0f - t;
			pts.push_back(p0 * (u * u) + c * (2.0f * u * t) + p1 * (t * t));
		}
		pen = p1;
	}
};

// Two-stop linear gradient ("pad" spread) as FlashGraphics.beginGradientFill + graphics_fill.gdshader evaluate it.
struct Gradient {
	Transform2D inv; // object space -> gradient space
	float r0, r1;
	Color c0, c1;
	float t_at(Vector2 p) const {
		Vector2 g = inv.xform(p);
		return g.x / 819.2f * 0.5f + 0.5f;
	}
	Color color_at(float t) const {
		t = std::clamp(t, 0.0f, 1.0f);
		if (t <= r0) {
			return c0;
		}
		if (t >= r1) {
			return c1;
		}
		float span = std::max(r1 - r0, 1e-5f);
		return c0.lerp(c1, (t - r0) / span);
	}
};

struct StrandMesh {
	std::vector<Vector2> points;
	std::vector<Color> colors;
	std::vector<int32_t> indices;
};

// Copies a std::vector into a packed array in one resize + memcpy (element-wise push_back goes through the
// engine API and is slow).
template <typename P, typename T>
P to_packed(const std::vector<T> &v) {
	P out;
	out.resize((int64_t)v.size());
	if (!v.empty()) {
		memcpy(out.ptrw(), v.data(), v.size() * sizeof(T));
	}
	return out;
}

// Emits triangle (a, b, c) split along the gradient's stop lines t = r0 and t = r1, so per-vertex colour
// interpolation reproduces the piecewise-linear ramp exactly. Allocation-free: a triangle clipped by two parallel
// half-planes has at most 5 vertices.
struct TV {
	Vector2 p;
	float t;
};

static int clip_side(const TV *in, int n, TV *out, float edge, bool keep_above) {
	int m = 0;
	for (int i = 0; i < n; i++) {
		const TV &s = in[i];
		const TV &e = in[(i + 1) % n];
		bool si = keep_above ? s.t >= edge : s.t <= edge;
		bool ei = keep_above ? e.t >= edge : e.t <= edge;
		if (si) {
			out[m++] = s;
		}
		if (si != ei) {
			float k = (edge - s.t) / (e.t - s.t);
			out[m++] = { s.p + (e.p - s.p) * k, edge };
		}
	}
	return m;
}

void emit_triangle(StrandMesh &m, const Gradient &g, Vector2 a, Vector2 b, Vector2 c) {
	TV tri[3] = { { a, g.t_at(a) }, { b, g.t_at(b) }, { c, g.t_at(c) } };
	float tmin = std::min(tri[0].t, std::min(tri[1].t, tri[2].t));
	float tmax = std::max(tri[0].t, std::max(tri[1].t, tri[2].t));
	const float bands[4] = { -INFINITY, g.r0, g.r1, INFINITY };
	for (int band = 0; band < 3; band++) {
		float lo = bands[band], hi = bands[band + 1];
		if (tmax < lo || tmin > hi) {
			continue;
		}
		TV buf1[6], buf2[6];
		const TV *poly = tri;
		int n = 3;
		if (tmin < lo) {
			n = clip_side(poly, n, buf1, lo, true);
			poly = buf1;
		}
		if (n >= 3 && tmax > hi) {
			n = clip_side(poly, n, buf2, hi, false);
			poly = buf2;
		}
		if (n < 3) {
			continue;
		}
		int base = (int)m.points.size();
		for (int k = 0; k < n; k++) {
			m.points.push_back(poly[k].p);
			m.colors.push_back(g.color_at(poly[k].t));
		}
		for (int k = 1; k + 1 < n; k++) {
			m.indices.push_back(base);
			m.indices.push_back(base + k);
			m.indices.push_back(base + k + 1);
		}
	}
}

} // namespace

Array SDTNative::build_strand(const PackedVector2Array &p_pos, const PackedFloat32Array &p_thickness,
		const PackedFloat32Array &p_density, const PackedByteArray &p_has_stored, const PackedVector2Array &p_stored,
		const Color &p_rgb, double p_alpha, double p_max_interp_dist) {
	StrandMesh mesh;
	const int n = (int)p_pos.size();
	Array result;
	if (n < 2) {
		result.push_back(PackedVector2Array());
		result.push_back(PackedColorArray());
		result.push_back(PackedInt32Array());
		return result;
	}
	const Vector2 *pos = p_pos.ptr();
	const float *thick = p_thickness.ptr();
	const float *dens = p_density.ptr();
	const uint8_t *has_stored = p_has_stored.size() >= n ? p_has_stored.ptr() : nullptr;
	const Vector2 *stored = p_stored.size() >= n * 2 ? p_stored.ptr() : nullptr;

	// --- Strand.generateInterpolationPoints
	std::vector<Vector2> dirs(std::max(n + 1, 2));
	for (int i = 0; i < n - 1; i++) {
		Vector2 d = pos[i + 1] - pos[i];
		if (!(d.x == 0 && d.y == 0)) {
			d /= std::sqrt(d.x * d.x + d.y * d.y);
		}
		dirs[i + 1] = d;
	}
	dirs[0] = dirs[1];
	dirs[n] = dirs[n - 1];
	std::vector<Vector2> in_off(n), out_off(n);
	std::vector<Line> in_line(n), out_line(n);
	Vector2 top_cap, bottom_cap;
	for (int i = 0; i < n; i++) {
		Vector2 l = pos[i];
		Vector2 nv = dirs[i + 1] + dirs[i];
		if (nv.x == 0 && nv.y == 0) {
			nv = dirs[i];
		}
		float t = thick[i];
		Vector2 inside(l.x - nv.y * t, l.y + nv.x * t);
		Vector2 outside(l.x + nv.y * t, l.y - nv.x * t);
		if (i == 0) {
			top_cap = Vector2(l.x - nv.x * t * 2.0f, l.y - nv.y * t * 2.0f);
		} else if (i == n - 1) {
			bottom_cap = Vector2(l.x + nv.x * t * 2.0f, l.y + nv.y * t * 2.0f);
		}
		in_off[i] = inside;
		out_off[i] = outside;
		in_line[i] = { inside + nv, inside - nv };
		out_line[i] = { outside + nv, outside - nv };
	}
	std::vector<Vector2> in_ip(n), out_ip(n);
	for (int i = 0; i < n - 1; i++) {
		if (has_stored && stored && has_stored[i]) {
			in_ip[i] = stored[i * 2];
			out_ip[i] = stored[i * 2 + 1];
			continue;
		}
		Vector2 a = pos[i], b = pos[i + 1];
		Vector2 mid((a.x + b.x) / 2.0f, (a.y + b.y) / 2.0f);
		if (i > 0 && i < n - 2) {
			in_ip[i] = inter_point(in_line[i], in_line[i + 1], mid, in_off[i], in_off[i + 1], p_max_interp_dist);
			out_ip[i] = inter_point(out_line[i], out_line[i + 1], mid, out_off[i], out_off[i + 1], p_max_interp_dist);
		} else if (i == 0) {
			in_ip[i] = maths_normal(in_line[1].p1, in_line[1].p2, mid);
			out_ip[i] = maths_normal(out_line[1].p1, out_line[1].p2, mid);
		} else if (i == n - 2) {
			in_ip[i] = maths_normal(in_line[n - 2].p1, in_line[n - 2].p2, mid);
			out_ip[i] = maths_normal(out_line[n - 2].p1, out_line[n - 2].p2, mid);
		}
	}

	// --- Strand.renderStrand: one gradient-filled outline per segment
	Geometry2D *geo = Geometry2D::get_singleton();
	Color c_rgb(p_rgb.r, p_rgb.g, p_rgb.b, 1.0f);
	Path path;
	path.pts.reserve(256);
	mesh.points.reserve(n * 64);
	mesh.colors.reserve(n * 64);
	mesh.indices.reserve(n * 128);
	PackedVector2Array poly;
	for (int i = 1; i < n; i++) {
		Vector2 cur = pos[i], prev = pos[i - 1];
		Vector2 d(cur.x - prev.x, cur.y - prev.y);
		float size = std::max(std::abs(d.x), std::abs(d.y));
		// FlashGraphics.createGradientBox(size, size, atan2(d.y, d.x), min x, min y)
		float rot = std::atan2(d.y, d.x);
		float cs = std::cos(rot), sn = std::sin(rot);
		Transform2D box(Vector2(cs * size / 1638.4f, sn * size / 1638.4f), Vector2(-sn * size / 1638.4f, cs * size / 1638.4f),
				Vector2(std::min(cur.x, prev.x) + size / 2.0f, std::min(cur.y, prev.y) + size / 2.0f));
		if (std::abs(box.determinant()) < 1e-12) {
			box = Transform2D(Vector2(1e-4f, 0.0f), Vector2(0.0f, 1e-4f), box.get_origin()); // zero-size box
		}
		Gradient g;
		g.inv = box.affine_inverse();
		g.r0 = 100.0f / 255.0f;
		g.r1 = 155.0f / 255.0f;
		g.c0 = c_rgb;
		g.c0.a = std::min(1.0, (double)dens[i - 1]) * p_alpha;
		g.c1 = c_rgb;
		g.c1.a = std::min(1.0, (double)dens[i]) * p_alpha;

		path.move_to(in_off[i - 1]);
		path.curve_to(in_ip[i - 1], in_off[i]);
		if (i == n - 1) {
			path.curve_to(bottom_cap, out_off[i]);
		} else {
			path.line_to(out_off[i]);
		}
		path.curve_to(out_ip[i - 1], out_off[i - 1]);
		if (i == 1) {
			path.curve_to(top_cap, in_off[0]);
		}
		if (path.pts.size() < 3) {
			continue;
		}
		poly = to_packed<PackedVector2Array>(path.pts);
		PackedInt32Array tri = geo->triangulate_polygon(poly);
		const int32_t *ti = tri.ptr();
		const int64_t tn = tri.size();
		const Vector2 *pp = path.pts.data();
		for (int64_t k = 0; k + 2 < tn; k += 3) {
			emit_triangle(mesh, g, pp[ti[k]], pp[ti[k + 1]], pp[ti[k + 2]]);
		}
	}
	result.push_back(to_packed<PackedVector2Array>(mesh.points));
	result.push_back(to_packed<PackedColorArray>(mesh.colors));
	result.push_back(to_packed<PackedInt32Array>(mesh.indices));
	return result;
}

// ------------------------------------------------------------------------------------------------ hit testing

namespace {

enum class Kind { SPRITE, SHAPE, OTHER };

struct Names {
	StringName _hb_gen = "_hb_gen", _hb = "_hb", _hit_bounds = "_hit_bounds", _graphics = "_graphics", hit = "hit",
			   _children = "_children", _clip_depth = "_clip_depth", _masking = "_masking", _clip_proxies = "_clip_proxies",
			   _depth = "_depth", _entry = "_entry", _library = "_library", _hit_masks = "_hit_masks",
			   _hit_masks_loaded = "_hit_masks_loaded", hit_mask_test = "hit_mask_test", _hit_shape = "_hit_shape";
	String hm = "hm", x = "x", y = "y";
};

Names &names() {
	static Names n;
	return n;
}

// Classifies an object by its script's inheritance chain (cached per script).
Kind kind_of(Object *o) {
	static std::unordered_map<Object *, Kind> cache;
	Variant sv = o->get_script();
	Object *script = sv;
	auto it = cache.find(script);
	if (it != cache.end()) {
		return it->second;
	}
	Kind k = Kind::OTHER;
	Ref<Script> s = Object::cast_to<Script>(script);
	while (s.is_valid()) {
		StringName gn = s->get_global_name();
		if (gn == StringName("FlashSprite")) {
			k = Kind::SPRITE;
			break;
		}
		if (gn == StringName("FlashShape")) {
			k = Kind::SHAPE;
			break;
		}
		if (gn == StringName("FlashBitmap") || gn == StringName("FlashTextField")) {
			break;
		}
		s = s->get_base_script();
	}
	cache[script] = k;
	return k;
}

bool hit_shape_rec(Object *o, Vector2 p, int64_t hb_gen);

// FlashSprite._clip_allows: children under a timeline clip mask only hit inside the mask.
bool clip_allows(Object *c, Vector2 p, const Dictionary &clips, int64_t hb_gen) {
	Names &N = names();
	int64_t d = c->get(N._depth);
	if (d < 0 || clips.is_empty()) {
		return true;
	}
	Array keys = clips.keys();
	for (int64_t i = 0; i < keys.size(); i++) {
		Object *m = keys[i];
		if (m == nullptr) {
			continue;
		}
		int64_t md = m->get(N._depth);
		int64_t mcd = m->get(N._clip_depth);
		if (d > md && d <= mcd) {
			Node2D *mn = Object::cast_to<Node2D>(m);
			return hit_shape_rec(m, mn->get_transform().affine_inverse().xform(p), hb_gen);
		}
	}
	return true;
}

bool hit_shape_rec(Object *o, Vector2 p, int64_t hb_gen) {
	Names &N = names();
	switch (kind_of(o)) {
		case Kind::SHAPE: {
			Dictionary e = o->get(N._entry);
			if (e.is_empty() || !e.has(N.hm)) {
				return false;
			}
			Object *lib = o->get(N._library);
			if (lib == nullptr) {
				return false;
			}
			if (!(bool)lib->get(N._hit_masks_loaded)) {
				return lib->call(N.hit_mask_test, e, p);
			}
			Array hm = e[N.hm];
			int64_t x = (int64_t)std::floor(p.x - (double)e[N.x]);
			int64_t y = (int64_t)std::floor(p.y - (double)e[N.y]);
			int64_t w = hm[1], h = hm[2];
			if (x < 0 || y < 0 || x >= w || y >= h) {
				return false;
			}
			int64_t bit = y * w + x;
			int64_t byte_i = (int64_t)hm[0] + (bit >> 3);
			PackedByteArray masks = lib->get(N._hit_masks);
			if (byte_i >= masks.size()) {
				return false;
			}
			return ((masks.ptr()[byte_i] >> (bit & 7)) & 1) == 1;
		}
		case Kind::SPRITE: {
			Rect2 hb;
			if ((int64_t)o->get(N._hb_gen) == hb_gen) {
				hb = o->get(N._hb);
			} else {
				hb = o->call(N._hit_bounds);
			}
			if (!hb.has_point(p)) {
				return false;
			}
			Variant gv = o->get(N._graphics);
			Object *gr = gv;
			if (gr != nullptr && (bool)gr->call(N.hit, p)) {
				return true;
			}
			Array children = o->get(N._children);
			Dictionary clips;
			bool clips_read = false;
			for (int64_t i = children.size() - 1; i >= 0; i--) {
				Object *c = children[i];
				if (c == nullptr) {
					continue;
				}
				// Test the child first (it rejects cheaply on its cached bounds); the mask / clip checks, which do
				// not change the outcome order, are only read for children that actually hit.
				Node2D *cn = Object::cast_to<Node2D>(c);
				if (!hit_shape_rec(c, cn->get_transform().affine_inverse().xform(p), hb_gen)) {
					continue;
				}
				if ((int64_t)c->get(N._clip_depth) > 0) {
					continue;
				}
				Array masking = c->get(N._masking);
				if (!masking.is_empty()) {
					continue;
				}
				if (!clips_read) {
					clips = o->get(N._clip_proxies);
					clips_read = true;
				}
				if (clip_allows(c, p, clips, hb_gen)) {
					return true;
				}
			}
			return false;
		}
		default:
			return o->call(N._hit_shape, p);
	}
}

} // namespace

bool SDTNative::hit_shape(Object *p_obj, const Vector2 &p_point, int64_t p_hb_gen) {
	if (p_obj == nullptr) {
		return false;
	}
	return hit_shape_rec(p_obj, p_point, p_hb_gen);
}
