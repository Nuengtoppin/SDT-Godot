class_name Noel
extends Character
## Port of chars.Noel (character preset).

func _init() -> void:
	charName = "Noel Vermillion"
	charShortName = "Noel"
	skinType = 0
	iris = "bright"
	breastSize = 40
	hairTop = "Noel"
	hairUnder = "Noel"
	hairBack = "Noel"
	hairBottom = "Noel"
	costume = "nude"
	headwear = "Noel\'s Cap"
	headwearFill = {"r": 47, "g": 56, "b": 221, "a": 1}
	headwearFill2 = {"r": 49, "g": 100, "b": 106, "a": 1}
	bodyScale = 1.005
	collar = 2
	collarFill = {"r": 195, "g": 2, "b": 0, "a": 1}
	collarFill2 = {"r": 232, "g": 240, "b": 255, "a": 1}
	irisFill = {"r": 70, "g": 100, "b": 37, "a": 1}
	eyebrowFill = {"r": 140, "g": 108, "b": 57, "a": 1}
	eyebrowLine = {"r": 89, "g": 67, "b": 51, "a": 1}
	scalpFill = {"r": 140, "g": 108, "b": 57}
	eyeShadow.a = 0.5
	bg = 4


func generateElements() -> Array:
	var _loc1_ = Flash.create("NoelHairSide")
	var _loc2_ = Rope.new(_loc1_,g.hairOverLayer,Vector2(40,-227),null,5)
	_loc2_.damping = 0.425
	var _loc3_ = Flash.create("NoelHairFront")
	var _loc4_
	_loc4_ = Rope.new(_loc3_,g.hairBackLayer,Vector2(120,-200),null,-5)
	_loc4_.lockTop(0.1)
	return [_loc2_,_loc4_]
