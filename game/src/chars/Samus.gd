class_name Samus
extends Character
## Port of chars.Samus (character preset).

func _init() -> void:
	charName = "Samus Aran"
	charShortName = "Samus"
	skinType = 0
	iris = "normal"
	breastSize = 80
	hairTop = "Samus"
	hairUnder = "Samus"
	hairBack = "Samus"
	hairBottom = "Samus"
	costume = "nude"
	bodyScale = 1.028
	irisFill = {"r": 56, "g": 100, "b": 137, "a": 1}
	eyebrowFill = {"r": 180, "g": 142, "b": 61, "a": 1}
	eyebrowLine = {"r": 89, "g": 67, "b": 51, "a": 1}
	scalpFill = {"r": 180, "g": 142, "b": 61}
	eyeShadow.a = 0.5
	bg = 2


func generateElements() -> Array:
	var _loc1_ = Flash.create("SamusHairBang")
	var _loc2_ = Rope.new(_loc1_,g.hairOverLayer,Vector2(10,-315),null,-5)
	_loc2_.damping = 0.425
	_loc2_.lockTop(0.25)
	var _loc3_ = Flash.create("SamusHairBackBang")
	var _loc4_
	_loc4_ = Rope.new(_loc3_,g.hairBackLayer,Vector2(55,-300),null,-5)
	_loc4_.damping = 0.425
	_loc4_.lockTop(0.25)
	var _loc5_ = Flash.create("SamusHairPonytail")
	var _loc6_
	_loc6_ = Rope.new(_loc5_,g.hairBackLayer,Vector2(-218,-318))
	_loc6_.damping = 0.425
	_loc6_.lockTop(0.25)
	var _loc7_
	_loc7_ = SamusTailTie.new()
	_loc7_.x = -149.2
	_loc7_.y = -266.95
	g.hairCostumeUnderOver.addChild(_loc7_)
	return [_loc2_,_loc4_,_loc6_,_loc7_]
