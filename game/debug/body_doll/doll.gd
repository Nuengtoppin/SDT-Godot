@tool
extends Node2D
## The body doll: Dima's pieces on bones (scene made by tools/body_proto/doll.py, kept out of git).
## In the editor: select a Bone2D under Skeleton2D and rotate it (do not move it).
## Running it (F6): drag a bone's ring to turn it around its joint; R resets the pose; M shows / hides the marks.
## A neck (or anything) put under NeckSlot follows the ribcage and draws between the back and the ribcage.
## Bones with metadata "follow" + "ratio" (knee_auto, ankle_auto) carry the joint pieces and turn by that share of
## the named bone (the kneecap: its place stays on the thigh, its turn comes from the calf), also in the editor;
## they cannot be grabbed. "limits" (degrees from rest) bound a dragged bone, shown as a blue arc; the thigh's
## "overflow_to" passes what goes past its limits to the pelvis, which turns around its own axis and carries the hip;
## the pelvis' "keep_upright" turns the lower back back by as much, so the torso stays and the waist bends.
##
## Marks: each piece has Marks with Marker2D children on its outline; a mark's metadata "weights" says how much each
## bone holds the outline there, e.g. {"pelvis": 0.5, "thigh": 0.5}. Between two marks the weights go over along
## the outline: the same weights on both = rigid, different = it bends there. A piece is only its outline loop
## (triangulated each frame, so nothing inside can fold); its "_line" is a Line2D along the same loop.
## To change: reset the pose (all bone rotations 0), move marks along the outline or edit their weights (or add a
## Marker2D with weights), then press "Rebuild weights" on this node. A mark snaps to the nearest outline point.
##
## The thigh (and the kneecap over it) are keyforms: Dima's drawings at three hip angles ("keyforms" metadata);
## the doll interpolates them by the thigh's angle, nothing in them is bent by weights (1/2/3 jump to the drawn
## poses, G shows the drawings).
##
## Skinning: done here on the CPU with dual quaternions (a bend keeps its thickness; Polygon2D's own skinning mixes
## matrices, which shrinks a bend), from the "weights" metadata the marks give.
##
## Poses: a piece with metadata "poses" (Dima's drawings of the leg in other poses: hip and knee angles and the drawn
## outline) gets a corrective per pose on rebuild: the outline is matched to the drawing (both in rest space, in
## order along the loops) and the change is kept in rest space ("pose_deltas"). Running, the thigh's and calf's angles pick
## the mix: rest and each drawn pose by how near their angles are (1 / distance squared).

const PICK := 24.0        # px: how close to a handle a press must be
const DEAD := 12.0        # px: no turning this close to the joint (the angle jumps there)
const MAX_STEP := 40.0    # degrees per mouse move at most
const HANDLE_AT := 0.6    # the handle sits this far along the bone

@export_tool_button("Rebuild weights") var rebuild_button = rebuild_weights

var _bones: Array[Bone2D] = []
var _rest := {}
var _drag: Bone2D
var _last := Vector2.ZERO
var _overlay: Node2D
var _halves := {}   # joint bone -> the bone it follows by half
var _show_marks := true
var _show_ghosts := false
var _last_sig := ""


func _ready() -> void:
	for b in find_children("*", "Bone2D", true, false):
		_rest[b] = b.rest.get_rotation()
		var follow := str(b.get_meta("follow", b.get_meta("half_of", "")))
		if follow != "":
			_halves[b] = b.get_parent().get_node_or_null(follow)
		else:
			_bones.append(b)
	for poly in _pieces() + _key_pieces():
		if (poly.has_node("Marks") and not poly.has_meta("weights")) or (poly.has_meta("poses") and not poly.has_meta("pose_deltas")) \
				or (poly.has_meta("keyforms") and not poly.has_meta("rest_tris")):
			rebuild_weights()
			break
	if Engine.is_editor_hint():
		return
	_overlay = Node2D.new()
	_overlay.z_index = 100
	add_child(_overlay)
	_overlay.draw.connect(_draw_overlay)
	var hint := Label.new()
	hint.text = "Drag a ring to turn its bone. R - reset, M - marks, 1/2/3 - the drawn thigh poses, G - the drawings."
	hint.position = Vector2(12, 8)
	var layer := CanvasLayer.new()
	layer.add_child(hint)
	add_child(layer)
	_fit()
	get_viewport().size_changed.connect(_fit)


func _process(_delta: float) -> void:
	for j in _halves:
		var n: Bone2D = _halves[j]
		if n:
			j.rotation = _rest[j] + float(j.get_meta("ratio", 0.5)) * (n.rotation - _rest[n])
	_skin_all()
	if Engine.is_editor_hint():
		return
	_overlay.queue_redraw()


func _fit() -> void:
	# the body in template space spans about (-530, -520)..(300, 400); leave room for a turned leg
	var vs := get_viewport_rect().size
	var s := minf(vs.x / 1150.0, vs.y / 1200.0)
	scale = Vector2(s, s)
	position = vs * 0.5 - Vector2(-120, -40) * s


# --- weights from the marks

func _pieces() -> Array[Polygon2D]:
	var out: Array[Polygon2D] = []
	for c in get_children():
		if c is Polygon2D and c.has_node("Marks"):
			out.append(c)
	return out


func rebuild_weights() -> void:
	for poly in _pieces():
		if not poly.has_meta("rest_polygon"):
			poly.set_meta("rest_polygon", poly.polygon)
		poly.polygon = poly.get_meta("rest_polygon")
		var w := _weights_from_marks(poly)
		if w.is_empty():
			continue
		poly.set_meta("weights", w)
		var rt := Geometry2D.triangulate_polygon(poly.polygon)   # kept for a frame whose loop crosses itself
		poly.set_meta("rest_tris", rt)
		if poly.has_meta("poses"):
			poly.set_meta("pose_deltas", _pose_deltas(poly))
	for poly in _key_pieces():
		poly.set_meta("rest_tris", Geometry2D.triangulate_polygon((poly.get_meta("keyforms")["shapes"] as Array)[0]))
	_last_sig = ""


func _marks(poly: Polygon2D, nb: int) -> Array:
	var V := poly.polygon
	var out := []
	for m in poly.get_node("Marks").get_children():
		var mk := m as Node2D
		if mk == null or not mk.has_meta("weights"):
			continue
		var best := 0
		var bd := INF
		for i in nb:
			var d := V[i].distance_squared_to(mk.position)
			if d < bd:
				bd = d
				best = i
		mk.set_meta("vertex", best)
		out.append([best, mk.get_meta("weights")])
	out.sort_custom(func(a, b): return a[0] < b[0])
	return out


func _weights_from_marks(poly: Polygon2D) -> Dictionary:
	var V := poly.polygon
	var n := V.size()
	var nb := n - poly.internal_vertex_count
	var marks := _marks(poly, nb)
	if marks.is_empty():
		return {}
	var names: Array[String] = []
	for m in marks:
		for k in m[1]:
			if not names.has(str(k)):
				names.append(str(k))
	var K := names.size()
	var W := PackedFloat32Array()
	W.resize(n * K)
	# the outline: from mark to mark along the arc
	var arc := PackedFloat32Array()
	arc.resize(nb + 1)
	for i in nb:
		arc[i + 1] = arc[i] + V[i].distance_to(V[(i + 1) % nb])
	var total := arc[nb]
	var mc := marks.size()
	for i in nb:
		var j := mc - 1
		for q in mc:
			if marks[q][0] <= i:
				j = q
		var a: Array = marks[j]
		var b: Array = marks[(j + 1) % mc]
		var span := fposmod(arc[b[0]] - arc[a[0]], total)
		var t := 0.0 if span <= 0.0 else fposmod(arc[i] - arc[a[0]], total) / span
		for k in K:
			W[i * K + k] = lerpf(float(a[1].get(names[k], 0.0)), float(b[1].get(names[k], 0.0)), t)
	var out := {}
	for k in K:
		var col := PackedFloat32Array()
		col.resize(n)
		for i in n:
			var sum := 0.0
			for q in K:
				sum += W[i * K + q]
			col[i] = W[i * K + k] / maxf(sum, 0.000001)
		out[names[k]] = col
	return out


# --- poses: correctives from Dima's drawings

func _pose_xf(b: Bone2D, angles: Dictionary) -> Transform2D:
	var local := Transform2D(b.rest.get_rotation() + float(angles.get(str(b.name), 0.0)), b.rest.origin)
	return local if not (b.get_parent() is Bone2D) else _pose_xf(b.get_parent(), angles) * local


func _pose_angles(hip_deg: float, knee_deg: float) -> Dictionary:
	return {"thigh": deg_to_rad(hip_deg), "calf": deg_to_rad(knee_deg), "knee_auto": deg_to_rad(knee_deg) * 0.5}


func _pose_deltas(poly: Polygon2D) -> Array:
	var pw := _piece_weights(poly)
	var rest: PackedVector2Array = poly.get_meta("rest_polygon")
	var n := rest.size()
	var nb := n - poly.internal_vertex_count
	var out := []
	for pose in poly.get_meta("poses"):
		var moves := _bone_moves(_pose_angles(float(pose["hip"]), float(pose["knee"])))
		var M: Array[Transform2D] = []
		for i in nb:
			M.append(_blend(moves, pw[0], pw[1], i))
		var target := _match_outline(rest, nb, M, pose["outline"])
		var D := PackedFloat32Array()
		D.resize(n * 2)
		for i in nb:
			var r := M[i].affine_inverse() * target[i] - rest[i]
			D[i * 2] = r.x
			D[i * 2 + 1] = r.y
		var dl := PackedVector2Array()
		dl.resize(n)
		for i in n:
			dl[i] = Vector2(D[i * 2], D[i * 2 + 1])
		out.append(dl)
	return out


func _area(P: PackedVector2Array) -> float:
	var a := 0.0
	for i in P.size():
		a += P[i].cross(P[(i + 1) % P.size()])
	return a * 0.5


func _match_outline(rest: PackedVector2Array, nb: int, M: Array[Transform2D], drawn: PackedVector2Array) -> PackedVector2Array:
	# Which drawn point each outline point of the piece goes to. The drawing is first taken back to rest space (each
	# drawn point by the bones of the piece's outline point nearest to it in the pose), so both loops lie nearly on
	# top of each other; then they are matched in order (dynamic time warping: nothing goes back along the drawing,
	# nothing is skipped), starting from the drawn point nearest the first outline point.
	var pred := PackedVector2Array()
	pred.resize(nb)
	for i in nb:
		pred[i] = M[i] * rest[i]
	var m := drawn.size()
	var back := PackedVector2Array()
	back.resize(m)
	for k in m:
		var best := 0
		var bd := INF
		for i in nb:
			var d := pred[i].distance_squared_to(drawn[k])
			if d < bd:
				bd = d
				best = i
		back[k] = M[best].affine_inverse() * drawn[k]
	var rev := signf(_area(back)) != signf(_area(rest.slice(0, nb)))
	var start := 0
	var sd := INF
	for k in m:
		var d := back[k].distance_squared_to(rest[0])
		if d < sd:
			sd = d
			start = k
	var order := PackedInt32Array()
	order.resize(m)
	for k in m:
		order[k] = posmod(start - k, m) if rev else (start + k) % m
	var cost := PackedFloat32Array()
	cost.resize(nb * m)
	for i in nb:
		for k in m:
			var best := 0.0
			if i > 0 and k > 0:
				best = minf(cost[(i - 1) * m + k - 1], minf(cost[(i - 1) * m + k], cost[i * m + k - 1]))
			elif i > 0:
				best = cost[(i - 1) * m + k]
			elif k > 0:
				best = cost[i * m + k - 1]
			cost[i * m + k] = rest[i].distance_to(back[order[k]]) + best
	var first := PackedInt32Array()
	var last := PackedInt32Array()
	first.resize(nb)
	last.resize(nb)
	first.fill(m)
	last.fill(-1)
	var i := nb - 1
	var k := m - 1
	while true:
		first[i] = mini(first[i], k)
		last[i] = maxi(last[i], k)
		if i == 0 and k == 0:
			break
		if i == 0:
			k -= 1
		elif k == 0:
			i -= 1
		else:
			var dg := cost[(i - 1) * m + k - 1]
			var up := cost[(i - 1) * m + k]
			var lf := cost[i * m + k - 1]
			if dg <= up and dg <= lf:
				i -= 1
				k -= 1
			elif up <= lf:
				i -= 1
			else:
				k -= 1
	var out := PackedVector2Array()
	out.resize(nb)
	for q in nb:
		out[q] = drawn[order[(first[q] + last[q]) / 2]]
	return out


# --- skinning on the CPU (dual quaternions) with the pose correctives

func _bone_moves(angles = null) -> Dictionary:
	# each bone's move from rest in skeleton space, as a rigid motion: [rotor cos(a/2), sin(a/2), dual dx, dy]
	# (planar dual quaternion). angles: null = the bones as they are now, else a pose (bone name -> extra rotation)
	var skel := get_node("Skeleton2D") as Skeleton2D
	var inv := skel.global_transform.affine_inverse()
	var out := {}
	for b in skel.find_children("*", "Bone2D", true, false):
		var cur: Transform2D = inv * b.global_transform if angles == null else _pose_xf(b, angles)
		var d := cur * _skel_rest(b).affine_inverse()
		var h := d.get_rotation() * 0.5
		var c := cos(h)
		var s := sin(h)
		var t := d.origin
		out[str(b.name)] = PackedFloat32Array([c, s, 0.5 * (t.x * c + t.y * s), 0.5 * (-t.x * s + t.y * c)])
	return out


func _blend(moves: Dictionary, names: Array, W: PackedFloat32Array, i: int) -> Transform2D:
	# dual quaternion blending: mixes rotations as rotations, so a bend keeps its thickness (a plain mix of
	# matrices shrinks it, and a 0.5 / 0.5 mix over a big angle almost collapses)
	var K := names.size()
	var c := 0.0
	var s := 0.0
	var dx := 0.0
	var dy := 0.0
	var c0 := 0.0
	var s0 := 0.0
	for k in K:
		var w := W[i * K + k]
		if w <= 0.0:
			continue
		var q: PackedFloat32Array = moves[names[k]]
		if c == 0.0 and s == 0.0:
			c0 = q[0]
			s0 = q[1]
		var sg := 1.0 if q[0] * c0 + q[1] * s0 >= 0.0 else -1.0
		c += w * sg * q[0]
		s += w * sg * q[1]
		dx += w * sg * q[2]
		dy += w * sg * q[3]
	var n := sqrt(c * c + s * s)
	if n < 0.000001:
		return Transform2D.IDENTITY
	c /= n
	s /= n
	dx /= n
	dy /= n
	var t := Vector2(2.0 * (c * dx - s * dy), 2.0 * (s * dx + c * dy))
	return Transform2D(2.0 * atan2(s, c), t)


func _piece_weights(poly: Polygon2D) -> Array:
	# [bone names, flat weights n * K] from the "weights" metadata
	var w: Dictionary = poly.get_meta("weights")
	var names := w.keys()
	var n: int = (w[names[0]] as PackedFloat32Array).size()
	var K := names.size()
	var W := PackedFloat32Array()
	W.resize(n * K)
	for k in K:
		var col: PackedFloat32Array = w[names[k]]
		for i in n:
			W[i * K + k] = col[i]
	return [names, W]


func _signature() -> String:
	var parts := PackedStringArray()
	for b in find_children("*", "Bone2D", true, false):
		parts.append(str(snappedf(b.rotation, 0.0001)))
	return ",".join(parts)


func _skin_all() -> void:
	var sig := _signature()
	if sig == _last_sig:
		return
	_last_sig = sig
	var skel := get_node_or_null("Skeleton2D") as Skeleton2D
	if skel == null:
		return
	var moves := _bone_moves()
	var thigh := skel.find_child("thigh", true, false) as Bone2D
	var calf := skel.find_child("calf", true, false) as Bone2D
	var now := Vector2.ZERO
	if thigh and calf:
		now = Vector2(rad_to_deg(thigh.rotation - thigh.rest.get_rotation()), rad_to_deg(calf.rotation - calf.rest.get_rotation()))
	for poly in _pieces():
		if not (poly.has_meta("weights") and poly.has_meta("rest_polygon")):
			continue
		var rest: PackedVector2Array = poly.get_meta("rest_polygon")
		var V := rest.duplicate()
		if poly.has_meta("pose_deltas"):
			var mix := _pose_mix(poly.get_meta("poses"), now)
			var deltas: Array = poly.get_meta("pose_deltas")
			for q in deltas.size():
				if mix[q] <= 0.0:
					continue
				var dl: PackedVector2Array = deltas[q]
				for i in V.size():
					V[i] += dl[i] * mix[q]
		var pw := _piece_weights(poly)
		var out := PackedVector2Array()
		out.resize(V.size())
		for i in V.size():
			out[i] = _blend(moves, pw[0], pw[1], i) * V[i]
		_set_shape(poly, out)
	var pelvis_move := _move_xf(moves["pelvis"]) if moves.has("pelvis") else Transform2D.IDENTITY
	var hip := _hip_deg()
	for poly in _key_pieces():
		var shape := _key_shape(poly.get_meta("keyforms"), hip)
		for i in shape.size():
			shape[i] = pelvis_move * shape[i]
		_set_shape(poly, shape)


func _pose_mix(poses: Array, now: Vector2) -> PackedFloat32Array:
	# how much of each drawn pose: rest and the poses by 1 / distance squared of the (hip, knee) angles
	var raw := PackedFloat32Array()
	var sum := 0.0
	var exact := -1
	for q in poses.size() + 1:
		var at := Vector2.ZERO if q == 0 else Vector2(float(poses[q - 1]["hip"]), float(poses[q - 1]["knee"]))
		var d2 := now.distance_squared_to(at)
		if d2 < 0.25:
			exact = q
		raw.append(1.0 / maxf(d2, 0.25))
		sum += raw[q]
	var out := PackedFloat32Array()
	for q in range(1, raw.size()):
		out.append((1.0 if exact == q else 0.0) if exact >= 0 else raw[q] / sum)
	return out


# --- keyform pieces: the thigh from Dima's drawings

func _key_pieces() -> Array[Polygon2D]:
	var out: Array[Polygon2D] = []
	for c in get_children():
		if c is Polygon2D and c.has_meta("keyforms"):
			out.append(c)
	return out


func _key_shape(kf: Dictionary, deg: float) -> PackedVector2Array:
	# Dima's drawings at their hip angles; between two of them each point goes around the hip (radius and angle
	# mixed), close to the hip straight; past the first / last drawing that drawing turns as a whole
	var angles: PackedFloat32Array = kf["angles"]
	var shapes: Array = kf["shapes"]
	var hip: Vector2 = kf["pivot"]
	var last := angles.size() - 1
	if deg <= angles[0] or deg >= angles[last]:
		var q := 0 if deg <= angles[0] else last
		var base: PackedVector2Array = shapes[q]
		var turn := Transform2D(deg_to_rad(deg - angles[q]), Vector2.ZERO)
		var out := PackedVector2Array()
		out.resize(base.size())
		for i in base.size():
			out[i] = hip + turn * (base[i] - hip)
		return out
	var j := 0
	while angles[j + 1] < deg:
		j += 1
	var t := (deg - angles[j]) / (angles[j + 1] - angles[j])
	var A: PackedVector2Array = shapes[j]
	var B: PackedVector2Array = shapes[j + 1]
	var res := PackedVector2Array()
	res.resize(A.size())
	for i in A.size():
		var p := A[i] - hip
		var q := B[i] - hip
		var straight := p.lerp(q, t)
		var r := lerpf(p.length(), q.length(), t)
		var a := p.angle() + wrapf(q.angle() - p.angle(), -PI, PI) * t
		var around := Vector2.from_angle(a) * r
		var k := clampf((minf(p.length(), q.length()) - 10.0) / 30.0, 0.0, 1.0)
		res[i] = hip + straight.lerp(around, k)
	return res


func _move_xf(q: PackedFloat32Array) -> Transform2D:
	return Transform2D(2.0 * atan2(q[1], q[0]), Vector2(2.0 * (q[0] * q[2] - q[1] * q[3]), 2.0 * (q[1] * q[2] + q[0] * q[3])))


func _hip_deg() -> float:
	var thigh := get_node("Skeleton2D").find_child("thigh", true, false) as Bone2D
	return rad_to_deg(thigh.rotation - thigh.rest.get_rotation()) if thigh else 0.0


func _set_shape(poly: Polygon2D, out: PackedVector2Array) -> void:
	poly.polygon = out
	var tris := Geometry2D.triangulate_polygon(out)
	if tris.is_empty():   # the loop crosses itself this frame: keep the rest triangles
		tris = poly.get_meta("rest_tris", PackedInt32Array())
	var polys := []
	for t in range(0, tris.size(), 3):
		polys.append(PackedInt32Array([tris[t], tris[t + 1], tris[t + 2]]))
	poly.polygons = polys
	var line := get_node_or_null(NodePath(str(poly.name) + "_line")) as Line2D
	if line:
		line.points = out


# --- running: turning bones with the mouse

func _unhandled_input(e: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	var key := e as InputEventKey
	var button := e as InputEventMouseButton
	var motion := e as InputEventMouseMotion
	if key and key.pressed and key.keycode == KEY_R:
		for b in _bones:
			b.rotation = _rest[b]
	elif key and key.pressed and key.keycode == KEY_M:
		_show_marks = not _show_marks
	elif key and key.pressed and key.keycode == KEY_G:
		_show_ghosts = not _show_ghosts
	elif key and key.pressed and key.keycode >= KEY_1 and key.keycode <= KEY_9:
		var legs := _key_pieces()
		if not legs.is_empty():
			var angles: PackedFloat32Array = legs[0].get_meta("keyforms")["angles"]
			var q := int(key.keycode - KEY_1)
			var thigh := get_node("Skeleton2D").find_child("thigh", true, false) as Bone2D
			if q < angles.size() and thigh:
				thigh.rotation = thigh.rest.get_rotation() + deg_to_rad(angles[q])
	elif button and button.button_index == MOUSE_BUTTON_LEFT:
		_drag = null
		if button.pressed:
			var best := PICK
			for b in _bones:
				var d := button.position.distance_to(_tip(b, HANDLE_AT))
				if d < best:
					best = d
					_drag = b
			_last = button.position
	elif motion and _drag:
		var o := _drag.global_position
		if motion.position.distance_to(o) > DEAD and _last.distance_to(o) > DEAD:
			var step := wrapf((motion.position - o).angle() - (_last - o).angle(), -PI, PI)
			_turn(_drag, clampf(step, -deg_to_rad(MAX_STEP), deg_to_rad(MAX_STEP)))
		_last = motion.position


func _turn(b: Bone2D, step: float) -> void:
	# a turn within the bone's limits ("limits": degrees from rest); with "overflow_to", what goes past them turns
	# that bone (the thigh carries the pelvis on), and turning back first takes the overflow back
	var lim = b.get_meta("limits", null)
	var to: Bone2D = get_node("Skeleton2D").find_child(str(b.get_meta("overflow_to", "")), true, false) as Bone2D if b.has_meta("overflow_to") else null
	if to:
		var held: float = to.rotation - float(_rest[to])
		if held * step < 0.0:   # turning back: the pelvis returns first
			var back := signf(step) * minf(absf(step), absf(held))
			_turn(to, back)
			step -= back
	var before := b.rotation
	if lim == null:
		b.rotation += step
	else:
		var lo: float = _rest[b] + deg_to_rad((lim as Vector2).x)
		var hi: float = _rest[b] + deg_to_rad((lim as Vector2).y)
		b.rotation = clampf(b.rotation + step, lo, hi)
	var want := before + step
	if b.has_meta("keep_upright"):   # the pelvis tilts under the torso: the waist bends, the back stays where it was
		var up := b.find_child(str(b.get_meta("keep_upright")), false, false) as Bone2D
		if up:
			up.rotation -= b.rotation - before
	if lim == null:
		return
	if to and not is_equal_approx(want, b.rotation):
		_turn(to, want - b.rotation)


func _tip(b: Bone2D, t := 1.0) -> Vector2:
	return b.global_transform * (Vector2.RIGHT.rotated(b.get_bone_angle()) * b.get_length() * t)


func _skel_rest(b: Node) -> Transform2D:
	return b.rest if not (b.get_parent() is Bone2D) else _skel_rest(b.get_parent()) * b.rest


func _draw_overlay() -> void:
	var inv := _overlay.get_global_transform().affine_inverse()
	var px := 1.0 / scale.x
	if _show_marks:
		for poly in _pieces():
			for m in poly.get_node("Marks").get_children():
				if not m.has_meta("vertex"):
					continue
				var bend: bool = (m.get_meta("weights") as Dictionary).size() > 1
				var at := inv * (poly.get_global_transform() * poly.polygon[int(m.get_meta("vertex"))])
				_overlay.draw_circle(at, (4.0 if bend else 3.0) * px, Color(0.1, 0.7, 0.25) if bend else Color(0.25, 0.25, 0.3))
	if _show_ghosts:
		var pm := _move_xf(_bone_moves()["pelvis"])
		for poly in _key_pieces():
			for shape in poly.get_meta("keyforms")["shapes"]:
				var pts := PackedVector2Array()
				for p in shape:
					pts.append(inv * (poly.get_global_transform() * (pm * p)))
				pts.append(pts[0])
				_overlay.draw_polyline(pts, Color(0.9, 0.2, 0.3, 0.8), 1.5 * px)
	for b in _bones:
		var o := inv * b.global_position
		var tip := inv * _tip(b)
		var h := inv * _tip(b, HANDLE_AT)
		var col := Color(1.0, 0.5, 0.0, 0.9) if b != _drag else Color(1.0, 0.2, 0.2, 1.0)
		if b == _drag and b.has_meta("limits"):   # the allowed range, as an arc around the joint
			var lim: Vector2 = b.get_meta("limits")
			var base: float = (b.get_parent() as Node2D).global_rotation + float(_rest[b]) + b.get_bone_angle()
			_overlay.draw_arc(o, 40.0 * px, base + deg_to_rad(lim.x), base + deg_to_rad(lim.y), 32, Color(0.3, 0.8, 1.0, 0.8), 3.0 * px)
		_overlay.draw_line(o, tip, col, 2.0 * px)
		_overlay.draw_circle(o, 5.0 * px, col)
		_overlay.draw_arc(h, 9.0 * px, 0.0, TAU, 24, col, 2.0 * px)
