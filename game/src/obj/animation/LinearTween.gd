class_name LinearTween
extends RefCounted
## Port of obj.animation.LinearTween: interpolates a transform between a start and end (rotation or skew based)
## and applies it to one or more display objects (others are corrected for differing parents).

var _targets: Array = []
var _startMatrix := Transform2D.IDENTITY
var _endMatrix := Transform2D.IDENTITY
var _tweenMatrix := Transform2D.IDENTITY
var _startAng: float = 0.0
var _endAng: float = 0.0
var _startSkew := Vector2()
var _endSkew := Vector2()
var _baseObject: FlashDisplayObject = null
var _offsetMatrices: Dictionary = {}
var _skewed := false


func _init(t1 = null, t2 = null, t3 = null, t4 = null) -> void:
	for t in [t1, t2, t3, t4]:
		if t is FlashDisplayObject:
			_targets.append(t)
			if _baseObject == null:
				_baseObject = t
			elif t.parent != _baseObject.parent:
				_offsetMatrices[t] = t.parent.transform.affine_inverse() * _baseObject.parent.transform
	if _targets.size() > 0:
		_startMatrix = _targets[0].transform
		_endMatrix = _targets[0].transform


func tween(r: float) -> Transform2D:
	if _skewed:
		_tweenMatrix.x.x = _startMatrix.x.x + r * (_endMatrix.x.x - _startMatrix.x.x)
		_tweenMatrix.y.y = _startMatrix.y.y + r * (_endMatrix.y.y - _startMatrix.y.y)
		_tweenMatrix.y.x = tan(_startSkew.x + r * (_endSkew.x - _startSkew.x))
		_tweenMatrix.x.y = tan(_startSkew.y + r * (_endSkew.y - _startSkew.y))
	else:
		var a := _startAng + r * (_endAng - _startAng)
		var c := cos(a)
		var s := sin(a)
		_tweenMatrix.x = Vector2(c, s)
		_tweenMatrix.y = Vector2(-s, c)
	_tweenMatrix.origin = Vector2(_startMatrix.origin.x + r * (_endMatrix.origin.x - _startMatrix.origin.x),
		_startMatrix.origin.y + r * (_endMatrix.origin.y - _startMatrix.origin.y))
	for t in _targets:
		if _offsetMatrices.has(t):
			t.transform = _offsetMatrices[t] * _tweenMatrix
		else:
			t.transform = _tweenMatrix
	return _tweenMatrix


func offsetStart(dx: float = 0.0, dy: float = 0.0, ang: float = 0.0) -> void:
	_startMatrix.origin += Vector2(dx, dy)
	if ang != 0:
		_startAng = ang / 180.0 * PI
		_skewed = false


func offsetEnd(dx: float = 0.0, dy: float = 0.0, ang: float = 0.0) -> void:
	_endMatrix.origin += Vector2(dx, dy)
	if ang != 0:
		_endAng = ang / 180.0 * PI
		_skewed = false


func skewStart(sx: float, sy: float, a: float = 0.0, d: float = 0.0) -> void:
	_startSkew = Vector2(sx / 180.0 * PI, sy / 180.0 * PI)
	if a:
		_startMatrix.x.x = a
	if d:
		_startMatrix.y.y = d
	_skewed = true


func skewEnd(sx: float, sy: float, a: float = 0.0, d: float = 0.0) -> void:
	_endSkew = Vector2(sx / 180.0 * PI, sy / 180.0 * PI)
	if a:
		_endMatrix.x.x = a
	if d:
		_endMatrix.y.y = d
	_skewed = true


func rotateStart(a: float) -> void:
	_startAng = a
	_skewed = false


func rotateEnd(a: float) -> void:
	_endAng = a
	_skewed = false


var start: Transform2D:
	get:
		return _startMatrix
	set(v):
		_startMatrix = v

var end: Transform2D:
	get:
		return _endMatrix
	set(v):
		_endMatrix = v

var translationLength: float:
	get:
		return Maths.vectorLength(_endMatrix.origin - _startMatrix.origin)
