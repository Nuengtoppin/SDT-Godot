class_name DevBodyRings
extends RefCounted
## Body > Her body > Mouse: Rotate / Limits (our layer). A ring around each joint of ours that turns a picture of
## the game's: neck (about the neck base), head (about the head pivot), hips and knees. On the ring: the allowed
## range (orange arc), the game's own angle (white tick) and the angle now (the needle). Rotate: drag a ring to turn
## the bone (Shift: 5° steps; right click: back to the game's angle); Limits: drag an end of the arc. A turn is ours
## on top of the game's (her movement and the loose leg still run under it), kept for the session; the limits are
## copied with "Copy numbers". The head and neck turn with the neck spring's hooks (one turn about the neck base,
## then the head about its pivot - the neck picture stays out of the head's own turn); the legs after the game's
## updateElements (the game places them anew every tick). Later: arms (IK), the jaw, the spine (one picture: a morph).

## id -> [label, centre mark, far mark (the bone's direction)]
const JOINTS := {
	"neck": ["Neck", "neck_base", "head_pivot"],
	"head": ["Head", "head_pivot", "jaw"],
	"hip_r": ["Right hip", "hip_r", "knee_r"],
	"hip_l": ["Left hip", "hip_l", "knee_l"],
	"knee_r": ["Right knee", "knee_r", "ankle_r"],
	"knee_l": ["Left knee", "knee_l", "ankle_l"],
}
## Allowed turn, degrees [min, max]: from the game's angle; the knees from a straight leg - their fold (0: straight,
## 140: folded as far as she kneels and a little more), the same range the loose leg keeps to. A knee's turn is in
## fold degrees too (more: folded more), so it never bends a knee the wrong way whatever the game or the loose
## leg has done to it.
const LIMITS := {"neck": Vector2(-25, 25), "head": Vector2(-35, 35), "hip_r": Vector2(-60, 60),
	"hip_l": Vector2(-60, 60), "knee_r": Vector2(0, 140), "knee_l": Vector2(0, 140)}
const MODES := ["Off", "Points", "Rotate", "Limits"]
const RING_PX := 26.0      # ring radius on screen (the left side's rings are larger: both knees sit together)
const LEFT_PX := 36.0
const BAND_PX := 6.0

static var mode := ""          # "Rotate" / "Limits" ("" otherwise)
static var turns := {}         # id -> degrees, ours on top of the game's
static var limits := {}        # id -> Vector2 set by hand this session
static var _grab := ""         # the ring held
static var _grab_end := -1     # Limits: 0 min, 1 max
static var _grab_from := 0.0   # Rotate: the mouse's angle when pressed (her space, radians)
static var _grab_turn := 0.0
static var _after := Callable()
static var _fold_game := {}    # knee id -> its fold before our turn (last applied)
static var _fold_turn := {}    # knee id -> the turn that fitted in its range (last applied)


static func radius(id: String) -> float:
	return LEFT_PX if id.ends_with("_l") else RING_PX


static func limit(id: String) -> Vector2:
	return limits.get(id, LIMITS[id])


static func turn(id: String) -> float:
	return turns.get(id, 0.0) if DevBodyOverlay.ours else 0.0


static func set_turn(id: String, deg: float) -> void:
	var l := limit(id)
	if is_knee(id):   # the fold it would make must stay in range
		var f0 := fold_game(id)
		turns[id] = clampf(deg, l.x - f0, l.y - f0)
	else:
		turns[id] = clampf(deg, l.x, l.y)
	refresh()


static func is_knee(id: String) -> bool:
	return id.begins_with("knee")


## +1 / -1: whether `xf` keeps or mirrors the turning sense.
static func _sgn(xf: Transform2D) -> float:
	return 1.0 if xf.x.cross(xf.y) >= 0.0 else -1.0


static func _scene() -> Transform2D:
	return g.sceneLayer.flash_global_transform().affine_inverse()


## A knee's thigh and calf pictures.
static func _knee_nodes(id: String) -> Array:
	var h = g.her
	if id == "knee_r":
		return [h.torso.leg, h.torso.rightCalfContainer.calf]
	return [h.leftLegContainer.leg, h.leftLegContainer.leg.calf]


## How far a knee is folded now, degrees (0: the calf in line with the thigh; she kneels at about 130). Thigh: from
## its pivot to the knee (where the calf turns); calf: knee -> our ankle point. Positive folds the way a knee does
## (as she kneels), in whatever way her pictures are turned or mirrored on screen.
static func knee_fold(id: String) -> float:
	var n: Array = _knee_nodes(id)
	var calf = n[1]
	var d1: Vector2 = calf.transform.origin
	var bend: float = wrapf(calf.transform.basis_xform(DevBodyOverlay.mark("ankle_" + id.right(1))).angle() - d1.angle(), -PI, PI)
	return rad_to_deg(bend) * _sgn(_scene() * n[0].flash_global_transform())


## The fold before our turn: as last applied, else as it is now.
static func fold_game(id: String) -> float:
	if turn(id) != 0.0 and _fold_game.has(id):
		return _fold_game[id]
	return knee_fold(id)


static func reset_turns() -> void:
	turns.clear()
	refresh()


## Hooks in what the turns need and, while the game is paused (pose mode frozen), places her again so it shows.
static func refresh() -> void:
	var legs := false
	for id in turns:
		if id.begins_with("hip") or id.begins_with("knee"):
			legs = legs or turns[id] != 0.0
	var want := legs and DevBodyOverlay.ours and g.her != null
	if want and not _after.is_valid():
		_after = func(_c): DevBodyRings._legs_after()
		Hooks.add_after(&"Her.updateElements", _after, "rings", 95)
	elif not want and _after.is_valid():
		Hooks.remove(&"Her.updateElements", _after)
		_after = Callable()
	DevBodyOverlay.sync_head()
	if g.her != null and g.gamePaused:
		g.her.updateElements()


static func head_turns() -> bool:
	return turn("neck") != 0.0 or turn("head") != 0.0


## Turns `m` (a node's own transform, in its parent) about the point `pivot` (parent's space) by `deg`.
static func _about(m: Transform2D, pivot: Vector2, deg: float) -> Transform2D:
	var r := deg_to_rad(deg)
	return Transform2D(r, pivot - pivot.rotated(r)) * m


static func _legs_after() -> void:
	var h = g.her
	if h == null or not DevBodyOverlay.ours:
		refresh()
		return
	var t = h.torso
	var cc = t.rightCalfContainer
	if turn("hip_r") != 0.0:
		var tm := _about(t.leg.transform, DevBodyOverlay.mark("hip_r"), turn("hip_r"))
		DevBodySides._right(h, tm, deg_to_rad(turn("hip_r")), cc.calf.transform)
	if turn("knee_r") != 0.0:
		_knee("knee_r", [cc.calf, cc.calfStocking, cc.calfStockingB, cc.footwear, cc.bottoms, cc.cuffs])
	var leg = h.leftLegContainer.leg
	if turn("hip_l") != 0.0:
		leg.transform = _about(leg.transform, DevBodyOverlay.mark("hip_l"), turn("hip_l"))
	if turn("knee_l") != 0.0:
		_knee("knee_l", [leg.calf, leg.calfStocking, leg.calfStockingB, leg.footwear, leg.leftCalfBottoms, leg.cuffs])


## A knee's turn: the fold the game (or the loose leg) made plus ours, kept in the knee's range; the calf turns
## about its own pivot (where it hangs on the thigh), so it never slides off.
static func _knee(id: String, layers: Array) -> void:
	var n: Array = _knee_nodes(id)
	var calf = n[1]
	var f0 := knee_fold(id)
	var l := limit(id)
	var f := clampf(f0 + turns.get(id, 0.0), l.x, l.y)
	_fold_game[id] = f0
	_fold_turn[id] = f - f0
	var r := deg_to_rad(f - f0) * _sgn(_scene() * n[0].flash_global_transform())
	var p: Vector2 = calf.transform.origin
	var cm: Transform2D = Transform2D(r, p - p.rotated(r)) * calf.transform
	for c in layers:
		c.transform = cm


# ---------------------------------------------------------------- drawing and the mouse (her space unless named)

static func shown() -> bool:
	return mode != "" and DevBodyOverlay.ours and g.her != null


## [centre, the bone's angle now, the game's angle, the limits' zero, k] in her space: a limit `d` sits at
## zero + k * d (k: 1; a knee's zero is the thigh's line and k the way it folds on screen).
static func geometry(id: String) -> Array:
	var c: Vector2 = DevBodyOverlay.mark_at(JOINTS[id][1])
	var a: float = (DevBodyOverlay.mark_at(JOINTS[id][2]) - c).angle()
	if not is_knee(id):
		var a0 := a - deg_to_rad(turn(id))
		return [c, a, a0, a0, 1.0]
	var n: Array = _knee_nodes(id)
	var thigh = n[0]
	var d1: Vector2 = n[1].transform.origin
	var zero: float = (DevBodyOverlay._at(thigh, d1) - DevBodyOverlay._at(thigh)).angle()
	var tg: Transform2D = thigh.flash_global_transform()
	var k := _sgn(_scene() * tg) * _sgn(g.her.flash_global_transform().affine_inverse() * tg)
	var done: float = _fold_turn.get(id, 0.0) if turn(id) != 0.0 else 0.0
	return [c, a, a - deg_to_rad(done) * k, zero, k]


## The point on ring `id` at her-space angle `a`, on screen.
static func ring_pt(xf: Transform2D, id: String, c: Vector2, a: float) -> Vector2:
	return xf * c + xf.basis_xform(Vector2.from_angle(a)).normalized() * radius(id)


static func draw(canvas: CanvasItem, xf: Transform2D, mouse: Vector2, width: float) -> void:
	var hover := _grab if _grab != "" else ring_under(xf, mouse)
	var font := ThemeDB.fallback_font
	var orange: Color = DevBodyOverlay.COLORS["ours"]
	for id in JOINTS:
		var gm := geometry(id)
		var c: Vector2 = gm[0]
		var s: Vector2 = xf * c
		var lit: bool = id == hover
		canvas.draw_arc(s, radius(id), 0.0, TAU, 48, Color(0.6, 0.6, 0.65, 0.6), width)
		var l := limit(id)
		var arc := PackedVector2Array()
		for i in 25:
			arc.append(ring_pt(xf, id, c, gm[3] + gm[4] * deg_to_rad(lerpf(l.x, l.y, i / 24.0))))
		canvas.draw_polyline(arc, orange if lit else orange.darkened(0.25), width * (3.0 if lit else 2.0), true)
		if mode == "Limits":
			canvas.draw_circle(arc[0], 4.0, orange)
			canvas.draw_circle(arc[arc.size() - 1], 4.0, orange)
		var tick := xf.basis_xform(Vector2.from_angle(gm[2])).normalized()
		canvas.draw_line(s + tick * (radius(id) - 5.0), s + tick * (radius(id) + 5.0), Color.WHITE, width * 1.5, true)
		canvas.draw_line(s, ring_pt(xf, id, c, gm[1]), Color.WHITE if lit else orange, width * 1.5, true)
		if lit:
			var text := "%s  %+.0f°  (%+.0f..%+.0f)" % [JOINTS[id][0], turn(id), l.x, l.y]
			if is_knee(id):
				text = "%s  folded %.0f°  (%.0f..%.0f)  turn %+.0f°" % [JOINTS[id][0], knee_fold(id), l.x, l.y, turn(id)]
			canvas.draw_string(font, s + Vector2(radius(id) + 6.0, -6.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)


## The ring under the mouse (screen), "" if none: the nearest ring band within reach.
static func ring_under(xf: Transform2D, mouse: Vector2) -> String:
	var best := ""
	var best_d := BAND_PX
	for id in JOINTS:
		var c: Vector2 = geometry(id)[0]
		var d := absf((xf * c).distance_to(mouse) - radius(id))
		if d < best_d:
			best_d = d
			best = id
	return best


static func busy() -> bool:
	return _grab != ""


## The mouse (screen) on the rings; true if it was ours.
static func input(e: InputEvent, xf: Transform2D) -> bool:
	if not shown():
		_grab = ""
		return false
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_RIGHT:
		var id := ring_under(xf, e.position)
		if id == "":
			return false
		if mode == "Rotate":
			set_turn(id, 0.0)
		else:
			limits.erase(id)
			set_turn(id, turn(id))
		return true
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if not e.pressed:
			var was := _grab != ""
			_grab = ""
			return was
		var id := ring_under(xf, e.position)
		if id == "":
			return false
		var gm := geometry(id)
		var m: Vector2 = xf.affine_inverse() * e.position
		_grab = id
		var c0: Vector2 = gm[0]
		_grab_from = (m - c0).angle()
		_grab_turn = turn(id)
		if mode == "Limits":
			var l := limit(id)
			var lo := ring_pt(xf, id, gm[0], gm[3] + gm[4] * deg_to_rad(l.x))
			var hi := ring_pt(xf, id, gm[0], gm[3] + gm[4] * deg_to_rad(l.y))
			_grab_end = 0 if lo.distance_to(e.position) <= hi.distance_to(e.position) else 1
		return true
	if e is InputEventMouseMotion and _grab != "":
		var gm := geometry(_grab)
		var m: Vector2 = xf.affine_inverse() * e.position
		var a: float = (m - gm[0]).angle()
		if mode == "Rotate":
			var deg: float = _grab_turn + rad_to_deg(wrapf(a - _grab_from, -PI, PI)) * gm[4]
			if Input.is_key_pressed(KEY_SHIFT):
				deg = snappedf(deg, 5.0)
			set_turn(_grab, deg)
		else:
			var deg: float = roundf(rad_to_deg(wrapf(a - gm[3], -PI, PI)) * gm[4])
			var l := limit(_grab)
			if _grab_end == 0:
				l.x = minf(deg, l.y)
			else:
				l.y = maxf(deg, l.x)
			limits[_grab] = l
			set_turn(_grab, turn(_grab))
		return true
	return false


static func numbers() -> PackedStringArray:
	var out := PackedStringArray()
	for id in JOINTS:
		var l := limit(id)
		out.append('"lim_%s": Vector2(%d, %d),' % [id, int(l.x), int(l.y)])
	return out
