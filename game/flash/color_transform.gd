class_name FlashColorTransform
extends RefCounted
## flash.geom.ColorTransform: per-channel multiplier (fraction) and offset (-255..255).

var red_multiplier: float = 1.0
var green_multiplier: float = 1.0
var blue_multiplier: float = 1.0
var alpha_multiplier: float = 1.0
var red_offset: float = 0.0
var green_offset: float = 0.0
var blue_offset: float = 0.0
var alpha_offset: float = 0.0


func _init(rm: float = 1.0, gm: float = 1.0, bm: float = 1.0, am: float = 1.0,
		ro: float = 0.0, go: float = 0.0, bo: float = 0.0, ao: float = 0.0) -> void:
	red_multiplier = rm
	green_multiplier = gm
	blue_multiplier = bm
	alpha_multiplier = am
	red_offset = ro
	green_offset = go
	blue_offset = bo
	alpha_offset = ao


static func from_array(a: Array) -> FlashColorTransform:
	return FlashColorTransform.new(a[0], a[1], a[2], a[3], a[4], a[5], a[6], a[7])


func clone() -> FlashColorTransform:
	return FlashColorTransform.new(red_multiplier, green_multiplier, blue_multiplier, alpha_multiplier,
		red_offset, green_offset, blue_offset, alpha_offset)


## Flash 'color' setter: sets offsets to the RGB value and multipliers to 0.
var color: int:
	get:
		return (int(red_offset) << 16) | (int(green_offset) << 8) | int(blue_offset)
	set(value):
		red_multiplier = 0.0
		green_multiplier = 0.0
		blue_multiplier = 0.0
		red_offset = (value >> 16) & 0xFF
		green_offset = (value >> 8) & 0xFF
		blue_offset = value & 0xFF


## Applies 'second' after this one (Flash concat semantics).
func concat(second: FlashColorTransform) -> void:
	red_offset = red_offset * second.red_multiplier + second.red_offset
	green_offset = green_offset * second.green_multiplier + second.green_offset
	blue_offset = blue_offset * second.blue_multiplier + second.blue_offset
	alpha_offset = alpha_offset * second.alpha_multiplier + second.alpha_offset
	red_multiplier *= second.red_multiplier
	green_multiplier *= second.green_multiplier
	blue_multiplier *= second.blue_multiplier
	alpha_multiplier *= second.alpha_multiplier


func has_offsets() -> bool:
	return red_offset != 0.0 or green_offset != 0.0 or blue_offset != 0.0 or alpha_offset != 0.0


func is_identity() -> bool:
	return not has_offsets() and red_multiplier == 1.0 and green_multiplier == 1.0 \
		and blue_multiplier == 1.0 and alpha_multiplier == 1.0
