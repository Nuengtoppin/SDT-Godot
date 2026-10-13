class_name FlashColorTransform
extends RefCounted
## flash.geom.ColorTransform: per-channel multiplier (fraction) and offset (-255..255).

var redMultiplier: float = 1.0
var greenMultiplier: float = 1.0
var blueMultiplier: float = 1.0
var alphaMultiplier: float = 1.0
var redOffset: float = 0.0
var greenOffset: float = 0.0
var blueOffset: float = 0.0
var alphaOffset: float = 0.0


func _init(rm: float = 1.0, gm: float = 1.0, bm: float = 1.0, am: float = 1.0,
		ro: float = 0.0, go: float = 0.0, bo: float = 0.0, ao: float = 0.0) -> void:
	redMultiplier = rm
	greenMultiplier = gm
	blueMultiplier = bm
	alphaMultiplier = am
	redOffset = ro
	greenOffset = go
	blueOffset = bo
	alphaOffset = ao


static func from_array(a: Array) -> FlashColorTransform:
	return FlashColorTransform.new(a[0], a[1], a[2], a[3], a[4], a[5], a[6], a[7])


func clone() -> FlashColorTransform:
	return FlashColorTransform.new(redMultiplier, greenMultiplier, blueMultiplier, alphaMultiplier,
		redOffset, greenOffset, blueOffset, alphaOffset)


## Flash 'color' setter: sets offsets to the RGB value and multipliers to 0.
var color: int:
	get:
		return (int(redOffset) << 16) | (int(greenOffset) << 8) | int(blueOffset)
	set(value):
		redMultiplier = 0.0
		greenMultiplier = 0.0
		blueMultiplier = 0.0
		redOffset = (value >> 16) & 0xFF
		greenOffset = (value >> 8) & 0xFF
		blueOffset = value & 0xFF


## Applies 'second' after this one (Flash concat semantics).
func concat(second: FlashColorTransform) -> void:
	redOffset = redOffset * second.redMultiplier + second.redOffset
	greenOffset = greenOffset * second.greenMultiplier + second.greenOffset
	blueOffset = blueOffset * second.blueMultiplier + second.blueOffset
	alphaOffset = alphaOffset * second.alphaMultiplier + second.alphaOffset
	redMultiplier *= second.redMultiplier
	greenMultiplier *= second.greenMultiplier
	blueMultiplier *= second.blueMultiplier
	alphaMultiplier *= second.alphaMultiplier


func has_offsets() -> bool:
	return redOffset != 0.0 or greenOffset != 0.0 or blueOffset != 0.0 or alphaOffset != 0.0


func is_identity() -> bool:
	return not has_offsets() and redMultiplier == 1.0 and greenMultiplier == 1.0 \
		and blueMultiplier == 1.0 and alphaMultiplier == 1.0
