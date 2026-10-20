extends SDTExtension
## Built-in reimplementation of the Loader mod ExtraModHim Core (SClover13, v1.12): mod types for him, for mods made
## with the ExtraModHim template. Needs TemplateExtension. Written from its behaviour.
##
## So far: HimBody (his torso, thighs, calves, feet, arms, hands, breasts) and HimPenis (penis, its wet layer,
## balls).
##   - Parts have a frame per body: "him" and "futa" (and "heel" for the feet with high heels on).
##   - A part's "skin" child shows the frame named after his skin ("Light", "Dark", ...).
##   - bodyOverwrite: his own pieces under the mod's parts are hidden.
##   - His body is rebuilt when it changes (male / futa): the mod's parts move onto the new pieces.
## Not yet: HimHead / HimHair / HimEye (ExtraModHim's own head art), HimTop / HimBottoms / HimFootwear, and
## HimLoaderArm (the Loader's extra arm is not in the port).

## Part name -> path from him
const BODY_PARTS := {"hisTorso": "torsoLayer.torso", "hisRightThigh": "rightLeg", "hisLeftThigh": "leftLeg",
	"hisRightCalf": "rightLeg.calf", "hisLeftCalf": "leftLeg.calf", "hisRightFoot": "rightLeg.calf.foot",
	"hisLeftFoot": "leftLeg.calf.foot", "hisRightArmUpper": "armContainer.arm.upperArm",
	"hisRightArmLower": "armContainer.arm.lowerArm", "hisRightArmHand": "armContainer.arm.hand",
	"hisLeftArmUpper": "leftArmContainer.arm", "hisLeftArmLower": "leftArmContainer.arm.foreArm",
	"hisLeftArmHand": "leftArmContainer.arm.foreArm.hand", "hisRightBreast": "torsoLayer.rightBreastContainer",
	"hisLeftBreast": "torsoLayer.leftBreastContainer"}
const PENIS_PARTS := {"hisPenisMod": "penis", "penisWetMod": "penis.wet", "ballsMod": "balls"}
const BREASTS := ["hisRightBreast", "hisLeftBreast"]

## HimBody / HimPenis mods placed: {"pkg", "overwrite": bodyOverwrite}
var _records: Array = []
var _hidden: Array = []       # his own pieces hidden under mod parts
var _skin := ""


func _init() -> void:
	id = "extramodhim"
	title = "ExtraModHim"
	description = "ExtraModHim Core (SClover13): mod types for his body and penis (more to come), for mods made with the ExtraModHim template. Needs TemplateExtension."
	default_enabled = true


func _enable() -> void:
	_register()
	hook_after(&"CustomElementLoader.addStaticModElement", func(h): _placed(h.args[0]))
	hook_after(&"CustomElementLoader.clearInstancedMods", func(_h): _reset())
	hook_after(&"Him.setBody", func(_h): _body_changed())
	on_late_tick(_tick)


func _disable() -> void:
	var cel = g.customElementLoader
	if cel != null:
		cel.clearModTypes(["HimBody", "HimPenis"])
		cel.modTargetHelpers.erase("HimBody")
		cel.modTargetHelpers.erase("HimPenis")
	_reset()


## His pieces by path ("armContainer.arm.hand"); they change with his body, so they are looked up again then.
func _node(path: String):
	var o = g.him
	for part in path.split("."):
		o = o.get(part) if o != null else null
		if not o is Object:
			return null
	return o


func _register() -> void:
	for t in [["HimBody", BODY_PARTS], ["HimPenis", PENIS_PARTS]]:
		var d := {}
		for p in t[1]:
			var o = _node(t[1][p])
			if o != null:
				d[p] = o
		g.customElementLoader.modTargetHelpers[t[0]] = CustomElementHelper.new(d)


func _parts() -> Array:
	var out: Array = []
	for lm in g.customElementLoader.instancedModElements:
		if (lm._modType == "HimBody" or lm._modType == "HimPenis") and lm._mod != null and is_instance_valid(lm._mod):
			out.append(lm._mod)
	return out


func _placed(m) -> void:
	if m == null or not m is FlashDisplayObject:
		return
	var t := str(m.get("modType"))
	if t != "HimBody" and t != "HimPenis":
		return
	if m.get("overwrite"):
		g.customElementLoader.clearModTypes([t])
		_records = _records.filter(func(r): return r["pkg"] == g.customElementLoader.loadingModPackage)
	_records.append({"pkg": g.customElementLoader.loadingModPackage, "overwrite": bool(m.get("bodyOverwrite"))})
	_update()


## Mod parts on his current pieces, on the frame of his body, his own pieces hidden where the mods say so.
func _update() -> void:
	var him = g.him
	if him == null:
		return
	_show_hidden()
	var futa: bool = him.currentBodyID == 1
	var heels := false
	var fw = him.currentBody.get("footwearControl") if him.currentBody != null else null
	if fw != null:
		heels = str(fw.selectedName) == "Highheel"
	var overwrite := _records.any(func(r): return r["overwrite"])
	var covered := {}
	for p in _parts():
		var n := str(p.flash_name)
		var path: String = BODY_PARTS.get(n, PENIS_PARTS.get(n, ""))
		var target = _node(path) if path != "" else null
		if target == null:
			continue
		if p._flash_parent != target:   # his body was rebuilt: onto the new piece
			target.addChild(p)
		covered[n] = target
		if heels and n in ["hisLeftFoot", "hisRightFoot"] and p.has_label("heel"):
			p.gotoAndStop("heel")
		elif p is FlashMovieClip:
			_label(p, "futa" if futa else "him")
		p.visible = true
	if overwrite:
		# his pieces that hold other pieces (his upper arm holds his forearm) stay; their own drawing goes
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
				if not c.visible or c in mine or pieces.any(func(piece): return piece == c or (c is FlashSprite and c.contains(piece))):
					continue
				c.visible = false
				_hidden.append(c)
		if covered.has("hisTorso"):
			var nipple = him.torsoLayer.torso.getChildAt(1) if him.torsoLayer.torso.numChildren > 1 else null
			if nipple is FlashMovieClip and nipple.visible:
				nipple.visible = false
				_hidden.append(nipple)
	_set_skin()


static func _label(mc, label: String) -> void:
	if mc is FlashMovieClip and mc.has_label(label):
		mc.gotoAndStop(label)


func _show_hidden() -> void:
	for c in _hidden:
		if is_instance_valid(c):
			c.visible = true
	_hidden.clear()


## Parts' "skin" child on the frame named after his skin.
func _set_skin() -> void:
	var him = g.him
	var body = him.currentBody
	if body == null or body.get("skinNameList") == null:
		return
	var label := str(body.skinNameList[body.currentSkinID])
	_skin = str(g.himSkinType)
	for p in _parts():
		var s = p.getChildByName("skin") if p is FlashSprite else null
		if s is FlashMovieClip:
			_label(s, label)


func _body_changed() -> void:
	_register()   # his pieces are new
	if not _records.is_empty():
		_update()


func _tick() -> void:
	if _records.is_empty():
		return
	if str(g.himSkinType) != _skin:
		_update()


func _reset() -> void:
	_show_hidden()
	_records.clear()
	_skin = ""
