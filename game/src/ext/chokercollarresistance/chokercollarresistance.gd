extends SDTExtension
## derrdev: after sby's chokercollarresistanceV4, on the throat ring model (stage 3 of the throat ring plan): her
## collar is a ring on her throat (ThroatRings.collar: edges from the collar's picture, material and tightness kept
## for each collar). Behaviour > Resistance, "Collar holds her throat", off by default. While she wears a collar and
## it is on, through value points:
##   - Her.pushBack: past the collar's top edge her head is pushed back, by how far he is past it and how much the
##     ring holds (its tightness, less its stretch) - like the game's intro limit;
##   - Her.resistance: past the top edge pushing in is harder by what the ring holds;
##   - Neck.pointBulge (clamp, P041): between the collar's edges her neck's outline may push out only as far as the
##     collar allows (a little, more as it stretches and its picture widens; metal never), so the throat bulge does
##     not go through the collar: her neck bulges above it and, when he is deeper, below it, held in by the band,
##     with a soft step at each edge. A wide collar holds a wide band, a thin one a thin band.
## The ring stretches under his pressure (his width, more while he pushes, the swallow wave too) and gives way: a
## leather collar slowly, a band fast, metal never. "Collar stretches" (P042): her throat pushes the collar out and
## the collar follows it with a lag, to show how tight it is - the neck may press a few pixels into it, the collar
## gives way after it, as far as the ring's stretch lets it (up to 17.5 px fully stretched), and settles back when
## her throat does. Only the front moves: the back of the collar, at her nape, stays where it is (the mod widened
## the whole picture by the ring's memory, about a point 70 px behind its origin, so it stayed wide in the air). "Wince when it holds": she winces while it holds him back (the mod's option).
## Pressure comes from what he does, not from holding the mouse button (the mod's), so auto mode works the same.
## Not taken yet: the dialogue line "collarresistance", the breath-below-50% option during the intro, snapping (the
## ring's durability is worked out; a snapped ring holds nothing; the reactions come in the next stage).

const PUSH := 0.0015          # pos pushed back per pixel past the top edge, at hold 1 (the game's intro: 0.0015)
const RESIST := 0.15          # resistance added past the top edge at hold 1 (the game's throat entrance at most: 0.2)
const WIDEN := 0.25           # fully stretched the collar gives way by 70 x this px (the mod's 25 % of 70 px)
const LAG := 0.15             # share of the way to her throat the collar's front catches up per tick
const SLACK := 3.0            # px her throat may press into the collar before it gives way
const WINCE_PUSH := 0.004     # pushed back at least this much in a tick: she winces
const BAND_GAP := 2.0         # px the outline may push out under the collar (the collar sits on the skin)
const BAND_WIDEN := 70.0 * WIDEN   # px more fully stretched, as much as the picture widens (the mod's 70 px)
const BAND_SOFT := 0.04       # depth over which the hold fades out past each edge
const BAND_SOFT_PX := 40.0    # px of room gained across that step

var _push_fn := Callable()
var _resist_fn := Callable()
var _band_fn := Callable()
var _widened := false
var _collar_x := 0.0
var _back := {}               # collar name -> [back edge, width] in its own space (back: its left side, her nape)
var push_px := 0.0            # how far the collar's front is pushed out now (px, follows her throat with LAG)


func _init() -> void:
	id = "chokercollarresistance"
	title = "chokerCollarResistance"
	description = "chokerCollarResistance (sby): her collar holds her throat and stretches (Behaviour > Resistance)."
	default_enabled = true


func _setup() -> void:
	setting("on", false, {"label": "Collar holds her throat",
		"desc": "While she wears a collar, past its top edge her head is pushed back and her neck stays narrow under it, until it stretches."})
	setting("widen", true, {"label": "Collar stretches", "desc": "The collar's picture widens as it stretches."})
	setting("wince", true, {"label": "Wince when it holds", "desc": "She winces while the collar holds him back."})


func _enable() -> void:
	_push_fn = func(v: float, _b: float, _her) -> float:
		var past := _past()
		return v + past * ThroatRings.DEPTH_SCALE * PUSH * ThroatRings.collar["hold"] if past > 0.0 else v
	_resist_fn = func(v: float, _b: float, _her) -> float:
		return v + RESIST * ThroatRings.collar["hold"] if _past() > 0.0 else v
	_band_fn = func(v: float, _b: float, neck) -> float:
		return minf(v, band_limit(neck.bulgePointDepth))
	on_late_tick(_tick)
	var on := func(): return get_setting("on")
	var after := {"after": "Throat resistance"}
	menu_control("behaviour", "Resistance", MenuSchema.setting_control(self, "on", after))
	menu_control("behaviour", "Resistance", MenuSchema.choice("Collar material",
		"For the collar she wears now (kept for each collar). Band: stretches, breaks easily. Leather: holds, breaks hard. Metal: does not give.",
		ThroatRings.MATERIALS.keys(), func(): return ThroatRings.collar_material, func(v): ThroatRings.set_collar_material(v),
		{"after": "Throat resistance", "visible": on}))
	menu_control("behaviour", "Resistance", {"type": "slider", "label": "Collar tightness", "after": "Throat resistance",
		"tip": "How hard the collar she wears now holds (kept for each collar; the material sets it too).", "min": 0.0, "max": 1.0, "step": 0.05,
		"get": func(): return ThroatRings.collar["tight"], "set": func(v: float): ThroatRings.set_collar_tight(v),
		"format": func(v): return "%.2f" % v, "visible": on})
	for key in ["widen", "wince"]:
		menu_control("behaviour", "Resistance", MenuSchema.setting_control(self, key, {"after": "Throat resistance", "visible": on}))
	_apply()


func _disable() -> void:
	_release()


func _setting_changed(_key: String, _value) -> void:
	_apply()


func _apply() -> void:
	_remove_points()
	if get_setting("on"):
		value_point(&"Her.pushBack", _push_fn)
		value_point(&"Her.resistance", _resist_fn, ValuePoints.MOOD, 10)
		value_point(&"Neck.pointBulge", _band_fn, ValuePoints.CLAMP)
	else:
		_release()
	if not get_setting("widen"):
		_unwiden()


func _remove_points() -> void:
	ValuePoints.remove(&"Her.pushBack", _push_fn)
	ValuePoints.remove(&"Her.resistance", _resist_fn)
	ValuePoints.remove(&"Neck.pointBulge", _band_fn)


func _release() -> void:
	_remove_points()
	_unwiden()


## How far (px) her neck's outline may push out at depth `f`: little between the collar's edges (more as it stretches,
## if its picture widens with it), rising across a soft step past each edge, free elsewhere.
func band_limit(f: float) -> float:
	var c: Dictionary = ThroatRings.collar
	if not c["on"] or c["snapped"]:
		return INF
	var room: float = c["stretch"] * BAND_WIDEN if get_setting("widen") else 0.0   # how far it can give now
	var inside: float = BAND_GAP + minf(room, push_px + SLACK) if room > 0.0 else BAND_GAP
	var out: float = maxf(c["top"] - f, f - c["bottom"])
	if out <= 0.0:
		return inside
	if out >= BAND_SOFT:
		return INF
	return inside + out / BAND_SOFT * BAND_SOFT_PX


## How far (depth units) his tip is past the collar's top edge while the collar holds.
func _past() -> float:
	var c: Dictionary = ThroatRings.collar
	if not c["on"] or c["snapped"] or g.penisOut:
		return 0.0
	return maxf(0.0, ThroatRings.tip - c["top"])


func _tick() -> void:
	var her = g.her
	if not get_setting("on") or her == null or g.gamePaused:
		return
	ThroatRings.tick(her)
	var c: Dictionary = ThroatRings.collar
	if get_setting("widen") and c["on"]:
		push_px += (_throat_push(her.head.neck, c) - push_px) * LAG
		_widen(her)
	else:
		push_px = 0.0
		if _widened:
			_unwiden()
	if get_setting("wince") and _past() * ThroatRings.DEPTH_SCALE * PUSH * c["hold"] >= WINCE_PUSH:
		her.wince()


## How far her throat pushes out under the collar this tick (px past the gap, from the drawn neck).
func _throat_push(neck, c: Dictionary) -> float:
	var pts: Array = neck.renderedPoints
	var n: int = neck.frontEndPoint
	if pts.size() != neck.neckPoints.size() or n < 2:
		return 0.0
	var most := 0.0
	for i in range(int(ceil(c["top"] * n)), mini(n, int(floor(c["bottom"] * n)) + 1)):
		most = maxf(most, (pts[i] as Vector2).x - (neck.neckPoints[i] as Vector2).x)
	return maxf(0.0, most - BAND_GAP)


## The collar's picture pushed out by push_px at its front; its back edge stays put.
func _widen(her) -> void:
	var col = her.collarContainer.collar
	if not _widened:
		_widened = true
		_collar_x = col.x
	var cname := ThroatRings.current_collar()
	if not _back.has(cname):
		var sx: float = col.scaleX
		col.scaleX = 1.0
		var b: Rect2 = col.getBounds(col)
		_back[cname] = [b.position.x, maxf(1.0, b.size.x)]
		col.scaleX = sx
	col.scaleX = 1.0 + push_px / _back[cname][1]
	col.x = _collar_x + _back[cname][0] * (1.0 - col.scaleX)   # the back edge stays put, the front moves out


func _unwiden() -> void:
	if not _widened or g.her == null:
		_widened = false
		return
	var col = g.her.collarContainer.collar
	col.scaleX = 1.0
	col.x = _collar_x
	_widened = false
