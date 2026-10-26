extends SDTExtension
## derrdev: after sby's chokercollarresistanceV4, on the throat ring model (stage 3 of the throat ring plan): her
## collar is a ring on her throat (ThroatRings.collar: edges from the collar's picture, material and tightness kept
## for each collar). Behaviour > Resistance, "Collar holds her throat", off by default. While she wears a collar and
## it is on, through value points:
##   - Her.pushBack: past the collar's top edge her head is pushed back, by how far he is past it and how much the
##     ring holds (its tightness, less its stretch) - like the game's intro limit;
##   - Her.resistance: past the top edge pushing in is harder by what the ring holds;
## P043: the collar's front is a spring pushed by her throat (it lags, overshoots a little and settles), and one
## setting, "Collar stiffness" (0 soft band .. 1 metal, quick buttons Band / Leather / Metal), sets how a collar holds
## and gives for every collar (ThroatRings.set_stiffness).
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
## P044 (after playing it): a collar holds like her throat entrance, a wall across its band: past its top edge pushing
## in gets harder, up to WALL x what the ring holds at its bottom edge, and her head is pushed back while he is in the
## band; once through, it squeezes only a little. How far its front gives way comes from its softness at once (a soft
## collar gives with the first push, the ring's stretch adds to that), the spring is fast, and stiffness 0 is a collar
## that holds nothing and rides along with her neck. "Collar can break" (off by default: collars never break): a worn
## out collar snaps, then holds nothing and rides along like stiffness 0, until it is repaired (the button, another
## collar or another stiffness). At its edges the band blends into the free bulge over a few outline points, so big
## bulges keep a round step.
## Not taken yet: the dialogue line "collarresistance", the breath-below-50% option during the intro, reactions when
## it snaps.

const PUSH := 0.0015          # pos pushed back per pixel past the top edge, at hold 1 (the game's intro: 0.0015)
const WALL := 0.3             # resistance at the collar's bottom edge at hold 1 (the game's throat: 0.2 at 100)
const SQUEEZE := 0.03         # resistance past the bottom edge at hold 1 (through it: it only squeezes)
const GIVE := 6.0             # px the front gives way at stiffness 0.5; GIVE x (1 - k) / k (0: free, 1: none)
const SPRING := 1.0           # the collar's front: pull toward her throat per tick per px (P044: fast, was 0.2)
const DAMP := 0.6             # share of its speed lost per tick (it settles in about 3 ticks, a little overshoot)
const SLACK := 3.0            # px her throat may press into the collar before it gives way
const WINCE_RES := 0.1        # the collar resists at least this much while he pushes: she winces
const BAND_GAP := 2.0         # px the outline may push out under the collar (the collar sits on the skin)
const BAND_WIDEN := 70.0 * 0.25   # px more fully stretched (the mod's 25 % of 70 px)
const BAND_SOFT := 0.08       # depth past each edge over which the held outline blends into the free bulge

var _push_fn := Callable()
var _resist_fn := Callable()
var _band_fn := Callable()
var _widened := false
var _collar_x := 0.0
var _back := {}               # collar name -> [back edge, width] in its own space (back: its left side, her nape)
var push_px := 0.0            # how far the collar's front is pushed out now (px, a spring pushed by her throat)
var push_speed := 0.0


func _init() -> void:
	id = "chokercollarresistance"
	title = "chokerCollarResistance"
	description = "chokerCollarResistance (sby): her collar holds her throat and stretches (Behaviour > Resistance)."
	default_enabled = true


func _setup() -> void:
	setting("on", false, {"label": "Collar holds her throat",
		"desc": "While she wears a collar it holds like her throat: past its top edge going deeper is harder and her head is pushed back, and her neck stays narrow under it as far as it gives."})
	setting("widen", true, {"label": "Collar stretches", "desc": "The collar's front gives way after her throat."})
	setting("wince", true, {"label": "Wince when it holds", "desc": "She winces while the collar holds him back."})
	setting("breaks", false, {"label": "Collar can break",
		"desc": "Pressed long and hard enough the collar snaps; then it holds nothing and only rides along with her neck. Off: collars never break."})


func _enable() -> void:
	_push_fn = func(v: float, _b: float, _her) -> float:
		return v + _band_past() * ThroatRings.DEPTH_SCALE * PUSH * ThroatRings.collar["hold"]
	_resist_fn = func(v: float, _b: float, _her) -> float:
		return v + wall()
	_band_fn = func(v: float, _b: float, neck) -> float:
		return minf(v, band_limit(neck.bulgePointDepth, v))
	on_late_tick(_tick)
	var on := func(): return get_setting("on")
	var after := {"after": "Throat resistance"}
	menu_control("behaviour", "Resistance", MenuSchema.setting_control(self, "on", after))
	menu_control("behaviour", "Resistance", {"type": "slider", "label": "Collar stiffness", "after": "Throat resistance",
		"tip": "One setting for every collar. 0: holds nothing, rides along with her neck. Higher: holds harder and gives less. 1: metal - a wall, never gives.",
		"min": 0.0, "max": 1.0, "step": 0.05, "get": func(): return ThroatRings.stiffness,
		"set": func(v: float): ThroatRings.set_stiffness(v), "format": func(v): return "%.2f" % v, "visible": on})
	menu_control("behaviour", "Resistance", MenuSchema.actions("", "", ThroatRings.PRESETS.keys().map(func(k):
		return [k, func(): ThroatRings.set_stiffness(ThroatRings.PRESETS[k]), "Collar stiffness %.1f." % ThroatRings.PRESETS[k]]),
		{"after": "Throat resistance", "visible": on}))
	for key in ["widen", "wince", "breaks"]:
		menu_control("behaviour", "Resistance", MenuSchema.setting_control(self, key, {"after": "Throat resistance", "visible": on}))
	menu_control("behaviour", "Resistance", MenuSchema.actions("", "", [["Repair collar", func(): ThroatRings.repair(),
		"A snapped collar holds again."]], {"after": "Throat resistance",
		"visible": func(): return get_setting("on") and get_setting("breaks")}))
	ThroatRings.load_stiffness()
	_apply()


func _disable() -> void:
	_release()
	ThroatRings.collar_breaks = false
	ThroatRings._apply_stiffness()


func _setting_changed(_key: String, _value) -> void:
	_apply()


func _apply() -> void:
	_remove_points()
	if ThroatRings.collar_breaks != bool(get_setting("breaks")):
		ThroatRings.collar_breaks = get_setting("breaks")
		ThroatRings._apply_stiffness()
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


## True while the collar holds nothing and rides along with her neck: stiffness 0, or snapped.
func rides_free() -> bool:
	var c: Dictionary = ThroatRings.collar
	return c["snapped"] or ThroatRings.collar_stiffness() <= 0.0


## How far (px) the collar's front may give way now: from its softness at once, plus what the ring has stretched;
## INF when it rides free, 0 when its picture does not widen ("Collar stretches" off).
func room() -> float:
	if not get_setting("widen"):
		return 0.0
	if rides_free():
		return INF
	var k := ThroatRings.collar_stiffness()
	return GIVE * (1.0 - k) / k + ThroatRings.collar["stretch"] * BAND_WIDEN


## How far (px) her neck's outline may push out at depth `f` (`free_px`: as far as it would without the collar):
## between the collar's edges as far as the collar has given way (plus the slack), blending into the free bulge
## across BAND_SOFT past each edge, free elsewhere and while the collar rides free.
func band_limit(f: float, free_px: float = INF) -> float:
	var c: Dictionary = ThroatRings.collar
	if not c["on"] or rides_free():
		return INF
	var inside: float = BAND_GAP + minf(room(), push_px + SLACK)
	var out: float = maxf(c["top"] - f, f - c["bottom"])
	if out <= 0.0:
		return inside
	if out >= BAND_SOFT or not is_finite(free_px):
		return INF
	return lerpf(inside, maxf(inside, free_px), smoothstep(0.0, 1.0, out / BAND_SOFT))


## How far (depth units) his tip is into the collar's band (0 above it, the band's height once through) while it holds.
func _band_past() -> float:
	var c: Dictionary = ThroatRings.collar
	if not c["on"] or c["snapped"] or g.penisOut:
		return 0.0
	return clampf(ThroatRings.tip - c["top"], 0.0, c["bottom"] - c["top"])


## What the collar adds to her resistance now: like her throat entrance, rising across its band up to WALL x what
## it holds at the bottom edge; once he is through, a little squeeze.
func wall() -> float:
	var c: Dictionary = ThroatRings.collar
	var past := _band_past()
	if past <= 0.0:
		return 0.0
	if ThroatRings.tip >= c["bottom"]:
		return SQUEEZE * c["hold"]
	return WALL * c["hold"] * past / maxf(0.001, c["bottom"] - c["top"])


func _tick() -> void:
	var her = g.her
	if not get_setting("on") or her == null or g.gamePaused:
		return
	ThroatRings.tick(her)
	var c: Dictionary = ThroatRings.collar
	if get_setting("widen") and c["on"]:
		_spring(_throat_push(her.head.neck, c), c)
		_widen(her)
	else:
		push_px = 0.0
		push_speed = 0.0
		if _widened:
			_unwiden()
	if get_setting("wince") and ThroatRings.push > 0.2 and wall() >= WINCE_RES:
		her.wince()


## The collar's front: a fast spring pulled toward where her throat pushes it, no further out than it can give and
## never into her neck.
func _spring(target: float, _c: Dictionary = {}) -> void:
	push_speed = (push_speed + (target - push_px) * SPRING) * (1.0 - DAMP)
	push_px += push_speed
	var most := room()
	if push_px > most or push_px < 0.0:
		push_px = clampf(push_px, 0.0, most)
		push_speed = 0.0


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
