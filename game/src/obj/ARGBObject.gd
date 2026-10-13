class_name ARGBObject
extends RefCounted
## Port of obj.ARGBObject: a colour as separate A, R, G, B components (0..255).

var _a: int = 0
var _r: int = 0
var _g: int = 0
var _b: int = 0


func _init(pa: int = 0, pr: int = 0, pg: int = 0, pb: int = 0) -> void:
	a = pa
	r = pr
	g = pg
	b = pb


## setARGB(0xAARRGGBB) or setARGB(a, r, g, b) / setARGB(r, g, b)
func setARGB(...rest: Array) -> void:
	if rest.size() == 1:
		split(int(rest[0]))
	else:
		fillARGB(rest)


var argb: int:
	get:
		return (_a << 24) | (_r << 16) | (_g << 8) | _b

var rgb: int:
	get:
		return (_r << 16) | (_g << 8) | _b

var a: int:
	get:
		return _a
	set(v):
		_a = v

var r: int:
	get:
		return _r
	set(v):
		_r = v

var g: int:
	get:
		return _g
	set(v):
		_g = v

var b: int:
	get:
		return _b
	set(v):
		_b = v


func split(c: int) -> void:
	if c < 16777215:
		_a = 255
	else:
		_a = (c & 0xFF000000) >> 24
	_r = (c & 0xFF0000) >> 16
	_g = (c & 0xFF00) >> 8
	_b = c & 0xFF


func fillARGB(vals: Array) -> void:
	vals = vals.duplicate()
	if vals.size() == 4:
		_a = int(vals.pop_front())
	if vals.size() > 0:
		_r = int(vals.pop_front())
	if vals.size() > 0:
		_g = int(vals.pop_front())
	if vals.size() > 0:
		_b = int(vals.pop_front())
