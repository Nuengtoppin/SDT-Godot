class_name ScreenEffects
extends FlashMovieClip
## Port of obj.ScreenEffects: white flash / pulse and whiteout overlays.

var whiteFlash: FlashMovieClip
var whiteout: FlashMovieClip
var flashing := false
var pulsing := false
var stoppingPulse := false


func _init() -> void:
	whiteout.stop()
	whiteFlash.stop()
	addEventListener(FlashEvent.ENTER_FRAME, tick)


func showWhiteout(v: float) -> void:
	v = minf(100, maxf(1, Maths.round(v)))
	whiteout.gotoAndStop(int(v))


func showFlash() -> void:
	whiteFlash.gotoAndPlay("flash")
	flashing = true
	pulsing = false
	stoppingPulse = false


func showPulse() -> void:
	if not pulsing:
		whiteFlash.gotoAndPlay("pulse")
		stoppingPulse = false
		pulsing = true


func stopPulse() -> void:
	if pulsing:
		stoppingPulse = true


func tick() -> void:
	if flashing:
		if whiteFlash.currentLabel == "flashDone":
			flashing = false
			whiteFlash.gotoAndStop("normal")
	if pulsing:
		if whiteFlash.currentLabel == "pulseDone":
			if stoppingPulse:
				stoppingPulse = false
				pulsing = false
				whiteFlash.gotoAndStop("normal")
			else:
				whiteFlash.gotoAndPlay("pulse")
