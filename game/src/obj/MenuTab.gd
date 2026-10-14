class_name MenuTab
extends FlashMovieClip
## Port of obj.MenuTab: a menu tab with On / Off / Over states.

var on := false


func _init() -> void:
	super()
	for f in 3:
		addFrameScript(f, stop)
	addEventListener(FlashEvent.ROLL_OVER, rolledOver)
	addEventListener(FlashEvent.ROLL_OUT, rolledOut)


func setOn() -> void:
	on = true
	gotoAndStop("On")


func setOff() -> void:
	on = false
	gotoAndStop("Off")


func rolledOver(_e = null) -> void:
	if not on:
		gotoAndStop("Over")


func rolledOut(_e = null) -> void:
	gotoAndStop("On" if on else "Off")
