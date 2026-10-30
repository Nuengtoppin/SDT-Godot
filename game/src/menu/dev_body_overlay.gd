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
		"head_ours": func(): return DevBodyOverlay.head_ours(), "neck_ours": func(): return DevBodyOverlay.neck_ours(),
		"neck_lines_ours": func(): return DevBodyOverlay.neck_lines_ours(), "breasts_ours": func(): return DevBodyOverlay.breasts_ours()}


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


## Every bone layer of ours (and our layer on), or every bone layer of the game's.
const OURS_PARTS := ["torso_ours", "legs_ours", "arms_ours", "neck_ours", "head_ours", "breasts_ours"]
const GAME_PARTS := ["legs", "arms", "breasts", "head", "neck", "him"]


static func show_skeleton(mine: bool) -> void:
	if mine:
		ours = true
	for p in (OURS_PARTS if mine else GAME_PARTS):
		set_on(p, "axis", true)


static func clear() -> void:
	_on.clear()
	set_pose(false)
	set_spring(false)
	DevBodySides.reset()
	DevBodyRings.mode = ""
	DevBodyRings.reset_turns()


## Our layer on / off; off takes back what ours puts on her (the neck spring, her sides apart).
## Body > Her body > Mouse: Off, Points (drag our points), Rotate / Limits (the rings).
static func set_mouse(v: String) -> void:
	editing = v == "Points"
	DevBodyRings.mode = v if v in ["Rotate", "Limits"] else ""
	DevBodyRings._grab = ""
	_drag = ""
	if v != "Off":
		_ensure()


static func mouse_mode() -> String:
	return "Points" if editing else (DevBodyRings.mode if DevBodyRings.mode != "" else "Off")


static func set_ours(on: bool) -> void:
	ours = on
	if not on:
		set_spring(false)
		DevBodySides.set_breasts(false)
	DevBodySides.sync()
	DevBodyRings.refresh()


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


## Pose mode's floor: a plain Flash shape in the background's layer (behind her, in front of the darkened
## background), at her knees' height (the pose's knee target), redrawn as the camera moves; until a real floor.
static var _floor: FlashSprite = null


static func _floor_on(on: bool) -> void:
	if _floor != null:
		if _floor.get_parent() != null:
			_floor.get_parent().removeChild(_floor)
		_floor = null
	if on:
		_floor = FlashSprite.new()
		g.bg.get_parent().addChildAt(_floor, g.bg.get_parent().getChildIndex(g.bg) + 1)
		_draw_floor()


static func _draw_floor() -> void:
	if _floor == null or g.her == null:
		return
	var knee: Vector2 = g.sceneLayer.localToGlobal(g.animationControl.getHerKneeTarget())
	var y: float = _floor.globalToLocal(knee).y + 25.0
	var gr: FlashGraphics = _floor.graphics
	gr.clear()
	gr.beginFill(0x3a3d45, 1.0)
	gr.drawRect(-20000, y, 40000, 20000)
	gr.endFill()
	gr.lineStyle(3, 0x8c93a3, 1.0)
	gr.moveTo(-20000, y)
	gr.lineTo(20000, y)


func _process(_delta: float) -> void:
	if posing:
		_draw_floor()
	_canvas.visible = (any_on() or (editing and ours) or posing or DevBodyRings.shown()) and g.gameRunning and SDTMenu.dev != null and SDTMenu.dev._enabled()
	if _canvas.visible:
		_canvas.queue_redraw()


func _draw_parts() -> void:
	var stage: Transform2D = Flash.stage.get_global_transform_with_canvas()
	if DevBodyRings.shown():
		DevBodyRings.draw(_canvas, _her_xf(), get_viewport().get_mouse_position(), line_width)
	if editing and ours and g.her != null:
		var xf := _her_xf()
		var hover := _drag if _drag != "" else _mark_under(get_viewport().get_mouse_position())
		var font := ThemeDB.fallback_font
		for id in live_marks():
			var p: Vector2 = xf * mark_at(id)
			_canvas.draw_circle(p, point_radius * (4.0 if id == hover else 3.0), COLORS["ours"])
			if id == hover:
				_canvas.draw_string(font, p + Vector2(8, -6), mark_defs()[id][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
		var mouse := get_viewport().get_mouse_position()
		for j in joint_labels():
			var q: Vector2 = xf * j[0]
			_canvas.draw_circle(q, point_radius * 2.0, COLORS["axis"])
			if hover == "" and q.distance_to(mouse) < GRAB_PX:
				_canvas.draw_string(font, q + Vector2(8, -6), j[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
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


# ---------------------------------------------------------------- our neck spring (Body > Neck)

## Her head sways on her neck like a pendulum: torso point (our neck base) -> the neck -> the head. A damped spring
## turns her whole head about the neck base, pushed by her body's own turn and up-and-down movement each tick (the
## game moves her whole body, head first; the torso follows by IK). "Her whole head" is many pictures: the head
## itself and its neighbours in her (eyes, brows, blush, freckles, tears, lipstick, ear, earrings, eyewear, tongue,
## gag, her hanging hair) and the hair layers the game places with her matrix each tick. Around the game's updateElements: before it
## the last turn is taken back (so nothing piles up), after it the new one is put on (the neck has turned to her
## torso by then; turning about its base keeps that base where it is). Only with our layer on; off by default.
const HEAD_GROUP := ["head", "tongueContainer", "topLipTongue", "gagBack", "bottomLipstick", "topLipstickContainer",
	"blush", "freckles", "eye", "tears", "leftEyebrow", "rightEyebrow", "gagFront", "eyewear", "ear", "earrings",
	"hairMidContainer", "hairBetweenLayer", "hairCostumeUnderLayer"]   # the last three: her hanging hair
static var spring_on := false
static var spring_k := 0.12        # pull back to rest per tick
static var spring_damp := 0.25     # share of its speed lost per tick
static var spring_push := 1.0      # how hard her body's movement pushes it
static var spring_limit := 15.0    # degrees either way
static var _before_fn := Callable()
static var _after_fn := Callable()
static var _applied := Transform2D.IDENTITY   # the turn put on last (her space)
static var _angle := 0.0
static var _speed := 0.0
static var _last_rot := NAN


static func _head_group() -> Array:
	var out := []
	for n in HEAD_GROUP:
		var c = g.her.getChildByName(n)
		if c != null:
			out.append(c)
	return out


static func _hair_layers() -> Array:
	return [g.her.hairBackContainer.hairBack, g.hairCostumeBack, g.hairTop, g.hairCostumeOver, g.hairCostumeUnderOver]


static func set_spring(on: bool) -> void:
	spring_on = on
	_angle = 0.0
	_speed = 0.0
	_last_rot = NAN
	sync_head()


## The hooks that turn her head: on while the spring is on or a ring turns her neck or head (Body > rings).
static func sync_head() -> void:
	var want := ours and g.her != null and (spring_on or DevBodyRings.head_turns())
	if want and _before_fn.is_valid():
		return
	if _before_fn.is_valid():
		Hooks.remove(&"Her.updateElements", _before_fn)
		Hooks.remove(&"Her.updateElements", _after_fn)
		_before_fn = Callable()
		_after_fn = Callable()
	if g.her != null:
		_take_back()
	if want:
		_before_fn = func(_c): DevBodyOverlay._spring_before()
		_after_fn = func(_c): DevBodyOverlay._spring_after()
		Hooks.add_before(&"Her.updateElements", _before_fn, "neckspring", 100)
		Hooks.add_after(&"Her.updateElements", _after_fn, "neckspring", 100)


static var _neck_saved = null   # the neck picture's own transform before the head's turn kept it out


static func _take_back() -> void:
	var inv := _applied.affine_inverse()
	for c in _head_group():
		c.transform = inv * c.transform
	_applied = Transform2D.IDENTITY
	if _neck_saved != null and g.her.head != null:
		g.her.head.neck.transform = _neck_saved
	_neck_saved = null


static func _spring_before() -> void:
	if not ours:
		set_spring(false)
		return
	_take_back()
	if not spring_on:
		_angle = 0.0
		return
	var h = g.her
	var rot: float = h.rotation_degrees
	var turn: float = 0.0 if is_nan(_last_rot) else rot - _last_rot
	_last_rot = rot
	_speed += -_angle * spring_k - _speed * spring_damp - (turn * 2.0 + h.absYMovement * 0.1) * spring_push
	_angle = clampf(_angle + _speed, -spring_limit, spring_limit)


static func _spring_after() -> void:
	var h = g.her
	var p := mark_at("neck_base")   # her space, after the torso has moved this tick
	var q := mark_at("head_pivot")
	var r := deg_to_rad(_angle + DevBodyRings.turn("neck"))
	var rh := deg_to_rad(DevBodyRings.turn("head"))
	var turn_h := Transform2D(rh, q - q.rotated(rh))   # the head about its pivot, then all about the neck base
	_applied = Transform2D(r, p - p.rotated(r)) * turn_h
	var head_xf: Transform2D = h.head.transform
	for c in _head_group():
		c.transform = _applied * c.transform
	if rh != 0.0:   # the neck picture (in her head) turns with the neck, not with the head's own turn
		var n = h.head.neck
		_neck_saved = n.transform
		n.transform = head_xf.affine_inverse() * turn_h.affine_inverse() * head_xf * n.transform
	for c in _hair_layers():
		if c != null:
			c.transform = c.transform * _applied   # these are placed with her matrix, outside her


# ---------------------------------------------------------------- pose mode (Body > Scene)

## Pose mode: the game frozen (paused) with her arms loose and his hand free, him shown / penis only / hidden, to
## place points and pose her; leaving it puts back everything it changed. Later this moves to our own scene.
const HIM_MODES := ["Shown", "Penis only", "Hidden"]
const POSE_MODES := ["Alive", "Frozen"]
static var pose_mode := "Alive"   # Alive: the game runs (she breathes), her head stays, no reactions; Frozen: paused
const QUIET := [&"Her.cough", &"Her.openCough", &"Her.wince", &"Her.passOut", &"Her.tapHands",
	&"Her.startClenchingTeeth"]   # her reactions switched off while posing alive
static var posing := false
static var pose_him := "Penis only"
static var pose_loose := true
static var pose_free := true
static var _saved := {}


static func set_pose(on: bool) -> void:
	if on == posing or g.her == null or g.him == null:
		return
	if on:
		_ensure()   # the zoom and the mouse go through the overlay
		_saved = {"paused": g.gamePaused, "body_hidden": g.him.bodyHidden, "him_visible": g.him.visible,
			"left": g.her.currentLeftArmPosition, "right": g.her.currentRightArmPosition, "his": g.him.currentArmPosition,
			"intro": g.her.intro, "gagging": g.gagging, "bg": g.bg.modulate}
		g.bg.modulate = Color(0.12, 0.13, 0.16)   # the background darkened while posing
		_floor_on(true)
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
		Hooks.remove_owner("pose")
		g.her.intro = _saved["intro"]
		g.gagging = _saved["gagging"]
		g.bg.modulate = _saved["bg"]
		_floor_on(false)
		g.sceneLayer.zoomTo(g.sceneZoom, true)   # the game's own camera back (the pose zoom moved it)
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
	Hooks.remove_owner("pose")
	if pose_mode == "Frozen":
		g.gamePaused = true
		return
	# alive: she breathes and blinks, but nothing pushes back, no intro, and she does not react to him
	g.her.intro = false
	g.gagging = false
	var veto := func(c): c.cancel()
	for h in QUIET:
		Hooks.add_before(h, veto, "pose", -99990)
	Hooks.add_modifier(&"Her.resistance", {"phase": Hooks.FINAL, "op": "set", "value": 0.0}, "pose")


## Pose mode's zoom: the scene's own camera (its zoom and position), about the mouse, 0.15 to 3 (the game's own goes to
## 1.4; much closer, the game's render targets for groups and masks get larger than the GPU allows and show
## garbage) - inside the scene, so nothing is cut off at the stage's edges. The game's camera only moves
## when its zoom changes, so ours stays; leaving pose mode puts the game's back.
func _zoom(at: Vector2, k: float) -> void:
	var sl: SceneLayer = g.sceneLayer
	var p: Vector2 = Flash.stage.get_global_transform_with_canvas().affine_inverse() * at   # stage coordinates
	var old: float = sl.currentZoom
	var z := clampf(old * k, 0.15, 3.0)
	k = z / old
	sl.currentZoom = z
	sl.targetZoom = z
	sl.zooming = false
	sl.scaleX = -z if g.mirrored else z
	sl.scaleY = z
	sl.camera = Vector2(p.x - (p.x - sl.x) * k, p.y - (p.y - sl.y) * k)
	sl.x = sl.camera.x
	sl.y = sl.camera.y
	sl.updateExternalLayerScales()
	sl.updateExternalLayerPositions()


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
## Fitted by Dima on her (30 Oct), the right leg; the left one mirrored from it: both thighs are the same picture
## (the left one x0.95), so the left knee is the right one's point and the left hip the right hip's place in its
## thigh put on the left thigh (the old fit checks out: -342,461 gives -319,452, fitted by hand -320,451); the left
## calf's skin is the right one's (the left calf also holds the far foot, hence its larger bounds), so the same ankle.
## The knees stay at the calf pictures' own pivots (357, 286): a knee ring turns the calf about its knee point, and
## about any other point the calf slides off the thigh (Dima tried 387, 280: a gap at the knee). Not yet: the
## breasts (their pivots for now).
const FIT := {"hip_r": Vector2(-361, 457), "hip_l": Vector2(-337, 448), "lumbar": Vector2(-169, 340),
	"thoracic": Vector2(-56, 180), "neck_base": Vector2(-1, 0), "shoulder_r": Vector2(12, -5),
	"shoulder_l": Vector2(-13, 5), "head_pivot": Vector2(-28, 31), "jaw": Vector2(-29, 85),
	"throat_top": Vector2(55, 66), "nape_top": Vector2(-21, 31), "throat_bottom": Vector2(65, 48),
	"nape_bottom": Vector2(-56, 134), "knee_r": Vector2(357, 286), "knee_l": Vector2(357, 286),
	"ankle_r": Vector2(-486, 61), "ankle_l": Vector2(-486, 61)}
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


## The points that can be dragged now: the neck lines' ends only while their layer is on.
static func live_marks() -> Array:
	var lines_on := is_on("neck_lines_ours", "axis")
	return mark_defs().keys().filter(func(id): return lines_on or not (id.begins_with("throat_") or id.begins_with("nape_")))


## Named joints of the game's that are not our points, for the labels while editing: elbows, wrists, nipples.
static func joint_labels() -> Array:
	if g.her == null or g.her.leftArmIK == null:
		return []
	var h = g.her
	return [[_at(h.rightArmIK.s2), "Right elbow"], [_at(h.rightArmIK.s3), "Right wrist"],
		[_at(h.leftArmIK.s2), "Left elbow"], [_at(h.leftArmIK.s3), "Left wrist"],
		[nipple_at(true), "Right nipple"], [nipple_at(false), "Left nipple"]]


static func numbers() -> String:
	var out := PackedStringArray()
	for id in mark_defs():
		var p := mark(id)
		out.append('"%s": Vector2(%d, %d),' % [id, int(p.x), int(p.y)])
	out.append_array(DevBodyRings.numbers())
	return "\n".join(out)


## The menus ask whether the mouse is ours (Flash.mouse_blocker, through DevMenu): while editing, over a point or
## dragging one, the game does not get the press.
static func wants_mouse() -> bool:
	if posing and pose_mode == "Alive":
		return true   # posing alive: the scene's mouse is ours (her head stays where it was; points, zoom)
	if DevBodyRings.shown() and instance != null:
		return DevBodyRings.busy() or DevBodyRings.ring_under(instance._her_xf(), instance.get_viewport().get_mouse_position()) != ""
	if not (editing and ours and instance != null and g.her != null):
		return false
	return _drag != "" or instance._mark_under(instance.get_viewport().get_mouse_position()) != ""


func _her_xf() -> Transform2D:
	return Flash.stage.get_global_transform_with_canvas() * (g.her as FlashDisplayObject).flash_global_transform()


func _mark_under(screen: Vector2) -> String:
	var xf := _her_xf()
	var best := ""
	var best_d := GRAB_PX
	for id in live_marks():
		var d := (xf * mark_at(id)).distance_to(screen)
		if d < best_d:
			best_d = d
			best = id
	return best


func _input(e: InputEvent) -> void:
	if posing and e is InputEventMouseButton and e.pressed and e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] \
			and not (SDTMenu.dev != null and SDTMenu.dev._dock.get_global_rect().has_point(e.position)):
		_zoom(get_viewport().get_mouse_position(), 1.1 if e.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.1)
		get_viewport().set_input_as_handled()
		return
	if DevBodyRings.shown() and SDTMenu.dev != null and SDTMenu.dev._enabled():
		if DevBodyRings.input(e, _her_xf()):
			get_viewport().set_input_as_handled()
		return
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


## Our neck (orange): the neck bone from the neck base (on the torso) to the head pivot (where the skull turns) - the
## spring goes here; and the neck's two lines, its skin, each with its own ends: the throat (chin -> its bottom) and
## the nape (skull -> its bottom). The lines are not bones: they stretch between head and torso.
static func neck_ours() -> Dictionary:
	if g.her == null or g.her.head == null:
		return {}
	return {"node": g.her, "axes_ours": [[mark_at("neck_base"), mark_at("head_pivot")]]}


## The neck's skin as two lines with their own ends (its own layer, so it is out of the way until we draw the neck
## from them): the throat (chin -> its bottom) and the nape (skull -> its bottom). Their points can be dragged only
## while this layer is on.
static func neck_lines_ours() -> Dictionary:
	if g.her == null or g.her.head == null:
		return {}
	return {"node": g.her, "axes_ours": [[mark_at("throat_top"), mark_at("throat_bottom")], [mark_at("nape_top"), mark_at("nape_bottom")]]}


## Our head (orange): from the head pivot to the jaw's pivot (a first guess; a joint's turn will be a ring with its
## limits later, not just a point).
static func head_ours() -> Dictionary:
	if g.her == null or g.her.head == null:
		return {}
	return {"node": g.her, "axes_ours": [[mark_at("head_pivot"), mark_at("jaw")]]}


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
