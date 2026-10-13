class_name Penis
extends RefCounted
## Port of obj.him.Penis: shape description of a penis graphic (tip, widths along its length) used for mouth
## fitting, hand-job grip and positions.

class WidthDefinition:
	var lengthPos: float
	var startY: float
	var positionWidth: float

	func _init(p: float, s: float, w: float) -> void:
		lengthPos = p
		startY = s
		positionWidth = w


var _sourceGraphic: FlashDisplayObject
var _tip: Vector2
var _length: float
var _fullLength: float
var _widths: Array = []
var _baseWidth: float = 0.0
var _basePos: float = -1.79e308


func _init(graphic: FlashDisplayObject, tip: Vector2) -> void:
	_sourceGraphic = graphic
	_tip = tip
	_length = Maths.vectorLength(_tip)
	_fullLength = _length


func getGlobalTip(dx: float = 0.0, dy: float = 0.0) -> Vector2:
	return _sourceGraphic.localToGlobal(Vector2(_tip.x + dx, _tip.y + dy))


var length: float:
	get:
		return _length

var fullLength: float:
	get:
		return _fullLength

var baseWidth: float:
	get:
		return _baseWidth


func defineWidth(p: float, startY: float, width: float) -> void:
	_widths.append(WidthDefinition.new(p, startY, width))
	if p > _basePos:
		_baseWidth = width
		_basePos = p
	_fullLength = maxf(_fullLength, _basePos - p)


func getPosOnPenis(p: Vector2) -> float:
	var local: Vector2 = _sourceGraphic.globalToLocal(p)
	return maxf(0.0, minf(1.0, (_fullLength + local.x) / _fullLength))


## Interpolated width / top edge at local x position 'pos'.
func _widthAt(pos: float) -> Array:
	var below: WidthDefinition = null
	var above: WidthDefinition = null
	for w in _widths:
		if w.lengthPos < pos:
			if below == null or below.lengthPos < w.lengthPos:
				below = w
		elif above == null or above.lengthPos > w.lengthPos:
			above = w
	if below and above:
		var t := (pos - below.lengthPos) / (above.lengthPos - below.lengthPos)
		return [below.positionWidth + t * (above.positionWidth - below.positionWidth), below.startY + t * (above.startY - below.startY)]
	if below:
		return [below.positionWidth, below.startY]
	if above:
		return [above.positionWidth, above.startY]
	return [0.0, 0.0]


func getSimplePenisWidth(p: Vector2) -> Dictionary:
	var local: Vector2 = _sourceGraphic.globalToLocal(p)
	var w := _widthAt(local.x)
	return {"width": w[0], "startY": w[1]}


func getPenisWidth(top: Vector2, bottom: Vector2) -> Dictionary:
	var t: Vector2 = _sourceGraphic.globalToLocal(top)
	var b: Vector2 = _sourceGraphic.globalToLocal(bottom)
	var pos := t.x
	var w := _widthAt(pos)
	var width: float = w[0]
	var startY: float = w[1]
	var topOffset := startY - t.y - 5.0
	var bottomOffset := startY + width - b.y + 5.0
	var ang := 90.0 + Maths.getAngle(pos, minf(0.0, topOffset) * absf(pos / _fullLength))
	ang += 90.0 + Maths.getAngle(pos, maxf(0.0, bottomOffset) * absf(pos / _fullLength))
	ang = Maths.normaliseAngle(ang)
	return {"width": width, "startY": startY, "topOffset": topOffset, "bottomOffset": bottomOffset, "pos": pos,
		"angOffset": ang}
