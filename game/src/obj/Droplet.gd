class_name Droplet
extends FlashMovieClip
## Port of obj.Droplet: a flying drop of spit / cum that stretches with its speed and shrinks away.

var speed: Vector2
var padding: float = 30.0
var sizeFactor: float
var sizeDecrease: float


func _init(p: Vector2 = Vector2.ZERO, v: Vector2 = Vector2.ZERO, size: float = 1.0, decrease: float = 0.2,
		a: float = 1.0, isCum: bool = false) -> void:
	super()
	if isCum:
		gotoAndStop("cum")
	else:
		stop()
	alpha = a
	x = p.x
	y = p.y
	speed = v
	sizeFactor = size
	sizeDecrease = decrease
	_orient()
	addEventListener(FlashEvent.ENTER_FRAME, tick)


func _orient() -> void:
	rotation_degrees = g.getAngle(speed.x, speed.y)
	var len := sqrt(speed.x * speed.x + speed.y * speed.y)
	scaleY = minf(6.0, maxf(1.0, len / 10.0)) * sizeFactor
	scaleX = sizeFactor


func tick() -> void:
	speed /= g.friction
	x += speed.x
	y += speed.y + g.gravity
	_orient()
	sizeFactor -= sizeDecrease
	if x < -padding or x > g.screenSize.x + padding:
		killMe()
	elif y > g.screenSize.y + padding:
		killMe()
	elif sizeFactor <= 0:
		killMe()


func killMe() -> void:
	removeEventListener(FlashEvent.ENTER_FRAME, tick)
	parent.removeChild(self)
	queue_free()
