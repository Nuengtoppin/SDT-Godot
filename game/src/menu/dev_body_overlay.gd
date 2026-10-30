class_name DevBodyOverlay
extends CanvasLayer
## derrdev: debug layers drawn over body parts (developer panel, Body tab). The same four layers for every part:
##   base       the part's source shape, undeformed (cyan)
##   rendered   what is drawn this tick (pink; a second outline such as a highlight in blue)
##   points     the control points (cyan; the second set in blue)
##   axis       axes and bones: the game's in yellow, ours (our body layer) in orange
##   zones      regions along the part (the throat's rings), each in its own colour, and markers on it
## A part is a provider Callable returning {"node": FlashDisplayObject, "base": Array, "rendered": Array,
## "rendered2": Array, "points": Array, "points2": Array, "axes": [[from, to], ...],
## "axes_ours": [[from, to], ...], "replace": bool, "zones": [[from, to, Color, width multiplier], ...],
## "marks": [[point, Color], ...]}, points in the node's own space; "axes_ours" are drawn only while our body layer is
## on (`ours`), and a part whose own bones replace the game's ("replace": true) then hides the game's ("axes");
## a part leaves out what it does not have.
## Drawn in screen space over the game (under the menus), outside the Flash display list: no hit testing, no change
## to what the game draws. Made the first time a layer is switched on; read only.

const LAYERS := ["base", "rendered", "points", "axis", "zones"]
const COLORS := {"base": Color(0.15, 1.0, 0.9), "rendered": Color(1.0, 0.3, 0.75), "rendered2": Color(0.5, 0.65, 1.0),
	"axis": Color(1.0, 0.85, 0.1), "ours": Color(1.0, 0.5, 0.1)}

static var instance: DevBodyOverlay = null
## Our body layer (Body > Her body), for this session: off = the game's body only. Our settings are greyed out
## while it is off.
static var ours := false
static var _on: Dictionary = {}          # "part:layer" -> true
static var line_width := 1.0
static var point_radius := 1.5

var _canvas: Node2D


## Body parts with debug layers, all with the same layers.
static func parts() -> Dictionary:
	return {"neck": func(): return DevBodyOverlay.neck(), "throat": func(): return DevBodyOverlay.throat(),
		"legs": func(): return DevBodyOverlay.legs(), "arms": func(): return DevBodyOverlay.arms(),
		"breasts": func(): return DevBodyOverlay.breasts(), "head": func(): return DevBodyOverlay.head(),
		"legs_ours": func(): return DevBodyOverlay.legs_ours(), "him": func(): return DevBodyOverlay.him(),
		"torso_ours": func(): return DevBodyOverlay.torso_ours(), "arms_ours": func(): return DevBodyOverlay.arms_ours(),
		"head_ours": func(): return DevBodyOverlay.head_ours(), "breasts_ours": func(): return DevBodyOverlay.breasts_ours()}


static func is_on(part: String, layer: String) -> bool:
	return _on.has(part + ":" + layer)


static func set_on(part: String, layer: String, on: bool) -> void:
	if on:
		_on[part + ":" + layer] = true
		_ensure()
	else:
		_on.erase(part + ":" + layer)


static func any_on() -> bool:
	return not _on.is_empty()


static func clear() -> void:
	_on.clear()
	set_pose(false)


static func _ensure() -> void:
	if instance == null:
		instance = DevBodyOverlay.new()
		instance.name = "DevBodyOverlay"
		Flash.add_child(instance)


func _ready() -> void:
	layer = 45   # over the game, under the menus (50) and the FPS counter
	_canvas = Node2D.new()
	_canvas.draw.connect(_draw_parts)
	add_child(_canvas)


func _process(_delta: float) -> void:
	_canvas.visible = (any_on() or (editing and ours)) and g.gameRunning and SDTMenu.dev != null and SDTMenu.dev._enabled()
	if _canvas.visible:
		_canvas.queue_redraw()


func _draw_parts() -> void:
	var stage: Transform2D = Flash.stage.get_global_transform_with_canvas()
	if editing and ours and g.her != null:
		var xf := _her_xf()
		var hover := _drag if _drag != "" else _mark_under(get_viewport().get_mouse_position())
		var font := ThemeDB.fallback_font
		for id in mark_defs():
			var p: Vector2 = xf * mark_at(id)
			_canvas.draw_circle(p, point_radius * (4.0 if id == hover else 3.0), COLORS["ours"])
			if id == hover:
				_canvas.draw_string(font, p + Vector2(8, -6), mark_defs()[id][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	for part in parts():
		if not LAYERS.any(func(l): return is_on(part, l)):
			continue
		var d: Dictionary = parts()[part].call()
		if d.is_empty():
			continue
		var xf: Transform2D = stage * (d["node"] as FlashDisplayObject).flash_global_transform()
		if is_on(part, "base"):
			_poly(xf, d.get("base", []), COLORS["base"])
		if is_on(part, "rendered"):
			_poly(xf, d.get("rendered", []), COLORS["rendered"])
			_poly(xf, d.get("rendered2", []), COLORS["rendered2"])
		if is_on(part, "points"):
			for p in d.get("points", []):
				_canvas.draw_circle(xf * p, point_radius, COLORS["base"])
			for p in d.get("points2", []):
				_canvas.draw_circle(xf * p, point_radius, COLORS["rendered2"])
		if is_on(part, "axis"):
			var kinds := [["axes_ours", "ours"]] if ours else []
			if not (ours and d.get("replace", false)):
				kinds.push_front(["axes", "axis"])
			for k in kinds:
				for a in d.get(k[0], []):
					_canvas.draw_line(xf * a[0], xf * a[1], COLORS[k[1]], line_width, true)
					_canvas.draw_circle(xf * a[0], point_radius * 2.0, COLORS[k[1]])
					_canvas.draw_circle(xf * a[1], point_radius * 2.0, COLORS[k[1]])
		if is_on(part, "zones"):
			for z in d.get("zones", []):
				_canvas.draw_line(xf * z[0], xf * z[1], z[2], line_width * z[3], true)
			for m in d.get("marks", []):
				_canvas.draw_circle(xf * m[0], point_radius * 2.5, m[1])


## A closed outline through `pts` (node space).
func _poly(xf: Transform2D, pts: Array, color: Color) -> void:
	if pts.size() < 2:
		return
	var out := PackedVector2Array()
	for p in pts:
		out.append(xf * p)
	out.append(out[0])
	_canvas.draw_polyline(out, color, line_width, true)


# ---------------------------------------------------------------- parts

## Her neck (obj.her.Neck): base = the respaced source outline, rendered = this tick's outline (throat bulge,
## swallow wave) and the highlight, points = both point sets, axis = neck origin to her torso.
static func neck() -> Dictionary:
	if g.her == null or g.her.head == null:
		return {}
	var n: Neck = g.her.head.neck
	var torso: Vector2 = n.globalToLocal(g.her.torso.localToGlobal(Vector2.ZERO))
	return {"node": n, "base": n.neckPoints, "rendered": n.renderedPoints if not n.renderedPoints.is_empty() else n.neckPoints,
		"rendered2": n.highlightPoints, "points": n.neckPoints, "points2": n.highlightPoints, "axes": [[Vector2.ZERO, torso]]}


## A display object's origin (or `p` in its own space) in her space.
static func _at(o: FlashDisplayObject, p := Vector2.ZERO) -> Vector2:
	return g.her.globalToLocal(o.localToGlobal(p))


## An IK chain (IKController): its three joints as two bones, and where it aims.
static func _chain(ik: IKController) -> Array:
	var j: Array = [_at(ik.s1), _at(ik.s2), _at(ik.s3)]
	var t: Vector2 = j[2]
	if ik.targetPointCoordinateSpace != null:
		t = _at(ik.targetPointCoordinateSpace, ik.targetPoint)
	return [[j[0], j[1]], [j[1], j[2]], t]


## Her legs: the right leg is an IK chain (torso -> thigh -> calf) aimed at the knee target of the pose; the left leg
## is no chain, it copies the right thigh's rotation (x0.95, its own start point), shown as its thigh -> calf.
static func legs() -> Dictionary:
	if g.her == null or g.her.torsoIK == null:
		return {}
	var h = g.her
	var c := _chain(h.torsoIK)
	var left = h.leftLegContainer.leg
	var bones := []
	if not (ours and is_on("torso_ours", "axis")):   # ours replaces the game's torso bone
		bones.append(c[0])
	if not (ours and is_on("legs_ours", "axis")):   # our thighs (from our hips) replace the game's
		bones.append_array([c[1], [_at(left), _at(left.calf)]])
	return {"node": h, "axes": bones, "points": [c[2]]}


# ---------------------------------------------------------------- pose mode (Body > Scene)

## Pose mode: the game frozen (paused) with her arms loose and his hand free, him shown / penis only / hidden, to
## place points and pose her; leaving it puts back everything it changed. Later this moves to our own scene.
const HIM_MODES := ["Shown", "Penis only", "Hidden"]
static var posing := false
static var pose_him := "Penis only"
static var pose_loose := true
static var pose_free := true
static var _saved := {}


static func set_pose(on: bool) -> void:
	if on == posing or g.her == null or g.him == null:
		return
	if on:
		_saved = {"paused": g.gamePaused, "body_hidden": g.him.bodyHidden, "him_visible": g.him.visible,
			"left": g.her.currentLeftArmPosition, "right": g.her.currentRightArmPosition, "his": g.him.currentArmPosition}
		posing = true
		apply_pose()
	else:
		posing = false
		g.gamePaused = false   # the arm lists do nothing while paused
		_arm(func(): return g.her.currentLeftArmPosition, func(): g.inGameMenu.leftArmRightClicked(), _saved["left"], func(): g.inGameMenu.leftArmLeftClicked())
		_arm(func(): return g.her.currentRightArmPosition, func(): g.inGameMenu.rightArmRightClicked(), _saved["right"], func(): g.inGameMenu.rightArmLeftClicked())
		_arm(func(): return g.him.currentArmPosition, func(): g.inGameMenu.hisArmRightClicked(), _saved["his"], func(): g.inGameMenu.hisArmLeftClicked())
		g.him.setBodyHidden(_saved["body_hidden"])
		g.him.visible = _saved["him_visible"]
		g.gamePaused = _saved["paused"]


## The pose settings as they are now (while posing).
static func apply_pose() -> void:
	if not posing:
		return
	g.gamePaused = false   # the arm lists do nothing while paused
	var loose := Her.armPositions.find("Loose")
	_arm(func(): return g.her.currentLeftArmPosition, func(): g.inGameMenu.leftArmRightClicked(),
		loose if pose_loose else _saved["left"], func(): g.inGameMenu.leftArmLeftClicked())
	_arm(func(): return g.her.currentRightArmPosition, func(): g.inGameMenu.rightArmRightClicked(),
		loose if pose_loose else _saved["right"], func(): g.inGameMenu.rightArmLeftClicked())
	_arm(func(): return g.him.currentArmPosition, func(): g.inGameMenu.hisArmRightClicked(),
		Him.armPositions.find("Free") if pose_free else _saved["his"], func(): g.inGameMenu.hisArmLeftClicked())
	g.him.setBodyHidden(pose_him != "Shown")
	g.him.visible = pose_him != "Hidden"
	g.gamePaused = true


## Steps an arrow list until `get` is `want`: its right arrow `step` while below, `back` (its left arrow) while above.
static func _arm(get_fn: Callable, step: Callable, want: int, back := Callable()) -> void:
	for _i in 12:
		var now: int = get_fn.call()
		if now == want:
			return
		if now > want and back.is_valid():
			back.call()
		else:
			step.call()


# ---------------------------------------------------------------- our skeleton points (marks)

## Our skeleton points, each in its own node's space (so it moves with that picture): id -> [label, node fn,
## default fn]. The fitted numbers are FIT (copied from "Copy numbers"); `marks` holds what is set by hand this
## session. Paired parts get a point each: the two sides' pictures are not the same (the left calf's bounds are
## larger than the right one's - its stockings / footwear sit inside it), so one shared point would sit wrong.
## Fitted by Dima on her (30 Oct). hip_l is not in it: unless fitted itself, the left hip moves with the right one
## (the game's left start plus the right hip's shift from the game's right start), so both stay alike.
const FIT := {"hip_r": Vector2(-342, 461), "lumbar": Vector2(-169, 340), "thoracic": Vector2(-56, 180),
	"neck_base": Vector2(-1, 0), "ankle_r": Vector2(-500, 59), "ankle_l": Vector2(-500, 59)}
static var marks := {}
static var editing := false        # Body > Her body > "Edit points": drag them with the left mouse button
static var _drag := ""
const GRAB_PX := 10.0


static func mark_defs() -> Dictionary:
	var h = g.her
	var torso := func(): return h.torso
	var hip_r := func(): return _local(h.torso, h.torso.leg)
	var hip_l := func(): return _local(h.torso, h.leftLegContainer.leg)
	var neck := func(): return _local(h.torso, h.head.neck)
	return {
		"hip_r": ["Right hip", torso, hip_r],
		"hip_l": ["Left hip", torso, func(): return hip_l.call() + (mark("hip_r") - hip_r.call())],
		"lumbar": ["Lumbar", torso, func(): return hip_r.call().lerp(neck.call(), 0.33).round()],   # first guesses
		"thoracic": ["Thoracic", torso, func(): return hip_r.call().lerp(neck.call(), 0.66).round()],
		"neck_base": ["Neck base", torso, func(): return neck.call().round()],
		"shoulder_r": ["Right shoulder", torso, func(): return _local(h.torso, h.rightArmContainer.upperArm).round()],
		"head_pivot": ["Head pivot", func(): return h.head, func(): return Vector2.ZERO],
		"jaw": ["Jaw pivot", func(): return h.head, func(): return _local(h.head, h.head.jaw).round()],
		"throat_top": ["Throat top (chin)", func(): return h.head, func(): return _neck_pt(h.head, 0)],
		"nape_top": ["Nape top (skull)", func(): return h.head, func(): return _neck_pt(h.head, -1)],
		"throat_bottom": ["Throat bottom", torso, func(): return _neck_pt(h.torso, h.head.neck.frontEndPoint)],
		"nape_bottom": ["Nape bottom", torso, func(): return _neck_pt(h.torso, h.head.neck.frontEndPoint + 1)],
		"knee_r": ["Right knee", func(): return h.torso.leg, func(): return _local(h.torso.leg, h.torso.rightCalfContainer.calf).round()],
		"knee_l": ["Left knee", func(): return h.leftLegContainer.leg, func(): return _local(h.leftLegContainer.leg, h.leftLegContainer.leg.calf).round()],
		"breast_r": ["Right breast base", func(): return h.torso.midLayer.rightBreast, func(): return Vector2.ZERO],
		"breast_l": ["Left breast base", func(): return h.torsoBack.leftBreast, func(): return Vector2.ZERO],
		"shoulder_l": ["Left shoulder", torso, func(): return _local(h.torso, h.leftArmContainer.upperArm).round()],
		"ankle_r": ["Right ankle", func(): return h.torso.rightCalfContainer.calf, func(): return (_far_end(h.torso.rightCalfContainer.calf) * 0.8).round()],
		"ankle_l": ["Left ankle", func(): return h.leftLegContainer.leg.calf, func(): return (_far_end(h.leftLegContainer.leg.calf) * 0.8).round()],
	}


## Where `o`'s origin is in `space`'s own coordinates.
static func _local(space: FlashDisplayObject, o: FlashDisplayObject) -> Vector2:
	return space.globalToLocal(o.localToGlobal(Vector2.ZERO))


## The neck outline's point `i` (-1: the last) in `space`'s own coordinates.
static func _neck_pt(space: FlashDisplayObject, i: int) -> Vector2:
	var n: Neck = g.her.head.neck
	var pts: Array = n.neckPoints
	if pts.is_empty():
		return Vector2.ZERO
	return space.globalToLocal(n.localToGlobal(pts[i % pts.size()])).round()


## Her nipple on breast `right` (true) or left, in her space: the game's own nipple picture (and its piercing point
## when it has one), which the game moves with every breast size - so it needs no fitting of ours.
static func nipple_at(right: bool) -> Vector2:
	var h = g.her
	var b = h.torso.midLayer.rightBreast if right else h.torsoBack.leftBreast
	var name := "rightBreast" if right else "leftBreast"
	var n = null
	if b.getChildByName(name):
		n = h.findChild("nipple", b.getChildByName(name))
	if not n:
		var nn = b.nipple
		n = nn.getChildByName("rightNipple" if right else "leftNipple") if nn.getChildByName("rightNipple" if right else "leftNipple") else nn
	var pp := Vector2.ZERO
	if n.getChildByName("piercingPoint"):
		var q = n.getChildByName("piercingPoint")
		pp = Vector2(q.x, q.y)
	return _at(n, pp)


## Mark `id` in its node's own space: as set by hand, else fitted, else its first guess.
static func mark(id: String) -> Vector2:
	if marks.has(id):
		return marks[id]
	if FIT.has(id):
		return FIT[id]
	return mark_defs()[id][2].call()


## Mark `id` in her space (where the layers draw).
static func mark_at(id: String) -> Vector2:
	return _at(mark_defs()[id][1].call(), mark(id))


static func numbers() -> String:
	var out := PackedStringArray()
	for id in mark_defs():
		var p := mark(id)
		out.append('"%s": Vector2(%d, %d),' % [id, int(p.x), int(p.y)])
	return "\n".join(out)


## The menus ask whether the mouse is ours (Flash.mouse_blocker, through DevMenu): while editing, over a point or
## dragging one, the game does not get the press.
static func wants_mouse() -> bool:
	if not (editing and ours and instance != null and g.her != null):
		return false
	return _drag != "" or instance._mark_under(instance.get_viewport().get_mouse_position()) != ""


func _her_xf() -> Transform2D:
	return Flash.stage.get_global_transform_with_canvas() * (g.her as FlashDisplayObject).flash_global_transform()


func _mark_under(screen: Vector2) -> String:
	var xf := _her_xf()
	var best := ""
	var best_d := GRAB_PX
	for id in mark_defs():
		var d := (xf * mark_at(id)).distance_to(screen)
		if d < best_d:
			best_d = d
			best = id
	return best


func _input(e: InputEvent) -> void:
	if not (editing and ours and g.her != null and SDTMenu.dev != null and SDTMenu.dev._enabled()):
		_drag = ""
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_drag = _mark_under(e.position)
		else:
			_drag = ""
	elif e is InputEventMouseMotion and _drag != "":
		var node: FlashDisplayObject = mark_defs()[_drag][1].call()
		var xf := Flash.stage.get_global_transform_with_canvas() * node.flash_global_transform()
		marks[_drag] = (xf.affine_inverse() * e.position).round()


## Our head and neck (orange): the neck bone from the neck base to the head pivot, the jaw from the head pivot; and
## the neck's two lines as their own bones: the throat from the chin to its bottom, the nape from the skull to its
## bottom (two lines with their own ends, not one rigid neck picture).
static func head_ours() -> Dictionary:
	if g.her == null or g.her.head == null:
		return {}
	var hp := mark_at("head_pivot")
	return {"node": g.her, "axes_ours": [[mark_at("neck_base"), hp], [hp, mark_at("jaw")],
		[mark_at("throat_top"), mark_at("throat_bottom")], [mark_at("nape_top"), mark_at("nape_bottom")]]}


## Our breasts (orange): from each breast's base (our point, in the breast picture's space) to the game's nipple -
## the nipple moves with the breast's size, so the bone lengthens with it.
static func breasts_ours() -> Dictionary:
	if g.her == null or g.her.leftBreastController == null:
		return {}
	return {"node": g.her, "axes_ours": [[mark_at("breast_r"), nipple_at(true)], [mark_at("breast_l"), nipple_at(false)]]}


## Our pelvis and spine (orange): the hip axis between both hip joints, then hips -> lumbar -> thoracic -> neck base.
## With it on, the game's one torso bone (the leg chain's first, drawn in Legs) is hidden: ours replaces it.
static func torso_ours() -> Dictionary:
	if g.her == null or g.her.torsoIK == null:
		return {}
	var hr := mark_at("hip_r")
	var hl := mark_at("hip_l")
	var mid := hr.lerp(hl, 0.5)
	return {"node": g.her, "axes_ours": [[hr, hl], [mid, mark_at("lumbar")], [mark_at("lumbar"), mark_at("thoracic")],
		[mark_at("thoracic"), mark_at("neck_base")]]}


## Our calf bones: from her knee to her ankle, right and left (orange). The game has no bone there: the calf is one
## rigid picture with her foot, hung at the knee. The ankles are our skeleton points ankle_r / ankle_l.
static func legs_ours() -> Dictionary:
	if g.her == null or g.her.torsoIK == null:
		return {}
	var h = g.her
	var knees := [mark_at("knee_r"), mark_at("knee_l")]
	return {"node": h, "axes_ours": [[mark_at("hip_r"), knees[0]], [mark_at("hip_l"), knees[1]],
		[knees[0], mark_at("ankle_r")], [knees[1], mark_at("ankle_l")]]}


## Our arms (orange): the collarbones from the neck base to both shoulders, then shoulder -> elbow -> wrist (the
## game's elbows and wrists: where its forearm and hand pictures hang). With it on, the game's arm bones are hidden.
static func arms_ours() -> Dictionary:
	if g.her == null or g.her.leftArmIK == null:
		return {}
	var h = g.her
	var nb := mark_at("neck_base")
	var out := {"node": h, "axes_ours": []}
	for side in [["shoulder_r", h.rightArmIK], ["shoulder_l", h.leftArmIK]]:
		var sh := mark_at(side[0])
		var ik: IKController = side[1]
		out["axes_ours"].append_array([[nb, sh], [sh, _at(ik.s2)], [_at(ik.s2), _at(ik.s3)]])
	return out


## The middle of the edge of `o`'s own bounds farthest from its origin.
static func _far_end(o: FlashDisplayObject) -> Vector2:
	var r: Rect2 = o.getBounds(o)
	var best := Vector2.ZERO
	for p in [Vector2(r.position.x, r.get_center().y), Vector2(r.end.x, r.get_center().y),
			Vector2(r.get_center().x, r.position.y), Vector2(r.get_center().x, r.end.y)]:
		if p.length() > best.length():
			best = p
	return best


## Her head: the pivot the game turns it about (one matrix from her position and tilt, not IK) and her jaw's pivot.
static func head() -> Dictionary:
	if g.her == null or g.her.head == null:
		return {}
	var hd = g.her.head
	return {"node": g.her, "axes": [[_at(hd), _at(hd.jaw)]], "points": [_at(hd), _at(hd.jaw)]}


## His body: his IK chains (both legs thigh -> calf -> foot, his right arm and his left arm) and his penis, base to
## tip; the chains' targets as points.
static func him() -> Dictionary:
	if g.her == null or g.him == null or g.him.currentBody == null:
		return {}
	var b = g.him.currentBody
	var out := {"node": g.her, "axes": [], "points": []}
	for k in ["rightLegIK", "leftLegIK", "rightArmIK", "leftArmIK"]:
		if k in b and b.get(k) != null:
			var c := _chain(b.get(k))
			out["axes"].append_array([c[0], c[1]])
			out["points"].append(c[2])
	out["axes"].append([g.her.globalToLocal(g.him.getPenisBasePoint()), g.her.globalToLocal(g.him.getPenisTipPoint())])
	return out


## Her arms: two IK chains (upper arm -> forearm -> hand) and where each hand aims.
static func arms() -> Dictionary:
	if g.her == null or g.her.leftArmIK == null:
		return {}
	var l := _chain(g.her.leftArmIK)
	var r := _chain(g.her.rightArmIK)
	var bones := [] if ours and is_on("arms_ours", "axis") else [l[0], l[1], r[0], r[1]]   # ours replace them
	return {"node": g.her, "axes": bones, "points": [l[2], r[2]]}


## Her breasts: each one's pivot and a line down it that leans with its sway (both springs get the same push in the
## game, BreastController.update).
static func breasts() -> Dictionary:
	if g.her == null or g.her.leftBreastController == null:
		return {}
	var out := {"node": g.her, "axes": [], "points": []}
	for b in [g.her.leftBreastController._breast, g.her.rightBreastController._breast]:
		out["axes"].append([_at(b), _at(b, Vector2(0, 60))])
		out["points"].append(_at(b))
	return out


## Her throat's rings (ThroatRings): a line across the neck at each ring's top and bottom edge, green while the ring
## is not stretched to red when fully stretched (grey once it would have snapped), thicker while he presses on it;
## a white dot at his tip and a blue one at the swallow wave, on the drawn front of the neck.
static func throat() -> Dictionary:
	if g.her == null or g.her.head == null:
		return {}
	var n: Neck = g.her.head.neck
	var front: Array = n.renderedPoints if n.renderedPoints.size() == n.neckPoints.size() else n.neckPoints
	var zones: Array = []
	for r in ThroatRings.rings():
		if not r["on"]:
			continue
		var c := Color(0.6, 0.6, 0.6) if r["snapped"] else Color.from_hsv(0.33 * (1.0 - r["stretch"]), 0.85, 1.0)
		var w: float = 1.0 + 2.0 * minf(1.0, r["pressure"])
		for depth in [r["top"], r["bottom"]]:
			var a := front_at(n, front, depth)
			zones.append([a, Vector2(_back_x(n, a.y), a.y), c, w])
	var marks: Array = []
	if ThroatRings.tip > 0.0:
		marks.append([front_at(n, front, ThroatRings.tip), Color.WHITE])
	if n.swallowing:
		marks.append([front_at(n, front, n.swallowProgress), COLORS["rendered2"]])
	return {"node": n, "zones": zones, "marks": marks}


## The point at `depth` along the front of the neck (`pts`: the neck's outline points, base or as drawn).
static func front_at(n: Neck, pts: Array, depth: float) -> Vector2:
	var f := clampf(depth, 0.0, 1.0) * n.frontEndPoint
	var i := mini(int(f), n.frontEndPoint - 2)
	return (pts[i] as Vector2).lerp(pts[i + 1], f - i)


## Where the back of the neck crosses height `y` (the outline after the front runs back up from her chest).
static func _back_x(n: Neck, y: float) -> float:
	var pts: Array = n.neckPoints
	for i in range(n.frontEndPoint, pts.size() - 1):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		if (y - a.y) * (y - b.y) <= 0.0 and a.y != b.y:
			return lerpf(a.x, b.x, (y - a.y) / (b.y - a.y))
	return -60.0
