class_name BraStrap
extends RefCounted
## Port of obj.her.BraStrap: stretches a strap shape from its anchor to a point on the (moving) bra / top.

var showingStrap := false
var strap: FlashDisplayObject
var strapContainer: FlashDisplayObject
var endObject: FlashDisplayObject
var targetObject: FlashDisplayObject
var targetPointName: String
var startPoint: Vector2
var endPoint: Vector2
var targetPoint: Vector2
var strapAng: float
var strapLength: float
var strapStartPos: Vector2
var strapStartAng: float


func _init(p_strap: FlashDisplayObject, target: FlashDisplayObject, pointName: String, helper = null) -> void:
	strap = p_strap
	targetObject = target
	targetPointName = pointName
	strapContainer = p_strap.parent
	strapStartPos = Vector2(strap.x, strap.y)
	strapStartAng = Maths.degToRad(strap.rotation_degrees)
	if helper:
		helper.registerListener(braChanged)
	g.characterControl.addBreastSizeChangeListener(breastSizeChanged)
	startPoint = Vector2(strap.x, strap.y)
	updatePoints()


func braChanged(_n: String = "") -> void:
	showingStrap = false
	var tf = targetObject.get("rgbFill")
	var sf = strap.get("rgbFill")
	if tf and sf:
		if tf.get(targetPointName) and sf.get("endPoint"):
			showingStrap = true
			updatePoints()
			update()


func breastSizeChanged() -> void:
	updatePoints()
	update()


func updatePoints() -> void:
	if showingStrap:
		var ep = strap.get("rgbFill").get("endPoint")
		var tp = targetObject.get("rgbFill").get(targetPointName)
		endPoint = Vector2(ep.x, ep.y)
		targetPoint = Vector2(tp.x, tp.y)
		strapAng = g.getRadAngle(endPoint.x, endPoint.y)
		strapLength = sqrt(endPoint.x * endPoint.x + endPoint.y * endPoint.y)


func update() -> void:
	if showingStrap:
		var target: Vector2 = strapContainer.globalToLocal(targetObject.localToGlobal(targetPoint))
		var d := Vector2(target.x - startPoint.x, target.y - startPoint.y)
		var skewAng: float = g.getRadAngle(d.x, d.y) - strapAng - strapStartAng
		var stretch: float = Maths.dot(g.getUnitVector(strapStartAng + strapAng), d)
		# Flash: scale(stretch / length, 1); b = tan(skew) * stretch / length; rotate; translate.
		var m := Transform2D(Vector2(stretch / strapLength, tan(skewAng) * stretch / strapLength), Vector2(0, 1), Vector2.ZERO)
		m = m.rotated(strapStartAng).translated(strapStartPos)
		strap.transform = m
