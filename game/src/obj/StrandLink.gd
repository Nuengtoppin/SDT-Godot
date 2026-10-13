class_name StrandLink
extends RefCounted
## Port of obj.StrandLink (a flash.geom.Point subclass): one mass point of a spit / cum strand. Anchors to body
## parts, slides, smears, and passes mass / density to lower neighbours.

var x: float = 0.0
var y: float = 0.0
var speed: Vector2
var mass: float
var density: float
var minMass: float = 0.01
var minDensity: float = 0.2
var anchorAge: int = 0
var collisionFree: int = 0
var onEye := false
var anchorObject: AnchorProp
var anchored := false
var anchorDelay: int = 0
var isJustAnchored := false
var sourceLink := false
var onTongue := false
var freed := false
var globalAnchorPoint = null
var slideOnAnchor := false
var anchorSliding := false
var anchorSlideCounter: int = 0
var anchorSlideMax: int = 45
var smearCounter: int = 0
var maxSmear: int = 150
var storedInterPoints = null
var hasStoredInterPoints := false
var generateMass := false
var neighbour1: StrandLink = null
var neighbour2: StrandLink = null
var neighbourVec := Vector2()
var neighbourAng: float = 0.0
var flowMult: float = 0.0
var isExpanded := false


func _init(pMass: float, pDensity: float, pSpeed = null, pCollisionFree: int = 0, pSlide: bool = false) -> void:
	anchorObject = AnchorProp.new()
	mass = maxf(minMass, pMass)
	density = pDensity
	slideOnAnchor = pSlide
	generateMass = false
	speed = pSpeed if pSpeed != null else Vector2(0, 0)
	collisionFree = pCollisionFree
	anchorAge = 0


func toVector() -> Vector2:
	return Vector2(x, y)


var anchorContainer: FlashDisplayObject:
	get:
		return anchorObject.container if anchorObject else null

var anchor:
	get:
		return anchorObject.localPoint if anchorObject else null

var globalAnchor: Vector2:
	get:
		if globalAnchorPoint == null:
			globalAnchorPoint = anchorObject.container.localToGlobal(anchorObject.localPoint)
		return globalAnchorPoint


func clearGlobalAnchor() -> void:
	globalAnchorPoint = null


func anchorTo(a: AnchorProp, isSource: bool = false, delayOnDetach: bool = true, slideCounter: int = -1) -> void:
	if anchored:
		detachAnchor(false, delayOnDetach)
	if a.eyeHit:
		onEye = true
	anchorObject = a
	anchorAge = 0
	anchored = true
	if slideOnAnchor:
		speed *= 0.7
		if slideCounter == -1:
			anchorSlideCounter = int(floor(randf() * anchorSlideMax))
		anchorSliding = true
	else:
		speed = Vector2.ZERO
	isJustAnchored = true
	sourceLink = isSource
	freed = false
	if anchorObject.container == g.her.tongueContainer.tongue.tipPoint:
		onTongue = true
		speed *= 0.5
		anchorSlideCounter += int((anchorSlideMax - anchorSlideCounter) * 0.5)
	if anchorObject.container == g.sceneLayer:
		if neighbour1:
			neighbour1.neighbourHitFloor()
		if neighbour2:
			neighbour2.neighbourHitFloor()


func neighbourHitFloor() -> void:
	speed.y *= 0.2
	speed.x += randf() * 20.0 - 10.0


func smear(p: Vector2, radius: float = 25.0) -> bool:
	if anchored:
		var r2 := radius * radius
		var d := globalAnchor - p
		var d2 := maxf(2.0, d.x * d.x + d.y * d.y)
		if d2 < r2:
			smearCounter += 1
			mass = maxf(minMass, mass - 0.05)
			density = maxf(0.05, density - 0.05)
			if smearCounter < maxSmear:
				var c: FlashDisplayObject = anchorObject.container
				var amount := maxf(0.0, minf(0.1, (r2 - d2) / r2)) * (1.0 - float(smearCounter) / maxSmear)
				if not g.smudgeCache.has(c):
					g.smudgeCache[c] = {"updated": false}
				var cache: Dictionary = g.smudgeCache[c]
				if not cache["updated"]:
					cache["localPoint"] = c.globalToLocal(p)
					if not cache.get("lastPoint"):
						cache["lastPoint"] = cache["localPoint"]
					cache["localVector"] = cache["localPoint"] - cache["lastPoint"]
					cache["updated"] = true
				var v: Vector2 = cache["localVector"]
				anchorObject.localPoint += v * amount
				recheckAnchor()
				return true
	return false


func recheckAnchor() -> void:
	if anchorObject.hitTarget != g.sceneLayer:
		var ga := globalAnchor
		if not anchorObject.hitTarget.hitTestPoint(ga.x, ga.y, true):
			if anchorObject.hitTarget == g.her.head.face:
				if g.her.head.jaw.hitTestPoint(ga.x, ga.y, true):
					anchorObject.localPoint = g.her.head.jaw.globalToLocal(ga)
					anchorObject.setContainer(g.her.head.jaw)
					return
			if anchorObject.hitTarget == g.her.head.jaw:
				if g.her.head.face.hitTestPoint(ga.x, ga.y, true):
					anchorObject.localPoint = g.her.head.face.globalToLocal(ga)
					anchorObject.setContainer(g.her.head.face)
					return
			if onEye:
				if not g.her.eye.hitBox.hitTestPoint(ga.x, ga.y, true):
					g.her.eyeClearHit()
			detachAnchor(false)


func tryToAnchorTo(a: AnchorProp) -> bool:
	if anchorDelay > 0:
		anchorDelay -= 1
		return false
	anchorTo(a)
	return true


func detachAnchor(free_: bool = true, delay: bool = true) -> void:
	if anchored:
		anchored = false
		isJustAnchored = false
		anchorSliding = false
		unstoreInterPoints()
		if free_:
			freed = true
		elif delay:
			anchorDelay = 2


var justAnchored: bool:
	get:
		if isJustAnchored:
			isJustAnchored = false
			return true
		return false

var anchorable: bool:
	get:
		if not anchored and not freed and collisionFree == 0:
			return true
		if anchored and (anchorObject.container == g.him or anchorObject.container == g.him.penis) and not sourceLink:
			return true
		return false


func storeInterPoints(pts: Dictionary) -> void:
	storedInterPoints = {
		"inside": anchorObject.container.globalToLocal(g.sceneLayer.localToGlobal(pts["inside"])),
		"outside": anchorObject.container.globalToLocal(g.sceneLayer.localToGlobal(pts["outside"])),
	}
	hasStoredInterPoints = true


func getStoredInterPoints() -> Dictionary:
	return {
		"inside": g.sceneLayer.globalToLocal(anchorObject.container.localToGlobal(storedInterPoints["inside"])),
		"outside": g.sceneLayer.globalToLocal(anchorObject.container.localToGlobal(storedInterPoints["outside"])),
	}


func unstoreInterPoints() -> void:
	storedInterPoints = null
	hasStoredInterPoints = false


func accelerate(ax: float, ay: float) -> void:
	if not anchored:
		if anchorSliding:
			var f := 0.5 - 0.5 * float(anchorSlideCounter) / anchorSlideMax
			ax *= f
			ay *= f
		speed.x += ax
		speed.y += ay


func move(fric: float) -> void:
	if not anchored or anchorSliding:
		x += speed.x
		y += speed.y
		speed /= fric


func setNeighbours(n1: StrandLink, n2: StrandLink = null) -> void:
	neighbour1 = n1
	neighbour2 = n2


func giveMass(m: float) -> float:
	if anchored:
		return 0.0
	mass += m
	return m


func giveDensity(d: float, mult: float = 1.0) -> float:
	var amount := minf(1.0 - density, minf(maxf(0.05, d * 0.1), d - minDensity) * mult)
	density += amount
	return amount


func halveMass() -> void:
	mass = maxf(minMass, mass * 0.5)


func massGenerator() -> void:
	generateMass = true


func cloneLink() -> StrandLink:
	var l := StrandLink.new(mass, density, speed, collisionFree)
	if anchored:
		l.anchorTo(anchorObject.clone(), false, false, anchorSlideCounter)
		l.anchorAge = anchorAge
		l.anchorDelay = anchorDelay
		l.onTongue = onTongue
	if hasStoredInterPoints:
		l.storedInterPoints = {"inside": storedInterPoints["inside"], "outside": storedInterPoints["outside"]}
	l.generateMass = generateMass
	l.isExpanded = isExpanded
	l.x = x
	l.y = y
	return l


func tick(grav: float) -> void:
	if anchored:
		anchorAge += 1
		if anchorSliding:
			speed.x *= 0.6
			speed.y = speed.y * 0.5 + grav * mass * density * (1.0 - float(anchorSlideCounter) / anchorSlideMax) * 0.5
			anchorSlideCounter += 1
			if anchorSlideCounter >= anchorSlideMax:
				anchorSliding = false
			var p := globalAnchor + speed
			anchorObject.localPoint = anchorObject.container.globalToLocal(p)
			recheckAnchor()
			if absf(speed.x) < 0.01 and absf(speed.y) < 0.01:
				anchorSliding = false
	if collisionFree > 0:
		collisionFree -= 1
	if generateMass:
		mass += g.massGenerateSpeed
	for n in [neighbour1, neighbour2]:
		if n and n.y > y:
			neighbourVec = Vector2(n.x - x, n.y - y)
			neighbourAng = atan2(neighbourVec.y, neighbourVec.x)
			flowMult = maxf(0.0, sin(neighbourAng))
			if mass > minMass:
				mass -= n.giveMass(minf(g.massFlow, mass - minMass) * flowMult)
			density -= n.giveDensity(density, flowMult)
