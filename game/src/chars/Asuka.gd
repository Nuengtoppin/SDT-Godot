class_name Asuka
extends Character
## Port of chars.Asuka (character preset).

func _init() -> void:
	charName = "Asuka Soryuu Shikinami"
	charShortName = "Asuka"
	skinType = 0
	iris = "bright"
	breastSize = 70
	hairTop = "Asuka"
	hairUnder = "Asuka"
	hairBack = "Asuka"
	hairBottom = "Asuka"
	costume = "nude"
	bodyScale = 1.005
	irisFill = {"r": 23, "g": 57, "b": 102, "a": 1}
	eyebrowFill = {"r": 87, "g": 53, "b": 32, "a": 1}
	eyebrowLine = {"r": 56, "g": 42, "b": 32, "a": 1}
	scalpFill = {"r": 87, "g": 53, "b": 32}
	eyeShadow.a = 0.5
	bg = 1
	dialogue = "resistance:\"Anta baka?!\"" + "\npull_off:\"Anta baka?!\"" + "\nnwake_up:\"You\'re the worst\"" + "\ncum_in_nose:\"Anta baka?!\""


func generateElements() -> Array:
	var _loc1_ = Flash.create("AsukaTail1")
	var _loc2_ = Rope.new(_loc1_,g.hairUnderLayer,Vector2(-100,-240),null,5,"right",0,0)
	_loc2_.lockTop(0.5)
	var _loc3_ = Flash.create("AsukaTail2")
	var _loc4_ = Rope.new(_loc3_,g.hairBackLayer,Vector2(-60,-80),null,20,"right",0,1)
	_loc2_.linkTo(_loc4_)
	_loc4_.makeUnToggleable()
	var _loc5_
	_loc5_ = AsukaHairClip.new()
	_loc5_.x = -165.7
	_loc5_.y = -270.95
	g.hairCostumeUnder.addChild(_loc5_)
	return [_loc2_,_loc4_,_loc5_]
