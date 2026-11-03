@tool
extends Node2D
## The body doll: Dima's pieces on bones (scene made by tools/body_proto/doll.py, kept out of git).
## In the editor: select a Bone2D under Skeleton2D and rotate it (do not move it).
## Running it (F6): drag a bone's ring to turn it around its joint; R resets the pose; M shows / hides the marks.
## A neck (or anything) put under NeckSlot follows the ribcage and draws between the back and the ribcage.
## Bones with metadata "half_of" (knee_auto, ankle_auto) carry the joint pieces and turn half as much as the named
## bone, also in the editor; they cannot be grabbed.
##
## Marks: each piece has Marks with Marker2D children on its outline; a mark's metadata "weights" says how much each
## bone holds the outline there, e.g. {"pelvis": 0.5, "thigh": 0.5}. Between two marks the weights go over along
## the outline: the same weights on both = rigid, different = it bends there. The inside follows the outline.
## To change: reset the pose (all bone rotations 0), move marks along the outline or edit their weights (or add a
## Marker2D with weights), then press "Rebuild weights" on this node. A mark snaps to the nearest outline point.
##
## Poses: a piece with metadata "poses" (Dima's drawings of the leg in other poses: hip and knee angles and the drawn
## outline) gets a corrective per pose on rebuild: the outline is matched to the drawing (marks first, then by
## length along it) and the change is kept in rest space ("pose_deltas"). Running, the thigh's and calf's angles pick
## the mix: rest and each drawn pose by how near their angles are (1 / distance squared).

const PICK := 24.0        # px: how close to a handle a press must be
const DEAD := 12.0        # px: no turning this close to the joint (the angle jumps there)
const MAX_STEP := 40.0    # degrees per mouse move at most
const HANDLE_AT := 0.6    # the handle sits this far along the bone
const SMOOTH_PASSES := 80 # smoothing of the inside weights after the first guess

@export_tool_button("Rebuild weights") var rebuild_button = rebuild_weights

var _bones: Array[Bone2D] = []
var _rest := {}
var _drag: Bone2D
var _last := Vector2.ZERO
var _overlay: Node2D
var _halves := {}   # joint bone -> the bone it follows by half
var _show_marks := true
var _last_angles := Vector2(INF, INF)


func _ready() -> void:
	for b in find_children("*", "Bone2D", true, false):
		_rest[b] = b.rest.get_rotation()
		if b.has_meta("half_of"):
			_halves[b] = b.get_parent().get_node_or_null(str(b.get_meta("half_of")))
		else:
			_bones.append(b)
	for poly in _pieces():
		if poly.get_bone_count() == 0 or (poly.has_meta("poses") and not poly.has_meta("pose_deltas")):
			rebuild_weights()
			break
	if Engine.is_editor_hint():
		return
	_overlay = Node2D.new()
	_overlay.z_index = 100
	add_child(_overlay)
	_overlay.draw.connect(_draw_overlay)
	var hint := Label.new()
	hint.text = "Drag a ring to turn its bone. R - reset, M - marks."
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
			j.rotation = _rest[j] + 0.5 * (n.rotation - _rest[n])
	_apply_poses()
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
	var skel := get_node("Skeleton2D") as Skeleton2D
	for poly in _pieces():
		var twin := get_node_or_null(NodePath(str(poly.name) + "_line")) as Polygon2D
		for p in [poly, twin]:
			if p and not p.has_meta("rest_polygon"):
				p.set_meta("rest_polygon", p.polygon)
			if p:
				p.polygon = p.get_meta("rest_polygon")
		var w := _weights_from_marks(poly)
		if w.is_empty():
			continue
		_apply(poly, skel, w)
		if twin and twin.polygon.size() == poly.polygon.size():
			_apply(twin, skel, w)
		if poly.has_meta("poses"):
			poly.set_meta("pose_deltas", _pose_deltas(poly, w))
	_last_angles = Vector2(INF, INF)


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
	W = _fill_inside(V, nb, poly.polygons, W, K)
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


func _fill_inside(V: PackedVector2Array, nb: int, polys: Array, W: PackedFloat32Array, K: int) -> PackedFloat32Array:
	# the inside from the outline: a first guess (nearer outline points count much more), then smoothing with the
	# outline held
	var n := V.size()
	for i in range(nb, n):
		var sw := 0.0
		for k in K:
			W[i * K + k] = 0.0
		for j in nb:
			var d := maxf(V[i].distance_to(V[j]), 0.001)
			var f := 1.0 / (d * d * d)
			sw += f
			for k in K:
				W[i * K + k] += f * W[j * K + k]
		for k in K:
			W[i * K + k] /= sw
	var nbrs := []
	nbrs.resize(n)
	for i in n:
		nbrs[i] = PackedInt32Array()
	for tri in polys:
		for x in 3:
			for y in 3:
				if x != y and not (nbrs[tri[x]] as PackedInt32Array).has(tri[y]):
					nbrs[tri[x]].append(tri[y])
	for _pass in SMOOTH_PASSES:
		for i in range(nb, n):
			var nn: PackedInt32Array = nbrs[i]
			if nn.is_empty():
				continue
			for k in K:
				var s := 0.0
				for j in nn:
					s += W[j * K + k]
				W[i * K + k] = s / nn.size()
	return W


# --- poses: correctives from Dima's drawings

func _pose_xf(b: Bone2D, angles: Dictionary) -> Transform2D:
	var local := Transform2D(b.rest.get_rotation() + float(angles.get(str(b.name), 0.0)), b.rest.origin)
	return local if not (b.get_parent() is Bone2D) else _pose_xf(b.get_parent(), angles) * local


func _pose_angles(hip_deg: float, knee_deg: float) -> Dictionary:
	return {"thigh": deg_to_rad(hip_deg), "calf": deg_to_rad(knee_deg), "knee_auto": deg_to_rad(knee_deg) * 0.5}


func _pose_deltas(poly: Polygon2D, w: Dictionary) -> Array:
	var skel := get_node("Skeleton2D") as Skeleton2D
	var rest: PackedVector2Array = poly.get_meta("rest_polygon")
	var n := rest.size()
	var nb := n - poly.internal_vertex_count
	var anchors := PackedInt32Array()
	for m in poly.get_node("Marks").get_children():
		if m.has_meta("vertex"):
			anchors.append(int(m.get_meta("vertex")))
	var step := maxi(1, nb / 24)
	for i in range(0, nb, step):
		anchors.append(i)
	anchors.sort()
	var out := []
	for pose in poly.get_meta("poses"):
		var angles := _pose_angles(float(pose["hip"]), float(pose["knee"]))
		var mx := PackedVector2Array()
		var my := PackedVector2Array()
		var mo := PackedVector2Array()
		mx.resize(n)
		my.resize(n)
		mo.resize(n)
		for name in w:
			var b := skel.find_child(name, true, false) as Bone2D
			var d := _pose_xf(b, angles) * _skel_rest(b).affine_inverse()
			var col: PackedFloat32Array = w[name]
			for i in n:
				mx[i] += d.x * col[i]
				my[i] += d.y * col[i]
				mo[i] += d.origin * col[i]
		var pred := PackedVector2Array()
		pred.resize(nb)
		for i in nb:
			pred[i] = Transform2D(mx[i], my[i], mo[i]) * rest[i]
		var target := _match_outline(pred, rest, nb, anchors, pose["outline"])
		var D := PackedFloat32Array()
		D.resize(n * 2)
		for i in nb:
			var r := Transform2D(mx[i], my[i], mo[i]).affine_inverse() * target[i] - rest[i]
			D[i * 2] = r.x
			D[i * 2 + 1] = r.y
		D = _fill_inside(rest, nb, poly.polygons, D, 2)
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


func _match_outline(pred: PackedVector2Array, rest: PackedVector2Array, nb: int, anchors: PackedInt32Array,
		drawn: PackedVector2Array) -> PackedVector2Array:
	# each outline point of the piece -> a point on the drawn outline: anchors (marks and evenly spaced points) go to
	# the nearest drawn point, kept only while they move forward along the drawing; the rest by length in between
	var C := drawn.duplicate()
	if signf(_area(C)) != signf(_area(pred)):
		C.reverse()
	var m := C.size()
	var sc := PackedFloat32Array()
	sc.resize(m + 1)
	for i in m:
		sc[i + 1] = sc[i] + C[i].distance_to(C[(i + 1) % m])
	var LC := sc[m]
	var ra := PackedFloat32Array()
	ra.resize(nb + 1)
	for i in nb:
		ra[i + 1] = ra[i] + rest[i].distance_to(rest[(i + 1) % nb])
	var LR := ra[nb]
	var keep_i := PackedInt32Array()
	var keep_u := PackedFloat32Array()
	for a in anchors:
		var best := 0
		var bd := INF
		for j in m:
			var d := C[j].distance_squared_to(pred[a])
			if d < bd:
				bd = d
				best = j
		var u := sc[best]
		if keep_u.is_empty():
			keep_i.append(a)
			keep_u.append(u)
			continue
		var du := fposmod(u - fposmod(keep_u[-1], LC), LC)
		var dr := ra[a] - ra[keep_i[-1]]
		if a != keep_i[-1] and du < LC * 0.5 and du < (dr / LR) * LC * 3.0 + 30.0:
			keep_i.append(a)
			keep_u.append(keep_u[-1] + du)
	var out := PackedVector2Array()
	out.resize(nb)
	var kc := keep_i.size()
	for q in kc:
		var a := keep_i[q]
		var b := keep_i[(q + 1) % kc]
		var ua := keep_u[q]
		var ub := keep_u[(q + 1) % kc] if q + 1 < kc else keep_u[0] + LC
		var span := fposmod(ra[b] - ra[a], LR) if kc > 1 else LR
		var i := a
		while true:
			var t := 0.0 if span <= 0.0 else fposmod(ra[i] - ra[a], LR) / span
			out[i] = _at(C, sc, fposmod(lerpf(ua, ub, t), LC))
			i = (i + 1) % nb
			if i == b:
				break
	return out


func _at(C: PackedVector2Array, sc: PackedFloat32Array, u: float) -> Vector2:
	var j := clampi(sc.bsearch(u, true) - 1, 0, C.size() - 1)
	var seg := sc[j + 1] - sc[j]
	var t := 0.0 if seg <= 0.0 else (u - sc[j]) / seg
	return C[j].lerp(C[(j + 1) % C.size()], t)


func _apply_poses() -> void:
	var skel := get_node_or_null("Skeleton2D")
	if skel == null:
		return
	var thigh := skel.find_child("thigh", true, false) as Bone2D
	var calf := skel.find_child("calf", true, false) as Bone2D
	if thigh == null or calf == null:
		return
	var now := Vector2(rad_to_deg(thigh.rotation - thigh.rest.get_rotation()), rad_to_deg(calf.rotation - calf.rest.get_rotation()))
	if now.is_equal_approx(_last_angles):
		return
	_last_angles = now
	for poly in _pieces():
		if not (poly.has_meta("pose_deltas") and poly.has_meta("rest_polygon")):
			continue
		var poses: Array = poly.get_meta("poses")
		var deltas: Array = poly.get_meta("pose_deltas")
		var mix := PackedFloat32Array()   # rest first, then each pose
		var sum := 0.0
		var exact := -1
		for q in poses.size() + 1:
			var at := Vector2.ZERO if q == 0 else Vector2(float(poses[q - 1]["hip"]), float(poses[q - 1]["knee"]))
			var d2 := now.distance_squared_to(at)
			if d2 < 0.25:
				exact = q
			mix.append(1.0 / maxf(d2, 0.25))
			sum += mix[q]
		var rest: PackedVector2Array = poly.get_meta("rest_polygon")
		var V := rest.duplicate()
		for q in range(1, mix.size()):
			var f := (1.0 if exact == q else 0.0) if exact >= 0 else mix[q] / sum
			if f <= 0.0:
				continue
			var dl: PackedVector2Array = deltas[q - 1]
			for i in V.size():
				V[i] += dl[i] * f
		poly.polygon = V
		var twin := get_node_or_null(NodePath(str(poly.name) + "_line")) as Polygon2D
		if twin and twin.has_meta("rest_polygon"):
			var TV: PackedVector2Array = (twin.get_meta("rest_polygon") as PackedVector2Array).duplicate()
			for i in TV.size():
				TV[i] += V[i] - rest[i]
			twin.polygon = TV


func _apply(poly: Polygon2D, skel: Skeleton2D, w: Dictionary) -> void:
	poly.clear_bones()
	for name in w:
		var bone := skel.find_child(name, true, false) as Bone2D
		if bone == null:
			push_warning("doll: no bone named %s (marks of %s)" % [name, poly.name])
			continue
		poly.add_bone(skel.get_path_to(bone), w[name])


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
			_drag.rotation += clampf(step, -deg_to_rad(MAX_STEP), deg_to_rad(MAX_STEP))
		_last = motion.position


func _tip(b: Bone2D, t := 1.0) -> Vector2:
	return b.global_transform * (Vector2.RIGHT.rotated(b.get_bone_angle()) * b.get_length() * t)


func _skel_rest(b: Node) -> Transform2D:
	return b.rest if not (b.get_parent() is Bone2D) else _skel_rest(b.get_parent()) * b.rest


func _skinned(poly: Polygon2D, i: int, skel: Skeleton2D) -> Vector2:
	# where vertex i is drawn now: the bones' moves since rest, mixed by its weights (as Polygon2D does)
	var v := poly.polygon[i]
	var p := Vector2.ZERO
	var inv := skel.global_transform.affine_inverse()
	for k in poly.get_bone_count():
		var w := poly.get_bone_weights(k)
		if w[i] <= 0.0:
			continue
		var b := skel.get_node(poly.get_bone_path(k)) as Bone2D
		p += w[i] * ((inv * b.global_transform) * _skel_rest(b).affine_inverse() * v)
	return skel.global_transform * p


func _draw_overlay() -> void:
	var inv := _overlay.get_global_transform().affine_inverse()
	var px := 1.0 / scale.x
	if _show_marks:
		var skel := get_node("Skeleton2D") as Skeleton2D
		for poly in _pieces():
			for m in poly.get_node("Marks").get_children():
				if not m.has_meta("vertex"):
					continue
				var bend: bool = (m.get_meta("weights") as Dictionary).size() > 1
				var at := inv * _skinned(poly, int(m.get_meta("vertex")), skel)
				_overlay.draw_circle(at, (4.0 if bend else 3.0) * px, Color(0.1, 0.7, 0.25) if bend else Color(0.25, 0.25, 0.3))
	for b in _bones:
		var o := inv * b.global_position
		var tip := inv * _tip(b)
		var h := inv * _tip(b, HANDLE_AT)
		var col := Color(1.0, 0.5, 0.0, 0.9) if b != _drag else Color(1.0, 0.2, 0.2, 1.0)
		_overlay.draw_line(o, tip, col, 2.0 * px)
		_overlay.draw_circle(o, 5.0 * px, col)
		_overlay.draw_arc(h, 9.0 * px, 0.0, TAU, 24, col, 2.0 * px)
