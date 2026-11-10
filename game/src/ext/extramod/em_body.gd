extends RefCounted
## ExtraMod's BodyExpanded type (stage 2): mods for her whole body, part by part. Written from ExtraMod Core's
## behaviour (SClover13, v1.51).
##   Parts: alt<name> next to her own arms, hands, shoulder, chest, breasts, back, hips, thighs and calves (TARGETS);
##   leftthumb (her thumb over him in a hand job, follows his width); animRightThigh / animLeftThigh (ExtraMod shows
##   them only with animtools' rotated thighs: hidden here).
##   Flags on the mod: overwrite (takes off the other BodyExpanded mods), vanillaOverwrite (also takes off Body mods
##   and hides her own parts that the mod brings: VANILLA_HIDE), useSkinPalette (parts show the frame named after her
##   skin; altchest the frame of her skin's chest, skin x 150 + 2).
##   Children of the parts: "skin" / "fingerr" (her skin's frame), "tan" (her tan lines, overlay), "rgbNail" (her
##   nail polish colour), "nipple" in the breasts (her skin's frame). Breast parts show her breast size's frame.
##   Hands: "normal" / "handjob" (and "handjobNoThumb" for the left hand with a thumb part) by her arm positions;
##   the right hand's "fingerr" sits on her grip. altrightupperarm: "backArm" behind her back, else "normalArm".
## Everything it hid comes back when the mods are cleared.

const TYPE := "BodyExpanded"
const TARGETS := {
	"altleftupperarm": "leftArmContainer.upperArm", "altleftforearm": "leftArmContainer.upperArm.foreArm",
	"altlefthand": "leftArmContainer.upperArm.foreArm.hand", "leftthumb": "#thumb",
	"altleftfingers": "leftHandOver.hand", "altleftshoulder": "torsoBack.leftShoulder",
	"altchestunder": "torsoBack.chestBack", "underboob": "torso.midLayer.chest", "altleftbreast": "torsoBack.leftBreast",
	"altbackside": "torsoBack.backside", "althip": "torso.backside", "altleftcalf": "leftLegContainer.leg.calf",
	"altleftthigh": "leftLegContainer.leg.thigh", "altchest": "torso.midLayer.chest", "altrightthigh": "torso.leg.thigh",
	"altrightcalf": "torso.rightCalfContainer.calf", "altrightbreast": "torso.midLayer.rightBreast",
	"altleftbehindback": "torso.midLayer.leftArm", "altrightbehindback": "torso.behindBackRightArm",
	"altback": "torso.back", "altrightupperarm": "rightArmContainer.upperArm",
	"altrightforearm": "rightForeArmContainer.upperArm.foreArm",
	"altrighthand": "rightForeArmContainer.upperArm.foreArm.hand", "animRightThigh": "torso.leg.thigh",
	"animLeftThigh": "leftLegContainer.leg.thigh"}
## A vanillaOverwrite mod's part hides these of her own children (indexes among her own, not the mods'):
## [] = all but none listed means the first one
const VANILLA_HIDE := {"altleftcalf": [1], "altrightcalf": [0, 2], "altleftbreast": [0, 1, 2, 3, 4],
	"altrightbreast": [0, 1, 2, 3, 4], "underboob": [1, 2]}
const THUMB_MAX_WIDTH := 1.303   # his width past which the thumb does not fit (ExtraMod's)
const THUMB_Y := 140.0

var em   # extramod.gd
var on := false            # a BodyExpanded mod is placed
var _over: Array = []      # part names some vanillaOverwrite mod brings: her own hidden
var _skin_palette := false
var _right_grip := false   # her hands showed a gripping frame at the last right_hand() / left_hand()
var _left_grip := false
var _hidden := {}         # her own parts hide_vanilla() hid -> true
var _thumb_open := -1      # the thumb's frame for his width: 1 open, 0 closed (-1: not set yet)


func _init(extramod) -> void:
	em = extramod


func register() -> void:
	em._register(TYPE, TARGETS)


## Her part by TARGETS name.
func target(n: String):
	var path: String = TARGETS.get(n, "")
	if path.begins_with("#"):
		return em.c.get(path.substr(1))
	return em._node(path) if path != "" else null


func _parts(n := "") -> Array:
	return em._parts(TYPE, n)


## A BodyExpanded mod was placed (`m`: the mod's item, its parts already in place; `pkg`: its package). `first`:
## just placed (overwrite takes off the others), else replayed after another mod went.
func placed(m, first: bool, pkg) -> void:
	on = true
	var loader = g.customElementLoader
	if first and m.get("overwrite"):
		loader.clearModTypes([TYPE])
	if m.get("useSkinPalette"):
		_skin_palette = true
	if m.get("vanillaOverwrite"):
		if first:
			loader.clearModTypes([ModTypes.BODY])
		for lm in loader.instancedModElements:
			if lm._modType == TYPE and lm.sourcePackage == pkg and lm._mod != null:
				var n := str(lm._mod.flash_name)
				if n in TARGETS and not n in _over:
					_over.append(n)
	for p in _parts("animRightThigh") + _parts("animLeftThigh"):
		p.visible = false
	g.characterControl.prepForBodyMod()
	refresh()


## Everything the parts follow, now: skin, tan, breasts, nail polish, hands, her own parts hidden.
func refresh() -> void:
	if not on:
		return
	skin()
	breasts()
	nails()
	right_hand()
	left_hand()
	skin_hsl()
	hide_vanilla()
	tick()


func skin() -> void:
	var cc = g.characterControl
	var label: String = g.dataName(CharacterControl.skinNameList[cc.currentSkin])
	for p in _parts():
		if _skin_palette:
			em._label(p, label, 1)
		for n in ["skin", "fingerr"]:
			var ch = em._child(p, n)
			if ch != null:
				em._label(ch, label, 1)
	if _skin_palette:
		for p in _parts("altchest"):
			em._frame(p, cc.currentSkin * 150 + 2)


## Breast parts at her breast size (ExtraMod: under 152 frames, the first size range's frames), their nipples on
## her skin.
func breasts() -> void:
	var cc = g.characterControl
	var label: String = g.dataName(CharacterControl.skinNameList[cc.currentSkin])
	for p in _parts("altrightbreast") + _parts("altleftbreast") + _parts("underboob"):
		if not p is FlashSprite:
			continue
		for i in p.numChildren:
			var ch = p.getChildAt(i)
			if not ch is FlashMovieClip:
				continue
			var base: float = CharacterControl.breastOffset[0] if ch.totalFrames < 152 else cc.currentBreastOffset
			em._frame(ch, int(cc.breastSize + base))
			var nip = em._child(ch, "nipple")
			if nip is FlashMovieClip and nip.totalFrames > 1:
				em._label(nip, label, 1)


## Her skin colour on the thumb and the fingers over him (outside the parts the game filters).
func skin_hsl() -> void:
	var cc = g.characterControl
	var hsl = cc.skinHSL
	var parts: Array = _parts("altleftfingers")
	if em.c.has("thumb"):
		parts.append(em.c["thumb"])
	var f = null if hsl == null or is_same(hsl, cc.blankHSL) else cc._hslFilter(hsl)
	for p in parts:
		p.filters = [] if f == null else [f]


func nails() -> void:
	var c = g.characterControl.nailPolishRGB
	if c == null:
		return
	var ct := FlashColorTransform.new(1, 1, 1, c.a, c.r, c.g, c.b)
	for p in _parts():
		var nail = em._child(p, "rgbNail")
		if nail != null:
			nail.colorTransform = ct


func _has_nail(parts: Array) -> bool:
	return parts.any(func(p): return em._child(p, "rgbNail") != null)


## Whether her hand shows one of its gripping frames (lightGrip, ...): ExtraMod's own test is her arm position (3,
## and 9 / 10, animtools' gripping positions), which are the positions with those frames; the frames also cover
## positions extensions add (armoverhaul's Holding Hand, Holding Stomach).
static func _gripping(hand) -> bool:
	return hand != null and str(hand.currentLabel).ends_with("Grip")


## Her right hand: around him or something (a gripping frame) or not; her upper arm behind her back or not.
func right_hand() -> void:
	var her = g.her
	var pos: int = her.currentRightArmPosition
	for p in _parts("altrightupperarm"):
		em._label(p, "backArm" if pos == 0 else "normalArm", 1)
	var hand = target("altrighthand")
	var grip = hand.get("grip") if hand != null else null
	_right_grip = _gripping(hand)
	for p in _parts("altrighthand"):
		var fingers = em._child(p, "fingerr")
		if _right_grip:
			em._label(p, "handjob", 1)
			hand.setChildIndex(p, hand.numChildren - 1)
			if fingers != null and grip != null:
				fingers.visible = true
				fingers.transform = grip.transform
		else:
			em._label(p, "normal", 1)
			if fingers != null:
				fingers.visible = false


func left_hand() -> void:
	var pos: int = g.her.currentLeftArmPosition
	var thumb := not _parts("leftthumb").is_empty() and g.him.penisWidthScale < THUMB_MAX_WIDTH
	var hand = target("altlefthand")
	_left_grip = _gripping(hand)
	for p in _parts("altlefthand"):
		if pos == 3:
			em._label(p, "handjobNoThumb" if thumb else "handjob", 1)
			hand.setChildIndex(p, hand.numChildren - 1)
		elif _left_grip:
			em._label(p, "handjob", 1)
		else:
			em._label(p, "normal", 1)


## Her own children of `o`, not the mods' parts.
func _own_children(o) -> Array:
	var mods := {}
	for lm in g.customElementLoader.instancedModElements:
		if lm._mod != null:
			mods[lm._mod] = true
	var out: Array = []
	if o is FlashSprite:
		for i in o.numChildren:
			if not mods.has(o.getChildAt(i)):
				out.append(o.getChildAt(i))
	return out


## Her own parts that vanillaOverwrite mods bring hidden (the game shows some again as frames change).
func hide_vanilla() -> void:
	var her = g.her
	for n in _over:
		var t = target(n)
		if t == null or n.begins_with("anim"):
			continue
		var tan = em._child(t, "tan")
		if tan != null and not tan in _parts():
			_hide(tan)
		var own := _own_children(t)
		if n == "altlefthand" or n == "altrighthand":
			for p in _parts(n):
				t.setChildIndex(p, t.numChildren - 1)
			if own.size() > 0:
				_hide(own[0])
			if _has_nail(_parts(n)):
				var arm = her.leftArmContainer if n == "altlefthand" else her.rightForeArmContainer
				_hide(arm.upperArmCostume.foreArmCostume.handCostume.nailPolish)
			continue
		var idx: Array = VANILLA_HIDE.get(n, [0])
		for i in idx:
			if i < own.size():
				_hide(own[i])
		if n == "altback" and her.torso.get("backHighlight") != null:
			_hide(her.torso.backHighlight)
		if n == "altrightthigh":
			_hide(her.torso.leg.highlights)
		if n == "altleftthigh":
			var hl = _left_thigh_highlight()
			if hl != null:
				_hide(hl)


## Hides one of her own parts, remembered so reset() shows exactly these again (the game hides others itself, e.g.
## her arms by their position).
func _hide(o) -> void:
	if o != null and o.visible:
		o.visible = false   # direct: replaced by a mod's art
		_hidden[o] = true


## The highlight shape on her left leg (a bare shape among the leg's children).
func _left_thigh_highlight():
	var leg = g.her.leftLegContainer.leg
	for i in leg.numChildren:
		var ch = leg.getChildAt(i)
		if ch is FlashShape:
			return ch
	return null


## Every tick: her right fingers on her grip, the thumb on him, the tan lines, her own parts kept hidden.
func tick() -> void:
	if not on:
		return
	var hand = target("altrighthand")
	var grip = hand.get("grip") if hand != null else null
	if _gripping(hand) != _right_grip:   # her hand's frame changed (her skin, an extension's position)
		right_hand()
	if _gripping(target("altlefthand")) != _left_grip:
		left_hand()
	if grip != null and _right_grip:
		for p in _parts("altrighthand"):
			var fingers = em._child(p, "fingerr")
			if fingers != null:
				fingers.transform = grip.transform
	_thumb()
	for p in _parts():
		_tan(p)
	if not _over.is_empty():
		hide_vanilla()


## Her thumb over him in a hand job (left arm position 3): closed or open by his width, lower on a wider penis.
func _thumb() -> void:
	var box = em.c.get("thumb")
	if box == null:
		return
	var thumbs := _parts("leftthumb")
	var him = g.him
	var width: float = him.penisWidthScale
	var show := not thumbs.is_empty() and g.her.currentLeftArmPosition == 3 and width <= THUMB_MAX_WIDTH
	box.visible = show
	if not show:
		return
	var open := 1 if width > 1.05 else 0
	if open != _thumb_open:
		_thumb_open = open
		for p in thumbs:
			for i in p.numChildren:
				em._label(p.getChildAt(i), "thumbopen" if open else "thumbclosed", 1)
		left_hand()
	var handpos: float = g.currentHandJobPos.x
	var offset := handpos * 35.0
	if width > 1.05 and him.penisLengthScale > 1.05:
		offset = handpos * -10.0 if handpos < 0.35 else handpos * 35.0
	box.y = THUMB_Y - (width - 1.0) * (offset * width if width >= 1.19 else offset)


## A part's "tan" child: her tan lines (their frame, overlay, as strong as her own).
func _tan(p) -> void:
	var t = em._child(p, "tan")
	if not t is FlashMovieClip:
		return
	var tan = g.her._tan
	var name_: String = tan._tanNameList[tan._currentTanID]
	var back_tan = g.her.torso.back.get("tan")
	if name_ == "None" or back_tan == null:
		em._label(t, "None", 1)
		t.alpha = 0.0
		return
	em._label(t, name_, 1)
	t.alpha = back_tan.alpha
	t.blendMode = "overlay"


## Her own body back as the mods are cleared.
func reset() -> void:
	if not on:
		return
	on = false
	for o in _hidden:
		if is_instance_valid(o):
			o.visible = true   # direct: art visibility restored
	_hidden.clear()
	if em.c.has("thumb"):
		em.c["thumb"].visible = false
	_over.clear()
	_skin_palette = false
	_thumb_open = -1
	var cc = g.characterControl
	cc.setSkin(cc.currentSkin, false)   # her own frames, highlights and breasts again
	cc.setArmSkin(true)
