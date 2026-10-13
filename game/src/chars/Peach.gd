class_name Peach
extends Character
## Port of chars.Peach (character preset).

func _init() -> void:
	charName = "Princess Peach"
	charShortName = "Peach"
	skinType = 0
	iris = "normal"
	breastSize = 100
	hairTop = "Peach"
	hairUnder = "Peach"
	hairBack = "Peach"
	hairBottom = "Peach"
	costume = "nude"
	earring = "Ball"
	earringFill = {"r": 18, "g": 90, "b": 184, "a": 1}
	headwear = "Peach\'s Crown"
	headwearFill = {"r": 255, "g": 208, "b": 25, "a": 1}
	bodyScale = 1.035
	irisFill = {"r": 56, "g": 100, "b": 137, "a": 1}
	eyebrowFill = {"r": 169, "g": 135, "b": 37, "a": 1}
	eyebrowLine = {"r": 89, "g": 67, "b": 51, "a": 1}
	scalpFill = {"r": 169, "g": 135, "b": 37}
	lipstickFill = {"r": 235, "g": 60, "b": 116, "a": 0.4}
	eyeShadow.a = 1
	bg = 4


func generateElements() -> Array:
	var _loc1_ = Flash.create("PeachHairTail")
	var _loc2_ = Rope.new(_loc1_,g.hairUnderLayer,Vector2(-116,-132),null,15,"right",0,1)
	_loc2_.lockTop(0.2)
	return [_loc2_]
