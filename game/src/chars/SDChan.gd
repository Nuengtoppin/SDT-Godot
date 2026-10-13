class_name SDChan
extends Character
## Port of chars.SDChan (character preset).

func _init() -> void:
	charName = "SD chan"
	charShortName = "SD chan"
	skinType = 0
	iris = "normal"
	breastSize = 70
	hairTop = "SDChan"
	hairUnder = "SDChan"
	hairBack = "SDChan"
	hairBottom = "SDChan"
	costume = "nude"
	irisFill = {"r": 56, "g": 100, "b": 137, "a": 1}
	eyebrowFill = {"r": 89, "g": 67, "b": 51, "a": 1}
	eyebrowLine = {"r": 0, "g": 0, "b": 0, "a": 1}
	scalpFill = {"r": 211, "g": 158, "b": 90}
	eyeShadow.a = 1
	bg = 3


func generateElements() -> Array:
	var _loc1_ = Flash.create("SDCHairLong")
	var _loc2_ = Rope.new(_loc1_,g.hairUnderLayer,Vector2(-105,-193),null,0,"right",0,0)
	var _loc3_ = Flash.create("SDCHairLong2")
	var _loc4_ = Rope.new(_loc3_,g.hairBackLayer,Vector2(-50,-140))
	return [_loc2_,_loc4_]
