class_name Ino
extends Character
## Port of chars.Ino (character preset).

func _init() -> void:
	charName = "Ino Yamanaka"
	charShortName = "Ino"
	skinType = 0
	iris = "solid"
	breastSize = 70
	hairTop = "Ino"
	hairUnder = "Ino"
	hairBack = "Ino"
	hairBottom = "Ino"
	costume = "nude"
	earring = "Stud"
	earringFill = {"r": 206, "g": 218, "b": 223, "a": 1}
	bodyScale = 1.01
	irisFill = {"r": 75, "g": 107, "b": 109, "a": 1}
	eyebrowFill = {"r": 208, "g": 181, "b": 135, "a": 1}
	eyebrowLine = {"r": 83, "g": 61, "b": 46, "a": 1}
	scalpFill = {"r": 208, "g": 181, "b": 135}
	eyeShadow.a = 0.5
	bg = 4


func generateElements() -> Array:
	var _loc1_ = Flash.create("InoHairFront")
	var _loc2_ = Rope.new(_loc1_,g.hairOverLayer,Vector2(51,-286))
	var _loc3_ = Flash.create("InoHairTail")
	var _loc4_ = Rope.new(_loc3_,g.hairBackLayer,Vector2(-216,-272),null,5)
	g.hairBackLayer.setChildIndex(_loc4_,0)
	var _loc5_
	_loc5_ = InoTailTie.new()
	_loc5_.x = -148.15
	_loc5_.y = -268
	g.hairCostumeOver.addChild(_loc5_)
	return [_loc2_,_loc4_,_loc5_]
