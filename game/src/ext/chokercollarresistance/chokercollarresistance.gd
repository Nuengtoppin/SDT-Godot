extends SDTExtension
## derrdev: after sby's chokercollarresistanceV4, on the throat ring model (stage 3 of the throat ring plan): her
## collar is a ring on her throat (ThroatRings.collar: edges from the collar's picture, material and tightness kept
## for each collar). Behaviour > Resistance, "Collar holds her throat", off by default. While she wears a collar and
## it is on, through value points:
##   - Her.pushBack: past the collar's top edge her head is pushed back, by how far he is past it and how much the
##     ring holds (its tightness, less its stretch) - like the game's intro limit;
##   - Her.resistance: past the top edge pushing in is harder by what the ring holds;
##   - Neck.depth (clamp): the throat bulge stops at the collar's top edge until the ring stretches, so her neck under
##     the collar stays narrow; fully stretched, no limit.
## The ring stretches under his pressure (his width, more while he pushes, the swallow wave too) and gives way: a
## leather collar slowly, a band fast, metal never. "Collar stretches": the collar's picture widens with the
## stretch, as the mod did. "Wince when it holds": she winces while it holds him back (the mod's option).
## Pressure comes from what he does, not from holding the mouse button (the mod's), so auto mode works the same.
## Not taken yet: the dialogue line "collarresistance", the breath-below-50% option during the intro, snapping (the
## ring's durability is worked out; a snapped ring holds nothing; the reactions come in the next stage).

const PUSH := 0.0015          # pos pushed back per pixel past the top edge, at hold 1 (the game's intro: 0.0015)
const RESIST := 0.15          # resistance added past the top edge at hold 1 (the game's throat entrance at most: 0.2)
const WIDEN := 0.25           # how much wider the collar's picture gets fully stretched
const WINCE_PUSH := 0.004     # pushed back at least this much in a tick: she winces

var _push_fn := Callable()
var _resist_fn := Callable()
var _depth_fn := Callable()
var _widened := false
var _collar_x := 0.0


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
	_depth_fn = func(v: float, _b: float, _neck) -> float:
		var c: Dictionary = ThroatRings.collar
		if not c["on"] or c["snapped"]:
			return v
		return minf(v, c["top"] + c["stretch"] * (1.0 - c["top"]))
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
		value_point(&"Neck.depth", _depth_fn, ValuePoints.CLAMP)
	else:
		_release()
	if not get_setting("widen"):
		_unwiden()


func _remove_points() -> void:
	ValuePoints.remove(&"Her.pushBack", _push_fn)
	ValuePoints.remove(&"Her.resistance", _resist_fn)
	ValuePoints.remove(&"Neck.depth", _depth_fn)


func _release() -> void:
	_remove_points()
	_unwiden()


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
		_widen(her, c["stretch"])
	elif _widened:
		_unwiden()
	if get_setting("wince") and _past() * ThroatRings.DEPTH_SCALE * PUSH * c["hold"] >= WINCE_PUSH:
		her.wince()


func _widen(her, stretch: float) -> void:
	var col = her.collarContainer.collar
	if not _widened:
		_widened = true
		_collar_x = col.x
	col.scaleX = 1.0 + stretch * WIDEN
	col.x = _collar_x + (col.scaleX - 1.0) * 70.0   # as the mod: keeps the front of the collar on her throat


func _unwiden() -> void:
	if not _widened or g.her == null:
		_widened = false
		return
	var col = g.her.collarContainer.collar
	col.scaleX = 1.0
	col.x = _collar_x
	_widened = false
