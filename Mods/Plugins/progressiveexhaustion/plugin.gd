extends SDTExtension
## Port of sby's progressiveExhaustionV8 Loader mod: she tires over a session. Every pass-out adds one unit of
## exhaustion, and what she goes through adds (or, breathing freely, takes away) a dynamic part up to
## dynamicExhaustionMax; her exhaustion = (pass-outs + dynamic part) x her exhaustion factor (character code field
## exhaustionFactor, 1 = the pack's pace). Each effect grows with it up to its most (values.cfg, the mod's keys and
## numbers). Behaviour > Exhaustion: on / off, her exhaustion now, Reset (key ') and +1 pass-out (key ;), her factor,
## one switch per group of effects. The counters (Settings > Counters) show it as "dynamic part (pass-outs)".
##
## Groups:
## - eyes: upper eyelids droop and lower eyelids lose the mood's squint (Her.upperEyelid / Her.lowerEyelid), eyebrows
##   rise (new value point Her.eyebrowFrame) and angry eyebrows relax after normalEyebrowsStart (new Her.angryEyebrows),
##   her gaze drops below his face (Her.lookTarget; Ahegao / Broken / Submissive: her rolled-up gaze, Her.gazeAngle) and
##   jitters upwards past eyeJitterStart (Her.gazeAngle), shock shrinks her pupils less (Her.irisScale), the highlights
##   in her eyes fade (Her.highlightsAlpha); she wakes with her eyes rolled from below and less shock (Her.wakeGaze,
##   Her.wakeShock).
## - breathing: less breath (Her.breathMax, not while moremoods' Asleep), she passes out faster with him in her mouth
##   and recovers slower (new value points Her.passOutGain, Her.passOutRecovery; past passOutRecoveryMax a pass-out
##   keeps her out until Reset), weaker pull-off while held (new Her.pullOffPower), less throat resistance at the
##   entrance of her throat (Her.resistance, its boundary part as the mod's slider), slower swallows (Her.swallowSpeed).
##   The game's own pass-out speed with no air is passOutMultiplier x her exhaustion factor (0.75 in the pack). Her
##   pass-out sound gets quieter.
## - coughs: she coughs less often, weaker (her cough's force) and quieter, her breasts move less on a cough, she gags
##   (the sound) less often and quieter, and past winceStart her winces are skipped more often.
## - body: less blush (with Dynamic blushing: of all of it), her hands tap less often and weaker, she waggles her eyebrows,
##   clenches her teeth and blinks less (and blinks twice in a row less), she sweats and (past tearsStart) cries more.
## - skin: her skin loses colour (CharacterControl.skinSaturation) and slowly gets it back after a reset.
## - arms: very tired she wakes with her arms on her legs (armsHerLegsStart) or loose (armsLooseStart), unless
##   armoverhaul's dynamic arms move her arms; below that her arms go back where they were before she passed out, and so
##   does a reset (saveArmPositions). The pack never did this: the mod worked it out only with armOverhaul installed and
##   used it only without it; here it is what its settings describe.
## - face: her mouth goes slack (Her.mouthShape "Normal", mouthNormalStart), the mascara on her lower eyelids thins as
##   her eyelids droop (Tears.lowerMascaraTop, Her.lowerEyelidSquint), she bites less with moremoods (Her.biteRarity);
##   off in the pack: her tongue out as she wakes (tongueOutStart), spent eyes (spentEyesStart, Her.lookTarget).
## - spent (offActionStart): now and then a soft lick sound with him in her mouth, otherwise a wince, a tear, a splat,
##   a breast jolt and a quiet cough, gag, swallow or splat sound (the pack's choice), and drool. Its own timer (the mod
##   borrowed the game's gagDroolTimer).
## The reset key no longer switches the game's Breathing option on (the breath value points recover by themselves).
## Adapted: every effect on her eyes is a MOOD modifier instead of the mod rewriting her eye frames after the game: the
## game's own easing moves her eyes, moods, dialogue triggers and passing out still apply on top; with no exhaustion
## nothing changes (the mod set her lower eyelids even then). The jitter only moves her gaze's target (the mod also
## eased her eyes faster towards it). Waking shock: wakeShockMax 1 means none (the mod took at most 1 off the game's 85).
## "Out cold" (noBreathingThreshold) stops her recovering instead of switching the game's Breathing option off.
## Coughs and body: value points instead of the mod's writes after the game (Her.coughDue, Her.coughForce,
## Her.openCoughForce, Her.winceTime, Her.blinks, Her.quickBlink, Her.blushAlpha, BreastController.kick,
## SoundControl.herSoundVolume, IKController.tapPower / tapSpeed); a skipped gag sound, tap, eyebrow waggle or teeth
## clench is a veto (hook) as in the mod. Blush: the mod multiplied the blush's alpha every frame (meant for dynamic
## blushing, which sets it again each frame; without it her blush faded out for good): here it is her blush (dynamic or
## the colour's own) times the effect. The breast kick applies to every push, as the mod's did (coughs, spanks, dialogue
## triggers): the cough's or the open cough's value by whether he is in her mouth.

const CARD := "Exhaustion"
const RESET_KEY := 222        # ' (the mod's resetKey)
const INCREMENT_KEY := 186    # ; (the mod's incrementKey)
const GROUPS := [["eyes", "Eyes", "Her eyelids droop, her eyebrows rise, her gaze drops and jitters, her eyes lose "
	+ "their shine and shock; she wakes with her eyes rolled."],
	["breathing", "Breathing and passing out", "Less breath, she passes out faster and recovers slower (very tired: "
		+ "out until you reset her), pulls off weaker, her throat resists less, she swallows slower, her pass-out sound "
		+ "is quieter."],
	["coughs", "Coughs, gags and winces", "She coughs less often, weaker and quieter, her breasts move less on a cough, "
		+ "she gags less often and quieter; very tired, she winces less."],
	["body", "Blush, hands, face, sweat and tears", "Less blush, weaker and fewer hand taps, fewer eyebrow waggles, "
		+ "teeth clenches and blinks; she sweats and (very tired) cries more."],
	["skin", "Skin colour", "Her skin loses colour as she tires and slowly gets it back after you reset her."],
	["arms", "Arms on waking", "Very tired she wakes with her arms on her legs (from 6 pass-outs) or loose (from 8), "
		+ "unless armoverhaul's dynamic arms move them; otherwise, and on Reset, her arms go back where they were."],
	["face", "Face", "Her mouth goes slack (from 5 pass-outs), the mascara under her eyes thins as her eyelids droop, she "
		+ "bites less (moremoods)."],
	["spent", "Spent", "From 6 pass-outs, now and then: a wince, a tear, drool, a quiet gag, swallow or splat sound; "
		+ "with him in her mouth a soft lick sound."]]
## moremoods' lower eyelid squint per mood (the mod's lowerEyelidValue)
const SQUINT := {"Happy": 10, "Excited": 10, "Overwhelmed": 10, "Drugged": 15, "Elated": 15, "Tease": 15,
	"Disgusted": 20, "Smug": 25, "Horny": 25}

var V := {}                   # values.cfg: the mod's key -> number
var pass_outs := 0            # passOutCount
var dynamic := 0.0            # dynamicExhaustion (starts at -dynamicExhaustionBuffer)
var current := 0.0            # currentExhaustion: the dynamic part, 0 .. dynamicExhaustionMax
var total := 0.0              # totalExhaustion
var factor := 1.0             # exhaustionFactor (character code)
var E := {}                   # each effect's strength now (the mod's ...Current values)
var _just_throated := false
var _head_grabbed := false
var _sweat_timer := -1        # ticks to the next sweat drop (-1: none)
var _tears_timer := -1        # ticks to the next tear (-1: none)
var _skin_back := 0.0         # after a reset her skin's colour comes back: this much is still missing
var _skin_shown := 0.0        # how much colour her skin has lost, as applied (in steps of 0.005)
var _saved_arms := [-1, -1]   # her arm positions before exhaustion moved them (savedLeft/RightArmPosition)
var _reset_arms := false      # reset while she was out: her arms go back as she wakes
var _mouth_normal := false    # her mouth is slack (kept while she is out with updateOnWake)
var _spent_timer := 0         # ticks to the next spent action
var _last_sound := {}         # sound list -> the last one played from it


func _init() -> void:
	title = "Progressive exhaustion"
	description = "She tires over a session: every pass-out and what she goes through make her eyes droop, her breath short, her coughs weak..."


func _setup() -> void:
	setting("on", true, {"label": "Exhaustion", "desc": "She tires over a session: every pass-out (and what she goes "
		+ "through) makes her more exhausted, and the effects grow with it. Off: none of it."})
	for gr in GROUPS:
		setting(gr[0], true, {"label": gr[1], "desc": gr[2]})


func _enable() -> void:
	_load_values()
	dynamic = -V["dynamicExhaustionBuffer"]
	_update()
	menu_control("behaviour", CARD, MenuSchema.setting_control(self, "on"))
	menu_control("behaviour", CARD, _readout())
	menu_control("behaviour", CARD, MenuSchema.actions("", "", [
		["Reset", reset, "She is rested again: no pass-outs, no exhaustion (key ')."],
		["+1 pass-out", increment, "Adds a pass-out's worth of exhaustion (key ;)."]]))
	menu_control("behaviour", CARD, {"type": "slider", "label": "How fast she tires", "tip": "Her exhaustion factor "
		+ "(this character, kept in her code): 0.5 tires half as fast, 2 twice as fast.", "min": 0.1, "max": 4.0,
		"step": 0.05, "wide": true, "get": func(): return factor, "set": func(v: float): factor = v; _update(),
		"release": func(): g.saveData.saveCharData(), "reset": func(): factor = 1.0; _update(),
		"format": func(v): return str(snappedf(v, 0.01))})
	for gr in GROUPS:
		menu_control("behaviour", CARD, MenuSchema.setting_control(self, gr[0]))
	menu_control("help", "Keys", MenuSchema.note("Progressive exhaustion: ' she is rested again, ; adds a pass-out"))
	on_key(RESET_KEY, reset, "exhaustion: rested again")
	on_key(INCREMENT_KEY, increment, "exhaustion: +1 pass-out")
	charcode_field("exhaustionFactor", func(): return null if factor == 1.0 else str(factor),
		func(v: String, _l): factor = maxf(0.0, v.to_float()); _update(), func(_l): factor = 1.0; _update())
	hook_after(&"Her.passOut", func(_c): _passed_out())
	hook_before(&"Her.wakeUp", func(_c): _waking(), -10)
	hook_after(&"Him.closeHand", func(_c): _head_grabbed = g.him.currentArmPosition == 0)
	var eyes := func(her): return _on("eyes") and total > 0.0 and Moods.current() != "Android"
	modify(&"Her.upperEyelid", {"phase": Hooks.MOOD, "op": "fn", "when": eyes, "fn": _upper_lid})
	modify(&"Her.lowerEyelid", {"phase": Hooks.MOOD, "op": "fn", "when": eyes, "fn": _lower_lid})
	modify(&"Her.eyebrowFrame", {"phase": Hooks.MOOD, "op": "fn", "when": eyes, "fn": func(v, _her): return v - E["eyebrow"]})
	modify(&"Her.angryEyebrows", {"phase": Hooks.MOOD, "op": "set", "value": false,
		"when": func(her): return eyes.call(her) and total >= V["normalEyebrowsStart"]})
	modify(&"Her.lookTarget", {"phase": Hooks.MOOD, "op": "fn", "when": eyes, "fn": _look})
	modify(&"Her.gazeAngle", {"phase": Hooks.MOOD, "op": "fn", "when": eyes, "fn": _gaze})
	modify(&"Her.irisScale", {"phase": Hooks.MOOD, "op": "fn", "when": eyes,
		"fn": func(v, her): return v + her.eyelidShock / 200.0 * E["shock"]})
	modify(&"Her.highlightsAlpha", {"phase": Hooks.MOOD, "op": "fn", "when": func(_her): return _on("eyes") and total > 0.0,
		"fn": func(v, _her): return v * (1.0 - E["highlight"])})
	# she wakes with her eyes rolled from below and less shock
	modify(&"Her.wakeGaze", {"phase": Hooks.MOOD, "op": "fn", "when": func(_her): return _on("eyes"),
		"fn": func(v, _her): return v + E["wake_eye_motion"]})
	modify(&"Her.wakeShock", {"phase": Hooks.MOOD, "op": "fn", "when": func(_her): return _on("eyes"),
		"fn": func(v, _her): return v * (1.0 - E["wake_shock"])})
	var breathing := func(_her): return _on("breathing")
	var tired := func(_her): return _on("breathing") and total > 0.0
	modify(&"Her.passOutGain", {"phase": Hooks.MOOD, "op": "fn", "when": breathing, "fn": _pass_out_gain})
	modify(&"Her.passOutRecovery", {"phase": Hooks.MOOD, "op": "fn", "when": tired,
		"fn": func(v, her): return 0.0 if E["out_cold"] and her.passedOut else maxf(0.0, v - E["recovery"])})
	modify(&"Her.breathMax", {"phase": Hooks.MOOD, "op": "fn", "when": func(her): return tired.call(her) and Moods.current() != "Asleep",
		"fn": func(v, _her): return v * (1.0 - E["breath"])})
	modify(&"Her.pullOffPower", {"phase": Hooks.MOOD, "op": "fn", "when": tired, "fn": _pull_off})
	modify(&"Her.resistance", {"phase": Hooks.MOOD, "op": "fn", "when": tired, "fn": _resistance})
	modify(&"Her.swallowSpeed", {"phase": Hooks.MOOD, "op": "fn", "when": tired, "fn": func(v, _her): return v / E["swallow_slow"]})
	modify(&"SoundControl.herSoundVolume", {"phase": Hooks.MOOD, "op": "fn", "when": func(_sc): return total > 0.0,
		"fn": _volume})
	# coughs
	var coughs := func(_o): return _on("coughs") and total > 0.0
	modify(&"Her.coughDue", {"phase": Hooks.MOOD, "op": "fn", "when": coughs, "fn": func(v, _her): return v and randf() > E["cough"]})
	modify(&"Her.coughForce", {"phase": Hooks.MOOD, "op": "fn", "when": coughs, "fn": func(v, _her): return v * (1.0 - E["cough_factor"])})
	modify(&"Her.openCoughForce", {"phase": Hooks.MOOD, "op": "fn", "when": coughs,   # with him in her mouth: a cough's
		"fn": func(v, her): return v * (1.0 - (E["open_cough_factor"] if her.penisInMouthDist <= 0 else E["cough_factor"]))})
	modify(&"BreastController.kick", {"phase": Hooks.MOOD, "op": "fn", "when": coughs,
		"fn": func(v, _b): return v * (1.0 - (E["cough_accel"] if g.her.penisInMouthDist > 0 else E["open_cough_accel"]))})
	modify(&"Her.winceTime", {"phase": Hooks.MOOD, "op": "fn", "when": coughs,
		"fn": func(v, _her): return 0 if E["wince"] > 0.0 and randf() <= E["wince"] else v})
	hook_before(&"SoundControl.playGag", func(c): if coughs.call(null) and randf() <= E["gag"]: c.cancel())
	# body
	var body := func(_o): return _on("body") and total > 0.0
	modify(&"Her.blushAlpha", {"phase": Hooks.MOOD, "op": "fn", "when": body, "fn": func(v, _her): return v * E["blush"]})
	modify(&"Her.blinks", {"phase": Hooks.MOOD, "op": "fn", "when": body, "fn": func(v, _her): return v and randf() > E["blink"]})
	modify(&"Her.quickBlink", {"phase": Hooks.MOOD, "op": "fn", "when": body,
		"fn": func(v, _her): return v * (1.0 - E["consecutive_blink"])})
	modify(&"IKController.tapPower", {"phase": Hooks.MOOD, "op": "fn", "when": body, "fn": func(v, _ik): return v * (1.0 - E["tap_power"])})
	modify(&"IKController.tapSpeed", {"phase": Hooks.MOOD, "op": "fn", "when": body, "fn": func(v, _ik): return v * E["tap_speed"]})
	hook_before(&"IKController.tap", func(c): if body.call(null) and randf() <= E["tap"]: c.cancel())
	hook_before(&"Her.waggleEyebrows", func(c): if body.call(null) and randf() <= E["waggle"]: c.cancel())
	hook_before(&"Her.startClenchingTeeth", func(c): if body.call(null) and randf() <= E["clench"]: c.cancel())
	# skin
	modify(&"CharacterControl.skinSaturation", {"phase": Hooks.MOOD, "op": "fn", "when": func(_cc): return _skin_shown > 0.0,
		"fn": func(v, _cc): return v * (1.0 - _skin_shown)})
	# arms (after _waking: her exhaustion as she wakes; before armoverhaul's wake fix, which then moves her arms there)
	hook_before(&"Her.wakeUp", func(_c): _wake_arms(), -10)
	hook_after(&"Her.wakeUp", func(_c): _woke())
	# face
	var face := func(_o): return _on("face") and total > 0.0 and Moods.current() != "Android"
	modify(&"Her.mouthShape", {"phase": Hooks.MOOD, "op": "set", "value": "Normal",
		"when": func(her): return _on("face") and _slack_mouth(her)})
	modify(&"Her.biteRarity", {"phase": Hooks.MOOD, "op": "fn", "when": func(_her): return _on("face") and total > 0.0,
		"fn": func(v, _her): return pow(v, pow(V["biteAdvisorFactor"], total))})
	modify(&"Tears.lowerMascaraTop", {"phase": Hooks.MOOD, "op": "fn", "when": face,
		"fn": func(v, _t): return v + floori(23.0 * E["upper_lid"])})
	modify(&"Her.lowerEyelidSquint", {"phase": Hooks.MOOD, "op": "fn", "when": face,
		"fn": func(v, _her): return v * (1.0 - E["lower_lid"])})
	modify(&"Her.lookTarget", {"phase": Hooks.MOOD, "op": "fn", "fn": _spent_look,
		"when": func(her): return face.call(her) and V["spentEyesStart"] <= total})
	on_late_tick(_tick)


func _setting_changed(_key: String, _value) -> void:
	_update()


func _load_values() -> void:
	V.clear()
	var cf := ConfigFile.new()
	var err := cf.load(file_path("values.cfg"))
	if err != OK:
		push_error("progressiveexhaustion: values.cfg could not be read (%s)" % error_string(err))
		return
	for section in cf.get_sections():
		for k in cf.get_section_keys(section):
			V[k] = float(cf.get_value(section, k))


func _on(group: String) -> bool:
	return get_setting("on") and get_setting(group)


## Her exhaustion now, for the menu
func _readout() -> Dictionary:
	return {"type": "custom", "label": "Her exhaustion", "tip": "Her exhaustion now: pass-outs plus what she has been "
		+ "through, times how fast she tires.", "wide": false,
		"build": func():
			var l := Label.new()
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			l.add_theme_color_override("font_color", MenuTheme.ACCENT)
			l.set_meta("refresh", func(): l.text = "%.2f (%d pass-outs)" % [total, pass_outs])
			return l}


## The counter's text (counters extension): the dynamic part and the pass-outs, as the mod showed them
func counter_text() -> String:
	return "%s (%d)" % [str(floorf(current * 100.0) / 100.0), pass_outs]


# ---------------------------------------------------------------- exhaustion

## She is rested again (the mod's reset key)
func reset() -> void:
	if _on("arms") and V["saveArmPositions"] == 1 and not _dynamic_arms():
		if g.her.passedOut:
			_reset_arms = true
		else:
			_restore_arms()
	_skin_back = _skin_shown   # her colour comes back slowly
	pass_outs = 0
	dynamic = -V["dynamicExhaustionBuffer"]
	_update()


## A pass-out's worth more (the mod's increment key)
func increment() -> void:
	pass_outs += 1
	_update()
	_save_arms()


func _passed_out() -> void:
	pass_outs += 1
	_update()
	_save_arms()


## Where her arms go back to (reset, waking below armsHerLegsStart): saved while exhaustion doesn't move them yet. The
## mod saved them only as she passed out (and started from position 0); here the +1 key saves them too, and with none
## saved yet her arms stay where they are.
func _save_arms() -> void:
	if not E["arms_legs"] and not E["arms_loose"]:
		_saved_arms = [g.her.currentLeftArmPosition, g.her.currentRightArmPosition]


## A spank or punch changes her exhaustion (spankanywhere): more (up to `cap`) or less (not below `floor_`, unless
## she was already below it)
func add_dynamic(delta: float, floor_ := 0.0, cap := 5.0) -> void:
	if delta > 0.0:
		dynamic = minf(cap, dynamic + delta)
	else:
		dynamic = maxf(minf(dynamic, floor_), dynamic + delta)
	_update()


func _waking() -> void:
	dynamic += V["wakeExhaustion"]
	_update()


## Every effect's strength from her exhaustion (the mod's updateExhaustion)
func _update() -> void:
	current = clampf(dynamic, 0.0, V["dynamicExhaustionMax"]) if V["dynamicExhaustionEnabled"] == 1 else 0.0
	total = (pass_outs + current) * factor if get_setting("on") else 0.0
	var before := (pass_outs + current - 1) * factor   # one pass-out less (her state when she wakes)
	E["upper_lid"] = _grow("upperEyelid")
	E["lower_lid"] = _grow("lowerEyelid")
	E["eye_motion"] = _grow("eyeMotion")
	E["jitter_range"] = maxf(0.0, V["eyeJitterRangeFactor"] * (total - V["eyeJitterStart"]))
	E["eyebrow"] = roundf(100.0 * _grow("eyebrow"))
	E["shock"] = _grow("shock")
	E["wake_eye_motion"] = roundf(150.0 * minf(V["wakeEyeMotionMax"], V["wakeEyeMotionRate"] * before))
	E["wake_shock"] = clampf(V["wakeShockRate"] * before, 0.0, V["wakeShockMax"])
	E["highlight"] = _grow("eyeHighlight")
	E["pass_out"] = 0.2 * _grow("passOut")
	E["recovery"] = 0.5 * _grow("passOutRecovery")
	E["out_cold"] = V["noBreathingThreshold"] == 1 and _grow("passOutRecovery") >= V["passOutRecoveryMax"]
	E["breath"] = _grow("breath")
	E["pull_increase"] = 1.0 / pow(V["pullOffPowerIncreaseFactor"], total)
	E["pull_max"] = 1.0 - _grow("pullOffPower")
	E["pull_start"] = 1.0 - _grow("pullOffPowerStart")
	E["throat"] = 1.0 - _grow("throatResistance")
	E["swallow_slow"] = 1.0 + _grow("swallowSlow") * (V["swallowSlowMultiplier"] - 1.0)
	E["pass_out_volume"] = _grow("passOutVolume")
	E["cough"] = _grow("cough")
	E["cough_factor"] = _grow("coughFactor")
	E["cough_accel"] = _grow("coughBreastAccel")
	E["cough_volume"] = _grow("coughVolume")
	E["open_cough_factor"] = _grow("openCoughFactor")
	E["open_cough_accel"] = _grow("openCoughBreastAccel")
	E["open_cough_volume"] = _grow("openCoughVolume")
	E["gag"] = _grow("gag")
	E["gag_volume"] = _grow("gagVolume")
	E["wince"] = minf(V["winceMax"], maxf(0.0, V["winceRate"] * (total - V["winceStart"])))
	E["blush"] = 1.0 - _grow("blush")
	E["tap"] = _grow("tapHands")
	E["tap_power"] = _grow("tapHandsPower")
	E["tap_speed"] = pow(1.0 + E["tap_power"] * 0.0005, 2100.0)
	E["waggle"] = _grow("waggleEyebrows")
	E["blink"] = _grow("blink")
	E["consecutive_blink"] = _grow("consecutiveBlink")
	E["clench"] = _grow("clenchTeeth")
	# sweat and tears: the mod set their timers here, and as this runs every tick a drop comes with a chance of
	# 1 in (180 - sweat) per tick, a tear 1 in 240
	var units: float = pass_outs + current
	E["sweat"] = roundi(180.0 * minf(V["sweatMax"], V["sweatRate"] * (units - 1.0) * factor)) if get_setting("on") else 0
	_sweat_timer = int(floor(randf() * (180 - E["sweat"]))) if E["sweat"] > 0 else -1
	E["tears"] = roundi(240.0 * minf(V["tearsMax"], V["tearsRate"] * (units - V["tearsStart"]) * factor))
	_tears_timer = int(floor(randf() * 240.0)) if get_setting("on") and V["tearsStart"] <= total else -1
	E["skin"] = _grow("skinSaturation") if V["enableSkinSaturationDecrease"] == 1 and _on("skin") else 0.0
	_apply_skin()
	E["arms_legs"] = V["armsHerLegsStart"] <= total
	E["arms_loose"] = V["armsLooseStart"] <= total
	E["spent"] = V["offActionStart"] <= total
	E["spent_rate"] = roundi(420.0 * minf(V["offActionMax"], V["offActionRate"] * (units - V["offActionStart"]) * factor))


## min(<key>Max, <key>Rate x exhaustion)
func _grow(key: String) -> float:
	return minf(V[key + "Max"], V[key + "Rate"] * total)


func _tick() -> void:
	var her: Her = g.her
	if her == null or g.gamePaused or her.passedOut or not get_setting("on"):
		return
	if V["dynamicExhaustionEnabled"] == 1:
		_gain(her)
		_update()
	if _on("body"):
		_sweat_and_tears(her)
	if _skin_back > 0.0:   # after a reset: her colour returns
		_skin_back = maxf(0.0, _skin_back - V["skinSaturationReturnRate"])
		_apply_skin()
	if _on("spent") and E["spent"]:
		_spent(her)


## The dynamic part: what she goes through tires her, breathing freely rests her (the mod's frameRefresh)
func _gain(her: Her) -> void:
	var mult: float = 1.0 + pass_outs * V["passOutExhaustionModifier"]
	var breath: float = g.breathLevel / g.breathLevelMax
	var tiring: bool = V["noExhaustionWithBreath"] == 0 or breath >= 1.0
	if her.breathing:
		dynamic += minf(0.0, V["breathingExhaustion"] * (1.0 - breath) / mult)
	elif tiring:
		dynamic += V["inMouthExhaustion"] * mult
	if tiring and her.held:
		dynamic += V["heldExhaustion"] * mult
	if tiring and her.penisInMouthDist > her.deepthroatDistance and her.mouthFull:
		if not _just_throated:
			dynamic += V["deepthroatExhaustion"] * mult
			_just_throated = true
	else:
		_just_throated = false
	if her.swallowing:
		dynamic += V["swallowExhaustion"] * mult
	if _head_grabbed:
		dynamic += V["headGrabExhaustion"] * mult
		_head_grabbed = false
	dynamic += her.vigour / 1050.0 * V["vigorExhaustion"] * mult
	dynamic = clampf(dynamic, -V["dynamicExhaustionBuffer"], V["dynamicExhaustionMax"])


# ---------------------------------------------------------------- eyes

func _squint() -> int:
	return SQUINT.get(Moods.current(), 0)


func _upper_lid(v, her: Her) -> int:
	if her.winceTimer != 0 and V["enableVanillaWince"] == 1:
		return v
	var lev := _squint()
	if lev <= 10:
		return roundi(v + (150 - v) * E["upper_lid"])
	return roundi(v + (135 - v) * E["upper_lid"] + 15 * E["lower_lid"])


func _lower_lid(_v, her: Her) -> int:
	var lev := _squint()
	return maxi(her.upperLid, 150 + lev - roundi(lev * E["lower_lid"]))


## Her gaze at his face drops (the mod moved her hisFace point down)
func _look(v: Vector2, her: Her) -> Vector2:
	if v == her.hisFace and not _rolled():
		return Vector2(v.x, v.y + E["eye_motion"] * 430.0)
	return v


func _rolled() -> bool:
	return Moods.current() in [Her.AHEGAO_MOOD, "Broken", "Submissive"]


func _gaze(v: float, _her: Her) -> float:
	if _rolled():
		v = minf(115.0, v + 6.0 * E["eye_motion"])
	var r: float = E["jitter_range"]
	if r > 0.0 and (V["disableEyeJitterFrightened"] == 0 or Moods.current() != "Frightened"):
		v -= randf() * r + r
	return v


# ---------------------------------------------------------------- sounds, coughs, body

## Her cough, open cough and gag sounds (coughs) and her pass-out sound (breathing) are quieter
func _volume(v: float, sc) -> float:
	match sc.herSound:
		&"cough":
			return v * (1.0 - E["cough_volume"]) if _on("coughs") else v
		&"openCough":
			return v * (1.0 - E["open_cough_volume"]) if _on("coughs") else v
		&"gag":
			return v * (1.0 - E["gag_volume"]) if _on("coughs") else v
		&"passOut":
			return v * (1.0 - E["pass_out_volume"]) if _on("breathing") else v
	return v


func _sweat_and_tears(her: Her) -> void:
	if _sweat_timer > 0:
		_sweat_timer -= 1
	elif _sweat_timer > -1:
		if randf() < 0.5:
			Sweat.spawn(her.head, Vector2(21, -65), Vector2(150, 100), [her.rightArmContainer.upperArm, her.torso.back,
				her.torso.midLayer.chest, her.torso.midLayer.rightBreast.hitArea, her.torso.leg])
		else:
			Sweat.spawn(her.torso.back, Vector2(110, -230), Vector2(320, 100), [her.torso.midLayer.chest,
				her.torso.midLayer.rightBreast.hitArea, her.torso.leg])
		_sweat_timer = int(30.0 * randf() + (180 - E["sweat"]) / (current + pass_outs + 1.0))
	if _tears_timer > 0:
		_tears_timer -= 1
	elif _tears_timer == 0:
		her.tears.addTearSpot()
		_tears_timer = int(floor(randf() * (240 - E["tears"]))) + 360


# ---------------------------------------------------------------- skin, arms, face, spent

## Her skin's colour: what she has lost, or what is still missing after a reset; the filters are made again only when
## it has changed by a step
func _apply_skin() -> void:
	var s := snappedf(maxf(E.get("skin", 0.0), _skin_back), 0.005)
	if s == _skin_shown or g.characterControl == null or g.her == null:
		return
	_skin_shown = s
	g.characterControl.updateSkinHSL()


## armoverhaul's dynamic arms move her arms by her exhaustion themselves (the mod's dynamicArms_comm)
func _dynamic_arms() -> bool:
	var ao = Extensions.by_id.get("armoverhaul")
	return ao != null and ao.enabled and Extensions.is_on("armoverhaul") and ao.dyn != null and ao.dyn.mode != 0


## As she wakes: arms on her legs or loose when very tired, otherwise back where they were (the mod's wakeUpPre)
func _wake_arms() -> void:
	if not _on("arms") or _dynamic_arms():
		return
	var her: Her = g.her
	if not E["arms_loose"] and not E["arms_legs"]:
		if V["saveArmPositions"] == 1:
			_restore_arms()
		return
	for left in [true, false]:
		var at: int = her.currentLeftArmPosition if left else her.currentRightArmPosition
		if at == 0:
			continue
		var to := 4 if E["arms_loose"] else (1 if at != 4 else -1)
		if to >= 0 and to != at:
			if left:
				her.setLeftArmPosition(to)
			else:
				her.setRightArmPosition(to)
	g.inGameMenu.updateArmsList()


func _restore_arms() -> void:
	var her: Her = g.her
	if _saved_arms[0] >= 0 and her.currentLeftArmPosition != _saved_arms[0]:
		her.setLeftArmPosition(_saved_arms[0])
	if _saved_arms[1] >= 0 and her.currentRightArmPosition != _saved_arms[1]:
		her.setRightArmPosition(_saved_arms[1])
	g.inGameMenu.updateArmsList()


func _woke() -> void:
	if _reset_arms:
		_reset_arms = false
		_restore_arms()
	if _on("face") and V["tongueOutStart"] <= total:
		g.her.tongue.hangOut()


## Her slack mouth from mouthNormalStart; with updateOnWake it changes only while she is awake
func _slack_mouth(her: Her) -> bool:
	if V["updateOnWake"] != 1 or not her.passedOut:
		_mouth_normal = V["mouthNormalStart"] <= total and Moods.current() != "Android"
	return _mouth_normal


## Spent eyes: she stares up past him (a point fixed to her head, the mod's 816, -138)
func _spent_look(_v: Vector2, her: Her) -> Vector2:
	return g.sceneLayer.globalToLocal(her.localToGlobal(Vector2(816, -138)))


## Now and then while she is spent (the mod's off action)
func _spent(her: Her) -> void:
	if _spent_timer > 0:
		_spent_timer -= 1
		return
	var scaled: bool = V["offActionScaleWithCoughSettings"] == 1
	var sc: SoundControl = g.soundControl
	if her.mouthFull:
		_play(sc.lick, minf(1.0, 0.2 + randf() * (1.0 - E["cough_volume"])) if scaled else 0.55 + randf() * 0.1, 0.5)
	else:
		var choices: Array = []
		for pair in [["offActionCoughSound", 0], ["offActionGagSound", 1], ["offActionQuietGagSound", 2],
				["offActionSwallowSound", 3], ["offActionSplatSound", 4]]:
			if V[pair[0]] == 1:
				choices.append(pair[1])
		if V["offActionWince"] == 1:
			her.wince()
		if V["offActionAddTear"] == 1:
			her.tears.addTearSpot()
		if V["offActionGenerateSplat"] == 1:
			her.generateSplat(3, 7)
		if V["offActionBreastAccel"] == 1:
			var a := 0.1 if scaled else 0.08
			her.leftBreastController.accelerate(a)
			her.rightBreastController.accelerate(a)
		if V["offActionCoughFactor"] == 1:
			her.coughFactor = randf() * (1.0 - E["open_cough_factor"]) + 0.25 if scaled else randf() / 10.0 + 0.2   # direct: a one-off flinch, as a cough sets it
		match choices[randi() % choices.size()] if not choices.is_empty() else -1:
			0:
				_spent_cough(her, scaled)
			1:
				sc.playGag(0.5)
			2:
				_play([sc.gag[2], sc.gag[5], sc.gag[7], sc.gag[10]],
					minf(1.0, 0.2 + randf() * (1.0 - E["cough_volume"])) if scaled else 0.3 + randf() * 0.1, 0.0)
			3:
				sc.playSwallow(0.5)
			4:
				sc.playSplat()
	_spent_timer = int(floor(randf() * 240.0)) + 420 - E["spent_rate"]
	if V["offActionDrool"] == 1 and (V["offActionDroolLimiter"] != 1 or _spent_timer > 120):
		her.randomSpitDrool()


## The spent cough: a quiet cough, without the game's cough's tear, splat and wince (the mod's spentcough)
func _spent_cough(her: Her, scaled: bool) -> void:
	her.nextCoughTime = int(floor(randf() * 210)) + 30   # direct: one-off, as a cough sets it
	her.coughing = true   # direct: (the same)
	_play(g.soundControl.cough, minf(1.0, 0.2 + randf() * (1.0 - E["cough_volume"])) if scaled else 0.15 + randf() * 0.1,
		her.pos * 2.0 - 1.0)
	her.justCoughed = true   # direct: (the same)


## One of `list` (not the last one played from it) at that volume and pan (-1 left .. 1 right, kept in the game's range)
func _play(list: Array, vol: float, pan: float) -> void:
	if list.is_empty():
		return
	var key: int = list[0].get_instance_id()
	var i := randi() % list.size()
	if list.size() > 1 and i == _last_sound.get(key, -1):
		i = (i + 1) % list.size()
	_last_sound[key] = i
	var sc: SoundControl = g.soundControl
	list[i].play(0.0, 0, FlashSoundTransform.new(vol, clampf(pan, sc.leftPan, sc.rightPan)))


# ---------------------------------------------------------------- breathing

## With no air: the game's pace times passOutMultiplier (and her exhaustion factor), plus more with him in her mouth
func _pass_out_gain(v: float, her: Her) -> float:
	v *= V["passOutMultiplier"] * (factor if V["passOutUseExhaustionFactor"] == 1 else 1.0)
	if her.mouthFull and g.breathing and total > 0.0:
		v += E["pass_out"]
	return v


func _pull_off(p: Dictionary, _her: Her) -> Dictionary:
	p["increase"] *= E["pull_increase"]
	p["max"] *= E["pull_max"]
	p["start"] *= E["pull_start"]
	return p


## The entrance of her throat resists less (the part the Throat resistance slider sets)
func _resistance(v: float, her: Her) -> float:
	if her.penisInMouthDist < her.deepthroatStartDistance or her.penisInMouthDist > her.deepthroatDistance:
		return v
	var upper: float = her.resistance["upper"]
	return upper + (v - upper) * E["throat"]
