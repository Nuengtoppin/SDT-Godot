class_name ZeldaTP
extends Character
## Port of chars.ZeldaTP (character preset).

func _init() -> void:
	charName = "Zelda (TP)"
	charShortName = "Zelda (TP)"
	skinType = 0
	iris = "normal"
	breastSize = 76
	hairTop = "ZeldaTP"
	hairUnder = "ZeldaTP"
	hairBack = "ZeldaTP"
	hairBottom = "ZeldaTP"
	costume = "nude"
	earType = "Elf"
	headwear = "Zelda\'s Circlet"
	headwearFill = {"r": 179, "g": 124, "b": 55, "a": 1}
	headwearFill2 = {"r": 62, "g": 142, "b": 193, "a": 1}
	bodyScale = 1.025
	irisFill = {"r": 60, "g": 82, "b": 114, "a": 1}
	eyebrowFill = {"r": 78, "g": 45, "b": 21, "a": 1}
	eyebrowLine = {"r": 30, "g": 19, "b": 19, "a": 1}
	scalpFill = {"r": 78, "g": 45, "b": 21}
	eyeShadow.a = 0.75
	bg = 4


func generateElements() -> Array:
	var _loc1_ = Flash.create("ZeldaTPTail")
	var _loc2_ = Rope.new(_loc1_,g.hairUnderLayer,Vector2(-117.25,-171.4),null,10,"right",0,0)
	var _loc3_ = Flash.create("ZeldaTPBang")
	var _loc4_ = Rope.new(_loc3_,g.hairOverLayer,Vector2(-14.7,-202.4))
	var _loc5_ = Flash.create("ZeldaTPBang")
	var _loc6_
	_loc6_ = Rope.new(_loc5_,g.hairBackLayer,Vector2(1.55,-193.55))
	_loc6_.setScaling(0.9,0.9)
	var _loc7_
	_loc7_ = ZeldaTPHairMask.new()
	_loc7_.dynamicAnchor(-1.15,-223.35,g.her)
	_loc7_.makeUnToggleable()
	g.hairOverLayer.addChild(_loc7_)
	return [_loc2_,_loc4_,_loc6_,_loc7_]
