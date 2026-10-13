class_name Mari
extends Character
## Port of chars.Mari (character preset).

func _init() -> void:
	charName = "Mari Illustrious Makinami"
	charShortName = "Mari"
	skinType = 0
	iris = "normal"
	breastSize = 80
	hairTop = "Mari"
	hairUnder = "Mari"
	hairBack = "Mari"
	hairBottom = "Mari"
	costume = "nude"
	bodyScale = 1.006
	irisFill = {"r": 46, "g": 111, "b": 100, "a": 1}
	eyebrowFill = {"r": 50, "g": 34, "b": 33, "a": 1}
	eyebrowLine = {"r": 30, "g": 19, "b": 19, "a": 1}
	scalpFill = {"r": 50, "g": 34, "b": 33}
	eyeShadow.a = 0.5
	eyewear = "Mari"
	eyewearFill = {"r": 113, "g": 46, "b": 68, "a": 1}
	bg = 1


func generateElements() -> Array:
	var _loc1_ = MariHairClip.new()
	_loc1_.x = -21.25
	_loc1_.y = -235.8
	g.hairCostumeUnderOver.addChild(_loc1_)
	var _loc2_ = Flash.create("MariBang")
	var _loc3_ = Rope.new(_loc2_,g.hairOverLayer,Vector2(28,-268))
	var _loc4_ = Flash.create("MariPonyTail")
	var _loc5_ = Rope.new(_loc4_,g.hairUnderLayer,Vector2(-120,-55),null,15,"right",0,1)
	return [_loc1_,_loc3_,_loc5_]
