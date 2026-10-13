class_name Balls
extends FlashMovieClip
## Port of obj.him.Balls: two coupled spring-weights that sway and stretch the ball graphics.

var leftHighlight
var rightHighlight
var leftOutline
var rightOutline
var leftFill
var rightFill

const G := 3.0
const PUSH := 0.08
const FRICTION := 0.8
var leftBallPos := Vector2()
var leftBallSpeed := Vector2()
var rightBallPos := Vector2()
var rightBallSpeed := Vector2()
var posDiff := Vector2()
var leftBallRatio: float = 0.0
var leftBallRatioChange: float = 0.0
var rightBallRatio: float = 0.0
var rightBallRatioChange: float = 0.0


func pushBalls(px: float = 0.0, py: float = 0.0) -> void:
	leftBallSpeed += Vector2(px, py) * leftBallRatio
	rightBallSpeed += Vector2(px, py) * rightBallRatio


func update() -> void:
	leftBallRatioChange += (randf() - 0.5) * 0.1
	leftBallRatioChange = minf(0.1, maxf(-0.1, leftBallRatioChange))
	leftBallRatio += leftBallRatioChange
	leftBallRatio = minf(1.0, maxf(1.0 - rightBallRatio, leftBallRatio))
	rightBallRatioChange += (randf() - 0.5) * 0.1
	rightBallRatioChange = minf(0.1, maxf(-0.1, rightBallRatioChange))
	rightBallRatio += rightBallRatioChange
	rightBallRatio = minf(1.0, maxf(1.0 - leftBallRatio, rightBallRatio))
	# The original mutates the Point arguments in place; with value-type vectors the results are written back.
	var r := updateBall(leftBallPos, leftBallSpeed, leftHighlight, leftFill, leftOutline)
	leftBallPos = r[0]
	leftBallSpeed = r[1]
	r = updateBall(rightBallPos, rightBallSpeed, rightHighlight, rightFill, rightOutline)
	rightBallPos = r[0]
	rightBallSpeed = r[1]
	posDiff = leftBallPos - rightBallPos
	leftBallSpeed -= posDiff * 0.05
	rightBallSpeed += posDiff * 0.05


func updateBall(p: Vector2, s: Vector2, highlight, fill, outline) -> Array:
	s.x -= p.x * 0.2
	s.y += G - p.y * 0.2
	s *= FRICTION
	p += s
	highlight.scaleY = 1.0 + p.y * 0.012
	highlight.y = p.y * 0.2
	fill.scaleY = 1.0 + p.y * 0.012
	outline.scaleY = 1.0 + p.y * 0.012
	highlight.rotation_degrees = -p.x * 20.0
	fill.rotation_degrees = -p.x * 20.0
	outline.rotation_degrees = -p.x * 20.0
	return [p, s]


func setSkin(skin: String) -> void:
	leftFill.gotoAndStop(skin)
	leftHighlight.gotoAndStop(skin)
	rightFill.gotoAndStop(skin)
	rightHighlight.gotoAndStop(skin)
