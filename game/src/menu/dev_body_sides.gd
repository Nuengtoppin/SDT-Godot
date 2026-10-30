class_name DevBodySides
extends RefCounted
## Body > Breasts and Body > Legs (our layer): her left and right side apart, as her arms already are. In the game
## both breasts get the same push each tick (they swing as one) and her left leg is a copy of her right thigh's
## turn. Breasts: the left one's push comes a few ticks later and each springs back at its own firmness (through
## the game's own value points). Legs: each one kneeling (the game's) or loose: it goes with her hips and swings
## behind their turning, its knee free. A first step; later our own skeleton drives them.


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

const LEG_MODES := ["Kneeling", "Loose"]
static var leg_l := "Kneeling"
static var leg_r := "Kneeling"
static var loose_k := 0.06       # pull back to its rest angle per tick
static var loose_damp := 0.12    # share of its speed lost per tick
static var loose_push := 1.0     # how much her hips' turning swings it
static var loose_limit := 35.0   # degrees either way from its rest
static var _after := Callable()
static var _st := {}             # "l" / "r" -> {rest, a, v (degrees, in her torso's space), calf}
static var _last_turn := NAN


static func set_leg(right: bool, mode: String) -> void:
	if right:
		leg_r = mode
	else:
		leg_l = mode
	_st.erase("r" if right else "l")
	sync()


static func any_loose() -> bool:
	return leg_l == "Loose" or leg_r == "Loose"


## Hooks in while our layer is on and a leg is loose (once after the game's updateElements, which has placed
## her legs by then); a leg back to kneeling is the game's again from the next tick.
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
	_last_turn = NAN


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
	var t: float = h.rotation_degrees + rad_to_deg(h.torso.transform.get_rotation())   # her hips' turn on screen
	var turn: float = 0.0 if is_nan(_last_turn) else wrapf(t - _last_turn, -180.0, 180.0)
	_last_turn = t
	var push: float = (turn + h.absYMovement * 0.05) * loose_push
	if leg_r == "Loose":
		_right(h, _swing("r", h.torso.leg.transform, h.torso.rightCalfContainer.calf.transform, push))
	if leg_l == "Loose":
		_left(h, _swing("l", h.leftLegContainer.leg.transform, h.leftLegContainer.leg.calf.transform, push))


## The leg's spring: its angle against her torso keeps its rest (taken when it went loose) and lags behind
## her hips' turning. Returns [the game's thigh angle, ours, the calf] (the calf keeps its bend).
static func _swing(side: String, thigh: Transform2D, calf: Transform2D, push: float) -> Array:
	var game_a := rad_to_deg(thigh.get_rotation())
	if not _st.has(side):
		_st[side] = {"rest": game_a, "a": game_a, "v": 0.0, "calf": calf}
	var s: Dictionary = _st[side]
	s["v"] += -(s["a"] - s["rest"]) * loose_k - s["v"] * loose_damp - push
	s["a"] = s["rest"] + clampf(s["a"] + s["v"] - s["rest"], -loose_limit, loose_limit)
	return [game_a, s["a"], s["calf"]]


static func _with_angle(m: Transform2D, deg: float) -> Transform2D:
	return Transform2D(deg_to_rad(deg), m.get_scale(), m.get_skew(), m.origin)


## Her right thigh and every layer the game puts with it (stockings, costume, its masks), as in updateTorso.
static func _right(h, sw: Array) -> void:
	var t = h.torso
	var s2 := _with_angle(t.leg.transform, sw[1])
	for c in [t.leg, t.rightThighBottoms, t.rightThighBottomsOver, t.rightCalfContainer, t.rightThighStocking,
			t.rightThighStockingB, t.rightThighCostume]:
		c.transform = s2
	var un := Transform2D(-(h.torsoIK.section2Angle + deg_to_rad(sw[1] - sw[0])), Vector2.ZERO)
	for st in [t.rightThighStocking, t.rightThighStockingB]:
		st.stocking.hipLayer.transform = un
		st.stocking2.hipLayer.transform = un
		st.stocking.hipOverLayer.transform = un
	t.chestCostume.legMask.rotation_degrees = t.leg.rotation_degrees - 27.6
	t.rightThighCostumeMask.legMask.rotation_degrees = t.leg.rotation_degrees
	var cc = t.rightCalfContainer
	for c in [cc.calf, cc.calfStocking, cc.calfStockingB, cc.footwear, cc.bottoms, cc.cuffs]:
		c.transform = sw[2]


## Her left leg: the thigh (the game's copy of the right one, x0.95) and its calf layers.
static func _left(h, sw: Array) -> void:
	var leg = h.leftLegContainer.leg
	leg.transform = _with_angle(leg.transform, sw[1])
	for c in [leg.calf, leg.calfStocking, leg.calfStockingB, leg.footwear, leg.leftCalfBottoms, leg.cuffs]:
		c.transform = sw[2]
