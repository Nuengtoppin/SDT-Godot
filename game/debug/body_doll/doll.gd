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


func _ready() -> void:
	for b in find_children("*", "Bone2D", true, false):
		_rest[b] = b.rest.get_rotation()
		if b.has_meta("half_of"):
			_halves[b] = b.get_parent().get_node_or_null(str(b.get_meta("half_of")))
		else:
			_bones.append(b)
	for poly in _pieces():
		if poly.get_bone_count() == 0:
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
		var w := _weights_from_marks(poly)
		if w.is_empty():
			continue
		_apply(poly, skel, w)
		var twin := get_node_or_null(NodePath(str(poly.name) + "_line")) as Polygon2D
		if twin and twin.polygon.size() == poly.polygon.size():
			_apply(twin, skel, w)


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
	# the inside: a first guess from the outline (nearer counts much more), then smoothing with the outline held
	for i in range(nb, n):
		var sw := 0.0
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
	for tri in poly.polygons:
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
