extends SDTExtension
## Built-in reimplementation of the Loader mod ExtraModHim Core (SClover13, v1.12): mod types for him, for mods made
## with the ExtraModHim template. Needs TemplateExtension. Written from its behaviour; its art (his head, the costume
## arm layers, the extra arm) is in assets/mods/extramodhim.
##
##   HimBody, HimPenis: his torso, legs, feet, arms, hands, breasts; penis, its wet layer, balls. bodyOverwrite hides
##     his own pieces under the mod's parts.
##   HimTop, HimBottoms, HimFootwear: on his clothing pieces (plus arm layers for tops and a layer under his hips for
##     bottoms); they take off his own top / bottoms / shoes and take the colour of his top / bottoms / shoes.
##   HimHead, HimHair, HimEye: on ExtraModHim's head for him (face, nose, ear, eyes, brows, neck, hair). It turns
##     towards her, blinks, and shuts its brows near the end. defaultHeadOverwrite / defaultEyeOverwrite hide its own
##     parts.
##   HimLoaderArm: on the Loader's extra arm (extension loaderarm), which gets ExtraModHim's arm art.
## Parts have a frame per body ("him", "futa"; "heel" for feet and shoes with high heels on), "skin" children the
## frame named after his skin, right hands "himopen" / "himclosed" / "futaopen" / "futaclosed".
##
## Port: his head shows only while a head, hair or eye mod is on (ExtraModHim always gave him one; the original game
## never draws his head). Taking a clothing mod off puts his own top / bottoms / shoes back.

const ART := "res://assets/mods/extramodhim"
const LIST := "extramodhim"   # the mod catalog's list of his mods (Him > Body in the new menu)
const TYPES := ["HimBody", "HimPenis", "HimTop", "HimBottoms", "HimFootwear", "HimHead", "HimHair", "HimEye",
	"HimLoaderArm"]
const HEAD_TYPES := ["HimHead", "HimHair", "HimEye"]

## Part name -> path from him
const BODY_PARTS := {"hisTorso": "torsoLayer.torso", "hisRightThigh": "rightLeg", "hisLeftThigh": "leftLeg",
	"hisRightCalf": "rightLeg.calf", "hisLeftCalf": "leftLeg.calf", "hisRightFoot": "rightLeg.calf.foot",
	"hisLeftFoot": "leftLeg.calf.foot", "hisRightArmUpper": "armContainer.arm.upperArm",
	"hisRightArmLower": "armContainer.arm.lowerArm", "hisRightArmHand": "armContainer.arm.hand",
	"hisLeftArmUpper": "leftArmContainer.arm", "hisLeftArmLower": "leftArmContainer.arm.foreArm",
	"hisLeftArmHand": "leftArmContainer.arm.foreArm.hand", "hisRightBreast": "torsoLayer.rightBreastContainer",
	"hisLeftBreast": "torsoLayer.leftBreastContainer"}
const PENIS_PARTS := {"hisPenisMod": "penis", "penisWetMod": "penis.wet", "ballsMod": "balls"}
## Clothing parts -> path from him ("@rightArm..." / "@leftArm..." / "@bottomsTorso": ExtraModHim's own layers)
const TOP_PARTS := {"hisTorsoCostume": "overLayer.torso.costume", "topBackCostume": "topBack",
	"hisRightArmUpperCostume": "@rightArm.arm.upperArm", "hisRightArmLowerCostume": "@rightArm.arm.foreArm",
	"hisRightArmHandCostume": "@rightArm.arm.hand", "hisLeftArmUpperCostume": "@leftArm.arm",
	"hisLeftArmLowerCostume": "@leftArm.arm.foreArm", "hisLeftArmHandCostume": "@leftArm.arm.foreArm.hand",
	"hisRightBreastCostume": "torsoLayer.rightBreastContainer", "hisLeftBreastCostume": "torsoLayer.leftBreastContainer"}
const BOTTOMS_PARTS := {"hisTorsoCostume": "@bottomsTorso", "hisHipsCostume": "midLayer.hips",
	"hisRightThighCostume": "rightLegCostume", "hisLeftThighCostume": "leftLegCostume",
	"hisRightCalfCostume": "rightLegCostume.calf", "hisLeftCalfCostume": "leftLegCostume.calf"}
const FOOTWEAR_PARTS := {"hisRightCalfCostume": "rightLegCostume.calf", "hisLeftCalfCostume": "leftLegCostume.calf",
	"hisRightShoe": "rightLegCostume.calf.foot", "hisLeftShoe": "leftLegCostume.calf.foot"}
## Head parts -> path from the head
const HEAD_PARTS := {"himFace": "headoriginpt.himFaceContainer", "himNose": "headoriginpt.himNoseContainer",
	"himEar": "headoriginpt.himEarContainer", "himEye": "headoriginpt.himEyeContainer",
	"himEyebrow": "headoriginpt.himEyebrowContainer", "himNeck": "neckoriginpt"}
const HAIR_PARTS := {"hairTop": "headoriginpt.himHairContainerTop",
	"hairBetween": "headoriginpt.himHairContainerBetween", "hairBack": "hairbackorigin.himHairContainerBack"}
const EYE_PARTS := {"eyeball": "headoriginpt.himEyeContainer.eyeball", "hisIris": "headoriginpt.himEyeContainer.hisIris",
	"upperEyeLid": "headoriginpt.himEyeContainer.upperEyeLid",
	"lowerEyeLid": "headoriginpt.himEyeContainer.lowerEyeLid", "staticEye": "headoriginpt.himEyeContainer"}
const BREASTS := ["hisRightBreast", "hisLeftBreast"]

var _art: FlashSwfMod = null
var head: FlashMovieClip = null          # ExtraModHim's head for him (shown with head / hair / eye mods)
var _r_arm: FlashSprite = null           # costume layer over his right arm (tops' sleeves)
var _l_arm: FlashSprite = null           # costume layer over his left arm
var _bottoms_torso: FlashSprite = null   # layer under his hips (bottoms' waist)
var _la: Array = []                      # the extra arm's art: [la_upperarm, la_lowerarm, la_hand]

## Mods placed: {"pkg", "type", "mod"} (mod: the item's root, for its flags)
var _records: Array = []
var _hidden: Array = []                  # pieces hidden under mod parts
var _cleared: Dictionary = {}            # his clothing control -> true: a mod took that clothing off
var _skin := ""
var _hsl = null
var _fills: Dictionary = {}              # control -> colour last applied to its mod parts
var _footwear := ""
# head state
var _p_adj := 0.0
var _blink_tension := 0
var _blink_until := -1


func _init() -> void:
	id = "extramodhim"
	title = "ExtraModHim"
	description = "ExtraModHim Core (SClover13): mod types for his body, penis, clothes, head, hair, eyes and the Loader arm, for mods made with the ExtraModHim template. Needs TemplateExtension."
	default_enabled = true


func _enable() -> void:
	_art = FlashSwfMod.load_art(ART)
	if _art == null:
		return
	_make_layers()
	_register()
	hook_after(&"CustomElementLoader.addStaticModElement", func(h): _placed(h.args[0]))
	hook_after(&"CustomElementLoader.clearInstancedMods", func(_h): _reset())
	hook_after(&"Him.setBody", func(_h): _body_changed())
	on_late_tick(_tick)
	if g.modCatalog != null:
		g.modCatalog.add_picker(LIST, TYPES)
	menu_control("him", "Body", {"type": "custom", "label": "ExtraModHim mods", "wide": true,
		"tip": "His body, clothes, head, hair and eye mods made with ExtraModHim, from Mods/Clothing. Several can be on.",
		"build": func(): return ModSwitchList.build(LIST, _toggle), "keywords": "extramodhim body penis head hair clothes athletic"})


func _disable() -> void:
	if g.modCatalog != null:
		g.modCatalog.remove_picker(LIST)
	var cel = g.customElementLoader
	if cel != null:
		cel.clearModTypes(TYPES)
		for t in TYPES:
			cel.modTargetHelpers.erase(t)
	_reset()
	var la = Extensions.get_extension("loaderarm")
	if la != null and la.enabled and not _la.is_empty() and la.hand == _la[2]:
		la.reset_art()
	for o in [head, _r_arm, _l_arm, _bottoms_torso]:
		if o != null and o._flash_parent != null:
			o._flash_parent.removeChild(o)
	head = null
	_r_arm = null
	_l_arm = null
	_bottoms_torso = null
	_la = []


# ---------------------------------------------------------------- his pieces and ExtraModHim's layers

## His pieces by path ("armContainer.arm.hand", "@rightArm.arm.hand" for ExtraModHim's layers); they change with his
## body, so they are looked up again then.
func _node(path: String, from = null):
	var o = from if from != null else g.him
	var parts := path.split(".")
	if parts[0].begins_with("@"):
		o = {"@rightArm": _r_arm, "@leftArm": _l_arm, "@bottomsTorso": _bottoms_torso}.get(parts[0])
		parts = parts.slice(1)
	for part in parts:
		o = o.get(part) if o is Object else null
		if not o is Object:
			return null
	return o


func _make_layers() -> void:
	head = _art.create("headorigin")
	head.flash_name = "hisHead"
	head.visible = false
	_r_arm = _art.create("rightarmcontainer")
	_l_arm = _art.create("leftarmcontainer")
	_bottoms_torso = FlashSprite.new()
	_bottoms_torso.flash_name = "bottomsTorso"
	for o in [_r_arm, _l_arm]:   # the layers hold only mod parts (their own shapes are the template's guides)
		_clear_guides(o)
	_attach_layers()
	var la = Extensions.get_extension("loaderarm")
	_la = [_art.create("la_upperarm"), _art.create("la_lowerarm"), _art.create("la_hand")]
	if la != null and la.enabled and la.arm != null:
		la.set_art(_la[0], _la[1], _la[2])


## Hides the template's own shapes in a layer (its named pieces stay, for the mod parts).
static func _clear_guides(o) -> void:
	for i in o.numChildren:
		var c = o.getChildAt(i)
		if c is FlashSprite and c.flash_name != "":
			_clear_guides(c)
		else:
			c.visible = false


## Puts ExtraModHim's layers in place (again after his body was rebuilt).
func _attach_layers() -> void:
	var him = g.him
	var arm_parent = him.armContainer._flash_parent
	if _r_arm._flash_parent != arm_parent:
		arm_parent.addChildAt(_r_arm, arm_parent.getChildIndex(him.armContainer) + 1)
	if _l_arm._flash_parent != him.overLayer:
		him.overLayer.addChild(_l_arm)
	var hips_parent = him.midLayer.hips._flash_parent
	if _bottoms_torso._flash_parent != hips_parent:
		hips_parent.addChildAt(_bottoms_torso, 0)
	if head._flash_parent != him:
		him.addChildAt(head, mini(2, him.numChildren))
	_follow_layers()


func _register() -> void:
	var cel = g.customElementLoader
	for t in [["HimBody", BODY_PARTS, null], ["HimPenis", PENIS_PARTS, null], ["HimTop", TOP_PARTS, null],
			["HimBottoms", BOTTOMS_PARTS, null], ["HimFootwear", FOOTWEAR_PARTS, null], ["HimHead", HEAD_PARTS, head],
			["HimHair", HAIR_PARTS, head], ["HimEye", EYE_PARTS, head]]:
		var d := {}
		for p in t[1]:
			var o = _node(t[1][p], t[2])
			if o != null:
				d[p] = o
		cel.modTargetHelpers[t[0]] = CustomElementHelper.new(d)
	cel.modTargetHelpers["HimLoaderArm"] = CustomElementHelper.new({"lupperarm": _la[0], "lforearm": _la[1],
		"lhand": _la[2]})


# ---------------------------------------------------------------- mods placed / taken off

func _placed(m) -> void:
	if m == null or not m is FlashDisplayObject:
		return
	var t := str(m.get("modType"))
	if not t in TYPES:
		return
	var cel = g.customElementLoader
	if m.get("overwrite") and t in ["HimBody", "HimHead"]:
		cel.clearModTypes([t])
		_records = _records.filter(func(r): return r["type"] != t or r["pkg"] == cel.loadingModPackage)
	_records.append({"pkg": cel.loadingModPackage, "type": t, "mod": m})
	_update()


func _toggle(on: bool, e: Dictionary) -> void:
	if on:
		g.modCatalog.apply(e)
		return
	g.modCatalog.remove_entry(e)
	var live := {}
	for lm in g.customElementLoader.instancedModElements:
		live[lm.sourcePackage] = true
	_records = _records.filter(func(r): return live.has(r["pkg"]))
	_update()


func _has(type: String) -> bool:
	return _records.any(func(r): return r["type"] == type)


func _flag(flag: String, types: Array = TYPES) -> bool:
	return _records.any(func(r): return r["type"] in types and r["mod"] != null and is_instance_valid(r["mod"]) and r["mod"].get(flag))


## A record's placed parts by name (the mod's own named children have moved onto him).
func _rec_parts(r: Dictionary) -> Dictionary:
	var out := {}
	for lm in g.customElementLoader.instancedModElements:
		if lm.sourcePackage == r["pkg"] and lm._modType == r["type"] and lm._mod != null and is_instance_valid(lm._mod):
			out[str(lm._mod.flash_name)] = lm._mod
	return out


## The placed parts of these mod types.
func _parts(types: Array = TYPES) -> Array:
	var out: Array = []
	for lm in g.customElementLoader.instancedModElements:
		if lm._modType in types and lm._mod != null and is_instance_valid(lm._mod):
			out.append(lm._mod)
	return out


## Everything from the records: parts on his current pieces and frames, his pieces hidden where the mods say so,
## his own clothes off under clothing mods, the head shown with head mods.
func _update() -> void:
	var him = g.him
	if him == null or head == null:
		return
	_show_hidden()
	_attach_layers()
	var futa: bool = him.currentBodyID == 1
	var body := "futa" if futa else "him"
	_footwear = str(him.currentBody.footwearControl.selectedName) if him.currentBody != null else ""
	var heels := _footwear == "Highheel"
	# body and penis parts follow his rebuilt pieces
	var covered := {}
	for p in _parts(["HimBody", "HimPenis"]):
		var n := str(p.flash_name)
		var path: String = BODY_PARTS.get(n, PENIS_PARTS.get(n, ""))
		var target = _node(path) if path != "" else null
		if target == null:
			continue
		if p._flash_parent != target:
			target.addChild(p)
		covered[n] = target
		p.visible = true
	for p in _parts(["HimBody", "HimPenis", "HimTop", "HimBottoms", "HimFootwear", "HimHead", "HimHair", "HimLoaderArm"]):
		var n := str(p.flash_name)
		if heels and n in ["hisLeftFoot", "hisRightFoot", "hisLeftShoe", "hisRightShoe"] and p is FlashMovieClip and p.has_label("heel"):
			p.gotoAndStop("heel")
		elif p.get("rotationBlending") == null:
			_label(p, body)
	if _flag("bodyOverwrite", ["HimBody", "HimPenis"]):
		_hide_under(covered, futa)
	_clothes()
	_update_head()
	_update_loader_arm(body)
	if _parts(["HimBody"]).any(func(p): return p.flash_name in ["hisLeftCalf", "hisLeftArmUpper", "hisLeftArmLower"]) \
			or _parts(["HimFootwear"]).any(func(p): return p.flash_name == "hisLeftCalfCostume"):
		_reset_layers()
	_set_skin()
	_fills.clear()
	_apply_fills()
	_hands()


## bodyOverwrite: his own drawing under the mod's parts goes (pieces holding other pieces stay).
func _hide_under(covered: Dictionary, futa: bool) -> void:
	var pieces: Array = []
	for path in BODY_PARTS.values() + PENIS_PARTS.values():
		var o = _node(path)
		if o != null:
			pieces.append(o)
	var mine := _parts()
	for n in covered:
		if n in BREASTS and not futa:
			continue
		var target = covered[n]
		for i in target.numChildren:
			var c = target.getChildAt(i)
			if not c.visible or c in mine or c == head or pieces.any(func(piece): return piece == c or (c is FlashSprite and c.contains(piece))):
				continue
			_hide(c)
	if covered.has("hisTorso"):
		var torso = g.him.torsoLayer.torso
		var nipple = torso.getChildAt(1) if torso.numChildren > 1 else null
		if nipple is FlashMovieClip:
			_hide(nipple)


func _hide(c) -> void:
	if c.visible:
		c.visible = false
		_hidden.append(c)


func _show_hidden() -> void:
	for c in _hidden:
		if is_instance_valid(c):
			c.visible = true
	_hidden.clear()


## Clothing mods take his own clothing of that kind off; taken off again, his own comes back.
func _clothes() -> void:
	var him = g.him
	var male = him.bodies[0]
	var want := {}
	if _has("HimTop"):
		want[male.topControl] = ["topBack", "overLayer.torso.costume"]
	if _has("HimBottoms"):
		want[male.bottomsControl] = ["rightLegCostume", "rightLegCostume.calf", "leftLegCostume", "leftLegCostume.calf",
			"midLayer.hips"]
	if _has("HimFootwear"):
		want[him.currentBody.footwearControl] = ["rightLegCostume.calf.foot", "leftLegCostume.calf.foot"]
	for c in _cleared.keys():
		if not want.has(c):
			c.select(c.selection)   # his own back
			_cleared.erase(c)
	for c in want:
		for path in want[c]:
			_label(_node(path), "None")
		_cleared[c] = true
	# hideFutaHeels: no high heels under the mod's feet
	if _flag("hideFutaHeels", ["HimBody", "HimFootwear"]) and _footwear == "Highheel":
		for path in ["leftLegCostume.calf.foot", "rightLegCostume.calf.foot"]:
			_label(_node(path), "None")


## The left forearm, hand (and foot, unless a mod says layerFootUnder) above the mod parts on their pieces.
func _reset_layers() -> void:
	var him = g.him
	var list: Array = [him.leftArmContainer.arm.foreArm, him.leftArmContainer.arm.foreArm.hand]
	if not _flag("layerFootUnder"):
		list.append(him.leftLeg.calf.foot)
	for o in list:
		if o != null and o._flash_parent != null:
			o._flash_parent.setChildIndex(o, o._flash_parent.numChildren - 1)


static func _label(mc, label: String) -> void:
	if mc is FlashMovieClip and mc.has_label(label):
		mc.gotoAndStop(label)


# ---------------------------------------------------------------- colours, skin, hands

## Clothing parts' "rgbFill" take his clothing colour (top, bottoms, shoes); the extra arm's parts made as costume
## take his top's.
func _apply_fills() -> void:
	var him = g.him
	var male = him.bodies[0]
	var sets := [[male.topControl, _parts(["HimTop"]) + _parts(["HimLoaderArm"]).filter(func(p): return _arm_costume(p))],
		[male.bottomsControl, _parts(["HimBottoms"])], [him.currentBody.footwearControl, _parts(["HimFootwear"])]]
	for s in sets:
		var c = s[0]
		var key := _rgb_key(c.rgb1)
		if s[1].is_empty() or _fills.get(c) == key:
			continue
		_fills[c] = key
		_fill(s[1], c.rgb1)


func _arm_costume(p) -> bool:
	for r in _records:
		var m = r["mod"]
		if r["type"] == "HimLoaderArm" and m != null and is_instance_valid(m) and str(m.get("loaderArmAssignment")) == "costume" \
				and _rec_parts(r).get(str(p.flash_name)) == p:
			return true
	return false


## A control's colour ({r, g, b, a} or an AlphaRGBObject) as a string, to see when it changes.
static func _rgb_key(c) -> String:
	return "%s,%s,%s,%s" % [c.get("r"), c.get("g"), c.get("b"), c.get("a")]


static func _fill(parts: Array, c) -> void:
	var ct := FlashColorTransform.new(0, 0, 0, float(c.get("a")), float(c.get("r")), float(c.get("g")), float(c.get("b")))
	for o in parts:
		var f = o.getChildByName("rgbFill") if o is FlashSprite else null
		if f != null and o.visible:
			f.colorTransform = ct


## Parts' "skin" child and the head's own parts on the frame named after his skin.
func _set_skin() -> void:
	var body = g.him.currentBody
	if body == null or body.get("skinNameList") == null:
		return
	var label := str(body.skinNameList[body.currentSkinID])
	_skin = str(g.himSkinType)
	for p in _parts():
		var s = p.getChildByName("skin") if p is FlashSprite else null
		if s is FlashMovieClip:
			_label(s, label)
	var hp = head.headoriginpt
	for o in [hp.himFaceContainer.tpFace, hp.himNoseContainer.tpNose, hp.himEarContainer.tpEar,
			hp.himEyeContainer.upperEyeLid, head.neckoriginpt.tpNeck]:
		if o._flash_parent != null and o._flash_parent.visible:
			_label(o, label)


## His right hand parts: open while he holds her head, closed otherwise; his top's colour on the male body.
func _hands() -> void:
	var hands := _parts(["HimBody", "HimTop"]).filter(func(p): return p.flash_name in ["hisRightArmHand", "hisRightArmHandCostume"])
	if hands.is_empty():
		return
	var him = g.him
	var open: bool = not g.her.passedOut and not g.handsOff and not g.penisOut and g.currentPos.x > g.her.pos and him.handOpen
	var label := ("futa" if him.currentBodyID == 1 else "him") + ("open" if open else "closed")
	for p in hands:
		if p is FlashMovieClip:
			if p.has_label(label):
				p.gotoAndStop(label)
			else:
				p.gotoAndStop(1)
	if him.currentBodyID == 0:
		_fill(hands, him.bodies[0].topControl.rgb1)


# ---------------------------------------------------------------- the head

func _update_head() -> void:
	var on := HEAD_TYPES.any(func(t): return _has(t))
	head.visible = on
	if not on:
		return
	var him = g.him
	head.transform = him.torsoLayer.torso.transform   # placed like his torso (the Loader mod's cloneProps)
	if him.currentBodyID == 1:
		head.scaleX = 1.13
		head.scaleY = 1.13
		head.x += head.x - 191
		head.y += head.y - 15
		head.gotoAndStop(2)
	else:
		head.scaleX = 1.0
		head.scaleY = 1.0
		_label(head, "him")
	# its own parts back, then what the mods replace
	var hp = head.headoriginpt
	var ec = hp.himEyeContainer
	var own := [hp.himFaceContainer.tpFace, hp.himNoseContainer.tpNose, hp.himEarContainer.tpEar,
		hp.himEyebrowContainer.tpLeftBrow, hp.himEyebrowContainer.tpRightBrow, head.neckoriginpt.tpNeck,
		ec.eyeball.deEyeball, ec.hisIris.hisPupil, ec.hisIris.iriscolor, ec.lowerEyeLid.tplowerEyeLid,
		ec.upperEyeLid.tpupperEyeLid]
	for o in own:
		o.visible = true
	for i in ec.numChildren:
		ec.getChildAt(i).visible = true
	for r in _records:
		var m = r["mod"]
		if m == null or not is_instance_valid(m):
			continue
		var have := _rec_parts(r)
		if r["type"] == "HimHead" and m.get("defaultHeadOverwrite"):
			var ht := int(m.get("headType") if m.get("headType") != null else 0)
			if not (him.currentBodyID == 0 and ht == 2) and not (him.currentBodyID == 1 and ht == 1):
				for pair in [["himFace", [hp.himFaceContainer.tpFace]], ["himNose", [hp.himNoseContainer.tpNose]],
						["himEar", [hp.himEarContainer.tpEar]], ["himNeck", [head.neckoriginpt.tpNeck]],
						["himEyebrow", [hp.himEyebrowContainer.tpLeftBrow, hp.himEyebrowContainer.tpRightBrow]],
						["himEye", [ec.eyeball.deEyeball, ec.hisIris.hisPupil, ec.hisIris.iriscolor,
							ec.lowerEyeLid.tplowerEyeLid, ec.upperEyeLid.tpupperEyeLid]]]:
					if have.has(pair[0]):
						for o in pair[1]:
							o.visible = false
		if m.get("defaultEyeOverwrite"):
			if r["type"] == "HimHead":
				for i in ec.numChildren:
					ec.getChildAt(i).visible = false
			elif r["type"] == "HimEye":
				for pair in [["eyeball", [ec.eyeball.deEyeball]], ["hisIris", [ec.hisIris.hisPupil, ec.hisIris.iriscolor]],
						["lowerEyeLid", [ec.lowerEyeLid.tplowerEyeLid]], ["upperEyeLid", [ec.upperEyeLid.tpupperEyeLid]]]:
					if have.has(pair[0]):
						for o in pair[1]:
							o.visible = false
	_head_hsl(true)


## His skin tint on the head (as on his body).
func _head_hsl(force := false) -> void:
	var hsl = g.characterControl.hisSkinHSL
	if not force and is_same(hsl, _hsl):
		return
	_hsl = hsl
	var hp = head.headoriginpt
	var f: Array = [] if is_same(hsl, g.characterControl.blankHSL) else [g.characterControl._hslFilter(hsl)]
	for o in [hp.himFaceContainer, hp.himNoseContainer, hp.himEarContainer, hp.himEyeContainer.upperEyeLid,
			hp.himEyeContainer.lowerEyeLid, hp.himEyebrowContainer, head.neckoriginpt]:
		o.filters = f


## Each tick: brows shut near the end, the head turns towards her, the eyes follow and blink.
func _head_tick() -> void:
	var him = g.him
	var hp = head.headoriginpt
	var ec = hp.himEyeContainer
	var p := int(him.pleasure / (him.ejacPleasure / 0.97) * 10000) / 100.0
	if p >= 97:
		p += him.maxPleasureTimer / 20.0
	var stat := minf(100.0, p)
	_p_adj = maxf(0.0, _p_adj - 0.5)
	var brow := "normal"
	if stat > 80:
		_p_adj = (stat - 80) * 1.25
		brow = "closed"
	var brows: Array = [hp.himEyebrowContainer.tpLeftBrow, hp.himEyebrowContainer.tpRightBrow]
	for b in _parts(["HimHead"]).filter(func(o): return o.flash_name == "himEyebrow"):
		for n in ["tpLeftBrow", "tpRightBrow"]:
			var c = b.getChildByName(n)
			if c != null:
				brows.append(c)
	for b in brows:
		_label(b, brow)
	# the angle at his head between his penis and her nose
	var hd: Vector2 = hp.localToGlobal(Vector2.ZERO)
	var pn: Vector2 = him.penis.localToGlobal(Vector2.ZERO)
	var tg: Vector2 = g.her.head.face.nose.localToGlobal(Vector2.ZERO)
	var a2 := tg.distance_squared_to(pn)
	var b2 := hd.distance_squared_to(pn)
	var c2 := hd.distance_squared_to(tg)
	var rot := 0.0
	if b2 > 0 and c2 > 0:
		rot = rad_to_deg(acos(clampf((b2 + c2 - a2) / (2 * sqrt(b2) * sqrt(c2)), -1, 1))) - 80
	if rot < -135:
		rot = round(rot + 135)
	if rot > 135:
		rot = round(rot - 135)
	rot = clampf(rot, -38, 10)
	ec.hisIris.rotation = maxf(-32, rot - 5)
	if not g.gamePaused:
		var lids: Array = []
		for c in [ec.upperEyeLid, ec.lowerEyeLid]:
			for i in c.numChildren:
				if c.getChildAt(i) is FlashMovieClip:
					lids.append(c.getChildAt(i))
		var now := Time.get_ticks_msec()
		if _blink_until >= 0 and now >= _blink_until:
			_blink_until = -1
			_blink_tension = 0
		if stat > 88:
			for l in lids:
				_label(l, "blink")
		elif _blink_tension < 15000 and _blink_until < 0:
			var frame := int(round(-0.583 * rot + 7.83))
			for l in lids:
				l.gotoAndStop(frame)
			_blink_tension += randi() % 100
		elif _blink_until < 0:
			_blink_until = now + 250
			for l in lids:
				_label(l, "blink")
	hp.rotation = rot + _p_adj
	head.hairbackorigin.rotation = rot + _p_adj


# ---------------------------------------------------------------- the Loader's extra arm

func _update_loader_arm(body: String) -> void:
	if _la.is_empty():
		return
	var own := [_la[0].getChildByName("upperarm"), _la[1].getChildByName("forearm"), _la[2].getChildByName("hand")]
	for o in own:
		if o != null:
			o.visible = true
			_label(o, body)
	for r in _records:
		var m = r["mod"]
		if r["type"] != "HimLoaderArm" or m == null or not is_instance_valid(m) or not m.get("armOverwrite"):
			continue
		var have := _rec_parts(r)
		for i in 3:
			var part = have.get(["lupperarm", "lforearm", "lhand"][i])
			if part is FlashSprite and part.numChildren > 0 and own[i] != null:
				own[i].visible = false


# ---------------------------------------------------------------- every tick

## ExtraModHim's layers take his pieces' transforms (the costume arms, the layer under his hips).
func _follow_layers() -> void:
	var him = g.him
	_bottoms_torso.transform = him.midLayer.hips.transform
	if _bottoms_torso._flash_parent != null and _bottoms_torso._flash_parent.getChildIndex(_bottoms_torso) != 0:
		_bottoms_torso._flash_parent.setChildIndex(_bottoms_torso, 0)
	var a = him.armContainer
	_r_arm.transform = a.transform
	_r_arm.arm.transform = a.arm.transform
	_r_arm.arm.upperArm.transform = a.arm.upperArm.transform
	_r_arm.arm.foreArm.transform = a.arm.lowerArm.transform
	_r_arm.arm.hand.transform = a.arm.hand.transform
	_l_arm.visible = him.currentLeftArmPosition == 1
	if _l_arm.visible:
		var l = him.leftArmContainer
		_l_arm.transform = l.transform
		_l_arm.arm.transform = l.arm.transform
		_l_arm.arm.foreArm.transform = l.arm.foreArm.transform
		_l_arm.arm.foreArm.hand.transform = l.arm.foreArm.hand.transform


## Futa breasts: the mod's breast parts (and breast clothing) on his breast size's frame, following his breasts.
func _breasts() -> void:
	var him = g.him
	var size := int(him.bodies[1].breastSize) + 2
	for p in _parts(["HimBody", "HimTop"]):
		if not p.flash_name in ["hisRightBreast", "hisLeftBreast", "hisRightBreastCostume", "hisLeftBreastCostume"]:
			continue
		for i in p.numChildren:
			var c = p.getChildAt(i)
			if c is FlashMovieClip:
				c.gotoAndStop(size)
		if p.flash_name in BREASTS:
			var own = him.torsoLayer.rightBreastContainer.get("rightBreast") if p.flash_name == "hisRightBreast" \
				else him.torsoLayer.leftBreastContainer.get("leftBreast")
			if own is FlashDisplayObject:
				p.transform = own.transform


func _tick() -> void:
	if head == null:
		return
	var la = Extensions.get_extension("loaderarm")
	if la != null and la.enabled and la.arm != null and la.hand != _la[2]:   # the extra arm was switched on later
		la.set_art(_la[0], _la[1], _la[2])
	if _records.is_empty():
		return
	_follow_layers()
	var him = g.him
	if him.currentBodyID == 1:
		_breasts()
	if str(g.himSkinType) != _skin or (him.currentBody != null and str(him.currentBody.footwearControl.selectedName) != _footwear):
		_update()
		return
	_apply_fills()
	_hands()
	if head.visible:
		_head_hsl()
		_head_tick()


func _body_changed() -> void:
	if head == null:
		return
	_attach_layers()
	_register()   # his pieces are new
	if not _records.is_empty():
		_update()


func _reset() -> void:
	_show_hidden()
	_records.clear()
	for c in _cleared.keys():
		c.select(c.selection)
	_cleared.clear()
	_fills.clear()
	_skin = ""
	if head != null:
		head.visible = false
		_update_loader_arm("futa" if g.him.currentBodyID == 1 else "him")
