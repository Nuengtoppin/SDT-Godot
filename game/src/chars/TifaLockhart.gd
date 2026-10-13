class_name TifaLockhart
extends Character
## Port of chars.TifaLockhart (character preset).

func _init() -> void:
	charName = "Tifa Lockhart"
	charShortName = "Tifa"
	skinType = 0
	iris = "normal"
	breastSize = 116
	hairTop = "Tifa"
	hairUnder = "Tifa"
	hairBack = "Tifa"
	hairBottom = "Tifa"
	costume = "nude"
	earring = "Teardrop"
	earringFill = {"r": 181, "g": 182, "b": 190, "a": 1}
	bodyScale = 1.019
	irisFill = {"r": 72, "g": 28, "b": 10, "a": 1}
	eyebrowFill = {"r": 31, "g": 25, "b": 24, "a": 1}
	eyebrowLine = {"r": 15, "g": 10, "b": 9, "a": 1}
	scalpFill = {"r": 15, "g": 10, "b": 9}
	eyeShadow.a = 0.5
	bg = 2
	defaultCostume = ";lipstick:0,0,0,0,0;eyeshadow:55,26,99,0.5;sclera:255,255,255,1;blush:196,80,77,0.35;freckles:60,24,24,0.8,0;mascara:0,0,0,1,20;nailpolish:0,0,0,0;eyebrow:normal,31,25,24,1,15,10,9,1;collar:none,0,0,0,1,233,233,233,1;cuffs:leather,0,0,0,1,0,0,0,1;gag:none,0,0,0,1;panties:bikini,255,255,255,1;top:none,255,255,255,1;armwear:elbowglove,0,0,0,1;bottoms:miniskirt,0,0,0,1,106,187,190,1;tops:cropped,249,247,247,0.969;legwear:kneehigh,0,0,0,1,0,0,0,1;legwearB:kneehigh,0,0,0,1,0,0,0,1;footwear:school,0,0,0,1,0,0,0,1;eyewear:none,0,0,0,1;headwear:none,24,24,24,1,139,42,95,1;tonguePiercing:none,183,187,195,1;earring:teardrop,181,182,190,1;herTan:none,0"


func generateElements() -> Array:
	var _loc1_ = Flash.create("TifaTail")
	var _loc2_ = Rope.new(_loc1_,g.hairUnderLayer,Vector2(-91.35,-224.05),null,10,"right",0,0)
	var _loc3_ = Flash.create("TifaBang1")
	var _loc4_ = Rope.new(_loc3_,g.hairOverLayer,Vector2(11.9,-255.5),null,-10)
	var _loc5_ = Flash.create("TifaBang2")
	var _loc6_ = Rope.new(_loc5_,g.hairOverLayer,Vector2(-17.3,-202.8),null,18,"right",0,0)
	return [_loc2_,_loc4_,_loc6_]
