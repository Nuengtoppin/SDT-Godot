extends SDTExtension
## Built-in reimplementation of the Loader mod dynamicHairExtender (stuntcock, v5.91; the fork ExtraMod mods bundle,
## extraModDHE 0.1): extra settings for dynamic hair strands, so mods that use them (wings, cables, machines anchored
## to her body) hang where their authors put them. Written from its behaviour.
##
## A dynamic hair item with any of these settings is built by this extension instead of the game (items with the
## game's own damping / topDamping / gravityAngle stay the game's):
##   anchorContainer   path from the game object (e.g. "her.torso.back"): the strand hangs from it, its first
##                     segment's position read in that container's coordinates (default: her head, as the game)
##   visualParent      path: the container the strand is drawn in (placed through global coordinates)
##   visualChildIndex, segmentVisualIndex, maskPath, autoPlay, reverseSegmentOrder, useSkinPalette (per segment),
##   modTypeReplacer   the item counts as that mod type (wings that go on and off with a top)
##   anchored, rotationBlending, linkWeights, simCyclesPerUpdate, maxCyclesPerUpdate, slavedUpdates, doNotSimulate,
##   sharedLinkInfluences, proximal/distalElasticityFactors, allowElongations, allowCompressions, blendingExclusions,
##   relativeRotationTargets / Multipliers, minRotations / maxRotations, anchorSource, hideAnchor, isotropicScaling:
##                     DHE's physics (dhe_rope.gd)
##   Segments named SHARED_<x> share their link with other strands' segments of the same name.
##   rgbElement        a CharacterControl element helper: the strand's rgbFill / rgbFill2 parts take its colours
##   floorAtKneeLevel, floorKneeOffset: the strand stops at the floor by her knees
## Not supported: monitorTension, orientationSource (DHE stores it but does not use it), custom objects of other
## Loader mods (loaderObject).

const DheRope := preload("res://src/ext/dynamichair/dhe_rope.gd")
## Any of these on a dynamic hair item: this extension builds it.
const FIELDS := ["anchorContainer", "visualParent", "visualChildIndex", "segmentVisualIndex", "maskPath",
	"modTypeReplacer", "anchored", "rotationBlending", "linkWeights", "simCyclesPerUpdate", "maxCyclesPerUpdate",
	"slavedUpdates", "doNotSimulate", "sharedLinkInfluences", "proximalElasticityFactors", "distalElasticityFactors",
	"allowElongations", "allowCompressions", "blendingExclusions", "relativeRotationTargets",
	"relativeRotationMultipliers", "minRotations", "maxRotations", "anchorSource", "useSkinPalette",
	"reverseSegmentOrder", "autoPlay", "isotropicScaling", "rgbElement", "floorAtKneeLevel"]

var shared_links := {}   # SHARED_<x> segment name -> [link, the strand that owns it]
var shared_ropes := {}   # strand graphic name -> strand (one that owns a shared link; maskPath can name it)
var ropes: Array = []    # the strands built here, while they live


func _init() -> void:
	id = "dynamichair"
	title = "Dynamic Hair Extender"
	description = "dynamicHairExtender (stuntcock): dynamic hair strands that hang from any part of her, sit in any layer and keep their shape (stiffness, rotation limits, shared links), for mods made with it (many ExtraMod mods: wings, cables)."
	default_enabled = true


func _enable() -> void:
	hook_before(&"CustomElementLoader.addDynamicHairMod", _add)
	hook_after(&"CharacterElementHelper.setFill", func(c): _fill(c.obj, c.args[0], c.args[1]))
	hook_before(&"IKController.newTarget", func(c): _her_target(c.obj, c.args[0], c.args[1]))
	hook_after(&"CharacterControl.setSkin", func(h):
		for r in ropes:
			r.set_skin(h.args[0]))


func _disable() -> void:
	shared_links.clear()
	shared_ropes.clear()


func _add(h) -> void:
	var m = h.args[0]
	if m == null:
		return
	for k in ["damping", "topDamping", "gravityAngle"]:   # DHE leaves the game's own settings to the game
		var v = m.get(k)
		if v is float or v is int:
			return
	if m.get("targetElement") == null or not FIELDS.any(func(k): return m.get(k) != null):
		return
	h.cancel()
	_build(m)


## DHE's addDynamicHairMod: the strand in its target (or visual parent), hanging from its anchor container.
func _build(m) -> void:
	var cel = g.customElementLoader
	if m.get("modTypeReplacer") != null:
		m.set("modType", str(m.modTypeReplacer))
	var pkg = cel.loadingModPackage
	if ModCatalog.is_leash(m) and pkg != null:
		pkg.set_meta(&"leash", true)
	if ModCatalog.is_leash(m) or (pkg != null and pkg.has_meta(&"leash")):
		m.set("modType", ModTypes.LEASH)
	var helper = cel.modTargetHelpers.get(str(m.targetElement))
	if helper == null:
		push_warning("dynamicHairExtender: no target %s" % m.targetElement)
		return
	var layer = helper.targetDictionary["target"]
	var mod_type := str(m.get("modType"))
	if DheRope._truthy(m.get("overwrite")):
		shared_links.clear()
		shared_ropes.clear()
		match mod_type:
			ModTypes.DYNAMIC_HAIR:
				cel.clearModTypes([ModTypes.DYNAMIC_HAIR])
				cel.clearModTypes([ModTypes.HAIR_COSTUME])
			_:
				cel.clearModTypes([mod_type])
	var container = null
	if m.get("anchorContainer") != null:
		container = find_path(g, str(m.anchorContainer))
		if container == null:
			push_warning("dynamicHairExtender: anchorContainer '%s' was not recognized" % m.anchorContainer)
	if m.get("visualParent") != null:
		var vp = find_path(g, str(m.visualParent))
		if vp == null:
			push_warning("dynamicHairExtender: visualParent '%s' was not recognized" % m.visualParent)
		else:
			layer = vp
	# a leash's end in his left hand: his arm is in front of hers, the leash must not cross over her forearm
	if m.get("modType") == ModTypes.LEASH and str(m.get("visualParent")).begins_with("him.leftArmContainer"):
		layer = g.her.rightArmContainer.parent
		m.set("visualChildIndex", layer.getChildIndex(g.her.rightArmContainer))
	var rope = DheRope.new(self, m, layer, container, 0.0)
	var tog = m.get("toggleable")
	if tog != null and not DheRope._truthy(tog):
		rope.makeUnToggleable()
	rope.setup(m)
	ropes.append(rope)
	var lm := LoadedMod.new(cel.loadingModPackage, cel._settings(m), rope)
	cel.instancedModElements.append(lm)
	if cel.loadingModPackage != null:
		cel.loadingModPackage.addElement(lm)


## The leash mods (Clothes > Head and neck > Leash).
func leashes() -> Array:
	return g.modCatalog.picker_entries.get(ModCatalog.LEASH_LIST, []) if g.modCatalog else []


## Her leash now (empty: none).
func worn_leash() -> Dictionary:
	for e in leashes():
		if g.modCatalog.is_applied(e):
			return e
	return {}


## A leash with its end in his left hand (the mods' names say which: "...LeftLong", "...DangleLong").
static func _in_left_hand(e: Dictionary) -> bool:
	return "Left" in str(e["title"])


func _put_on_leash(e: Dictionary) -> void:
	var worn := worn_leash()
	if not worn.is_empty():
		g.modCatalog.remove_entry(worn)
	if not e.is_empty():
		g.modCatalog.apply(e)


## The Leash picker: index 0 is None. His left arm follows a leash that ends in his hand or stops holding one.
func pick_leash(i: int) -> void:
	var e: Dictionary = leashes()[i - 1] if i > 0 else {}
	_put_on_leash(e)
	if not e.is_empty():
		if _in_left_hand(e):
			g.him.setLeftArmPosition(Him.LEFT_ARM_LEASH)
		elif g.him.currentLeftArmPosition == Him.LEFT_ARM_LEASH:
			g.him.setLeftArmPosition(1)
	g.saveData.saveCharData()


## His left arm changed in the menu: her leash goes to the same leash held in his hand, or dangling. Not from his
## arm's setter: a character code sets the arm and her mods on its own, in its own order.
func left_arm_changed() -> void:
	var e := worn_leash()
	var hold: bool = g.him.currentLeftArmPosition == Him.LEFT_ARM_LEASH
	if not e.is_empty() and hold != _in_left_hand(e):
		var title := str(e["title"])
		var other: String = title.replace("Dangle", "Left") if hold else title.replace("Left", "Dangle")
		for l in leashes():
			if l["title"] == other and l != e:
				_put_on_leash(l)
				break
	g.saveData.saveCharData()


## An element helper's colour changed: the strands that follow it (rgbElement) change with it.
func _fill(helper, c, fill_name: String) -> void:
	for r in ropes:
		if r.rgbHelper == helper:
			r.set_fill(c, fill_name)


## Her body's target moved: the floor by her knees moves with it (floorAtKneeLevel).
func _her_target(ik, p: Vector2, space) -> void:
	if g.her != null and ik == g.her.torsoIK:
		for r in ropes:
			r.set_floor(p, space)


## DHE's findObjectByPath: each step a child of that name (the topmost), else a property.
func find_path(from, path: String):
	var o = from
	for part in path.split("."):
		if o == null:
			return null
		var found = null
		if o is FlashSprite:
			for i in range(o.numChildren - 1, -1, -1):
				if str(o.getChildAt(i).flash_name) == part:
					found = o.getChildAt(i)
					break
		if found == null and o is Object:
			found = o.get(part)
		o = found
	return o if o is FlashDisplayObject else null


## A strand went (its mod was taken off): its shared links and its name are free again.
func forget(rope) -> void:
	ropes.erase(rope)
	for n in shared_links.keys():
		if shared_links[n][1] == rope:
			shared_links.erase(n)
	for n in shared_ropes.keys():
		if shared_ropes[n] == rope:
			shared_ropes.erase(n)
