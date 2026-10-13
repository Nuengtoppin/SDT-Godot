class_name Misty
extends Character
## Port of chars.Misty (character preset).

func _init() -> void:
	charName = "Misty"
	charShortName = "Misty"
	skinType = 0
	iris = "normal"
	breastSize = 50
	hairTop = "Misty"
	hairUnder = "Misty"
	hairBack = "Misty"
	hairBottom = "Misty"
	costume = "nude"
	bodyScale = 0.98
	irisFill = {"r": 46, "g": 111, "b": 100, "a": 1}
	eyebrowFill = {"r": 185, "g": 71, "b": 0, "a": 1}
	eyebrowLine = {"r": 83, "g": 61, "b": 46, "a": 1}
	scalpFill = {"r": 185, "g": 71, "b": 0}
	eyeShadow.a = 0.5
	bg = 4


func generateElements() -> Array:
	var _loc1_ = MistyPonytail.new()
	_loc1_.x = -196.85
	_loc1_.y = -262.05
	g.hairTop.addChild(_loc1_)
	return [_loc1_]
