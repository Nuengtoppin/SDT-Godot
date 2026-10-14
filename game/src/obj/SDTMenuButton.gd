class_name SDTMenuButton
extends FlashMovieClip
## Port of obj.MenuButton (renamed: Godot has a built-in MenuButton class): Up / Over / Down states.

var labelContainer: FlashMovieClip
var thumb: FlashMovieClip
var referenceBorder: FlashMovieClip
var isOver := false


func _init() -> void:
	super()
	addEventListener(FlashEvent.ROLL_OVER, rolledOver)
	addEventListener(FlashEvent.ROLL_OUT, rolledOut)
	addEventListener(FlashEvent.MOUSE_DOWN, pressed)
	addEventListener(FlashEvent.MOUSE_UP, released)
	mouseChildren = false


func rolledOver(_e = null) -> void:
	isOver = true
	gotoAndStop("Over")


func rolledOut(_e = null) -> void:
	isOver = false
	gotoAndStop("Up")


func pressed(_e = null) -> void:
	gotoAndStop("Down")


func released(_e = null) -> void:
	gotoAndStop("Over" if isOver else "Up")
