class_name MenuCheckbox
extends FlashMovieClip
## Port of obj.MenuCheckbox: On / Off / OnOver / OffOver / Disabled states.

var on := false
var isOver := false
var disabled := false


func _init() -> void:
	super()
	for f in 4:
		addFrameScript(f, stop)
	addEventListener(FlashEvent.ROLL_OVER, rolledOver)
	addEventListener(FlashEvent.ROLL_OUT, rolledOut)


func setOn() -> void:
	on = true
	if not disabled:
		gotoAndStop("OnOver" if isOver else "On")


func setOff() -> void:
	on = false
	if not disabled:
		gotoAndStop("OffOver" if isOver else "Off")


func disable() -> void:
	disabled = true
	gotoAndStop("Disabled")


func enable() -> void:
	disabled = false
	gotoAndStop("On" if on else "Off")


func rolledOver(_e = null) -> void:
	isOver = true
	if not disabled:
		gotoAndStop("OnOver" if on else "OffOver")


func rolledOut(_e = null) -> void:
	isOver = false
	if not disabled:
		gotoAndStop("On" if on else "Off")
