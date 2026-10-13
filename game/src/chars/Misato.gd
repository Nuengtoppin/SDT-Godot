class_name Misato
extends Character
## Port of chars.Misato (character preset).

func _init() -> void:
	charName = "Misato Katsuragi"
	charShortName = "Misato"
	skinType = 0
	iris = "bright"
	breastSize = 110
	hairTop = "Misato"
	hairUnder = "Misato"
	hairBack = "Misato"
	hairBottom = "Misato"
	costume = "nude"
	earring = "Stud"
	earringFill = {"r": 206, "g": 218, "b": 223, "a": 1}
	bodyScale = 1.035
	irisFill = {"r": 62, "g": 39, "b": 29, "a": 1}
	eyebrowFill = {"r": 33, "g": 33, "b": 51, "a": 1}
	eyebrowLine = {"r": 30, "g": 19, "b": 19, "a": 1}
	scalpFill = {"r": 33, "g": 33, "b": 51}
	bg = 1


func generateElements() -> Array:
	var _loc1_ = Flash.create("MisatoBack")
	var _loc2_ = Rope.new(_loc1_,g.hairUnderLayer,Vector2(-136,-145),null,0,"right",0,0)
	var _loc3_ = Flash.create("MisatoSide")
	var _loc4_ = Rope.new(_loc3_,g.hairOverLayer,Vector2(-76,-78),null,-30,"left",0,2)
	var _loc5_ = Flash.create("MisatoNecklace")
	var _loc6_ = Rope.new(_loc5_,g.hairUnderLayer,Vector2(-65,60),null,-35,"left",0,2)
	return [_loc2_,_loc4_,_loc6_]
