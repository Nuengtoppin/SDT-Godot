class_name BreastController
extends RefCounted
## Port of obj.animation.BreastController: spring-driven skew/stretch of a breast and its costume layers.

var _breast: FlashDisplayObject
var _costumeLayers: Array = []
var _breastOrigin: Vector2
var _originalRotation: float
var _breastFirmness: float = 0.2
var _costumeOn := false
var _flip: int = 1
var _skew: float = 0.0
var _speed: float = 0.0


func _init(breast: FlashDisplayObject, c1 = null, c2 = null) -> void:
	_breast = breast
	_breastOrigin = Vector2(_breast.x, _breast.y)
	_originalRotation = _breast.rotation_degrees
	_flip = int(Maths.round(_breast.transform.x.x / _breast.scaleX))
	for c in [c1, c2]:
		if c is FlashDisplayObject:
			_costumeLayers.append(c)


func accelerate(v: float) -> void:
	_speed += v


func update(push: float = 0.0, rot: float = 0.0, ox: float = 0.0, oy: float = 0.0) -> void:
	if Hooks.has_value(&"BreastController.push"):   # HOOK value point: the force her movement gives the breast
		push = Hooks.value(&"BreastController.push", self, push)
	var damping := 0.7
	if Hooks.has_value(&"BreastController.damping"):   # HOOK value point: how much of its speed the breast keeps
		damping = Hooks.value(&"BreastController.damping", self, damping)
	_speed += -_skew * _breastFirmness + push
	_speed *= damping + randf() * 0.1
	_skew += _speed
	# Flash: identity, rotate, translate, scale(sx, 1), then b = skew.
	var r := rot / 180.0 * PI
	var sx := 0.95 + cos(_skew * 5.0) * 0.1
	var m := Transform2D(Vector2(cos(r) * sx, _skew), Vector2(-sin(r) * sx, cos(r)),
		Vector2((_breastOrigin.x + ox) * sx, _breastOrigin.y + oy))
	_breast.transform = m
	for c in _costumeLayers:
		c.transform = m


func updateFirmness(size: int, costumeOn: bool = false) -> void:
	_breastFirmness = maxf(0.2, 0.2 + (60 - size) * 0.01)
	_costumeOn = costumeOn
	if _costumeOn:
		_breastFirmness = maxf(0.2, _breastFirmness + 0.1)
	if Hooks.has_value(&"BreastController.firmness"):   # HOOK value point: how firmly the breast springs back
		_breastFirmness = Hooks.value(&"BreastController.firmness", self, _breastFirmness)
