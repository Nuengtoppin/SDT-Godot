extends SDTExtension
## Built-in reimplementation of the Loader's extra arm (sby's Loader 5.45, its "Arm" button): a second copy of his
## right arm drawn above everything with him, so his hand shows in front of her head. Every tick it takes his right
## arm's pose and his skin tint. With "hold", she can't pull off while it shows (the Loader's armHold setting).
## Written from its behaviour; the art is the Loader's (assets/mods/loader).
##
## ExtraModHim swaps its art for its own (set_art) and dresses it with HimLoaderArm mods.

const ART := "res://assets/mods/loader"

var arm: FlashSprite = null      # the Loader's aMC: above himOverLayer, takes himOverLayer's transform
var _mid: FlashSprite = null     # the arm (his armContainer.arm's transform)
var upper: FlashDisplayObject = null
var lower: FlashDisplayObject = null
var hand: FlashDisplayObject = null
var _own: Array = []             # the Loader's art: [upper, lower, hand]


func _init() -> void:
	id = "loaderarm"
	title = "Loader arm"
	description = "The Loader's extra arm for him: a copy of his right arm in front of her (Him > Arms > Extra arm)."
	default_enabled = true


func _setup() -> void:
	setting("hold", false, {"label": "She can't pull off while it shows"})


func _enable() -> void:
	var art := FlashSwfMod.load_art(ART)
	if art == null:
		return
	arm = FlashSprite.new()
	arm.flash_name = "loaderArm"
	_mid = FlashSprite.new()
	arm.addChild(_mid)
	g.himOverLayer._flash_parent.addChild(arm)
	arm.visible = false
	_own = [art.create("upperArm"), art.create("lowerArm"), art.create("hand")]
	set_art(_own[0], _own[1], _own[2])
	on_late_tick(_tick)
	menu_control("him", "Arms", MenuSchema.toggle("Extra arm",
		"The Loader's extra arm: a copy of his right arm in front of her head.", func(): return shown(),
		func(on: bool): show_arm(on)))
	menu_control("him", "Arms", MenuSchema.toggle("Extra arm holds her",
		"While the extra arm shows, she can't pull off.", func(): return get_setting("hold"),
		func(on: bool): set_setting("hold", on), {"visible": func(): return shown()}))


func _disable() -> void:
	if arm != null and arm._flash_parent != null:
		arm._flash_parent.removeChild(arm)
	arm = null
	_mid = null
	_own = []


## Puts other art on the arm (ExtraModHim's); the pieces take his arm's pieces' transforms.
func set_art(p_upper: FlashDisplayObject, p_lower: FlashDisplayObject, p_hand: FlashDisplayObject) -> void:
	for o in [upper, lower, hand]:
		if o != null and o._flash_parent == _mid:
			_mid.removeChild(o)
	upper = p_upper
	lower = p_lower
	hand = p_hand
	for o in [upper, lower, hand]:
		_mid.addChild(o)
	_follow()


## Back to the Loader's own art.
func reset_art() -> void:
	if not _own.is_empty():
		set_art(_own[0], _own[1], _own[2])


func shown() -> bool:
	return arm != null and arm.visible


func show_arm(on: bool) -> void:
	if arm == null:
		return
	arm.visible = on
	_follow()


func toggle() -> void:
	show_arm(not shown())


## The Loader's cloneProps: the target takes the source's transform (matrix and colour), keeping its alpha.
static func _clone(src: FlashDisplayObject, dst: FlashDisplayObject) -> void:
	var a := dst.alpha
	dst.transform = src.transform
	dst.alpha = a


func _follow() -> void:
	var him = g.him
	if arm == null or him == null:
		return
	var a = him.armContainer.arm
	_clone(g.himOverLayer, arm)
	_clone(a, _mid)
	_clone(a.upperArm, upper)
	_clone(a.lowerArm, lower)
	_clone(a.hand, hand)
	var hsl = g.characterControl.hisSkinHSL
	arm.filters = [] if is_same(hsl, g.characterControl.blankHSL) else [g.characterControl._hslFilter(hsl)]


func _tick() -> void:
	if not shown():
		return
	_follow()
	if get_setting("hold"):
		g.her.activeHold(false)
		g.her.pullOff = 0
