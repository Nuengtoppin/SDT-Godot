class_name AnimationControl
extends RefCounted
## Port of obj.animation.AnimationControl: the two body positions ("default" and "face fuck") and the per-tick step
## that moves her and him.

const DEFAULT := "default"
const FACE_FUCK := "face_fuck"

var currentAnimation := DEFAULT
var animations: Dictionary = {}
var linearPenisOutTransition: float = 0.0
var smoothedPenisOutTransition: float = 0.0


func _init() -> void:
	var defaultAnimation := MainAnimation.new()
	var defaultHer := LinearTween.new()
	defaultHer.offsetStart(-40, 270, -15)
	defaultHer.offsetEnd(250, 367.3, -20)
	var defaultHim := LinearTween.new()
	defaultHim.offsetStart(420, 135, -3)
	defaultHim.offsetEnd(340, 135)
	defaultAnimation.herTween = defaultHer
	defaultAnimation.herKneeTarget = Vector2(160, 1240)
	defaultAnimation.altVector = Vector2(0, 1)
	defaultAnimation.altRange = 80
	defaultAnimation.hisTween = defaultHim
	defaultAnimation.hisLeftFootTarget = Vector2(625, 1315)
	defaultAnimation.hisRightFootTarget = Vector2(620, 1168)
	defaultAnimation.torsoMinAng = 4.3
	defaultAnimation.torsoStartAng = 3.43
	defaultAnimation.torsoAngMultiplier = 0.61
	defaultAnimation.torsoMinDist = 180
	defaultAnimation.torsoStartDist = 130
	defaultAnimation.torsoDistMultiplier = 35
	animations[DEFAULT] = defaultAnimation
	var faceFuckAnimation := MainAnimation.new()
	var ffHer := LinearTween.new()
	ffHer.offsetStart(35, 300, -15)
	ffHer.offsetEnd(145, 382.3, -20)
	var ffHim := LinearTween.new()
	ffHim.offsetStart(470, 160, -3)
	ffHim.offsetEnd(235, 150)
	faceFuckAnimation.herTween = ffHer
	faceFuckAnimation.herKneeTarget = Vector2(20, 1240)
	faceFuckAnimation.altVector = Vector2(0, 1)
	faceFuckAnimation.altRange = 80
	faceFuckAnimation.hisTween = ffHim
	faceFuckAnimation.hisLeftFootTarget = Vector2(520, 1300)
	faceFuckAnimation.hisRightFootTarget = Vector2(550, 1133)
	faceFuckAnimation.torsoMinAng = 4.3
	faceFuckAnimation.torsoStartAng = 3.9
	faceFuckAnimation.torsoAngMultiplier = 0.3
	faceFuckAnimation.torsoMinDist = 180
	faceFuckAnimation.torsoStartDist = 145
	faceFuckAnimation.torsoDistMultiplier = 5
	faceFuckAnimation.posScaling = func(p: float) -> float: return pow(p, 1.5) if p > 0 else p
	animations[FACE_FUCK] = faceFuckAnimation


func stepAnimation() -> void:
	var p: float = g.her.move(g.currentPos.x, g.currentPos.y)
	g.herCurrentPos = p
	g.him.move(p, g.currentPos.x, g.currentPos.y)
	g.her.updateArms()


func setAnimation(n: String) -> void:
	currentAnimation = n
	dispatchUpdates()
	stepAnimation()


func loadStyle(n: String) -> void:
	if animations.has(n):
		currentAnimation = n
		dispatchUpdates()


func dispatchUpdates() -> void:
	g.him.animationChanged()
	g.her.updateKneeTarget()
	EventBus.dispatch("penisTipPosChanged")


var currentAnimationID: int:
	get:
		return 2 if currentAnimation == FACE_FUCK else 1

var currentAnimationName: String:
	get:
		return currentAnimation


func debugSetLeftFoot(p: Vector2) -> void:
	animations[currentAnimation].hisLeftFootTarget = p
	g.him.animationChanged()


func debugSetRightFoot(p: Vector2) -> void:
	animations[currentAnimation].hisRightFootTarget = p
	g.him.animationChanged()


func update() -> void:
	if g.penisOut and linearPenisOutTransition < 1:
		linearPenisOutTransition = minf(1.0, linearPenisOutTransition + 0.1)
		smoothedPenisOutTransition = (1.0 - cos(linearPenisOutTransition * PI)) * 0.5
	elif not g.penisOut and linearPenisOutTransition > 0:
		linearPenisOutTransition = maxf(0.0, linearPenisOutTransition - 0.1)
		smoothedPenisOutTransition = (1.0 - cos(linearPenisOutTransition * PI)) * 0.5


var penisOutTransition: float:
	get:
		return smoothedPenisOutTransition


func estimateTipPos() -> float:
	return animations[currentAnimation].estimateTipPos


func getHerMatrix(p: float, tilt: float) -> Transform2D:
	var anim: MainAnimation = animations[currentAnimation]
	var m := anim.getHerMatrix(p, tilt * maxf(smoothedPenisOutTransition, maxf(0.0, p * 2.0 - 0.5)))
	m.origin.y += -g.him.currentPenisBaseWidth * 0.5 * (p if p > 0 else 0.0)
	var d := Vector2(m.origin.x - anim.herKneeTarget.x, m.origin.y - anim.herKneeTarget.y)
	var dist := sqrt(d.x * d.x + d.y * d.y)
	var maxDist: float = 1100.0 * g.her.bodyScale
	if dist > maxDist:
		d *= maxDist / dist
		m.origin = anim.herKneeTarget + d
	return m


func getHerKneeTarget() -> Vector2:
	return animations[currentAnimation].herKneeTarget


func getHisMatrix(p: float) -> Transform2D:
	return animations[currentAnimation].getHisMatrix(p)


func getHisLeftFootTarget() -> Vector2:
	return animations[currentAnimation].hisLeftFootTarget


func getHisRightFootTarget() -> Vector2:
	return animations[currentAnimation].hisRightFootTarget


var torsoMinAng: float:
	get:
		return animations[currentAnimation].torsoMinAng

var torsoStartAng: float:
	get:
		return animations[currentAnimation].torsoStartAng

var torsoAngMultiplier: float:
	get:
		return animations[currentAnimation].torsoAngMultiplier

var torsoMinDist: float:
	get:
		return animations[currentAnimation].torsoMinDist

var torsoStartDist: float:
	get:
		return animations[currentAnimation].torsoStartDist

var torsoDistMultiplier: float:
	get:
		return animations[currentAnimation].torsoDistMultiplier
