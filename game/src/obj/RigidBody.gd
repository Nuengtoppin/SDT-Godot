class_name RigidBody
extends FlashMovieClip
## Port of obj.RigidBody: dangling items (piercings, earrings) that swing from their attachment point.

var rgbFill

var movement := Vector2()
var lastMovement := Vector2()
var acceleration := Vector2()
var lastPos = null
var pos := Vector2()
var angSpeed: float = 0.0
var hanging := true
var lengthMultiplier: float = 0.0
var lastFrameLabel := ""
var clockwiseLimit: float = 0.0
var haveClockwiseLimit := false
var antiClockwiseLimit: float = 0.0
var haveAntiClockwiseLimit := false


func _init() -> void:
	addEventListener(FlashEvent.ENTER_FRAME, tick)
	addEventListener(FlashEvent.ADDED, childAdded)
	frameChanged()
	if parent:
		lastPos = parent.localToGlobal(Vector2(x, y))


func childAdded(e: FlashEvent) -> void:
	if e.target != self:
		frameChanged()


func setLimit(limit: float, clockwise: bool = true) -> void:
	if clockwise:
		clockwiseLimit = limit
		haveClockwiseLimit = true
	else:
		antiClockwiseLimit = limit
		haveAntiClockwiseLimit = true


func frameChanged() -> void:
	lastFrameLabel = currentLabel
	lengthMultiplier = maxf(0.2, height * 0.002)
	if height < 20:
		rotation_degrees = 0
		hanging = false
	else:
		hanging = true


func tick() -> void:
	if currentLabel != lastFrameLabel:
		lastFrameLabel = currentLabel
		frameChanged()
	if parent == null:
		return
	pos = parent.localToGlobal(Vector2(x, y))
	if hanging:
		if lastPos == null:
			# The original throws here (null lastPos) and never animates; start tracking instead.
			lastPos = pos
		var down := 180.0
		var o: FlashDisplayObject = parent
		while o and o != g.sceneLayer:
			down -= o.rotation_degrees
			o = o.parent
		down = down * PI / 180.0
		var dv := Vector2(sin(down), -cos(down))
		movement = pos - lastPos
		acceleration = movement - lastMovement - dv * 40.0
		lastMovement = movement
		var a := rotation_degrees * PI / 180.0 + PI * 0.5
		var side := Vector2(sin(a), -cos(a))
		var push := side.x * acceleration.x + side.y * acceleration.y
		angSpeed += push * lengthMultiplier * (0.9 + randf() * 0.2)
		angSpeed *= 0.9
		rotation_degrees += angSpeed
		if haveAntiClockwiseLimit and angSpeed < 0 and rotation_degrees < antiClockwiseLimit:
			angSpeed *= -0.7
		if haveClockwiseLimit and angSpeed > 0 and rotation_degrees > clockwiseLimit:
			angSpeed *= -0.7
	lastPos = pos
