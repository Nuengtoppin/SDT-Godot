extends SDTExtension
## Port of sby's breastfirmnessV5 Loader mod: how firmly her breasts spring back, and how hard her movement throws
## them, each in one of three modes: the game's own, by breast size (Auto), or set by hand (Manual). In Her > Body;
## saved in the character code as breastfirmness:<mode>,<firmness> and breastforce:<mode>,<force>, like the Loader mod.
## Dialogue words [BREASTFIRMNESS_STIFFER] / [BREASTFIRMNESS_LOOSER] make them firmer / looser by dialogchangerate.
## Adapted: the Loader mod replaced the breasts' update method; here it changes the value points
## BreastController.firmness, .push and .damping, so the game's own spring stays and other extensions combine.
## Defaults: the game's own firmness and force (the Loader pack started both in Auto).

const MODES := ["Game", "By size", "Manual"]
const CODE_MODES := ["Normal", "Auto", "Manual"]

var mode := 0          # firmness: 0 the game's, 1 by breast size, 2 manual
var firmness := 0.4    # manual firmness (0.01 - 1)
var force_mode := 0
var force := 0.25      # manual force (0 - 1; the movement's push times 4 x this)
var change := 0.0      # what the dialogue words added to the Auto range


func _init() -> void:
	title = "Breast firmness"
	description = "How firmly her breasts spring back and how much her movement throws them."


func _setup() -> void:
	setting("defaultmode", "Game", {"label": "Firmness for new characters", "options": MODES})
	setting("defaultsliderval", 0.4, {"label": "Manual firmness for new characters", "min": 0.0, "max": 1.0})
	setting("defaultforcemode", "Game", {"label": "Bounce for new characters", "options": MODES})
	setting("defaultforcesliderval", 0.25, {"label": "Manual bounce for new characters", "min": 0.0, "max": 1.0})
	setting("breastsizestart", 20, {"label": "By size: from breast size", "min": 0, "max": 300})
	setting("breastsizeend", 70, {"label": "By size: to breast size", "min": 0, "max": 300})
	setting("firmnessstart", 0.9, {"label": "By size: firmness at the first size", "min": 0.02, "max": 1.0})
	setting("firmnessend", 0.2, {"label": "By size: firmness at the second size", "min": 0.02, "max": 1.0})
	setting("extrafirmnessforcostume", 0.1, {"label": "Extra firmness with a top or bra on", "min": 0.0, "max": 1.0})
	setting("dialogchangerate", 0.1, {"label": "Change per dialogue word", "min": 0.0, "max": 1.0})
	setting("speedreturn", 0.7, {"label": "Speed kept each frame (the game: 0.7)", "min": 0.0, "max": 0.9})
	setting("enablevanillasaving", true, {"label": "Save in the character code"})


func _enable() -> void:
	_defaults()
	modify(&"BreastController.firmness", {"op": "fn", "when": func(_c): return mode != 0,
		"fn": func(_v, c): return _firmness(c._costumeOn)})
	modify(&"BreastController.push", {"op": "fn", "when": func(_c): return force_mode != 0,
		"fn": func(v, _c): return v * _force() * 4.0})
	var damping: float = get_setting("speedreturn")
	if damping != 0.7:
		modify(&"BreastController.damping", {"op": "set", "value": damping})
	hook_before(&"Dialogue.checkWordAction", _on_word)
	var her_tip := " Saved with the character."
	menu_control("her", "Body", MenuSchema.choice("Breast firmness",
		"How firmly her breasts spring back: the game's own, by breast size, or the slider below." + her_tip,
		MODES, func(): return MODES[mode], func(v: String): _set_mode(MODES.find(v)), {"after": "Breast size",
		"keywords": "breast firmness bounce jiggle breastfirmness"}))
	menu_control("her", "Body", {"type": "slider", "label": "Firmness", "min": 0.01, "max": 1.0, "after": "Breast size",
		"tip": "Moving it sets the firmness by hand (0.01 floppy, 1 stiff); otherwise it shows the current one.",
		"get": func(): return g.her.leftBreastController._breastFirmness,
		"set": func(v: float): firmness = v; _set_mode(2)})
	menu_control("her", "Body", MenuSchema.choice("Breast bounce",
		"How much her movement throws her breasts: the game's own, by breast size, or the slider below." + her_tip,
		MODES, func(): return MODES[force_mode], func(v: String): force_mode = maxi(0, MODES.find(v)),
		{"after": "Breast size", "keywords": "breast force bounce jiggle breastfirmness"}))
	menu_control("her", "Body", {"type": "slider", "label": "Bounce", "min": 0.0, "max": 1.0, "after": "Breast size",
		"tip": "Moving it sets the force by hand; otherwise it shows the current one (0.25: about the game's).",
		"get": func(): return _force() if force_mode != 0 else 0.25,
		"set": func(v: float): force = v; force_mode = 2})
	if get_setting("enablevanillasaving"):
		charcode_field("breastfirmness", func(): return "%s,%.5f" % [CODE_MODES[mode], firmness],
			func(v: String, _l): _load_code(v, false), func(_l): _default_firmness())
		charcode_field("breastforce", func(): return "%s,%.5f" % [CODE_MODES[force_mode], force],
			func(v: String, _l): _load_code(v, true), func(_l): _default_force())
	g.her.updateBreastFirmness()


func _disable() -> void:
	if g.her != null:
		g.her.updateBreastFirmness()   # the game's firmness back (the modifiers are gone)


func _defaults() -> void:
	_default_force()
	_default_firmness()


func _default_firmness() -> void:
	mode = maxi(0, MODES.find(str(get_setting("defaultmode"))))
	firmness = _limit(get_setting("defaultsliderval"))
	change = 0.0
	if g.her != null:
		g.her.updateBreastFirmness()


func _default_force() -> void:
	force_mode = maxi(0, MODES.find(str(get_setting("defaultforcemode"))))
	force = get_setting("defaultforcesliderval")


func _load_code(v: String, is_force: bool) -> void:
	var parts := v.split(",")
	var m := maxi(0, CODE_MODES.find(parts[0]))
	var val := float(parts[1]) if parts.size() > 1 and parts[1].is_valid_float() else -1.0
	if is_force:
		force_mode = m
		if val >= 0:
			force = clampf(val, 0, 1)
	else:
		change = 0.0
		mode = m
		if val >= 0:
			firmness = _limit(val)
		g.her.updateBreastFirmness()


func _set_mode(m: int) -> void:
	mode = maxi(0, m)
	change = 0.0
	g.her.updateBreastFirmness()


static func _limit(v: float) -> float:
	return clampf(v, 0.01, 1.0)


## The firmness of the current mode (by size: a line between two sizes and firmnesses, moved by the dialogue words).
func _firmness(costume_on: bool) -> float:
	var f := firmness
	if mode == 1:
		var s0: float = get_setting("breastsizestart")
		var s1: float = get_setting("breastsizeend")
		var f0 := _limit(get_setting("firmnessstart") + change)
		var f1 := _limit(get_setting("firmnessend") + change)
		var size := clampf(g.characterControl.breastSize, minf(s0, s1), maxf(s0, s1))
		f = f0 if s1 == s0 else (size - s0) * (f1 - f0) / (s1 - s0) + f0
	if costume_on:
		f += get_setting("extrafirmnessforcostume")
	return _limit(f)


## The force of the current mode (by size: none for tiny breasts, a little less past size 100).
func _force() -> float:
	if force_mode != 1:
		return force
	var size := clampf(g.characterControl.breastSize, 0, 150)
	var mult := clampf(size / 25.0, 0, 1)
	var upper := 1.0 - 0.5 * clampf((size - 100) / 50.0, 0, 1)
	return clampf((0.1 + size / 150.0 * 0.23 * upper) * mult, 0, 0.9)


func _on_word(h) -> void:
	var raw: String = h.args[0]
	var step: float = get_setting("dialogchangerate")
	if raw == "[BREASTFIRMNESS_STIFFER]":
		pass
	elif raw == "[BREASTFIRMNESS_LOOSER]":
		step = -step
	else:
		return
	if mode == 2:
		firmness = _limit(firmness + step)
	else:
		change += step
	g.her.updateBreastFirmness()
	g.dialogueControl.nextWord()
	h.cancel()
