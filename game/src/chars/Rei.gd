class_name Rei
extends Character
## Port of chars.Rei (character preset).

func _init() -> void:
	charName = "Ayanami Rei"
	charShortName = "Rei"
	skinType = 1
	iris = "bright"
	breastSize = 75
	hairTop = "Rei"
	hairUnder = "Rei"
	hairBack = "Rei"
	hairBottom = "Rei"
	costume = "nude"
	bodyScale = 0.995
	irisFill = {"r": 71, "g": 18, "b": 28, "a": 1}
	eyebrowFill = {"r": 105, "g": 121, "b": 137, "a": 1}
	eyebrowLine = {"r": 56, "g": 42, "b": 32, "a": 1}
	scalpFill = {"r": 82, "g": 119, "b": 148}
	eyeShadow.a = 0.1
	bg = 2


func generateElements() -> Array:
	var _loc1_ = ReiHairClip.new()
	_loc1_.x = -23.4
	_loc1_.y = -270.85
	g.hairCostumeOver.addChild(_loc1_)
	return [_loc1_]
