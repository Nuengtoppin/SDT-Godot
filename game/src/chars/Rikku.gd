class_name Rikku
extends Character
## Port of chars.Rikku (character preset).

func _init() -> void:
	charName = "Rikku"
	charShortName = "Rikku"
	skinType = 0
	iris = "swirl"
	breastSize = 88
	hairTop = "Rikku"
	hairUnder = "Rikku"
	hairBack = "Rikku"
	hairBottom = "Rikku"
	costume = "nude"
	earring = "Feather"
	earringFill = {"r": 222, "g": 86, "b": 6, "a": 1}
	bodyScale = 1.006
	irisFill = {"r": 14, "g": 94, "b": 66, "a": 1}
	eyebrowFill = {"r": 172, "g": 105, "b": 50, "a": 1}
	eyebrowLine = {"r": 89, "g": 67, "b": 51, "a": 1}
	scalpFill = {"r": 172, "g": 105, "b": 50}
	eyeShadow.a = 0.25
	bg = 4
	defaultCostume = ";lipstick:0,0,0,0,0;eyeshadow:55,26,99,0.25;sclera:255,255,255,1;blush:196,80,77,0.35;freckles:60,24,24,0.8,0;mascara:0,0,0,1,20;nailpolish:0,0,0,0;eyebrow:normal,172,105,50,1,89,67,51,1;collar:none,0,0,0,1,233,233,233,1;cuffs:none,0,0,0,1,0,0,0,1;gag:none,0,0,0,1;panties:highleg,255,213,0,1;top:bikini,255,213,0,1;armwear:none,0,0,0,1;bottoms:miniskirt,74,44,20,1,106,187,190,1;legwear:none,0,0,0,1,0,0,0,1;footwear:none,0,0,0,1,0,0,0,1;eyewear:none,0,0,0,1;headwear:none,24,24,24,1,139,42,95,1;tonguePiercing:none,183,187,195,1;earring:feather,222,86,6,1;herTan:none,0"


func generateElements() -> Array:
	var _loc1_ = Flash.create("RikkuBang1")
	var _loc2_ = Rope.new(_loc1_,g.hairUnderLayer,Vector2(58,-261.6),null,10)
	_loc2_.lockTopRotation()
	var _loc3_ = Flash.create("RikkuBang2")
	var _loc4_
	_loc4_ = Rope.new(_loc3_,g.hairUnderLayer,Vector2(79.2,-250.75),null,10)
	_loc4_.lockTopRotation()
	var _loc5_
	_loc5_ = RikkuBandanaBack.new()
	_loc5_.x = -17.55
	_loc5_.y = -144
	g.hairCostumeBack.addChild(_loc5_)
	_loc5_.makeUnToggleable()
	var _loc6_
	_loc6_ = RikkuBandana.new()
	_loc6_.x = -30.2
	_loc6_.y = -191.7
	g.hairCostumeUnder.addChild(_loc6_)
	var _loc7_ = Flash.create("RikkuBraidBackRight")
	var _loc8_
	_loc8_ = Rope.new(_loc7_,g.hairUnderLayer,Vector2(-89.75,-254.65))
	_loc8_.makeUnToggleable()
	var _loc9_ = Flash.create("RikkuBraidFrontRight")
	var _loc10_
	_loc10_ = Rope.new(_loc9_,g.hairOverLayer,Vector2(25.4,-220))
	_loc10_.makeUnToggleable()
	var _loc11_
	_loc11_ = RikkuBraidFrontRightExtend.new()
	_loc11_.dynamicAnchor(25.4,-220,g.her)
	g.hairOverLayer.addChild(_loc11_)
	_loc11_.makeUnToggleable()
	var _loc12_ = Flash.create("RikkuBraidFrontLeft")
	var _loc13_
	_loc13_ = Rope.new(_loc12_,g.hairBackLayer,Vector2(55.4,-270))
	_loc13_.makeUnToggleable()
	var _loc14_
	_loc14_ = RikkuBraidLoops.new()
	_loc14_.dynamicAnchor(-56.25,-222.2,g.her)
	g.hairOverLayer.addChild(_loc14_)
	_loc14_.makeUnToggleable()
	_loc6_.linkTo(_loc5_,true)
	_loc6_.linkTo(_loc8_,true)
	_loc6_.linkTo(_loc10_,true)
	_loc6_.linkTo(_loc13_,true)
	_loc6_.linkTo(_loc14_,true)
	_loc6_.linkTo(_loc11_,true)
	var _loc15_ = Flash.create("RikkuTail")
	var _loc16_
	_loc16_ = Rope.new(_loc15_,g.hairOverLayer,Vector2(-223.55,-305.15))
	_loc16_.lockTopRotation()
	var _loc17_
	_loc17_ = RikkuHairTop.new()
	_loc17_.dynamicAnchor(-133.7,-298.2,g.her)
	g.hairOverLayer.addChild(_loc17_)
	return [_loc8_,_loc5_,_loc6_,_loc13_,_loc10_,_loc11_,_loc14_,_loc16_,_loc17_,_loc2_,_loc4_]
