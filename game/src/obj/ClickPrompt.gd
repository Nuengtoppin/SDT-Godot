class_name ClickPrompt
extends FlashMovieClip
## Port of obj.ClickPrompt: the "click to start" prompt that fades in and out.

var fadingIn := false
var fadingOut := false
var showing := false


func _init() -> void:
	addEventListener(FlashEvent.ENTER_FRAME, tick)
	alpha = 0
	visible = false


func tick() -> void:
	if fadingIn:
		alpha += 0.025
		if alpha >= 1:
			alpha = 1
			fadingIn = false
	elif fadingOut:
		alpha -= 0.025
		if alpha <= 0:
			alpha = 0
			visible = false
			fadingOut = false


func fadeIn() -> void:
	fadingIn = true
	fadingOut = false
	showing = true
	visible = true


func fadeOut() -> void:
	if showing:
		fadingOut = true
		fadingIn = false
		showing = false
