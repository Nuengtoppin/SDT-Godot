extends SDTExtension
## Built-in reimplementation of the Loader mod TemplateExtension (sby, v9; formerly moremodtypes): the extra mod
## types of sby's "alternate loader template", so clothing mods made with it load:
##   CostumeArmwear, CostumeOverTop, CostumeLegwear, CostumeLegwearB, CostumePanties, CostumeCuffs,
##   CostumeAnkleCuffs, the hair layer dynamicHairOverExtended (over the other hair, under his arm) and more parts
##   for CostumeBra (chest, back strap, shoulder strap).
## Plus its fixes: armwear gloves follow her hands (grip / free) and take the armwear colour on the hands too; the
## over-top layer takes her breast size and moves with her right breast; dialogue mods with line settings. Written
## from its behaviour (the game already has the parts these types go on).
##
## Port: over-tops (a shibari top) have a slot of their own, "Over top" in the new menu's Clothes, with
## their own colour (saved in the character code), so they go over her top instead of replacing it (the original
## used the top's slot and colour).

## Mod type -> {part name in the mod -> path from her} (paths are tried when the extension is switched on)
const TYPES := {
	"CostumeCuffs": {"leftcuff": "leftArmContainer.upperArmCostume.foreArmCostume.cuff", "behindback": "torso.cuffs",
		"rightcuff": "rightForeArmContainer.upperArmCostume.foreArmCostume.cuff"},
	"CostumeAnkleCuffs": {"leftanklecuff": "leftLegContainer.leg.cuffs", "rightanklecuff": "torso.rightCalfContainer.cuffs"},
	"CostumeLegwear": {"rightThigh": "torso.rightThighStocking.stocking", "rightCalf": "torso.rightCalfContainer.calfStocking",
		"leftThigh": "leftLegContainer.leg.stocking", "leftCalf": "leftLegContainer.leg.calfStocking",
		"backside": "torsoBackCostume.backsideCostume.stocking",
		"back": "torso.rightThighStocking.stocking2.hipLayer.backStocking",
		"chest": "torso.rightThighStocking.stocking2.hipLayer.chestStocking",
		"backOver": "torso.rightThighStocking.stocking.hipOverLayer.backStocking",
		"chestOver": "torso.rightThighStocking.stocking.hipOverLayer.chestStocking"},
	"CostumeLegwearB": {"rightThighB": "torso.rightThighStockingB.stocking", "rightCalfB": "torso.rightCalfContainer.calfStockingB",
		"leftThighB": "leftLegContainer.leg.stockingB", "leftCalfB": "leftLegContainer.leg.calfStockingB",
		"backsideB": "torsoBackCostume.backsideCostume.stockingB",
		"backB": "torso.rightThighStockingB.stocking2.hipLayer.backStocking",
		"chestB": "torso.rightThighStockingB.stocking2.hipLayer.chestStocking",
		"backOverB": "torso.rightThighStockingB.stocking.hipOverLayer.backStocking",
		"chestOverB": "torso.rightThighStockingB.stocking.hipOverLayer.chestStocking"},
	"CostumeArmwear": {"leftglove": "torso.leftGlove", "rightglove": "torso.rightGlove",
		"rightlowerarmwear": "rightForeArmContainer.upperArmCostume.foreArmCostume.glove",
		"leftlowerarmwear": "leftArmContainer.upperArmCostume.foreArmCostume.glove",
		"righthandglove": "rightForeArmContainer.upperArmCostume.foreArmCostume.handCostume",
		"lefthandglove": "leftArmContainer.upperArmCostume.foreArmCostume.handCostume",
		"rightupperarmwear": "rightArmContainer.upperArmCostume.glove",
		"leftupperarmwear": "leftArmContainer.upperArmCostume.glove", "handoverglove": "leftHandOver.hand.glove"},
	"CostumePanties": {"rightThigh": "torso.rightThighCostume.panties", "leftThigh": "leftLegContainer.leg.leftThighCostume.panties",
		"back": "torso.backUnderCostume.panties", "chest": "torso.chestUnderCostume.panties",
		"backside": "torsoBackCostume.backsideCostume.panties"},
	"CostumeBra": {"rightBreast": "torso.breastCostume.bra", "back": "torso.braStrap", "under": "torso.shoulderStrap",
		"chest": "torso.upperChestCostume.bra", "leftBreast": "torsoBackCostume.breastCostume.bra"},
}
## Mod type -> CharacterControl element helper (its menu list, colours)
const CONTROLS := {"CostumeCuffs": "cuffsControl", "CostumeAnkleCuffs": "ankleCuffsControl",
	"CostumeLegwear": "legwearControl", "CostumeLegwearB": "legwearBControl", "CostumeArmwear": "armwearControl",
	"CostumePanties": "pantiesControl", "CostumeBra": "braControl"}
## Over-top layer: part name -> the top part it sits over (a new layer above it, same place)
const OVER_TOP := {"rightBreast": "torso.topContainer.breastTop", "chest": "torso.topContainer.chestTop",
	"back": "torso.topContainer.backTop", "strap": "torso.topContainer.topStrap",
	"leftBreast": "torsoBackCostume.breastCostume.top", "under": "torsoUnderCostume.top",
	"rightArm": "rightArmContainer.upperArmCostume.top", "leftArm": "leftArmContainer.upperArmCostume.top"}
const HAIR_OVER_EXTENDED := "dynamicHairOverExtended"

var _saved: Dictionary = {}     # mod type -> the helper it replaced (CostumeBra), restored when switched off
## The over-top slot: no built-in options ("None"), the over-top mods from Mods/Clothing after it
var over_top: CharacterElementHelper = null
var _layers: Dictionary = {}    # over-top part -> its layer
var hair_over_extended: FlashSprite = null


func _init() -> void:
	id = "templateextension"
	title = "TemplateExtension"
	description = "The extra clothing mod types of sby's alternate loader template: armwear, over-tops, legwear A/B, panties, wrist and ankle cuffs, an extra hair layer, more bra parts."
	default_enabled = true


func _enable() -> void:
	var cel = g.customElementLoader
	var cc = g.characterControl
	for t in TYPES:
		var parts := {}
		for p in TYPES[t]:
			var o = _node(TYPES[t][p])
			if o != null:
				parts[p] = o
			else:
				push_warning("TemplateExtension: no %s for %s.%s" % [TYPES[t][p], t, p])
		if cel.modTargetHelpers.has(t):
			_saved[t] = cel.modTargetHelpers[t]
		cel.modTargetHelpers[t] = CustomElementHelper.new(parts, cc.get(CONTROLS[t]))
	_make_over_top()
	_make_hair_layer()
	hook_after(&"CustomElementLoader.addStaticModElement", func(c): _mod_added(c.args[0]))
	hook_after(&"Her.updateHandJobMode", func(_c): update_gloves())
	hook_after(&"CharacterControl.setArmwearFill", func(c): _armwear_fill(c.args[0], c.args[1]))
	hook_after(&"CharacterControl.setBreastCostumeSize", func(_c): _over_top_size())
	charcode_field("overtop", _over_top_code, func(v, _l): _load_over_top_code(v), func(_l): _over_top_default())
	for spec in MenuSchema.element("Over top", "Worn over her top, e.g. shibari (over-top mods from Mods/Clothing).",
			func(): return over_top, true):
		menu_control("clothes", "Upper body", spec)
	hook_after(&"Her.updateBreathingScaledElements", func(_c): _follow_chest())
	hook_after(&"CharacterControl.applyHairHSL", func(_c): _hair_filters())
	hook_after(&"CharacterControl.removeHairHSL", func(_c): _hair_filters())
	hook_before(&"DialogueLibrary.loadDialogueMod", _dialogue_mod)
	_hair_filters()


func _disable() -> void:
	var cel = g.customElementLoader
	if cel == null:
		return
	for t in ["CostumeOverTop", "costumeovertop", HAIR_OVER_EXTENDED] + TYPES.keys():
		cel.modTargetHelpers.erase(t)
	for t in _saved:
		cel.modTargetHelpers[t] = _saved[t]
	_saved.clear()
	var rb = g.her.rightBreastController if g.her != null else null
	for p in _layers:
		var l: FlashSprite = _layers[p]
		if rb != null:
			rb._costumeLayers.erase(l)
		if l._flash_parent != null:
			l._flash_parent.removeChild(l)
	_layers.clear()
	if hair_over_extended != null and hair_over_extended._flash_parent != null:
		hair_over_extended._flash_parent.removeChild(hair_over_extended)
	hair_over_extended = null


## A display object by a dotted path from her ("torso.cuffs"), null if a part is missing.
func _node(path: String):
	var o = g.her
	for part in path.split("."):
		o = o.get(part) if o != null else null
		if not o is Object:
			return null
	return o


func _make_over_top() -> void:
	var parts := {}
	for p in OVER_TOP:
		var under = _node(OVER_TOP[p])
		if under == null:
			continue
		var l := FlashSprite.new()
		l.flash_name = p + "OverTop"
		under._flash_parent.addChild(l)   # above the top's own part
		l.transform = under.transform
		_layers[p] = l
		parts[p] = l
	if _layers.has("rightBreast"):
		g.her.rightBreastController._costumeLayers.append(_layers["rightBreast"])   # moves with her breast
	over_top = CharacterElementHelper.new(["None"], func(_i): pass, _over_top_fill)
	over_top.haveRGBFill = true
	over_top.associatedModType = "CostumeOverTop"
	over_top.rgb1 = {"r": 0, "g": 0, "b": 0, "a": 1}
	var helper := CustomElementHelper.new(parts, over_top)
	g.customElementLoader.modTargetHelpers["CostumeOverTop"] = helper
	g.customElementLoader.modTargetHelpers["costumeovertop"] = helper   # some mods write "CostumeOvertop"


## A hair layer over the other hair (and strands), under his arm.
func _make_hair_layer() -> void:
	hair_over_extended = FlashSprite.new()
	hair_over_extended.flash_name = HAIR_OVER_EXTENDED
	var front: FlashSprite = g.frontLayer
	front.addChildAt(hair_over_extended, maxi(0, front.getChildIndex(g.himOverLayer) - 1))
	g.customElementLoader.modTargetHelpers[HAIR_OVER_EXTENDED] = CustomElementHelper.new({"target": hair_over_extended})


func _hair_filters() -> void:
	if hair_over_extended != null:
		hair_over_extended.filters = g.hairBetweenLayer.filters


func _mod_added(m) -> void:
	var t: String = str(m.get("modType")) if m != null else ""
	if t.to_lower() == "costumeovertop":
		g.characterControl.setBreastCostumeSize()
	elif t == "CostumePanties":
		# her chest part of the panties shows from the start (the game left it on the wrong frame)
		var p = _node("torso.chestUnderCostume.panties")
		var names: Array = g.characterControl.pantiesNameList
		if p is FlashMovieClip and names.size() > 1:
			p.gotoAndStop(names[1])
			p.gotoAndStop(names[0])
	elif t == "CostumeArmwear":
		update_gloves()


# ---------------------------------------------------------------- armwear

## Armwear gloves: closed around his penis or free, as her hands are; upper arm pieces behind her back or free.
func update_gloves() -> void:
	var her = g.her
	for lm in g.customElementLoader.instancedModElements:
		if lm._modType != "CostumeArmwear" or lm._mod == null or not is_instance_valid(lm._mod):
			continue
		var part = lm._mod
		match str(part.flash_name):
			"righthandglove":
				_set_label(part, "Grip" if g.rightHandJobMode else "Free")
				_align_grip(part)
			"lefthandglove":
				_set_label(part, "Grip" if g.leftHandJobMode else "Free")
			"rightupperarmwear":
				_set_label(part, "Free" if her.isRightArmFree() else "back")
			"leftupperarmwear":
				_set_label(part, "Free" if her.isLeftArmFree() else "back")


## Shows `label` if the piece has it, else "None" if it has that; else leaves it (the mod's version did the same:
## its failing gotoAndStop was caught).
static func _set_label(part, label: String) -> void:
	if not part is FlashMovieClip:
		return
	if part.has_label(label):
		part.gotoAndStop(label)
	elif part.has_label("None"):
		part.gotoAndStop("None")


## The glove's "grip" piece (her fingers around him) where her hand's grip is.
func _align_grip(part) -> void:
	var target = null
	for path in ["rightForeArmContainer.upperArm.foreArm.hand.grip",
			"rightForeArmContainer.upperArmCostume.foreArmCostume.handCostume.glove.grip",
			"rightForeArmContainer.upperArm.foreArm.hand.tan.grip"]:
		target = _node(path)
		if target != null:
			break
	if target == null and _node("leftHandOver.hand.grip") != null:
		target = _node("leftHandOver.hand")
	if target == null or not part is FlashSprite:
		return
	for i in part.numChildren:
		var c = part.getChildAt(i)
		if c.flash_name == "grip":
			c.scaleY = target.scaleY
			c.x = target.x
			c.y = target.y
			c.rotation_degrees = target.rotation_degrees


## The armwear colour on the hand pieces too (mod gloves sit directly in her hand costume).
func _armwear_fill(c, n: String) -> void:
	update_gloves()
	var ct := FlashColorTransform.new(1, 1, 1, c.a, c.r, c.g, c.b)
	for path in ["rightForeArmContainer.upperArmCostume.foreArmCostume.handCostume",
			"leftArmContainer.upperArmCostume.foreArmCostume.handCostume"]:
		CharacterControl.tryToSetFill(_node(path), n, ct)


# ---------------------------------------------------------------- over-top layer

func _over_top_size() -> void:
	var cc = g.characterControl
	for p in ["rightBreast", "chest", "leftBreast"]:
		if _layers.has(p):
			cc.setChildrenFrame(_layers[p], 2 + cc.breastSize)


func _over_top_code() -> String:
	var c = over_top.rgb1
	return "%d,%d,%d,%s" % [c["r"], c["g"], c["b"], c["a"]]


func _load_over_top_code(v: String) -> void:
	var p := v.split(",")
	if p.size() >= 4:
		over_top.setFill({"r": int(p[0]), "g": int(p[1]), "b": int(p[2]), "a": float(p[3])}, "rgbFill")


func _over_top_default() -> void:
	over_top.setFill({"r": 0, "g": 0, "b": 0, "a": 1}, "rgbFill")


func _over_top_fill(c, n: String) -> void:
	var see_through := FlashColorTransform.new(1, 1, 1, c.a, c.r, c.g, c.b)
	var opaque := FlashColorTransform.new(1, 1, 1, 1, c.r, c.g, c.b)
	for p in _layers:
		CharacterControl.tryToSetFill(_layers[p], n, opaque if p in ["rightBreast", "chest", "back", "strap"] else see_through)
	var outline := FlashColorTransform.new(1, 1, 1, 1, c.r * 0.5, c.g * 0.5, c.b * 0.5)
	for p in ["rightBreast", "leftBreast"]:
		if _layers.has(p):
			CharacterControl.tryToSetFill(_layers[p], "outline", outline)


## The chest layer follows her chest costume (it is scaled with her breathing).
func _follow_chest() -> void:
	var chest = _node("torso.chestUnderCostume")
	if _layers.has("chest") and chest != null:
		_layers["chest"].transform = chest.transform


# ---------------------------------------------------------------- dialogue mods

## Dialogue mods made with the alternate template can give a line settings (a JSON object, like a dialogue file's).
func _dialogue_mod(c: Hooks.Call) -> void:
	var m = c.args[0]
	var s = m.get("settings") if m is Object else (m.get("settings") if m is Dictionary else null)
	if s == null or str(s) == "":
		return
	var settings = JSON.parse_string(str(s))
	if not settings is Dictionary:
		return
	c.cancel()
	var lib = c.obj
	var t := str(m.get("lineType"))
	var line := str(m.get("dialogueLine"))
	if not lib.customLibrary.has(t):
		lib.customLibrary[t] = []
	lib.customLibrary[t].append(DialogueLine.new(line, settings))
	if m.get("audio") != null:
		var a := AudioMod.new(m.get("audio"), float(m.get("volume")))
		lib.customAudio[line] = a
		if t == "cough":
			g.soundControl.loadAudioMod("cough", a)
