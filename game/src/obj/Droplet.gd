class_name Droplet
extends FlashMovieClip
## Port of obj.Droplet: a flying drop of spit / cum that stretches with its speed and shrinks away.

var speed: Vector2
var padding: float = 30.0
var sizeFactor: float
var sizeDecrease: float
var _spare := false   # goes back to the spares instead of being freed

## Spent drops of a splat, for the next one (a new drop costs about 0.1 ms, and a hilt makes 20 in one tick). By isCum.
static var _spares := {false: [], true: []}
const MAX_SPARES := 40


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


## A drop in layer for bursts: reuses a spent one when there is one.
static func spawn(layer: FlashSprite, p: Vector2, v: Vector2, size: float, decrease: float = 0.2, a: float = 1.0,
		isCum: bool = false) -> Droplet:
	var d: Droplet = null
	var spares: Array = _spares[isCum]
	while d == null and not spares.is_empty():
		var o = spares.pop_back()
		if is_instance_valid(o):
			d = o
	if d == null:
		d = Droplet.new(p, v, size, decrease, a, isCum)
		d._spare = true
	else:
		d.alpha = a
		d.x = p.x
		d.y = p.y
		d.speed = v
		d.sizeFactor = size
		d.sizeDecrease = decrease
		d._orient()
		d.addEventListener(FlashEvent.ENTER_FRAME, d.tick)
	layer.addChild(d)
	d.reset_physics_interpolation()
	return d


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
	var spares: Array = _spares[_frame != 0]
	if _spare and spares.size() < MAX_SPARES:
		spares.append(self)
	else:
		queue_free()
