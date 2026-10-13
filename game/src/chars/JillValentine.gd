class_name JillValentine
extends Character
## Port of chars.JillValentine (character preset).

func _init() -> void:
	charName = "Jill Valentine"
	charShortName = "Jill Valentine"
	skinType = 0
	iris = "normal"
	breastSize = 100
	hairTop = "JillValentine"
	hairUnder = "JillValentine"
	hairBack = "JillValentine"
	hairBottom = "JillValentine"
	costume = "nude"
	bodyScale = 1.025
	irisFill = {"r": 66, "g": 90, "b": 120, "a": 1}
	eyebrowFill = {"r": 45, "g": 25, "b": 16, "a": 1}
	eyebrowLine = {"r": 30, "g": 19, "b": 19, "a": 1}
	scalpFill = {"r": 45, "g": 25, "b": 16}
	eyeShadow.a = 0.5
	bg = 2


func generateElements() -> Array:
	var _loc1_ = Flash.create("JillValentineHairBang")
	var _loc2_ = Rope.new(_loc1_,g.hairOverLayer,Vector2(105,-265))
	_loc2_.damping = 0.425
	var _loc3_ = Flash.create("JillValentineHairBack")
	var _loc4_
	_loc4_ = Rope.new(_loc3_,g.hairOverLayer,Vector2(-61,-219),null,10)
	_loc4_.damping = 0.255
	var _loc5_ = Flash.create("JillValentineHairFront")
	var _loc6_
	_loc6_ = Rope.new(_loc5_,g.hairOverLayer,Vector2(47,-252),null,5)
	_loc6_.damping = 0.255
	var _loc7_
	_loc7_ = JillValentineHairHighlight.new()
	_loc7_.dynamicAnchor(96,-250,g.her)
	_loc7_.makeUnToggleable()
	g.hairOverLayer.addChild(_loc7_)
	return [_loc2_,_loc4_,_loc6_,_loc7_]
