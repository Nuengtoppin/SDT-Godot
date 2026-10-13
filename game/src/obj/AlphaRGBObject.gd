class_name AlphaRGBObject
extends RefCounted
## Port of obj.AlphaRGBObject: a colour with fractional alpha (0..1) and 0..255 RGB.

var a: float
var r: int
var g: int
var b: int


func _init(pa: float = 0.0, pr: int = 0, pg: int = 0, pb: int = 0) -> void:
	a = pa
	r = pr
	g = pg
	b = pb
