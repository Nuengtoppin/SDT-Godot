extends SDTExtension
## A fix of the game: her tongue goes in while her teeth are clenched, and her teeth wait for it.
## In the game (checked in a run): her teeth close in 5 ticks while her tongue takes about 30 to come in, and may
## still lick meanwhile (its move in waits for the action playing); with her tongue hanging out (Ahegao mood,
## DialogueActions' TONGUE_OUT, moremoods) its move in turns back out at once (Tongue.moveTongueIn) and it stays
## almost all the way out between her clenched teeth; a long lick plays on for over a second.
## "Tongue in when she clenches her teeth" (Behaviour > Reactions, on by default): while her teeth are clenched or
## still opening, the tongue's own update is skipped and it moves in quickly instead (4 frames a tick, the game's
## fast move in), no licks; her teeth hold (value point Her.teethClosing) until it is in, at most WAIT ticks. When
## her teeth have opened and she was hanging it out, it goes out again.

const STEP := 4    # frames a tick on the way in (Tongue.moveTongueIn's fast in)
const WAIT := 12   # ticks her teeth wait at most for her tongue

var _wait := 0
var _was_clenched := false


func _init() -> void:
	id = "tongueguard"
	title = "tongueGuard"
	description = "Fix: her tongue goes in while her teeth are clenched, and her teeth wait for it (Behaviour > Reactions)."
	default_enabled = true


func _setup() -> void:
	setting("on", true, {"label": "Tongue in when she clenches her teeth",
		"desc": "A fix of the game: her tongue goes in before her teeth close and stays in while they are clenched (the game lets them close over it)."})


func _enable() -> void:
	hook_before(&"Tongue.update", _on_update, -50)
	menu_control("behaviour", "Reactions", MenuSchema.setting_control(self, "on"))
	_was_clenched = false
	_apply()


func _disable() -> void:
	pass   # its hook and modifier go with it


func _setting_changed(key: String, _value) -> void:
	if key == "on":
		_apply()


func _apply() -> void:
	unmodify()
	_wait = 0
	if get_setting("on"):
		modify(&"Her.teethClosing", {"phase": Hooks.CLAMP, "op": "fn", "fn": func(v, her): return v and _tongue_in_or_waited(her)})


## Her tongue is at rest inside her mouth.
static func tongue_in(t) -> bool:
	return t.currentLabel == "InDone" or (t.currentLabel == "TongueOut" and t.currentFrame <= t.tongueOutStartFrame)


func _tongue_in_or_waited(her) -> bool:
	if tongue_in(her.tongue):
		_wait = 0
		return true
	_wait += 1
	return _wait > WAIT


func _on_update(c) -> void:
	if not get_setting("on"):
		return
	var her = g.her
	var t = c.obj
	if her == null:
		return
	if not (her.clenchTeeth or her.clenchTeethRatio > 0.0):
		if _was_clenched:
			_was_clenched = false
			_wait = 0
			if t.hangingOut:
				t.startMovingTongue("out")
		return
	_was_clenched = true
	c.cancel()   # no licks and no tongue out while her teeth are clenched or still opening
	if tongue_in(t):
		return
	if t.currentLabel != "TongueOut":
		t.gotoAndStop(t.tongueOutEndFrame)   # an action (a lick) or the end of the move out: from her tongue's out pose
	else:
		t.gotoAndStop(maxi(t.tongueOutStartFrame, t.currentFrame - STEP))
	if t.currentFrame <= t.tongueOutStartFrame:   # in: as the game's move in ends
		t.swallowTime = int(ceil(randf() * 60)) + 15
		t.cumOnTongue = 0
		t.gotoAndStop("InDone")
		t.tongueOut = false
		t.playingAction = false
		t.currentAction = Callable()
		t.waitingForIn = false
		t.waitingForOut = false
		t.waitingToTouch = false
		t.fastIn = false
