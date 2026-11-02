class_name DevBodyVector
extends RefCounted
## Body > Legs > Vector right leg (our layer): her right leg drawn from vector outlines - a mod template's body
## references (an Adobe Animate .fla in the save folder; read here, never shipped) - instead of the game's two
## pictures: thigh and calf each one filled outline with its lines, every point bound to both bones near the knee,
## so the knee bends as one leg with no gap. The outlines' coordinates are the game's own: a template symbol sits
## in its picture's space (the calf 357.4, 286.1 from the thigh, as in the game). Plain fill for now; the game's
## highlights stay. A first step: then the hip with the torso, shape corrections by the knee's angle, the left leg.

const PARTS := {"thigh_r": "Right Thigh Body", "calf_r": "Right Calf Body"}
const SYMBOL_DIR := "LIBRARY/Assets/Template Elements/Body Elements/"
const KNEE := Vector2(357.4, 286.1)   # the calf's place on the thigh (the template's and the game's)
const BLEND := 110.0                  # how far from the knee a point follows both bones
const FILL := Color8(240, 211, 191)
const LINE := Color8(92, 66, 52)
const LINE_W := 2.0

static var on := false
static var data := {}           # part -> {"outer": PackedVector2Array, "lines": [PackedVector2Array]}
static var status := ""         # what the menu shows
static var _nodes := []         # [calf fill, calf lines, thigh fill, thigh lines]
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


## A symbol's shape: its outer outline (the largest closed loop where one side is filled and the other empty) and
## its lines (edges between two different fills: the knee, the toes...). Pixels (XFL counts in 1/20).
static func parse_shape(xml: String) -> Dictionary:
	var outer_runs := []
	var lines := []
	var re := RegEx.new()
	re.compile("<Edge ([^>]*?)edges=\"([^\"]*)\"")
	var f0 := RegEx.new()
	f0.compile("fillStyle0=\"(\\d+)\"")
	var f1 := RegEx.new()
	f1.compile("fillStyle1=\"(\\d+)\"")
	for m in re.search_all(xml):
		var attrs := m.get_string(1)
		var a := f0.search(attrs)
		var c := f1.search(attrs)
		var runs := parse_edges(m.get_string(2))
		if (a == null) != (c == null):
			outer_runs.append_array(runs)
		elif a != null and c != null and a.get_string(1) != c.get_string(1):
			lines.append_array(runs)
	var loops := chain(outer_runs)
	var best := PackedVector2Array()
	var best_a := 0.0
	for l in loops:
		var ar := absf(area(l))
		if ar > best_a:
			best_a = ar
			best = l
	return {"outer": best, "lines": lines}


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


## Our nodes in her torso, where her right thigh sits (the game's skin pictures hidden; its highlights stay).
static func _build() -> void:
	var t = g.her.torso
	var at: int = t.leg.get_index()
	for k in 4:
		var n: Node2D
		if k == 0 or k == 2:
			n = Polygon2D.new()
			(n as Polygon2D).color = FILL
			(n as Polygon2D).antialiased = true
		else:
			n = Node2D.new()
		n.name = "VectorLeg%d" % k
		t.add_child(n)
		t.move_child(n, at + k)
		_nodes.append(n)
	var n1: Node2D = _nodes[1]
	var n3: Node2D = _nodes[3]
	n1.draw.connect(func(): DevBodyVector._draw_lines(1, n1))
	n3.draw.connect(func(): DevBodyVector._draw_lines(3, n3))
	_hidden.clear()
	for p in [t.leg.thigh, _skin(t.rightCalfContainer.calf)]:
		if p != null and p.visible:
			p.visible = false
			_hidden.append(p)


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


static var _drawn := {}   # node index -> [outer (closed), inner lines...] in the torso's space


## Each tick after the game's updateElements (and ours): the outlines placed by her thigh and calf (torso space).
static func _update() -> void:
	if g.her == null or not DevBodyOverlay.ours:
		_sync()
		return
	var t = g.her.torso
	var tt: Transform2D = t.leg.transform
	var tc: Transform2D = t.rightCalfContainer.transform * t.rightCalfContainer.calf.transform
	var thigh := _place(data["thigh_r"], tt, tc, false)
	var calf := _place(data["calf_r"], tt, tc, true)
	_nodes[0].polygon = calf[0]
	_nodes[2].polygon = thigh[0]
	var closed_calf: PackedVector2Array = calf[0].duplicate()
	if closed_calf.size() > 0:
		closed_calf.append(closed_calf[0])
	_drawn[1] = [closed_calf] + calf.slice(1)
	_drawn[3] = _outside(thigh, calf[0], data["thigh_r"])
	_nodes[1].queue_redraw()
	_nodes[3].queue_redraw()


## The thigh's lines (drawn over the calf) without the stretch that lies inside the calf near the knee: at rest the
## thigh's lower edge rests on the calf, and once the knee unfolds it would cross the calf as a stray line.
static func _outside(thigh: Array, calf_poly: PackedVector2Array, rest: Dictionary) -> Array:
	var runs := []
	var sources: Array = [rest["outer"]] + rest["lines"]
	for k in thigh.size():
		var pts: PackedVector2Array = thigh[k]
		var src: PackedVector2Array = sources[k]
		if k == 0 and pts.size() > 0:   # the outline is closed
			pts = pts.duplicate()
			pts.append(pts[0])
			src = src.duplicate()
			src.append(src[0])
		var cur := PackedVector2Array()
		for j in pts.size():
			var hide: bool = src[j].distance_to(KNEE) < BLEND * 1.6 and Geometry2D.is_point_in_polygon(pts[j], calf_poly)
			if hide:
				if cur.size() > 1:
					runs.append(cur)
				cur = PackedVector2Array()
			else:
				cur.append(pts[j])
		if cur.size() > 1:
			runs.append(cur)
	return runs


## Linear blend of the two bones: a point follows its own bone, and near the knee half of it the other one.
static func _place(part: Dictionary, tt: Transform2D, tc: Transform2D, is_calf: bool) -> Array:
	var out := [_skin_pts(part["outer"], tt, tc, is_calf)]
	for l in part["lines"]:
		out.append(_skin_pts(l, tt, tc, is_calf))
	return out


static func _skin_pts(pts: PackedVector2Array, tt: Transform2D, tc: Transform2D, is_calf: bool) -> PackedVector2Array:
	var res := PackedVector2Array()
	res.resize(pts.size())
	for k in pts.size():
		var q: Vector2 = pts[k]
		var in_thigh := q + KNEE if is_calf else q          # the point at rest, thigh space
		var w := 0.5 * (1.0 - smoothstep(0.0, BLEND, in_thigh.distance_to(KNEE)))   # share of the other bone
		var by_thigh: Vector2 = tt * in_thigh
		var by_calf: Vector2 = tc * (in_thigh - KNEE)
		res[k] = by_calf.lerp(by_thigh, w) if is_calf else by_thigh.lerp(by_calf, w)
	return res


static func _draw_lines(idx: int, n: Node2D) -> void:
	var parts: Array = _drawn.get(idx, [])
	if parts.is_empty() or _nodes.is_empty():
		return
	for k in parts.size():
		var pl: PackedVector2Array = parts[k]
		if pl.size() > 1:
			n.draw_polyline(pl, LINE, LINE_W, true)
