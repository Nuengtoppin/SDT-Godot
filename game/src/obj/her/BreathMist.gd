class_name BreathMist
extends FlashMovieClip
## Port of obj.her.BreathMist: a puff of breath that drifts, grows and fades.

var speed: Vector2
var angSpeed: float
var fadingIn: bool
var maxAlpha: float


func _init() -> void:
	super()
	speed = Vector2(randf() * (g.breathLevel / 40.0) + 3.0, randf() * 2.0 - 1.2)
	angSpeed = (randf() - 0.5) / 10.0
	rotation_degrees = randf() * 360.0
	alpha = 0
	var s := 0.3 + randf() / 5.0
	scaleX = s
	scaleY = s
	maxAlpha = minf(1.0, g.breathLevel / g.outOfBreathPoint) / 5.0
	fadingIn = true
	addEventListener(FlashEvent.ENTER_FRAME, tick)


func tick() -> void:
	x += speed.x
	y += speed.y
	scaleX += 0.01
	scaleY += 0.01
	rotation_degrees += angSpeed
	if fadingIn:
		alpha += 0.1
		if alpha >= maxAlpha:
			fadingIn = false
	else:
		alpha -= 0.005
		if alpha <= 0:
			removeEventListener(FlashEvent.ENTER_FRAME, tick)
			parent.removeChild(self)
			queue_free()
