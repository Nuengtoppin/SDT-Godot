extends SDTExtension
## Built-in reimplementation of the Loader mod alternativePassOut (V2): when she passes out, her eyes do one of
##   - roll: her upper eyelids settle at a random height (frames 100-140) while her eyes roll up (chance 0.33),
##   - freeze: her eyelids and eyes stay where they were (chance 0.5 of the rest),
##   - the game's own;
## her eyes go blank and their highlights fade, she does not wince or start coughing until she wakes, and the pass-out
## sound often stays silent (it plays only with him in her mouth, like the mod). "Alternative pass-out" (Behaviour >
## Reactions) is off by default. Values from the mod's settings file as shipped. Written from its source; port fix:
## the mod's settings were read as text, so its eyelid height became "100" + a number joined as text (eyes shut,
## rolling down); here they are numbers.

const EYELID_MAX := 140.0
const EYELID_MIN := 100.0
const EYELID_FRAMES := 30.0
const EYEROLL_FRAMES := 60.0
const EYEROLL_SILENT_CHANCE := 0.75
const FREEZE_SILENT_CHANCE := 0.75
const HIGHLIGHT_FADE_FRAMES := 40.0
const BLANK_IRIS := 3

var option := 0   # 0: the game's, 1: roll, 2: freeze
var _active := false
var _lid_frame := 0.0
var _lid_target := 0
var _lid_start := 0
var _lid_rate := 0.0
var _roll := 0.0
var _roll_max := 0.0
var _roll_rate := 0.0
var _saved_iris := 0
var _frozen_frame := 1
var _frozen_rotation := 0.0
var _frozen_target := 0.0
var _frozen_ang := 0.0


func _init() -> void:
	id = "alternativepassout"
	title = "alternativePassOut"
	description = "alternativePassOut: her eyes roll up or freeze when she passes out (Behaviour > Reactions)."
	default_enabled = true


func _setup() -> void:
	setting("on", false, {"label": "Alternative pass-out",
		"desc": "When she passes out her eyes may roll up or freeze, go blank, and she stays quiet."})
	setting("eyeroll_chance", 0.33, {"label": "Eye roll chance", "min": 0, "max": 1, "step": 0.01})
	setting("freeze_chance", 0.5, {"label": "Freeze chance (of the rest)", "min": 0, "max": 1, "step": 0.01})
	setting("blank_eyes", true, {"label": "Blank eyes while passed out"})


func _enable() -> void:
	hook_before(&"Her.passOut", _pass_out, -10)   # before moremoods' (it replaces both, like the mod)
	hook_after(&"Her.updateEyes", func(_c): _update_eyes())
	hook_after(&"Her.lookAt", func(_c): _after_look())
	hook_before(&"Her.updateElements", func(_c):
		if _active and option != 0 and g.her.passedOut:
			g.her.winceTimer = 0)
	hook_before(&"SoundControl.playStartBreath", func(c):
		if _active and option != 0 and g.her.passedOut:
			c.cancel())
	hook_before(&"Her.wakeUp", func(_c): _wake())
	menu_control("behaviour", "Reactions", MenuSchema.setting_control(self, "on"))


func _disable() -> void:
	_wake()


func _pass_out(c: Hooks.Call) -> void:
	if not get_setting("on"):
		return
	var her = g.her
	_choose(her)
	c.cancel()
	her.passOutFactor = her.passOutMax
	var silent: bool = not her.mouthFull or (option == 1 and EYEROLL_SILENT_CHANCE > randf()) \
		or (option == 2 and FREEZE_SILENT_CHANCE > randf())
	var mm = Extensions.get_extension("moremoods")
	var asleep: bool = mm != null and mm.enabled and mm.mood_name == "Asleep"
	if not silent and not asleep:
		g.soundControl.playPassOut(her.pos)
	her.passedOut = true
	her.startArmsPassOut()
	Hooks.after(&"Her.passOut", her)


func _choose(her) -> void:
	_active = true
	var eye = her.eye
	_frozen_frame = eye.upperEyelid.currentFrame
	_frozen_rotation = eye.ball.irisContainer.rotation_degrees
	_frozen_target = her.eyeMotion["target"]
	_frozen_ang = her.eyeMotion["ang"]
	_saved_iris = g.characterControl.currentIris
	option = 0
	if get_setting("eyeroll_chance") > randf():
		if not (her.eyelidMotion["isClosed"] or her.winceTimer > 0):
			option = 1
			_lid_target = int(EYELID_MIN + randf() * (EYELID_MAX - EYELID_MIN))
			_lid_start = eye.upperEyelid.currentFrame
			_lid_rate = (_lid_start - _lid_target) / EYELID_FRAMES
			_roll_max = (150.0 - _lid_target) / 2.0
			_roll_rate = _roll_max / EYEROLL_FRAMES
			_lid_frame = 0.0
			_roll = 0.0
	elif get_setting("freeze_chance") > randf() and her.winceTimer <= 0:
		option = 2
	if option != 0 and get_setting("blank_eyes"):
		g.characterControl.setIris(BLANK_IRIS)


func _set_lids(frame: int) -> void:
	var eye = g.her.eye
	eye.upperEyelid.gotoAndStop(frame)
	eye.ball.upperEyelidMask.gotoAndStop(frame)
	eye.upperEyelid.eyeshadow.gotoAndStop(frame)
	eye.upperEyelid.mascara.gotoAndStop(frame)


func _update_eyes() -> void:
	var her = g.her
	if not _active or not her.passedOut or her.winceTimer != 0:
		return
	if option == 1:
		_lid_frame += _lid_rate
		var f: float = maxf(_lid_target, _lid_start - _lid_frame) if _lid_rate > 0 else minf(_lid_target, _lid_start - _lid_frame)
		if not her.eyelidMotion["isClosed"]:
			_set_lids(int(floor(f + 0.5)))
		_roll = minf(_roll_max, _roll + _roll_rate)
		her.eyeMotion["target"] -= her.passOutFactor / her.passOutMax * _roll
		her.eyeMotion["ang"] += (her.eyeMotion["target"] - her.eyeMotion["ang"]) * 0.2
		her.eye.ball.irisContainer.rotation_degrees = her.eyeMotion["ang"] - 90.0
		her.eye.ball.highlights.alpha -= 1.0 / HIGHLIGHT_FADE_FRAMES
	elif option == 2:
		_set_lids(_frozen_frame)


func _after_look() -> void:
	var her = g.her
	if _active and her.passedOut and option == 2:
		her.eye.ball.irisContainer.rotation_degrees = _frozen_rotation
		her.eyeMotion["target"] = _frozen_target
		her.eyeMotion["ang"] = _frozen_ang


func _wake() -> void:
	if not _active or g.her == null:
		return
	_active = false
	g.her.eye.ball.highlights.alpha = 1
	if g.characterControl.currentIris != _saved_iris:
		g.characterControl.setIris(_saved_iris)
	option = 0
