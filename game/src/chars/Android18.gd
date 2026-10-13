class_name Android18
extends Character
## Port of chars.Android18 (character preset).

func _init() -> void:
	charName = "Android 18"
	charShortName = "Android 18"
	mood = Her.ANGRY_MOOD
	skinType = 0
	noseType = 1
	iris = "sharp"
	breastSize = 105
	hairTop = "Android18"
	hairUnder = "Android18"
	hairBack = "Android18"
	hairBottom = "Android18"
	costume = "nude"
	earring = "Ring"
	earringFill = {"r": 153, "g": 21, "b": 13, "a": 1}
	bodyScale = 1.027
	irisFill = {"r": 88, "g": 114, "b": 108, "a": 1}
	eyebrowFill = {"r": 87, "g": 53, "b": 32, "a": 1}
	eyebrowLine = {"r": 30, "g": 19, "b": 19, "a": 0}
	scalpFill = {"r": 45, "g": 25, "b": 16}
	eyeShadow.a = 0.25
	bg = 4


func generateElements() -> Array:
	var _loc1_ = Flash.create("Android18HairBack")
	var _loc2_ = Rope.new(_loc1_,g.hairOverLayer,Vector2(-94,-212))
	_loc2_.damping = 0.255
	var _loc3_ = Flash.create("Android18HairFront")
	var _loc4_
	_loc4_ = Rope.new(_loc3_,g.hairOverLayer,Vector2(11,-241))
	_loc4_.damping = 0.255
	var _loc5_
	_loc5_ = Android18HairMask.new()
	_loc5_.dynamicAnchor(49,-235,g.her)
	_loc5_.makeUnToggleable()
	g.hairOverLayer.addChild(_loc5_)
	_loc4_.linkTo(_loc5_)
	return [_loc2_,_loc4_,_loc5_]
