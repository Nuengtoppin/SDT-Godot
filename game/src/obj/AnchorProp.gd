class_name AnchorProp
extends RefCounted
## Port of obj.AnchorProp: a point attached to a display object (used for strand ends).

var hit := true
var forceHit := true
var localPoint: Vector2
var container: FlashDisplayObject
var originalHitTarget: FlashDisplayObject = null
var eyeHit := false


func _init(p: Vector2 = Vector2.ZERO, c: FlashDisplayObject = null, force: bool = true) -> void:
	localPoint = p
	container = c
	forceHit = force


func setContainer(c: FlashDisplayObject) -> void:
	container = c
	if originalHitTarget:
		originalHitTarget = c


func setOriginalHitTarget(c: FlashDisplayObject) -> void:
	originalHitTarget = c


func setEyeHit() -> void:
	eyeHit = true


var hitTarget: FlashDisplayObject:
	get:
		return originalHitTarget if originalHitTarget else container


func clone() -> AnchorProp:
	return AnchorProp.new(localPoint, container, forceHit)
