extends SDTExtension
## Built-in reimplementation of the Loader mod gaggeddialog (sby, v3): she can say her spoken lines while gagged
## (and, as an option, with him in her mouth but not deep), garbled, with small mouth movements. Written from its
## documentation and behaviour; the defaults are the settings of sby's Loader pack.
##
## Modes (buttons in the Options menu, Behaviour > Speech in the new menu, saved in the character code):
## - when gagged: off / on / on, also with him in her mouth while gagged
## - with him in her mouth (not deep, no gag): off / on
## While she speaks like this the dialogue variables gaggedialog_gagged and gaggedialog_mouthfull are 1 or 0.

const GAGGED_MODES := ["Off", "Gagged", "Gagged + mouth full"]
## Garbling, applied in order to each spoken word: [from, to]
const JUMBLE := [["Ch", "HC"], ["S", "SH"], ["P", "PH"], ["K", "KH"], ["D", "YR"], ["M", "MH"], ["B", "WH"],
	["J", "JH"], ["F", "YH"], ["N", "NH"], ["G", "YG"], ["Z", "YG"], ["X", "XH"], ["T", "HT"], ["V", "VH"],
	["ch", "hc"], ["s", "sh"], ["p", "ph"], ["k", "kh"], ["d", "yr"], ["m", "mh"], ["b", "wh"], ["j", "jh"],
	["f", "yh"], ["n", "nh"], ["g", "yg"], ["z", "yg"], ["x", "xh"], ["t", "ht"], ["v", "vh"]]
const JUMBLE_STRONG := [["S", "SH"], ["P", "HU"], ["Ch", "SCh"], ["K", "KH"], ["D", "YR"], ["M", "MH"],
	["B", "WH"], ["J", "JH"], ["F", "HY"], ["N", "NH"], ["G", "YG"], ["Z", "YG"], ["X", "XH"], ["Th", "CSH"],
	["T", "HT"], ["V", "VH"], ["s", "sh"], ["p", "hu"], ["ch", "sch"], ["k", "kh"], ["d", "yr"], ["m", "mh"],
	["b", "wh"], ["j", "jh"], ["f", "hy"], ["n", "nh"], ["g", "yg"], ["z", "yg"], ["x", "xh"], ["th", "csh"],
	["t", "ht"], ["v", "vh"]]

var gagged_mode := 0      # 0 off, 1 when gagged, 2 also gagged with him in her mouth
var in_mouth := false     # with him in her mouth (no gag)
var _held := false
var _mouth_full := false
var _plain: Array = []    # the line's words as written / garbled
var _garbled: Array = []
var _managing := false
var _swapped := false
var _gag_button: ExtButton = null
var _mouth_button: ExtButton = null


func _init() -> void:
	id = "gaggeddialog"
	title = "gaggeddialog"
	description = "She can say her spoken lines while gagged (or with him in her mouth), garbled, with small mouth movements."
	default_enabled = true


func _setup() -> void:
	setting("defaultmodegagged", "Gagged + mouth full", {"label": "When gagged (new characters)", "options": GAGGED_MODES})
	setting("defaultmodeinmouth", false, {"label": "With him in her mouth (new characters)"})
	setting("enablejumbleddialog", "Garbled", {"label": "Text while gagged", "options": ["As written", "Garbled", "Strongly garbled"]})
	setting("enablesmallmouthmovement", true, {"label": "Small mouth movements while speaking gagged"})
	setting("usedefaultonnocharcode", true, {"label": "Characters without these modes in their code use the defaults"})
	setting("enablevanillasaving", true, {"label": "Save the modes in the character code"})


func _enable() -> void:
	_defaults()
	hook_before(&"Her.canSpeak", _can_speak)
	hook_before(&"Her.setTargetPhoneme", _set_target_phoneme)
	hook_after(&"Her.checkPosition", func(_c): _check_position())
	hook_after(&"Her.checkMovementSounds", func(_c): _check_mouth())
	hook_after(&"Her.setSpeaking", func(_c): _set_speaking())
	hook_after(&"Dialogue.startSpeakingPhrase", func(_c): _line_started())
	hook_after(&"Dialogue.continueSpeaking", func(_c): _continue())
	if get_setting("enablevanillasaving"):
		charcode_field("gaggeddialog", _code, func(v, _l): _load_code(v), func(_l): _code_missing())
	_gag_button = menu_button("optionsMenu", -55, -38, "😷", func(): set_gagged_mode((gagged_mode + 1) % 3))
	_mouth_button = menu_button("optionsMenu", -72, -38, "😮", func(): set_in_mouth(not in_mouth))
	menu_control("behaviour", "Speech", MenuSchema.choice("Speech when gagged",
		"She can say her spoken lines with a gag on (garbled); \"+ mouth full\" also while gagged with him in her mouth.",
		GAGGED_MODES, func(): return GAGGED_MODES[gagged_mode], func(v: String): set_gagged_mode(GAGGED_MODES.find(v)),
		{"wide": true}))
	menu_control("behaviour", "Speech", MenuSchema.toggle("Speech with him in her mouth",
		"She can say her spoken lines with him in her mouth (not deep), garbled, opening her mouth a little.",
		func(): return in_mouth, func(on: bool): set_in_mouth(on)))
	_refresh()


func _defaults() -> void:
	gagged_mode = maxi(0, GAGGED_MODES.find(get_setting("defaultmodegagged")))
	in_mouth = get_setting("defaultmodeinmouth")
	_refresh()


func set_gagged_mode(m: int) -> void:
	gagged_mode = clampi(m, 0, 2)
	_refresh()


func set_in_mouth(on: bool) -> void:
	in_mouth = on
	_refresh()


func _refresh() -> void:
	if _gag_button != null:
		_gag_button.set_color([0xFFFFFF, 0x00FF00, 0xFFFF00][gagged_mode])
	if _mouth_button != null:
		_mouth_button.set_color(0x00FF00 if in_mouth else 0xFFFFFF)


# ---------------------------------------------------------------- character code

func _code() -> String:
	return ["Disabled", "Enabled", "EnabledInMouth"][gagged_mode] + "," + ("InMouthEnabled" if in_mouth else "InMouthDisabled")


## A full character code without the field.
func _code_missing() -> void:
	if get_setting("usedefaultonnocharcode"):
		_defaults()


func _load_code(v: String) -> void:
	var parts := v.split(",")
	var i := ["Disabled", "Enabled", "EnabledInMouth"].find(parts[0])
	if i != -1:
		gagged_mode = i
	if parts.size() > 1 and parts[1] in ["InMouthEnabled", "InMouthDisabled"]:
		in_mouth = parts[1] == "InMouthEnabled"
	_refresh()


# ---------------------------------------------------------------- speaking

func _active() -> bool:
	var her = g.her
	return (gagged_mode > 0 and her.gagged) or (her.mouthFull and in_mouth)


## Her.canSpeak: also while gagged / with him in her mouth, in the chosen modes.
func _can_speak(c: Hooks.Call) -> void:
	var dc = g.dialogueControl
	if not dc.speaking and not dc.waitingToContinue:
		_swapped = false
		_managing = false
	var mm = Extensions.get_extension("moremoods")
	if mm != null and mm.enabled and mm.get("can_speak_level") == 5:
		c.cancel(false)
		return
	if gagged_mode == 0 and not in_mouth:
		return   # the game's rule
	var her = g.her
	var ok: bool = not her.speaking and (not her.mouthFull or in_mouth or (gagged_mode == 2 and her.gagged)) \
		and (not her.gagged or gagged_mode > 0) and not her.held and not her.passedOut and not her.swallowing \
		and not her.clenchTeeth
	if ok:
		var st: Dictionary = dc.advancedController._dialogueDataStore
		st["gaggedialog_mouthfull"] = 1 if her.mouthFull else 0
		st["gaggedialog_gagged"] = 1 if her.gagged else 0
	c.cancel(ok)


## His penis width between her lips, as a jaw angle (the mouth opens around it).
func _penis_jaw() -> float:
	var her = g.her
	var w: float = g.him.getPenisWidth(her.localToGlobal(her.topLipA), her.head.jaw.localToGlobal(her.bottomLipA), her.mouthFull)
	w = (w - 20.0) / 2.0 / 165.0
	return rad_to_deg(asin(clampf(w, -1.0, 1.0)) / 12.0 * 20.0) - 11.0


func _last_lip() -> int:
	return mini(79, int(floor(maxf(0.0, -g.her.head.jaw.rotation_degrees * 4.5 + 30.0))))


## Her.setTargetPhoneme: gagged or full, her lips only move a little around the gag / him.
func _set_target_phoneme(c: Hooks.Call) -> void:
	var word: Dictionary = c.args[0]
	if not word.get("phoneme") or not _active():
		return
	c.cancel()
	var her = g.her
	her.targetPhoneme = word["phoneme"]
	her.phonemeDelay = c.args[1]
	var up := 3
	var down := 3
	if not her.gagged:
		up = _last_lip()
		down = up
	var top_mult := 0.5
	var bottom_mult := 1.5
	if her.head.face.currentFrameLabel == "Angry":
		top_mult = 0.5
		bottom_mult = 0.75
		if not her.gagged:
			up -= 1
			down += 6
		else:
			up = 2
			down = 9
	if not get_setting("enablesmallmouthmovement"):
		top_mult = 0.0
		bottom_mult = 0.0
	elif not her.gagged:
		top_mult = 0.25
		bottom_mult = 0.25
	var t: Dictionary = her.targetPhoneme
	var upper := clampi(int(up + (t["upperLip"] - 50) * top_mult), 0, 79)
	var lower := clampi(int(down + (t["lowerLip"] - 50) * bottom_mult), 0, 79)
	var jaw: float
	if her.gagged:   # gagged and full: the gag wins
		jaw = roundf(t["jaw"])
	else:   # full only: she opens her mouth over him a little for the vowels
		var base := _penis_jaw()
		var a := clampf((minf(0.0, t["jaw"]) + 2.6) / -9.0, 0.0, 1.0)   # 1 = most closed (mm), 0 = most open (oh)
		a = (1.0 - a) * (1.0 + maxf(0.0, minf(6.0, 7.0 - base)))
		if not get_setting("enablesmallmouthmovement"):
			a = 0.0
		jaw = roundf(base + a)
	her.targetPhoneme = {"name": "GTH", "upperLip": upper, "lowerLip": lower, "jaw": jaw}


func _set_speaking() -> void:
	if not _active():
		return
	var her = g.her
	var t: Dictionary = her.targetPhoneme.duplicate()
	t["jaw"] = _penis_jaw()
	t["upperLip"] = _last_lip()
	t["lowerLip"] = t["upperLip"]
	her.targetPhoneme = t


## Held down or pulled off while speaking like this: she stops.
func _check_position() -> void:
	var her = g.her
	if not _held and her.held and her.speaking:
		g.dialogueControl.interrupt()
	_held = her.held


func _check_mouth() -> void:
	var her = g.her
	if in_mouth and _mouth_full and not her.mouthFull and her.speaking:
		g.dialogueControl.interrupt()
	_mouth_full = her.mouthFull


# ---------------------------------------------------------------- garbled text

func _line_started() -> void:
	_swapped = false
	var dc = g.dialogueControl
	var mode: String = get_setting("enablejumbleddialog")
	if mode == "As written" or (gagged_mode == 0 and not in_mouth) or not dc.sayingSpeakingStyle:
		return
	var table: Array = JUMBLE_STRONG if mode == "Strongly garbled" else JUMBLE
	_plain = dc.words.duplicate()
	_garbled = []
	for w in _plain:
		var text: String = w.word
		if not w.actionWord:
			for r in table:
				text = text.replace(r[0], r[1])
		_garbled.append(Word.new(text))
	if _active():
		dc.words = _garbled.duplicate()
		_swapped = true
	_managing = true


## After a pause: garbled again if she is (still) gagged / full, as written if not any more.
func _continue() -> void:
	var dc = g.dialogueControl
	if not dc.speaking and not dc.waitingToContinue:
		_swapped = false
		_managing = false
	if not _managing:
		return
	var her = g.her
	if her.gagged or her.mouthFull:
		if not _swapped:
			dc.words = _garbled.duplicate()
			_swapped = true
	elif _swapped:
		dc.words = _plain.duplicate()
		_swapped = false
