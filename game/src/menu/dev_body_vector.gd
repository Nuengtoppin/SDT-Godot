class_name DevBodyVector
extends RefCounted
## Body > Legs > Vector right leg (our layer): her right leg drawn from vector outlines - a mod template's body
## references (an Adobe Animate .fla in the save folder; read here, never shipped) - instead of the game's two
## pictures: thigh and calf each one filled outline with its lines, every point bound to both bones near the knee,
## so the knee bends as one leg with no gap. The outlines' coordinates are the game's own: a template symbol sits
## in its picture's space (the calf 357.4, 286.1 from the thigh, as in the game). Plain fill for now; the game's
## highlights stay. A first step: then the hip with the torso, shape corrections by the knee's angle, the left leg.
## The foot bends with our ankle and toe rings (the game's calf cannot: its foot is part of the one picture): the
## calf's points past the ankle follow the foot, past the ball of the foot the toes, blended across each joint.

const PARTS := {"thigh_r": "Right Thigh Body", "calf_r": "Right Calf Body"}
const SYMBOL_DIR := "LIBRARY/Assets/Template Elements/Body Elements/"
const KNEE := Vector2(357.4, 286.1)   # the calf's place on the thigh (the template's and the game's)
const BLEND := 110.0                  # how far from the knee a point follows both bones
const FOOT_BLEND := 30.0              # how far either side of the ankle a point is shared by shin and foot
const TOE_BLEND := 14.0               # and of the ball of the foot, by foot and toes
const FILL := Color8(240, 211, 191)
const LINE := Color8(92, 66, 52)

static var on := false
static var data := {}           # part -> {"sil": PackedVector2Array}
static var status := ""         # what the menu shows
static var _nodes := []         # in draw order (see the enum below)
static var _after := Callable()
static var _hidden := []        # the game's pictures we hid


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

static func set_on(v: bool) -> void:
	on = v
	if v and (not DevBodyOverlay.ours or g.her == null or not load_template()):
		on = false
	_sync()


static func _sync() -> void:
	var want := on and DevBodyOverlay.ours and g.her != null
	if want and _nodes.is_empty():
		_build()
	elif not want and not _nodes.is_empty():
		_teardown()
	if want and not _after.is_valid():
		_after = func(_c): DevBodyVector._update()
		Hooks.add_after(&"Her.updateElements", _after, "vectorleg", 99)
	elif not want and _after.is_valid():
		Hooks.remove(&"Her.updateElements", _after)
		_after = Callable()
	if want:
		_update()


## The draw order, like the game's (the calf over the thigh: the calf's container comes after her leg group): each
## part's outline - its silhouette grown by OUTLINE (a filled shape: crisp, one draw) - then its skin over it. The
## calf's line along the shin shows over the thigh, as in the game's kneeling; at the knee a patch of thigh skin
## covers the calf's rounded top, so it never shows as a seam.
enum { THIGH_DARK, THIGH_SKIN, CALF_DARK, CALF_SKIN, PATCH }
const OUTLINE := 2.4
const CAP := 15.0   # how far down the calf (from its knee point) the thigh's skin covers the calf's top


## Our nodes in her torso: the thigh's just before her leg group (the group draws into a texture the size of the
## game's pictures, which would cut ours off), the calf's just before the calf's container; the game's skin pictures
## hidden, its highlights (in the group and the container, over ours) stay.
static func _build() -> void:
	var t = g.her.torso
	var anchor: Node = _anchor()
	var at: int = anchor.get_index()
	for k in 5:
		var n: Node2D
		if k == PATCH:
			n = Node2D.new()
			n.draw.connect(func(): DevBodyVector._draw_patch(n))
		else:
			n = Polygon2D.new()
			(n as Polygon2D).color = LINE if k in [CALF_DARK, THIGH_DARK] else FILL
			(n as Polygon2D).antialiased = true
		n.name = "VectorLeg%d" % k
		t.add_child(n)
		t.move_child(n, at + k if k < CALF_DARK else t.rightCalfContainer.get_index())
		_nodes.append(n)
	_hidden.clear()
	for p in [t.leg.thigh, _skin(t.rightCalfContainer.calf)]:
		if p != null and p.visible:
			p.visible = false
			_hidden.append(p)


## Her right thigh in her torso: itself, or the group it is drawn in.
static func _anchor() -> Node:
	var t = g.her.torso
	var n: Node = t.leg
	while n.get_parent() != t and n.get_parent() != null:
		n = n.get_parent()
	return n


## The calf's skin picture: its first shape (the second is the highlight).
static func _skin(calf) -> Node:
	for c in calf.get_children():
		if c is FlashShape:
			return c
	return null


static func _teardown() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	for p in _hidden:
		if is_instance_valid(p):
			p.visible = true
	_hidden.clear()
	_drawn.clear()


static var _drawn := []   # the patch's polygons


## Each tick after the game's updateElements (and ours): the outlines placed by her thigh and calf, torso space.
static func _update() -> void:
	if g.her == null or not DevBodyOverlay.ours:
		_sync()
		return
	var t = g.her.torso
	var tt: Transform2D = t.leg.transform
	var n: Node = t.leg.get_parent()
	while n != t and n is Node2D:
		tt = (n as Node2D).transform * tt
		n = n.get_parent()
	var tc: Transform2D = t.rightCalfContainer.transform * t.rightCalfContainer.calf.transform
	var calf := _skin_pts(data["calf_r"]["sil"], tt, tc, true, _foot())
	var thigh := _skin_pts(data["thigh_r"]["sil"], tt, tc, false)
	var w: float = OUTLINE * tt.get_scale().x
	_nodes[CALF_DARK].polygon = _grown(calf, w)
	_nodes[CALF_SKIN].polygon = calf
	_nodes[THIGH_DARK].polygon = _grown(thigh, w)
	_nodes[THIGH_SKIN].polygon = thigh
	var knee: Vector2 = tt * KNEE
	var r: float = BLEND * 1.2 * tt.get_scale().x
	var circle := PackedVector2Array()
	for k in 24:
		circle.append(knee + Vector2.from_angle(TAU * k / 24.0) * r)
	# the calf's top (behind its knee point, along the calf) inside the thigh: thigh skin over it, so the calf's
	# rounded top never shows as a seam across the knee; the calf's lines along the shin stay (over the thigh)
	var a: Vector2 = DevBodyOverlay.mark("ankle_r").normalized()
	var side := Vector2(-a.y, a.x)
	var cap := PackedVector2Array()
	for c in [a * CAP - side * 400.0, a * CAP + side * 400.0, a * -400.0 + side * 400.0, a * -400.0 - side * 400.0]:
		cap.append(tc * c)
	_drawn = []
	for piece in Geometry2D.intersect_polygons(cap, circle):
		_drawn.append_array(Geometry2D.intersect_polygons(piece, thigh))
	_nodes[PATCH].queue_redraw()


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


static func _draw_patch(n: Node2D) -> void:
	if _nodes.is_empty():
		return
	for poly in _drawn:
		if poly.size() > 2:
			n.draw_colored_polygon(poly, FILL)


## The right foot's bend for the calf's points: [ankle, ball, the foot's turn, the toes' turn] in calf space, or
## empty while the ankle and toes are as drawn.
static func _foot() -> Array:
	if DevBodyRings.turn("ankle_r") == 0.0 and DevBodyRings.turn("toes_r") == 0.0:
		return []
	var f: Array = DevBodyRings.foot_xf("_r")
	return [DevBodyOverlay.mark("ankle_r"), DevBodyOverlay.mark("ball_r"), f[0], f[1]]


## A calf point `q` (calf space) moved with the foot: past the ankle (along the shin, from the knee) by the foot's
## turn, past the ball of the foot (along the foot) by the toes', each blended across its joint.
static func _on_foot(q: Vector2, foot: Array) -> Vector2:
	var ankle: Vector2 = foot[0]
	var ball: Vector2 = foot[1]
	var wf := smoothstep(-FOOT_BLEND, FOOT_BLEND, (q - ankle).dot(ankle.normalized()))
	var wt := smoothstep(-TOE_BLEND, TOE_BLEND, (q - ball).dot((ball - ankle).normalized()))
	return q.lerp(foot[2] * q, wf).lerp(foot[3] * q, wt)


## Linear blend of the two bones: a point follows its own bone, and near the knee half of it the other one; a calf
## point on the foot moved with it first (`foot`: see _foot).
static func _skin_pts(pts: PackedVector2Array, tt: Transform2D, tc: Transform2D, is_calf: bool, foot := []) -> PackedVector2Array:
	var res := PackedVector2Array()
	res.resize(pts.size())
	for k in pts.size():
		var q: Vector2 = pts[k]
		var in_thigh := q + KNEE if is_calf else q          # the point at rest, thigh space
		var w := 0.5 * (1.0 - smoothstep(0.0, BLEND, in_thigh.distance_to(KNEE)))   # share of the other bone
		if is_calf and not foot.is_empty():
			in_thigh = _on_foot(q, foot) + KNEE
		var by_thigh: Vector2 = tt * in_thigh
		var by_calf: Vector2 = tc * (in_thigh - KNEE)
		res[k] = by_calf.lerp(by_thigh, w) if is_calf else by_thigh.lerp(by_calf, w)
	return res
