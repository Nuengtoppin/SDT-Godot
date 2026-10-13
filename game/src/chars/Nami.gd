class_name Nami
extends Character
## Port of chars.Nami (character preset).

func _init() -> void:
	charName = "Nami"
	charShortName = "Nami"
	skinType = 0
	iris = "wide"
	noseType = 1
	eyebrowType = 2
	earType = "Small"
	breastSize = 104
	hairTop = "Nami"
	hairUnder = "Nami"
	hairBack = "Nami"
	hairBottom = "Nami"
	costume = "nude"
	bodyScale = 1.021
	irisFill = {"r": 76, "g": 34, "b": 0, "a": 1}
	eyebrowFill = {"r": 79, "g": 40, "b": 21, "a": 1}
	eyebrowLine = {"r": 79, "g": 40, "b": 21, "a": 1}
	scalpFill = {"r": 161, "g": 66, "b": 30}
	eyeShadow.a = 0.1
	bg = 4
	defaultCostume = ";lipstick:0,0,0,0,0;eyeshadow:55,26,99,0.1;sclera:255,255,255,1;blush:196,80,77,0.35;freckles:60,24,24,0.8,0;mascara:0,0,0,1,20;nailpolish:0,0,0,0;eyebrow:lines,79,40,21,1,79,40,21,1;collar:none,0,0,0,1,233,233,233,1;cuffs:none,0,0,0,1,0,0,0,1;gag:none,0,0,0,1;panties:bikini,104,185,128,1;top:bikini,104,185,128,1;armwear:none,0,0,0,1;bottoms:jeanshorts,74,106,137,1,106,187,190,1;legwear:none,0,0,0,1,0,0,0,1;footwear:none,0,0,0,1,0,0,0,1;eyewear:none,0,0,0,1;headwear:none,24,24,24,1,139,42,95,1;tonguePiercing:none,183,187,195,1;herTan:none,0"


func generateElements() -> Array:
	var _loc1_ = Flash.create("NamiTailUnder")
	var _loc2_ = Rope.new(_loc1_,g.hairUnderLayer,Vector2(-100,-175),null,0,"right",0,0)
	_loc2_.makeUnToggleable()
	var _loc3_ = Flash.create("NamiTail")
	var _loc4_
	_loc4_ = Rope.new(_loc3_,g.hairUnderLayer,Vector2(-126.25,-233.35),null,7,"right",0,0)
	_loc4_.linkTo(_loc2_)
	var _loc5_ = Flash.create("NamiBangBack")
	var _loc6_ = Rope.new(_loc5_,g.hairBackLayer,Vector2(57.35,-177.75))
	return [_loc4_,_loc2_,_loc6_]
