class_name MainMenuButton
extends FlashMovieClip
## Port of obj.MainMenuButton: fades in at start and brightens on roll-over.

var intro := true
var fadingIn := false
var fadingOut := false
var fade: float = 0.0
var alphaFade: float = 0.0


func _init() -> void:
	super()
	addEventListener(FlashEvent.ENTER_FRAME, tick)
	addEventListener(FlashEvent.ROLL_OVER, rolledOver)
	addEventListener(FlashEvent.ROLL_OUT, rolledOut)
	buttonMode = true
	useHandCursor = true
	alpha = 0


func tick() -> void:
	if intro:
		alphaFade += 0.033
		if alphaFade >= 1:
			alphaFade = 1
			intro = false
	if fadingIn:
		fade += 51
		if fade >= 255:
			fade = 255
			fadingIn = false
	elif fadingOut:
		fade -= 10
		if fade <= 0:
			fade = 0
			fadingOut = false
	colorTransform = FlashColorTransform.new(1, 1, 1, alphaFade, fade, fade, fade)


func rolledOver(_e = null) -> void:
	fadingIn = true
	fadingOut = false


func rolledOut(_e = null) -> void:
	fadingOut = true
	fadingIn = false
