class_name HatsuneMiku
extends Character
## Port of chars.HatsuneMiku (character preset).

func _init() -> void:
	charName = "Hatsune Miku"
	charShortName = "Miku"
	skinType = 0
	iris = "bright"
	breastSize = 63
	hairTop = "Miku"
	hairUnder = "Miku"
	hairBack = "Miku"
	hairBottom = "Miku"
	costume = "nude"
	bodyScale = 1.006
	irisFill = {"r": 44, "g": 96, "b": 108, "a": 1}
	eyebrowFill = {"r": 0, "g": 53, "b": 48, "a": 1}
	eyebrowLine = {"r": 0, "g": 53, "b": 48, "a": 0}
	scalpFill = {"r": 19, "g": 107, "b": 115}
	eyeShadow.a = 0.25
	bg = 2
	defaultCostume = ";lipstick:0,0,0,0,0;eyeshadow:55,26,99,0.25;sclera:255,255,255,1;blush:196,80,77,0.35;freckles:60,24,24,0.8,0;mascara:0,0,0,1,20;nailpolish:0,0,0,0;eyebrow:normal,0,53,48,1,0,53,48,0;collar:tie,106,187,190,1,233,233,233,1;cuffs:none,0,0,0,1,0,0,0,1;gag:none,0,0,0,1;panties:highleg,0,0,0,1;top:bra,0,0,0,1;armwear:elbowglove,0,0,0,1;bottoms:skirt,0,0,0,1,106,187,190,1;tops:shirt,209,209,219,0.976;legwear:latexthighhigh,0,0,0,1,0,0,0,1;footwear:school,106,187,190,1,0,0,0,1;eyewear:none,0,0,0,1;headwear:none,24,24,24,1,139,42,95,1;tonguePiercing:none,183,187,195,1;herTan:none,0"


func generateElements() -> Array:
	var _loc1_ = Flash.create("MikuBang")
	var _loc2_ = Rope.new(_loc1_,g.hairOverLayer,Vector2(4.45,-320.65))
	_loc2_.lockTopRotation()
	var _loc3_ = MikuHairRibbon.new()
	_loc3_.dynamicAnchor(-129.3,-237.45,g.her)
	g.hairUnderLayer.addChild(_loc3_)
	var _loc4_ = Flash.create("MikuTail")
	var _loc5_ = Rope.new(_loc4_,g.hairUnderLayer,Vector2(-143.85,-221.15),null,10,"right",0,0)
	var _loc6_ = Flash.create("MikuTail")
	var _loc7_ = Rope.new(_loc6_,g.hairBackLayer,Vector2(-43.85,-261.15),null,10,"right",0,0)
	var _loc8_
	_loc8_ = MikuHairRibbon.new()
	_loc8_.x = -29.3
	_loc8_.y = -277.45
	g.hairCostumeBack.addChild(_loc8_)
	return [_loc2_,_loc5_,_loc3_,_loc7_,_loc8_]
