class_name ThroatRings
extends RefCounted
## derrdev, the throat ring model: her throat as a path by depth with rings on it, the throat entrance and, when she
## wears one, her collar. Every tick it works out how hard he presses on each ring, how far the ring has stretched
## and how much it would hold him back. It is ticked by the throatresiststretch extension while its "Throat loosens"
## is on (then the entrance ring acts on the game through value points, see that extension) or Developer mode is on
## (read only, for the Body tab). The collar ring acts in a later stage.
##
## Depth is the neck's own: 0 at her lips, 1 = 400 deep (penisInMouthDist / 400, what Neck.render uses), so a ring's
## edges are where they are drawn on the neck. The collar ring's edges come from the collar's picture (its bounds on
## the neck, kept to the band so a hanging tie does not count), with a hand adjustment for each edge. The adjustments
## and the material are kept for each collar (Leather, Tie, ...) in port.cfg, section throat_rings.
##
## Pressure comes from what he does, not from the mouse: his width while he is past the ring's top edge, more while
## he pushes in, plus the swallow wave passing through the ring. Under pressure a ring stretches (faster when it is
## tight, slower when it is stiff) and wears down if it can break; without pressure it recovers.

const DEPTH_SCALE := 400.0
const ENTRANCE_TOP := 75.0 / DEPTH_SCALE      # Her.deepthroatStartDistance: the resistance at the throat entrance
const ENTRANCE_BOTTOM := 150.0 / DEPTH_SCALE  # Her.deepthroatDistance: past it he is in her throat
const STRETCH_RATE := 0.016   # per tick, at pressure 1 on a fully tight, fully stretchy ring
const RECOVER_RATE := 0.002   # per tick without pressure (halved for a fully stiff ring)
const WEAR_REST := 0.1        # durability back per tick without pressure (none for a fully stiff ring)
const PUSH_FULL := 10.0       # his movement per tick that counts as a full push (the game's "fast" threshold)
const WAVE_PRESSURE := 0.05   # pressure per unit of swallow size while the wave is inside a ring
const COLLAR_BAND := 70.0     # the most of the collar's height (neck pixels) taken as its band
const BOUNDS_EVERY := 15      # ticks between reading the collar's bounds again
## material -> [tightness, stiffness, durability (INF: does not break)]
const MATERIALS := {"Band": [0.35, 0.2, 60.0], "Leather": [0.6, 0.6, 200.0], "Metal": [0.85, 1.0, INF]}
const SECTION := "throat_rings"   # port.cfg: edges_<collar> = [top, bottom], material_<collar> (spaces as _)
## edge adjustments for the game's collars where the picture's bounds are not the band (seen in the game)
const DEFAULT_EDGES := {"Leather": [0.005, -0.05], "Tie": [0.04, -0.085], "Gem Choker": [0.03, -0.03]}

static var entrance := _ring("Throat entrance", ENTRANCE_TOP, ENTRANCE_BOTTOM, 0.5, 0.5, INF)
static var collar := _ring("Collar", 0.55, 0.75, 0.6, 0.6, 200.0)
static var collar_material := "Leather"
static var collar_top_adjust := 0.0     # added to the edge found from the collar's picture (depth units)
static var collar_bottom_adjust := 0.0
static var tip := 0.0                   # his tip, in depth units (0 while outside her mouth)
static var push := 0.0                  # how hard he pushes in this tick, 0..1
static var collar_name := ""            # the collar the ring is for ("Leather", "Tie", ...; "Custom" for a mod's)
static var _tick_done := -1            # the game tick last worked out (several extensions may ask)
static var _bounds_tick := -1000000
static var _bounds_collar = null


static func _ring(label: String, top: float, bottom: float, tight: float, stiff: float, durability: float) -> Dictionary:
	return {"label": label, "on": true, "top": top, "bottom": bottom, "tight": tight, "stiff": stiff,
		"max_durability": durability, "durability": durability, "stretch": 0.0, "pressure": 0.0, "hold": 0.0,
		"snapped": false, "recover": 1.0}


static func rings() -> Array:
	return [entrance, collar]


## Worked out only while Developer mode is on (for its Body tab).
static func active() -> bool:
	return SDTMenu.dev != null and SDTMenu.dev._enabled()


static func tick(her) -> void:
	if Flash.tick_count == _tick_done:
		return
	_tick_done = Flash.tick_count
	var neck = her.head.neck
	tip = 0.0 if g.penisOut else maxf(0.0, her.penisInMouthDist / DEPTH_SCALE)
	push = 0.0 if g.penisOut else clampf(her.movement / PUSH_FULL, 0.0, 1.0)
	entrance["tight"] = clampf(g.throatResistance / 100.0, 0.0, 1.0)
	_update_collar(her, neck)
	var width: float = g.him.getPenisWidthWithTwitch()
	for r in rings():
		_step(r, width, neck)


static func _step(r: Dictionary, width: float, neck) -> void:
	if not r["on"]:
		r["pressure"] = 0.0
		r["hold"] = 0.0
		r["stretch"] = 0.0
		return
	var p := 0.0
	if tip > r["top"]:
		p = width * (0.3 + 0.7 * push)
	if neck.swallowing and neck.swallowProgress >= r["top"] and neck.swallowProgress <= r["bottom"]:
		p += WAVE_PRESSURE * neck.swallowSize
	r["pressure"] = p
	if p > 0.0:
		r["stretch"] = minf(1.0, r["stretch"] + p * r["tight"] * (1.0 - r["stiff"]) * STRETCH_RATE)
	else:
		r["stretch"] = maxf(0.0, r["stretch"] - RECOVER_RATE * r["recover"] * (1.0 - 0.5 * r["stiff"]))
	if is_finite(r["max_durability"]) and not r["snapped"]:
		if p > 0.0:
			r["durability"] = maxf(0.0, r["durability"] - p * (0.2 + r["stretch"]))
			r["snapped"] = r["durability"] <= 0.0
		else:
			r["durability"] = minf(r["max_durability"], r["durability"] + WEAR_REST * (1.0 - r["stiff"]))
	r["hold"] = 0.0 if r["snapped"] or tip <= r["top"] else r["tight"] * (1.0 - r["stretch"])


## The collar ring follows what she wears: on while a collar is shown, its edges from the collar's picture.
static func _update_collar(her, neck) -> void:
	var c = her.collarContainer.collar
	var worn: bool = c.visible and (g.characterControl.collarControl.selection != 0 or c.numChildren > 0)
	if not worn:
		collar["on"] = false
		_bounds_collar = null
		return
	collar["on"] = true
	_sync_collar()
	var sel = [g.characterControl.collarControl.selection, c.numChildren]
	if sel == _bounds_collar and Flash.tick_count - _bounds_tick < BOUNDS_EVERY:
		return
	_bounds_collar = sel
	_bounds_tick = Flash.tick_count
	var b: Rect2 = c.getBounds(neck)
	if b.size.y <= 0.0:
		collar["on"] = false
		return
	var top := depth_at_y(neck, b.position.y) + collar_top_adjust
	var bottom := depth_at_y(neck, minf(b.end.y, b.position.y + COLLAR_BAND)) + collar_bottom_adjust
	collar["top"] = clampf(top, 0.0, 0.99)
	collar["bottom"] = clampf(maxf(bottom, collar["top"] + 0.01), 0.01, 1.0)


## Depth of the front of the neck at height `y` (neck space): the front outline points run from her jaw (depth 0)
## down to her chest (depth 1).
static func depth_at_y(neck, y: float) -> float:
	var pts: Array = neck.neckPoints
	var n: int = neck.frontEndPoint
	if n < 2 or y <= pts[0].y:
		return 0.0
	for i in n - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		if y >= a.y and y < b.y:
			return (i + (y - a.y) / (b.y - a.y)) / n
	return float(n - 1) / n


## The collar she wears now ("Leather", "Tie", "Gem Choker"; "Custom" for a mod's).
static func current_collar() -> String:
	var sel_id: int = g.characterControl.collarControl.selection
	return g.characterControl.collarNameList[sel_id] if sel_id != 0 else "Custom"


## Loads the ring settings kept for the collar she wears now if the ring was for another one.
static func _sync_collar() -> void:
	if g.characterControl != null and current_collar() != collar_name:
		_load_collar(current_collar())


## The ring settings kept for this collar: edge adjustments (else DEFAULT_EDGES) and material (else Leather).
static func _load_collar(cname: String) -> void:
	collar_name = cname
	var e = PortSettings.get_value(SECTION, _key("edges", cname), DEFAULT_EDGES.get(cname, [0.0, 0.0]))
	collar_top_adjust = float(e[0])
	collar_bottom_adjust = float(e[1])
	_set_material(str(PortSettings.get_value(SECTION, _key("material", cname), "Leather")))
	var t = PortSettings.get_value(SECTION, _key("tight", cname))
	if t != null:
		collar["tight"] = float(t)
	_bounds_collar = null


static func _key(kind: String, cname: String) -> String:
	return kind + "_" + cname.replace(" ", "_")


static func set_collar_material(m: String) -> void:
	if not MATERIALS.has(m):
		return
	_sync_collar()
	_set_material(m)
	if collar_name != "":
		PortSettings.set_value(SECTION, _key("material", collar_name), m)
		PortSettings.set_value(SECTION, _key("tight", collar_name), collar["tight"])


static func _set_material(m: String) -> void:
	if not MATERIALS.has(m):
		m = "Leather"
	collar_material = m
	collar["tight"] = MATERIALS[m][0]
	collar["stiff"] = MATERIALS[m][1]
	collar["max_durability"] = MATERIALS[m][2]
	repair()


## Collar tightness, kept for this collar (the material sets it too).
static func set_collar_tight(v: float) -> void:
	_sync_collar()
	collar["tight"] = clampf(v, 0.0, 1.0)
	if collar_name != "":
		PortSettings.set_value(SECTION, _key("tight", collar_name), collar["tight"])


static func adjust_collar(top: float, bottom: float) -> void:
	_sync_collar()
	collar_top_adjust = top
	collar_bottom_adjust = bottom
	_bounds_collar = null   # read the edges again on the next tick
	if collar_name != "":
		PortSettings.set_value(SECTION, _key("edges", collar_name), [top, bottom])


static func repair() -> void:
	for r in rings():
		r["durability"] = r["max_durability"]
		r["snapped"] = false


static func reset_stretch() -> void:
	for r in rings():
		r["stretch"] = 0.0
