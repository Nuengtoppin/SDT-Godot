class_name Line
extends RefCounted
## Port of obj.Line: a segment with implicit-equation coefficients (A x + B y = C).

var p1: Vector2
var p2: Vector2


func _init(a, b) -> void:
	p1 = Vector2(a.x, a.y)
	p2 = Vector2(b.x, b.y)


var A: float:
	get:
		return p2.y - p1.y

var B: float:
	get:
		return p1.x - p2.x

var C: float:
	get:
		return (p2.y - p1.y) * p1.x + (p1.x - p2.x) * p1.y

var x1: float:
	get:
		return p1.x

var y1: float:
	get:
		return p1.y

var x2: float:
	get:
		return p2.x

var y2: float:
	get:
		return p2.y
