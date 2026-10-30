class_name DevBodyDrag
extends RefCounted
## Body > Her body > Mouse: Drag (our layer) - pull her by a point and the chain behind it follows, within the rings'
## limits (DevBodyRings): her chin (head -> neck -> back: the head takes what its range allows, the neck the rest,
## the back what is left), her back (thoracic: leans about the pelvis), her pelvis (lumbar: she moves by it, her
## knees staying while a leg kneels), her torso (between them: all of her, knees too), a knee (turns the
## thigh) and an ankle (thigh and knee, a two-bone IK), a nipple (the breast follows; let go, its spring brings it
## back). A kneeling leg keeps the pose it is pulled into (the rings' turns); a loose leg is held by the mouse and,
## let go, falls and swings on with the speed it had.

## id -> [label, mark]
const HANDLES := {
	"head": ["Chin (head, neck, back)", "jaw"], "back": ["Back (leans)", "thoracic"],
	"pelvis": ["Pelvis (she moves by it)", "lumbar"], "torso": ["Torso (all of her)", "torso"], "knee_r": ["Right knee", "knee_r"], "knee_l": ["Left knee", "knee_l"],
	"ankle_r": ["Right ankle", "ankle_r"], "ankle_l": ["Left ankle", "ankle_l"],
	"nipple_r": ["Right nipple", ""], "nipple_l": ["Left nipple", ""],
}
const GRAB_PX := 12.0

static var on := false
static var _hold := ""
static var _last := Vector2.ZERO        # the mouse in the scene, last motion
static var _nipple := {}                # "r" / "l" -> the mouse's point (stage) the nipple is pulled to
static var _after := Callable()


static func shown() -> bool:
	return on and DevBodyOverlay.ours and g.her != null


static func busy() -> bool:
	return _hold != ""


## Handle `id` in her space.
static func point(id: String) -> Vector2:
	if id.begins_with("nipple"):
		return DevBodyOverlay.nipple_at(id.ends_with("_r"))
	return DevBodyOverlay.mark_at(HANDLES[id][1])


static func under(xf: Transform2D, mouse: Vector2) -> String:
	var best := ""
	var best_d := GRAB_PX
	for id in HANDLES:
		var d := (xf * point(id)).distance_to(mouse)
		if d < best_d:
			best_d = d
			best = id
	return best


static func draw(canvas: CanvasItem, xf: Transform2D, mouse: Vector2) -> void:
	var hover := _hold if _hold != "" else under(xf, mouse)
	var font := ThemeDB.fallback_font
	var orange: Color = DevBodyOverlay.COLORS["ours"]
	for id in HANDLES:
		var p := xf * point(id)
		var lit: bool = id == hover
		if id == "torso":
			canvas.draw_rect(Rect2(p - Vector2(6, 6), Vector2(12, 12)), Color.WHITE if lit else orange, false, 2.0)
		else:
			canvas.draw_circle(p, 6.0 if lit else 4.5, Color.WHITE if lit else orange)
		if lit:
			canvas.draw_string(font, p + Vector2(9, -7), HANDLES[id][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)


static func release() -> void:
	if _hold.begins_with("knee") or _hold.begins_with("ankle"):
		DevBodySides.release(_hold.right(1))
	_hold = ""
	_nipple.clear()
	_sync()


## The mouse (screen) on the handles; true if it was ours.
static func input(e: InputEvent, xf: Transform2D) -> bool:
	if not shown():
		if _hold != "":
			release()
		return false
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if not e.pressed:
			var was := _hold != ""
			release()
			return was
		_hold = under(xf, e.position)
		_last = DevBodyRings._mouse_scene(e.position)
		return _hold != ""
	if e is InputEventMouseMotion and _hold != "":
		pull(_hold, DevBodyRings._mouse_scene(e.position), Flash.stage.get_global_transform_with_canvas().affine_inverse() * e.position)
		return true
	return false


## Pulls handle `id` to the scene point `m` (`stage`: the same point on the stage, for the breasts).
static func pull(id: String, m: Vector2, stage: Vector2) -> void:
	var sg := DevBodyRings.her_sgn()
	match id:
		"pelvis":
			DevBodyRings.hips += m - _last
			DevBodyRings.refresh()
		"torso":
			DevBodyRings.offset += m - _last
			DevBodyRings.refresh()
		"back":
			var l := DevBodyRings.scene_pt("lumbar")
			var t := DevBodyRings.scene_pt("thoracic")
			_give(["back"], rad_to_deg(wrapf((m - l).angle() - (t - l).angle(), -PI, PI)) * sg)
		"head":
			var p := DevBodyRings.scene_pt("head_pivot")
			var j := DevBodyRings.scene_pt("jaw")
			_give(["head", "neck", "back"], rad_to_deg(wrapf((m - p).angle() - (j - p).angle(), -PI, PI)) * sg)
		"knee_r", "knee_l", "ankle_r", "ankle_l":
			_leg(id, m)
		"nipple_r", "nipple_l":
			_nipple[id.right(1)] = stage
			_sync()
			if g.gamePaused:
				g.her.updateElements()
	_last = m


## A turn along a chain: each joint takes what its range allows, the next one the rest.
static func _give(chain: Array, deg: float) -> void:
	for id in chain:
		if absf(deg) < 0.01:
			break
		var before := DevBodyRings.turn(id)
		DevBodyRings.set_turn(id, before + deg)
		deg -= DevBodyRings.turn(id) - before


## A leg pulled by its knee (the thigh turns to it) or its ankle (thigh and knee, the knee folding the way knees do).
static func _leg(id: String, m: Vector2) -> void:
	var side := id.right(1)
	var n: Array = DevBodyRings._knee_nodes("knee_" + side)
	var thigh = n[0]
	var calf = n[1]
	var sc := DevBodyRings._scene()
	var tg: Transform2D = sc * thigh.flash_global_transform()
	var o: Vector2 = tg.origin
	var k: Vector2 = tg * calf.transform.origin
	var cg: Transform2D = tg * calf.transform
	var a: Vector2 = cg * DevBodyOverlay.mark("ankle_" + side)
	var l1 := (k - o).length()
	var l2 := (a - k).length()
	var p1: float = (m - o).angle()
	var p2: float = (a - k).angle() + (p1 - (k - o).angle())   # the knee as it is
	if id.begins_with("ankle"):
		var d := clampf((m - o).length(), absf(l1 - l2) + 0.01, l1 + l2 - 0.01)
		var bend := acos(clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0))
		var fs := DevBodyRings._sgn(tg)   # the way the knee folds in the scene
		p1 = (m - o).angle() - bend * fs
		var kk := o + Vector2.from_angle(p1) * l1
		p2 = (o + (m - o).normalized() * d - kk).angle()
	if (DevBodySides.leg_r if side == "r" else DevBodySides.leg_l) == "Loose":
		DevBodySides.hold(side, p1, p2 if id.begins_with("ankle") else NAN)
		if g.gamePaused:
			g.her.updateElements()
		return
	# kneeling: the rings' turns (the hip turns the thigh in its parent's space, the knee in fold degrees)
	var parent_sg := DevBodyRings._sgn(tg * thigh.transform.affine_inverse())
	var hip_id := "hip_" + side
	DevBodyRings.set_turn(hip_id, DevBodyRings.turn(hip_id) + rad_to_deg(wrapf(p1 - (k - o).angle(), -PI, PI)) * parent_sg)
	if id.begins_with("ankle"):
		var fold := rad_to_deg(wrapf(p2 - p1, -PI, PI)) * DevBodyRings._sgn(tg)
		var knee_id := "knee_" + side
		DevBodyRings.set_turn(knee_id, fold - DevBodyRings.fold_game(knee_id))


# ---------------------------------------------------------------- the breasts, pulled by a nipple

static func _sync() -> void:
	var want := not _nipple.is_empty() and g.her != null
	if want and not _after.is_valid():
		_after = func(_c): DevBodyDrag._breasts_after()
		Hooks.add_after(&"Her.updateElements", _after, "drag", 97)
	elif not want and _after.is_valid():
		Hooks.remove(&"Her.updateElements", _after)
		_after = Callable()


## After the game's breasts (in updateElements): a held breast's skew set so its nipple reaches the mouse's height
## (the game's sway is a skew of the breast picture), its spring's speed stopped - let go, the spring takes it back.
static func _breasts_after() -> void:
	var h = g.her
	if h == null:
		return
	for side in _nipple:
		var c: BreastController = h.rightBreastController if side == "r" else h.leftBreastController
		var b: FlashDisplayObject = c._breast
		var parent_g: Transform2D = b.flash_global_transform() * b.transform.affine_inverse()
		var tgt: Vector2 = parent_g.affine_inverse() * _nipple[side]
		var nip: Vector2 = b.globalToLocal(h.localToGlobal(DevBodyOverlay.nipple_at(side == "r")))
		if absf(nip.x) < 1.0:
			continue
		var m: Transform2D = b.transform
		var skew := clampf((tgt.y - m.origin.y - m.y.y * nip.y) / nip.x, -0.8, 0.8)
		m.x.y = skew
		b.transform = m
		for cl in c._costumeLayers:
			cl.transform = m
		c._skew = skew
		c._speed = 0.0
	h.updateNipplePiercing()
