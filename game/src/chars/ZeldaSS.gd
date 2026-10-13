class_name ZeldaSS
extends Character
## Port of chars.ZeldaSS (character preset).

func _init() -> void:
	charName = "Zelda (SS)"
	charShortName = "Zelda (SS)"
	skinType = 0
	iris = "wide"
	breastSize = 66
	hairTop = "ZeldaSS"
	hairUnder = "ZeldaSS"
	hairBack = "ZeldaSS"
	hairBottom = "ZeldaSS"
	costume = "nude"
	earType = "Elf"
	bodyScale = 0.9925
	irisFill = {"r": 60, "g": 82, "b": 114, "a": 1}
	eyebrowFill = {"r": 221, "g": 147, "b": 23, "a": 1}
	eyebrowLine = {"r": 83, "g": 61, "b": 46, "a": 1}
	scalpFill = {"r": 221, "g": 147, "b": 23}
	eyeShadow.a = 0.25
	bg = 4


func generateElements() -> Array:
	var _loc1_ = Flash.create("ZeldaSSTail")
	var _loc2_ = Rope.new(_loc1_,g.hairUnderLayer,Vector2(-64.45,-251.05),null,10,"right",0,0)
	var _loc3_ = Flash.create("ZeldaSSBang")
	var _loc4_ = Rope.new(_loc3_,g.hairOverLayer,Vector2(-8.45,-298.6))
	var _loc5_ = Flash.create("ZeldaSSBang")
	var _loc6_
	_loc6_ = Rope.new(_loc5_,g.hairBackLayer,Vector2(56.8,-285.85))
	_loc6_.setScaling(-0.9,0.9)
	var _loc7_
	_loc7_ = ZeldaSSHighlights.new()
	_loc7_.dynamicAnchor(-19.2,-317.65,g.her)
	_loc7_.makeUnToggleable()
	g.hairOverLayer.addChild(_loc7_)
	return [_loc2_,_loc4_,_loc6_,_loc7_]
