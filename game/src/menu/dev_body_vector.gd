class_name DevBodyVector
extends RefCounted
## Body > Legs > Vector legs (our layer): her legs drawn from vector outlines - a mod template's body references (an
## Adobe Animate .fla in the save folder; read here, never shipped) - instead of the game's pictures. The outlines'
## coordinates are the game's own: a template symbol sits in its picture's space (each calf 357.4, 286.1 from its
## thigh, as in the game). Each part is its silhouette, its outline (the silhouette grown) and its skin; a point
## follows its bone and, near the knee, half the other one (the knee bends as one leg, no gap); the top of the
## thigh is held partly by her pelvis (where the game puts the thigh), so the crease in front and the buttock stay
## when the thigh turns; and by how far the knee unfolds the calf thins a little and the kneecap shows. Plain fill
## for now; the game's highlights stay. The game's skin pictures are hidden (their shader ignores modulate).

const PARTS := {"thigh_r": "Right Thigh Body", "calf_r": "Right Calf Body", "thigh_l": "Left Thigh Body",
	"calf_l": "Left Calf Body", "backside": "Backside Body"}
const SYMBOL_DIR := "LIBRARY/Assets/Template Elements/Body Elements/"
const KNEE := Vector2(357.4, 286.1)   # the calf's place on the thigh (the template's and the game's)
const BLEND := 110.0                  # how far from the knee a point follows both bones
const FILL := Color8(240, 211, 191)
const LINE := Color8(92, 66, 52)

static var on := false
static var data := {}           # part -> {"sil": PackedVector2Array}
static var status := ""         # what the menu shows
static var _legs := {}          # "r" / "l" -> {"nodes": [in draw order, see the enum], "hidden": [[picture, was visible]]}
static var _nodes := []         # the right leg's nodes (the checks look at them)
static var _after := Callable()
static var _game_fn := Callable()
static var _game := {}          # side -> the game's own thigh transform this tick (before ours), drawing space


## The first .fla in the save folder (where port.cfg and the saves are).
static func template_path() -> String:
	var dir := DirAccess.open(FlashSharedObject.save_dir)
	if dir == null:
		return ""
	for f in dir.get_files():
		if f.to_lower().ends_with(".fla"):
			return FlashSharedObject.save_dir.path_join(f)
	return ""


static func folder() -> String:
	return ProjectSettings.globalize_path(FlashSharedObject.save_dir)


## Reads the outlines from the template (once). False with `status` saying why.
static func load_template() -> bool:
	if not data.is_empty():
		return true
	var p := template_path()
	if p == "":
		status = "no template: put a mod template (.fla) into %s" % folder()
		return false
	var files := read_fla(p, PARTS.values().map(func(n): return SYMBOL_DIR + n + ".xml"))
	for part in PARTS:
		var xml: String = files.get(SYMBOL_DIR + PARTS[part] + ".xml", "")
		if xml == "" and part == "backside":
			continue   # the legs do without it (the game's backside stays)
		if xml == "":
			status = "the template has no %s" % PARTS[part]
			data.clear()
			return false
		data[part] = parse_shape(xml)
	status = "template: %s" % p.get_file()
	return true


## Files out of an .fla (a zip) by their names, read from the entries themselves - mod templates are often a little
## broken at the end (the zip's directory missing), which ZIPReader refuses. A deflated entry is wrapped as gzip
## (its CRC and size from the entry), which Godot can inflate.
static func read_fla(path: String, names: Array) -> Dictionary:
	var b := FileAccess.get_file_as_bytes(path)
	var out := {}
	var i := 0
	var n := b.size()
	while i < n - 30:
		if not (b[i] == 0x50 and b[i + 1] == 0x4b and b[i + 2] == 3 and b[i + 3] == 4):
			i += 1
			continue
		var meth := b.decode_u16(i + 8)
		var crc := b.decode_u32(i + 14)
		var cs := b.decode_u32(i + 18)
		var us := b.decode_u32(i + 22)
		var nl := b.decode_u16(i + 26)
		var el := b.decode_u16(i + 28)
		var name := b.slice(i + 30, i + 30 + nl).get_string_from_utf8()
		var start := i + 30 + nl + el
		if name in names:
			var raw := b.slice(start, start + cs)
			if meth == 8:
				var gz := PackedByteArray([0x1f, 0x8b, 8, 0, 0, 0, 0, 0, 0, 0xff])
				gz.append_array(raw)
				var tail := PackedByteArray()
				tail.resize(8)
				tail.encode_u32(0, crc)
				tail.encode_u32(4, us)
				gz.append_array(tail)
				raw = gz.decompress(us, FileAccess.COMPRESSION_GZIP)
			out[name] = raw.get_string_from_utf8()
		i = start + cs
	return out


## A symbol's silhouette: the largest closed loop of its outer boundary (an edge with a fill on one side only).
## Pixels (XFL counts in 1/20). The template's references are two greys (what shows, and what another part covers),
## not the game's line art: the outline is drawn here, around the silhouette.
static func parse_shape(xml: String) -> Dictionary:
	var sil_runs := []
	var re := RegEx.new()
	re.compile("<Edge ([^>]*?)edges=\"([^\"]*)\"")
	var f0 := RegEx.new()
	f0.compile("fillStyle0=\"(\\d+)\"")
	var f1 := RegEx.new()
	f1.compile("fillStyle1=\"(\\d+)\"")
	for m in re.search_all(xml):
		var attrs := m.get_string(1)
		if (f0.search(attrs) == null) != (f1.search(attrs) == null):
			sil_runs.append_array(parse_edges(m.get_string(2)))
	return {"sil": _largest(chain(sil_runs))}


static func _largest(loops: Array) -> PackedVector2Array:
	var best := PackedVector2Array()
	var best_a := 0.0
	for l in loops:
		var ar := absf(area(l))
		if ar > best_a:
			best_a = ar
			best = l
	return best


## XFL edge strings: "!x y" move, "|x y" or "/x y" line, "[cx cy x y" quadratic curve (sampled), "S<n>" style marks;
## numbers in twips, plain or "#hex[.frac]". One polyline per unbroken run.
static func parse_edges(s: String) -> Array:
	var re := RegEx.new()
	re.compile("[!|\\[/]|S\\d+|#[0-9A-Fa-f.]+|-?\\d+(?:\\.\\d+)?")
	var toks := []
	for m in re.search_all(s):
		toks.append(m.get_string())
	var runs := []
	var cur := PackedVector2Array()
	var pos := Vector2(INF, INF)
	var i := 0
	while i < toks.size():
		var t: String = toks[i]
		if t.begins_with("S"):
			i += 1
		elif t == "!":
			var p := Vector2(_num(toks[i + 1]), _num(toks[i + 2]))
			i += 3
			if p.distance_to(pos) > 0.01:
				if cur.size() > 1:
					runs.append(cur)
				cur = PackedVector2Array([p])
			pos = p
		elif t == "|" or t == "/":
			var p := Vector2(_num(toks[i + 1]), _num(toks[i + 2]))
			i += 3
			cur.append(p)
			pos = p
		elif t == "[":
			var c := Vector2(_num(toks[i + 1]), _num(toks[i + 2]))
			var p := Vector2(_num(toks[i + 3]), _num(toks[i + 4]))
			i += 5
			var p0 := pos
			for k in range(1, 9):
				var u := k / 8.0
				cur.append(p0 * (1 - u) * (1 - u) + c * 2.0 * (1 - u) * u + p * u * u)
			pos = p
		else:
			i += 1
	if cur.size() > 1:
		runs.append(cur)
	return runs


static func _num(t: String) -> float:
	if t.begins_with("#"):
		var h := t.substr(1)
		var parts := h.split(".")
		var v := parts[0].hex_to_int()
		if v >= 0x800000:
			v -= 0x1000000
		var frac := 0.0
		if parts.size() > 1:
			frac = parts[1].hex_to_int() / 256.0
		return (v + frac) / 20.0
	return t.to_float() / 20.0


## Runs joined end to end into closed loops (either direction).
static func chain(runs: Array) -> Array:
	var left := runs.duplicate()
	var loops := []
	while not left.is_empty():
		var loop: PackedVector2Array = left.pop_back()
		var grew := true
		while grew and loop[0].distance_to(loop[loop.size() - 1]) > 0.5:
			grew = false
			var end: Vector2 = loop[loop.size() - 1]
			for k in left.size():
				var r: PackedVector2Array = left[k]
				if r[0].distance_to(end) < 0.5:
					loop.append_array(r.slice(1))
				elif r[r.size() - 1].distance_to(end) < 0.5:
					var rr := r.duplicate()
					rr.reverse()
					loop.append_array(rr.slice(1))
				else:
					continue
				left.remove_at(k)
				grew = true
				break
		loops.append(loop)
	return loops


static func area(l: PackedVector2Array) -> float:
	var s := 0.0
	for k in l.size():
		var a := l[k]
		var b := l[(k + 1) % l.size()]
		s += a.x * b.y - b.x * a.y
	return s * 0.5


# ---------------------------------------------------------------- on her

static var _back := {}   # the backside: {"nodes": [dark, skin], "hidden": [[picture, visible]]}


static func set_on(v: bool) -> void:
	on = v
	if v and (not DevBodyOverlay.ours or g.her == null or not load_template()):
		on = false
	_sync()


static func _sync() -> void:
	var want := on and DevBodyOverlay.ours and g.her != null
	if want and _legs.is_empty():
		if data.has("backside"):
			_build_back()
		for side in ["r", "l"]:
			if data.has("thigh_" + side) and data.has("calf_" + side):
				_build(side)
		_nodes = _legs.get("r", {}).get("nodes", [])
	elif not want and not _legs.is_empty():
		_teardown()
	if want and not _after.is_valid():
		_game_fn = func(_c): DevBodyVector._remember_game()
		Hooks.add_after(&"Her.updateElements", _game_fn, "vectorleg", 10)
		_after = func(_c): DevBodyVector._update()
		Hooks.add_after(&"Her.updateElements", _after, "vectorleg", 99)
	elif not want and _after.is_valid():
		Hooks.remove(&"Her.updateElements", _game_fn)
		Hooks.remove(&"Her.updateElements", _after)
		_game_fn = Callable()
		_after = Callable()
	if want:
		_remember_game()
		_update()


## The draw order, like the game's (the thigh over the calf): each part's outline - its silhouette grown by OUTLINE
## (a filled shape: crisp, one draw) - then its skin over it. Near the knee a patch of calf skin over the thigh's
## outline hides the thigh's edge where it lies inside the calf (the knee unfolded); further down the shin it still
## shows, as in the game's kneeling. The backside (her far buttock, on her pelvis) under the thighs: the thigh's
## edge over it is the crease under the buttock.
enum { CALF_DARK, CALF_SKIN, THIGH_DARK, PATCH, THIGH_SKIN }
const OUTLINE := 2.4
const FOLD_REST := 134.0   # the knee's fold in the template (thigh to calf, degrees): she kneels
# The shape once the leg is straight (by how far the knee unfolds), thigh pixels at rest:
const CALF_THIN := 0.10    # the calf thins this much mid calf ...
const SHIN_THIN := 0.07    # ... and the shin under the knee this much (a narrower bone line)
const KNEECAP := 6.0       # the kneecap comes out, a little below the joint ...
const KNEECAP_DROP := 28.0
const KNEE_BACK := 9.0     # ... and the back of the knee goes in (the hollow behind it)
const THIGH_END := 22.0    # the thigh's rounded end (drawn to cover a folded calf) goes into the calf
const KNEE_ZONE := 120.0
const HIP_ZONE := 210.0    # the top of the thigh held by her pelvis: from the hip down this far ...
const HIP_HOLD := 0.6      # ... at most this share of the thigh's turn ...
const HIP_HOLD_MAX := 20.0 # ... and never more than this (degrees: a far turn bends the thigh's front, so the
                           # buttock goes with the thigh there)


## Where a leg is drawn and its pictures: the right one in her torso, the left one in her, each just before the
## group (or container) its thigh is drawn in - a group draws into a texture the size of the game's pictures, which
## would cut ours off. [parent, index, thigh, calf, calf's container or null]
static func _where(side: String) -> Array:
	var h = g.her
	var leg = h.torso.leg if side == "r" else h.leftLegContainer.leg
	var parent: Node = h.torso if side == "r" else h
	var n: Node = leg
	while n.get_parent() != parent and n.get_parent() != null:
		n = n.get_parent()
	if side == "r":
		return [parent, n.get_index(), leg, h.torso.rightCalfContainer.calf, h.torso.rightCalfContainer]
	return [parent, n.get_index(), leg, leg.calf, null]


## Her thigh and calf transforms in the leg's drawing space.
static func _bones(side: String) -> Array:
	var w := _where(side)
	var parent: Node = w[0]
	var tt: Transform2D = w[2].transform
	var n: Node = w[2].get_parent()
	while n != parent and n is Node2D:
		tt = (n as Node2D).transform * tt
		n = n.get_parent()
	var tc: Transform2D = (w[4].transform * w[3].transform) if w[4] != null else (tt * w[3].transform)
	return [tt, tc]


static func _poly(dark: bool) -> Polygon2D:
	var n := Polygon2D.new()
	n.color = LINE if dark else FILL
	n.antialiased = true
	return n


static func _build(side: String) -> void:
	var w := _where(side)
	var parent: Node = w[0]
	var nodes := []
	for k in 5:
		var n: Node2D
		if k == PATCH:
			n = Node2D.new()
			var sd := side
			n.draw.connect(func(): DevBodyVector._draw_patch(sd, n))
		else:
			n = _poly(k in [CALF_DARK, THIGH_DARK])
		n.name = "VectorLeg%s%d" % [side, k]
		parent.add_child(n)
		parent.move_child(n, w[1] + k)
		nodes.append(n)
	# the game's skin pictures hidden (their own shader ignores modulate, so see-through would not do)
	_legs[side] = {"nodes": nodes, "hidden": _hide([w[2].thigh, _skin(w[3])]), "patch": []}


## Her backside from the template, in her torso where the game's is (its picture hidden).
static func _build_back() -> void:
	var b = g.her.torso.backside
	var parent: Node = b.get_parent()
	var at: int = b.get_index()
	var nodes := [_poly(true), _poly(false)]
	for k in 2:
		nodes[k].name = "VectorBackside%d" % k
		parent.add_child(nodes[k])
		parent.move_child(nodes[k], at + k)
	_back = {"nodes": nodes, "hidden": _hide([b])}


static func _hide(pics: Array) -> Array:
	var out := []
	for pic in pics:
		if pic != null and pic.visible:
			out.append([pic, true])
			pic.visible = false
	return out


## The calf's skin picture: its first shape (the second is the highlight).
static func _skin(calf) -> Node:
	for c in calf.get_children():
		if c is FlashShape:
			return c
	return null


static func _teardown() -> void:
	var all := _legs.values()
	if not _back.is_empty():
		all.append(_back)
	for part in all:
		for n in part["nodes"]:
			if is_instance_valid(n):
				n.queue_free()
		for hp in part["hidden"]:
			if is_instance_valid(hp[0]):
				hp[0].visible = hp[1]
	_legs.clear()
	_back = {}
	_nodes = []
	_game.clear()


## Right after the game's updateElements, before our rings and loose legs turn them: where the game put each thigh.
static func _remember_game() -> void:
	if g.her == null:
		return
	for side in _legs:
		_game[side] = _bones(side)[0]


## Each tick after the game's updateElements and ours: every leg placed by its bones.
static func _update() -> void:
	if g.her == null or not DevBodyOverlay.ours:
		_sync()
		return
	if not _back.is_empty():
		var bt: Transform2D = g.her.torso.backside.transform
		var bk := PackedVector2Array()
		for q in data["backside"]["sil"]:
			bk.append(bt * q)
		_back["nodes"][0].polygon = _grown(bk, OUTLINE * bt.get_scale().x)
		_back["nodes"][1].polygon = bk
	for side in _legs:
		var b := _bones(side)
		var tt: Transform2D = b[0]
		var tc: Transform2D = b[1]
		var tg: Transform2D = _game.get(side, tt)
		var ankle: Vector2 = DevBodyOverlay.mark("ankle_" + side)
		var u := unfold(tt, tc, ankle)
		var nodes: Array = _legs[side]["nodes"]
		var calf := _skin_pts(data["calf_" + side]["sil"], tt, tc, true, u, tg, ankle)
		var thigh := _skin_pts(data["thigh_" + side]["sil"], tt, tc, false, u, tg, ankle)
		var wd: float = OUTLINE * tt.get_scale().x
		nodes[CALF_DARK].polygon = _grown(calf, wd)
		nodes[CALF_SKIN].polygon = calf
		nodes[THIGH_DARK].polygon = _grown(thigh, wd)
		nodes[THIGH_SKIN].polygon = thigh
		var knee: Vector2 = tt * KNEE
		var r: float = BLEND * 1.2 * tt.get_scale().x
		var circle := PackedVector2Array()
		for k in 24:
			circle.append(knee + Vector2.from_angle(TAU * k / 24.0) * r)
		_legs[side]["patch"] = Geometry2D.intersect_polygons(calf, circle)
		nodes[PATCH].queue_redraw()


## How far the knee has unfolded: 0 as she kneels (the template's fold), 1 straight.
static func unfold(tt: Transform2D, tc: Transform2D, ankle: Vector2) -> float:
	var sg := 1.0 if tt.x.cross(tt.y) >= 0.0 else -1.0
	var fold := rad_to_deg(wrapf(tc.basis_xform(ankle).angle() - tt.basis_xform(KNEE).angle(), -PI, PI)) * sg
	return clampf((FOLD_REST - fold) / FOLD_REST, 0.0, 1.0)


## A silhouette grown outward by `w` (the largest piece Clipper gives back).
static func _grown(poly: PackedVector2Array, w: float) -> PackedVector2Array:
	var best := poly
	var best_a := 0.0
	for p in Geometry2D.offset_polygon(poly, w, Geometry2D.JOIN_ROUND):
		var a := absf(area(p))
		if a > best_a:
			best_a = a
			best = p
	return best


static func _draw_patch(side: String, n: Node2D) -> void:
	if not _legs.has(side):
		return
	for poly in _legs[side]["patch"]:
		if poly.size() > 2:
			n.draw_colored_polygon(poly, FILL)


## The knee's shape at rest, by how far it unfolds (`u`), thigh space (the calf's points brought over by KNEE): the
## kneecap comes out a little below the joint, the back of the knee goes in, and the thigh's rounded end (drawn to
## cover a folded calf) goes into the calf.
static func _knee_shape(p: Vector2, u: float, is_calf: bool) -> Vector2:
	if u <= 0.0:
		return Vector2.ZERO
	var axis := KNEE.normalized()                  # along the thigh, hip to knee
	var d := p - KNEE
	var out := Vector2(-axis.y, axis.x)
	if out.dot(d) < 0.0:
		out = -out                                 # away from the thigh's line
	var front := axis.cross(d) < 0.0               # above the line: the front of the thigh (she faces right)
	var res := Vector2.ZERO
	if front:
		var cap := d - axis * KNEECAP_DROP         # the kneecap's centre a little down the leg
		res += out * KNEECAP * u * (1.0 - smoothstep(0.0, KNEE_ZONE * 0.7, cap.length()))
	else:
		res -= out * KNEE_BACK * u * (1.0 - smoothstep(0.0, KNEE_ZONE, d.length()))
		if not is_calf and d.dot(axis) > -30.0:     # the thigh's end behind the knee
			res -= out * THIGH_END * u * (1.0 - smoothstep(0.0, KNEE_ZONE, d.length()))
	return res


## The calf and shin thin toward the calf's line, by how far the knee unfolds: most mid calf, and a narrower shin
## just under the knee.
static func _calf_thin(q: Vector2, u: float, ankle: Vector2) -> Vector2:
	var t := q.dot(ankle) / ankle.length_squared()
	if t <= 0.0 or t >= 1.0 or u <= 0.0:
		return q
	var perp := q - ankle * t
	var k := CALF_THIN * sin(PI * t) + SHIN_THIN * exp(-pow((t - 0.18) / 0.12, 2.0))
	return q - perp * (k * u)


## A turn of `r` radians about the point `c`.
static func _turn(c: Vector2, r: float) -> Transform2D:
	return Transform2D(r, c - c.rotated(r))


## Where a point goes, blending turns rather than places (a blend of places folds the skin when the bones are far
## apart): a point follows its own bone and, near the knee, half the other one's turn about the knee; the top of the
## thigh keeps back part of the thigh's turn from where the game put it (`tg`), about the turn's own centre.
static func _skin_pts(pts: PackedVector2Array, tt: Transform2D, tc: Transform2D, is_calf: bool, u := 0.0,
		tg = null, ankle := Vector2(-486, 61)) -> PackedVector2Array:
	var res := PackedVector2Array()
	res.resize(pts.size())
	var axis := KNEE.normalized()
	var knee_w: Vector2 = tt * KNEE
	var rel := wrapf(tc.get_rotation() - tt.get_rotation(), -PI, PI)   # the calf's turn against the thigh
	var hip_turn := 0.0
	var hip_c := Vector2.ZERO
	if not is_calf and tg != null:
		var dm: Transform2D = tt * (tg as Transform2D).affine_inverse()   # from the game's place to ours
		hip_turn = wrapf(dm.get_rotation(), -PI, PI)
		if absf(hip_turn) > 0.0001:
			var m := Transform2D(dm.x - Vector2(1, 0), dm.y - Vector2(0, 1), Vector2.ZERO)   # (R - I)
			hip_c = -(m.affine_inverse() * dm.origin)                  # its fixed point
	for k in pts.size():
		var q: Vector2 = pts[k]
		if is_calf and u > 0.0:
			q = _calf_thin(q, u, ankle)
		var in_thigh := q + KNEE if is_calf else q          # the point at rest, thigh space
		in_thigh += _knee_shape(in_thigh, u, is_calf)
		var w := 0.5 * (1.0 - smoothstep(0.0, BLEND, in_thigh.distance_to(KNEE)))   # share of the other bone
		var p: Vector2
		if is_calf:
			p = _turn(knee_w, -rel * w) * (tc * (in_thigh - KNEE))
		else:
			p = _turn(knee_w, rel * w) * (tt * in_thigh)
			if hip_turn != 0.0:
				var hold := HIP_HOLD * (1.0 - smoothstep(0.0, HIP_ZONE, in_thigh.dot(axis)))
				if hold > 0.0:
					var back := clampf(hip_turn * hold, -deg_to_rad(HIP_HOLD_MAX), deg_to_rad(HIP_HOLD_MAX))
					p = _turn(hip_c, -back) * p
		res[k] = p
	return res
