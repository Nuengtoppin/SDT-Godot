class_name Morrigan
extends Character
## Port of chars.Morrigan (character preset).

func _init() -> void:
	charName = "Morrigan"
	charShortName = "Morrigan"
	skinType = 0
	iris = "bright"
	breastSize = 110
	hairTop = "Morrigan"
	hairUnder = "Morrigan"
	hairBack = "Morrigan"
	hairBottom = "Morrigan"
	costume = "nude"
	headwear = "Bat Wings"
	headwearFill = {"r": 24, "g": 24, "b": 24, "a": 1}
	headwearFill2 = {"r": 139, "g": 42, "b": 95, "a": 1}
	bodyScale = 1.025
	irisFill = {"r": 35, "g": 89, "b": 67, "a": 1}
	eyebrowFill = {"r": 35, "g": 89, "b": 67, "a": 1}
	eyebrowLine = {"r": 11, "g": 58, "b": 45, "a": 1}
	scalpFill = {"r": 35, "g": 89, "b": 67}
	eyeShadow.a = 1
	bg = 2


func generateElements() -> Array:
	var _loc1_ = MorriganTailUnder.new()
	_loc1_.dynamicAnchor(-134.95,-194.1,g.her)
	_loc1_.makeUnToggleable()
	g.hairUnderLayer.addChild(_loc1_)
	var _loc2_ = Flash.create("MorriganTail")
	var _loc3_ = Rope.new(_loc2_,g.hairUnderLayer,Vector2(-131.95,-168.4),null,5,"right",0,0)
	var _loc4_
	_loc4_ = MorriganTailHighlight.new()
	_loc4_.dynamicAnchor(-28.55,-243.15,g.her)
	_loc4_.makeUnToggleable()
	g.hairOverLayer.addChild(_loc4_)
	_loc3_.linkTo(_loc1_)
	_loc3_.linkTo(_loc4_)
	var _loc5_ = Flash.create("MorriganBang")
	var _loc6_ = Rope.new(_loc5_,g.hairOverLayer,Vector2(-25.8,-208.1))
	var _loc7_
	_loc7_ = MorriganHairOver.new()
	_loc7_.dynamicAnchor(-28.55,-243.15,g.her)
	_loc7_.makeUnToggleable()
	g.hairOverLayer.addChild(_loc7_)
	return [_loc3_,_loc6_,_loc1_,_loc4_,_loc7_]
