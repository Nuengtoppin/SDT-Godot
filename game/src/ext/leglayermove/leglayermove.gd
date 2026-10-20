extends SDTExtension
## Built-in reimplementation of the Loader mod leglayermove (sby, v1): her left leg's layers in two groups, all calf
## pieces (calf, its stockings, footwear, cuffs, calf bottoms) under all thigh pieces (thigh, its shading, stockings,
## thigh costume and bottoms), instead of the game's interleaved order. The difference shows only where her calf and
## thigh overlap, with leg angles the game's own poses do not use (her right leg covers it otherwise).

## Her left leg's pieces, bottom to top. "#shape" is the unnamed shading drawn over the thigh (child 2 in the game).
const ORDER := ["calf", "calfStocking", "calfStockingB", "footwear", "cuffs", "leftCalfBottoms", "thigh", "#shape",
	"stocking", "stockingB", "leftThighCostume", "leftThighBottoms"]

var _original: Array = []   # the game's order, put back when switched off


func _init() -> void:
	id = "leglayermove"
	title = "leglayermove"
	description = "Her left leg's thigh pieces drawn above all its calf pieces (visible only with unusual leg angles)."
	default_enabled = true


func _enable() -> void:
	var leg = g.her.leftLegContainer.leg
	_original = []
	for i in leg.numChildren:
		_original.append(leg.getChildAt(i))
	var shape = leg.getChildAt(2) if leg.numChildren > 2 else null
	var index := 0
	for n in ORDER:
		var o = shape if n == "#shape" else leg.get(n)
		if o is FlashDisplayObject and o._flash_parent == leg:
			leg.setChildIndex(o, index)
			index += 1


func _disable() -> void:
	var leg = g.her.leftLegContainer.leg if g.her != null else null
	if leg == null:
		return
	var index := 0
	for o in _original:
		if is_instance_valid(o) and o._flash_parent == leg:
			leg.setChildIndex(o, index)
			index += 1
	_original.clear()
