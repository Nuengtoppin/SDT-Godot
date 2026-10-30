class_name DevBodySides
extends RefCounted
## Body > Breasts and Body > Legs (our layer): her left and right side apart, as her arms already are. In the game
## both breasts get the same push each tick (they swing as one) and her left leg is a copy of her right thigh's
## turn. Breasts: the left one's push comes a few ticks later and each springs back at its own firmness (through
## the game's own value points). Legs: each one kneeling (the game's) or loose: thigh and calf hang from her hip
## by gravity and swing with her movement, the knee bends one way only, the floor holds her knee and foot.
## A first step; later our own skeleton drives them.


# ---------------------------------------------------------------- breasts

static var breasts_on := false
static var lag := 3          # ticks the left breast's push comes after the right's
static var push_l := 0.85
static var push_r := 1.0
static var firm_l := 1.15    # x the game's firmness (higher: springs back faster)
static var firm_r := 1.0
static var _breast_ids: Array = []
static var _history: Array = []   # the pushes of the last ticks, for the left breast's lag


static func set_breasts(on: bool) -> void:
	breasts_on = on
	for id in _breast_ids:
		Hooks.remove_modifier(id)
	_breast_ids.clear()
	_history.clear()
	if on and DevBodyOverlay.ours:
		_breast_ids.append(Hooks.add_modifier(&"BreastController.push", {"phase": Hooks.OVERRIDE, "op": "fn",
			"fn": func(v, obj): return DevBodySides._push(v, obj)}, "breastsides"))
		_breast_ids.append(Hooks.add_modifier(&"BreastController.firmness", {"phase": Hooks.OVERRIDE, "op": "fn",
			"fn": func(v, obj): return DevBodySides._firm(v, obj)}, "breastsides"))
	refirm()


static func set_firm(right: bool, v: float) -> void:
	if right:
		firm_r = v
	else:
		firm_l = v
	refirm()


## The game works out the firmness only when her breast size or costume changes: ask again.
static func refirm() -> void:
	if g.her != null and g.her.leftBreastController != null:
		g.her.updateBreastFirmness()


static func _push(v, obj):
	var h = g.her
	if h == null or not DevBodyOverlay.ours:
		return v
	if obj == h.rightBreastController:
		return v * push_r
	if obj == h.leftBreastController:   # updated first each tick, with the same push as the right one
		_history.push_back(v)
		while _history.size() > lag + 1:
			_history.pop_front()
		return _history[0] * push_l
	return v   # his breasts (a female him) stay the game's


static func _firm(v, obj):
	var h = g.her
	if h == null or not DevBodyOverlay.ours:
		return v
	if obj == h.rightBreastController:
		return v * firm_r
	if obj == h.leftBreastController:
		return v * firm_l
	return v


# ---------------------------------------------------------------- legs

## The game has no physics, no gravity: every part follows its own rule (her arms "loose" are an IK aimed at a
## point below her shoulder). A loose leg here is a small one of its own: two bones, thigh (hip -> knee, where
## the calf turns) and calf (knee -> our ankle point), each pulled down and thrown by its joint's movement
## (inertia), the knee bending only within its ring's range (straight .. folded), the thigh within a range of
## where it knelt, and the floor (the pose's knee target) under her knee and foot. Worked out in the scene's
## space (the camera's zoom doesn't move it), once after the game's updateElements has placed her legs.
const LEG_MODES := ["Kneeling", "Loose"]
static var leg_l := "Kneeling"
static var leg_r := "Kneeling"
static var loose_gravity := 0.02   # pull down, radians per tick squared (at a level bone)
static var loose_damp := 0.08      # share of its swing lost per tick
static var loose_push := 1.0       # how much her movement throws it (1: as a real weight would)
static var loose_limit := 60.0     # how far the thigh may turn from where it knelt (degrees either way)
static var loose_floor := true     # the floor holds her knee and foot (off: they hang through it)
static var _after := Callable()
static var _st := {}               # "l" / "r" -> the leg's state (angles in the scene's space, radians)
static var _holds := {}            # "l" / "r" -> [thigh, calf] scene angles the mouse holds it at (NAN: free)


## Body > Mouse > Drag: the mouse holds a loose leg's thigh (and calf) at these scene angles; let go, it swings on.
static func hold(side: String, thigh: float, calf: float) -> void:
	_holds[side] = [thigh, calf]


static func release(side: String) -> void:
	_holds.erase(side)


static func set_leg(right: bool, mode: String) -> void:
	if right:
		leg_r = mode
	else:
		leg_l = mode
	_st.erase("r" if right else "l")
	sync()


static func any_loose() -> bool:
	return leg_l == "Loose" or leg_r == "Loose"


## Hooks in while our layer is on and a leg is loose; a leg back to kneeling is the game's again from the next tick.
static func sync() -> void:
	var want := DevBodyOverlay.ours and any_loose() and g.her != null
	if want and not _after.is_valid():
		_after = func(_c): DevBodySides._legs_after()
		Hooks.add_after(&"Her.updateElements", _after, "legsides", 90)
	elif not want and _after.is_valid():
		Hooks.remove(&"Her.updateElements", _after)
		_after = Callable()
	if not want:
		_st.clear()


static func reset() -> void:
	set_breasts(false)
	leg_l = "Kneeling"
	leg_r = "Kneeling"
	sync()


static func _legs_after() -> void:
	var h = g.her
	if h == null or not DevBodyOverlay.ours:
		sync()
		return
	var scene: Transform2D = g.sceneLayer.flash_global_transform().affine_inverse()
	var floor_y: float = g.animationControl.getHerKneeTarget().y   # in the scene's space, as the game's IK uses it
	if leg_r == "Loose":
		var t = h.torso
		var game_a: float = t.leg.transform.get_rotation()
		var m: Array = _leg("r", t.leg, t.rightCalfContainer.calf, scene, floor_y)
		_right(h, m[0], m[0].get_rotation() - game_a, m[1])
	if leg_l == "Loose":
		var leg = h.leftLegContainer.leg
		var m: Array = _leg("l", leg, leg.calf, scene, floor_y)
		leg.transform = m[0]
		for c in [leg.calf, leg.calfStocking, leg.calfStockingB, leg.footwear, leg.leftCalfBottoms, leg.cuffs]:
			c.transform = m[1]


## One tick of a loose leg; returns [the thigh's transform, the calf's] (their own, in their parents).
static func _leg(side: String, thigh, calf, scene: Transform2D, floor_y: float) -> Array:
	var tg: Transform2D = scene * thigh.flash_global_transform()
	var pg: Transform2D = tg * thigh.transform.affine_inverse()   # the thigh's parent (her torso), scene space
	var cg: Transform2D = tg * calf.transform
	var d1: Vector2 = calf.transform.origin                       # the knee, in the thigh's space
	var d2: Vector2 = DevBodyOverlay.mark("ankle_" + side)        # the ankle, in the calf's space
	var hip: Vector2 = tg.origin
	var l1: float = tg.basis_xform(d1).length()
	var l2: float = cg.basis_xform(d2).length()
	if not _st.has(side):
		var p1: float = tg.basis_xform(d1).angle()
		var p2: float = cg.basis_xform(d2).angle()
		_st[side] = {"p1": p1, "o1": p1, "p2": p2, "o2": p2, "hip": [hip, hip], "knee": [cg.origin, cg.origin],
			"rest": thigh.transform.get_rotation(),
			"floor": cg.origin.y - floor_y, "ankle": (cg * d2).y - cg.origin.y}
	var s: Dictionary = _st[side]
	# the thigh: gravity and her hip's movement
	var ha: Vector2 = hip - 2.0 * s["hip"][0] + s["hip"][1]
	s["hip"] = [hip, s["hip"][0]]
	var n1: float = _step(s["p1"], s["o1"], ha, l1)
	var held: Array = _holds.get(side, [NAN, NAN])
	if not is_nan(held[0]):
		n1 = held[0]
	var a: float = _turn_for(pg, thigh.transform, d1, n1)
	var da: float = wrapf(a - s["rest"], -PI, PI)
	var lim := deg_to_rad(loose_limit)
	if absf(da) > lim:   # her hip joint's range
		a = s["rest"] + clampf(da, -lim, lim)
		n1 = (pg * _rot(thigh.transform, a)).basis_xform(d1).angle()
	var fk: float = floor_y + s["floor"]
	if loose_floor and hip.y + sin(n1) * l1 > fk:   # her knee on the floor
		n1 = _onto(hip.y, l1, fk, n1)
	var tm := _rot(thigh.transform, _turn_for(pg, thigh.transform, d1, n1))
	s["o1"] = s["p1"]
	s["p1"] = n1
	# the calf: gravity and her knee's movement
	var tg2: Transform2D = pg * tm
	var knee: Vector2 = tg2 * d1
	var ka: Vector2 = knee - 2.0 * s["knee"][0] + s["knee"][1]
	s["knee"] = [knee, s["knee"][0]]
	var fold := _knee_range("knee_" + side, tg)
	var n2: float = _bend(n1, held[1] if not is_nan(held[1]) else _step(s["p2"], s["o2"], ka, l2), fold)
	var fa: float = fk + s["ankle"]
	if loose_floor and knee.y + sin(n2) * l2 > fa:   # her foot on the floor
		n2 = _bend(n1, _onto(knee.y, l2, fa, n2), fold)
	var cm := _rot(calf.transform, _turn_for(tg2, calf.transform, d2, n2))
	s["o2"] = s["p2"]
	s["p2"] = n2
	return [tm, cm]


## A bone's next angle: its swing (less damping), pulled down, thrown by its joint's acceleration `acc`.
static func _step(p: float, o: float, acc: Vector2, l: float) -> float:
	var v: float = wrapf(p - o, -PI, PI) * (1.0 - loose_damp)
	v += loose_gravity * cos(p) - loose_push * (cos(p) * acc.y - sin(p) * acc.x) / maxf(l, 1.0)
	return p + v


## The knee's range (the ring's: 0 straight .. folded) as a scene-space turn of the calf from the thigh's line
## (radians, [lo, hi]); a knee folds the other way on screen when her thigh is mirrored there.
static func _knee_range(id: String, thigh_scene: Transform2D) -> Vector2:
	var l := DevBodyRings.limit(id) * (PI / 180.0)
	if DevBodyRings._sgn(thigh_scene) < 0.0:
		return Vector2(-l.y, -l.x)
	return l


## The knee bends one way only: within its range from straight (calf in line with the thigh).
static func _bend(thigh: float, calf: float, fold: Vector2) -> float:
	return thigh + clampf(wrapf(calf - thigh, -PI, PI), fold.x, fold.y)


## The angle that puts a bone of length `l` from height `py` onto the height `fy`, on the side it points to.
static func _onto(py: float, l: float, fy: float, p: float) -> float:
	var a := asin(clampf((fy - py) / maxf(l, 1.0), -1.0, 1.0))
	return PI - a if cos(p) < 0.0 else a


## The turn (in its parent) that points a node's bone `d` (its own space) at the scene angle `p`.
static func _turn_for(parent: Transform2D, local: Transform2D, d: Vector2, p: float) -> float:
	var want: Vector2 = parent.affine_inverse().basis_xform(Vector2.from_angle(p))
	var e: Vector2 = Transform2D(0.0, local.get_scale(), local.get_skew(), Vector2.ZERO).basis_xform(d)
	return want.angle() - e.angle()


static func _rot(m: Transform2D, a: float) -> Transform2D:
	return Transform2D(a, m.get_scale(), m.get_skew(), m.origin)


## Her right thigh and every layer the game puts with it (stockings, costume, its masks), as in updateTorso;
## `extra`: how much further it turned than the game's.
static func _right(h, tm: Transform2D, extra: float, cm: Transform2D) -> void:
	var t = h.torso
	for c in [t.leg, t.rightThighBottoms, t.rightThighBottomsOver, t.rightCalfContainer, t.rightThighStocking,
			t.rightThighStockingB, t.rightThighCostume]:
		c.transform = tm
	var un := Transform2D(-(h.torsoIK.section2Angle + extra), Vector2.ZERO)
	for st in [t.rightThighStocking, t.rightThighStockingB]:
		st.stocking.hipLayer.transform = un
		st.stocking2.hipLayer.transform = un
		st.stocking.hipOverLayer.transform = un
	t.chestCostume.legMask.rotation_degrees = t.leg.rotation_degrees - 27.6
	t.rightThighCostumeMask.legMask.rotation_degrees = t.leg.rotation_degrees
	var cc = t.rightCalfContainer
	for c in [cc.calf, cc.calfStocking, cc.calfStockingB, cc.footwear, cc.bottoms, cc.cuffs]:
		c.transform = cm
