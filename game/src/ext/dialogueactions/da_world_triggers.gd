extends RefCounted
## DialogueActions: loading from dialogue (hair, background, character code, mods, dialogues), CLEARLINES,
## da.clothes.* / da.her.body.* / da.him.body.* / da.sdtoptions.* variables, the ten dialogue buttons, and the
## Loader recording triggers. Port's own implementation of the documented behaviour.
##
## File names in dialogues: "$Folder/file" is Mods/Folder/file; a plain name is looked up in the current
## character's folder (DialogueActions: the last loaded Loader character folder), then in Mods/Dialogue,
## Mods/Backgrounds, Mods/Hair, Mods/Characters and Mods.

const CLOTHES := ["ankleCuffs", "armwear", "bellyPiercing", "bottoms", "collar", "cuffs", "earring", "eyewear",
	"footwear", "gag", "headwear", "himBottoms", "himFootwear", "himTop", "legwear", "legwearB", "nipplePiercing",
	"panties", "tonguePiercing", "top", "tops"]
const OPTIONS := ["hoverOptions", "showMouse", "strandShaders", "mirrored", "spit", "tears", "mascara", "smudging",
	"nostrilSpray", "sweat", "breathing", "gagging", "coughing", "tongue", "dialogue", "invertControls", "bukkakeMode"]
const BUTTONS := 10

var da
var vars
var buttons: Array = []
## Folder of the current character (set by the character folder feature when it exists); "" = none.
var character_folder := ""
var _pending := {}   # "hair" / "bg" / "code" / "mod" / "dialogue" -> value waiting for the next line


func _init(p_da) -> void:
	da = p_da
	vars = da.vars


func register() -> void:
	var t: Callable = Callable(da, "register_trigger")
	# loading, either right away by a trigger or when the next line starts (DialogueActions' "delay set")
	vars.register_write("da.hair.load", func(v): _set_pending("hair", str(v), ["[LOAD_HAIR]"]))
	t.call("LOAD_HAIR", 0, func(_a): _do("hair"))
	vars.register_write("da.background.load", func(v): _set_pending("bg", str(v), ["[CHANGE_BACKGROUND]", "[FADE_BACKGROUND_"]))
	t.call("CHANGE_BACKGROUND", 0, func(_a): _do("bg"))
	vars.register_write("da.charcode.load", func(v): _set_pending("code", str(v), ["[LOAD_CHARCODE]", "[LOAD_CHARCODE2]", "[LOAD_FULL_CHARCODE]"]))
	t.call("LOAD_CHARCODE", 0, func(_a): _do("code"))
	t.call("LOAD_CHARCODE2", 0, func(_a): _do("code", "add"))
	t.call("LOAD_FULL_CHARCODE", 0, func(_a): _do("code", "full"))
	vars.register_write("da.mod.load", func(v): _set_pending("mod", str(v), ["[LOAD_MOD]"]))
	t.call("LOAD_MOD", 0, func(_a): _do("mod"))
	t.call("CLEAR_MOD", 0, func(_a): g.customElementLoader.clearInstancedMods(); g.soundControl.resetAudioMods())
	vars.register_write("da.dialogue.load", func(v): _set_pending("dialogue", str(v), []))
	vars.register_write("da.dialogue.import", func(v): _import_dialogue(str(v)))
	t.call("CLEARLINES", 1, func(a): _clear_lines(a[0]))
	t.call("RANDOMIZE_HER_BODY", 0, func(_a): _randomize_body())
	# the Loader's recordings and auto keys are not in the port yet
	for r in ["AUTO_KEYS", "AUTO_KEYS_ON", "AUTO_KEYS_OFF", "PAUSE", "CONTINUE", "PULL_OFF"]:
		var name: String = r
		t.call(name, 0, func(_a): vars.dlog("[%s]: Loader recordings are not supported yet" % name))
	_register_clothes()
	_register_body()
	_register_options()
	_register_buttons(t)
	vars.register_read("da.held", func(): return g.him.currentArmPosition == 0)
	vars.register_read("da.finishes", func(): return g.totalFinishes)
	vars.register_read("da.her.name", func(): return g.dialogueControl.herName())
	vars.register_read("da.her.namePossessive", func(): return g.dialogueControl.herPosessive())
	vars.register_read("da.him.name", func(): return g.dialogueControl.partnerName())
	vars.register_read("da.him.namePossessive", func(): return g.dialogueControl.partnerPosessive())


# ---------------------------------------------------------------- files and loading

func resolve(name: String) -> String:
	if name == "":
		return ""
	if name.begins_with("$"):
		return Flash.mods_dir().path_join(name.substr(1))
	var dirs: Array = []
	if character_folder != "":
		dirs.append(character_folder)
	for sub in ["Dialogue", "Backgrounds", "Hair", "Characters", ""]:
		dirs.append(Flash.mods_dir(sub))
	for d in dirs:
		var p: String = d.path_join(name)
		if FileAccess.file_exists(p):
			return p
	return dirs[0].path_join(name)


## A value written to da.xxx.load is used by its trigger, or when the next line starts if that line does not
## contain the trigger.
func _set_pending(kind: String, value: String, triggers: Array) -> void:
	_pending[kind] = value
	da.add_line_change_listener(func():
		var phrase: String = g.dialogueControl.sayingPhrase
		if not triggers.any(func(tr): return tr in phrase):
			_do(kind)
	)


func _do(kind: String, mode := "") -> void:
	var v = _pending.get(kind)
	if v == null or v == "":
		vars.dlog("nothing set to load for " + kind)
		return
	_pending.erase(kind)
	match kind:
		"hair":
			if ".swf" in v:
				vars.dlog("da.hair.load is for images, not .swf hair mods: " + v)
			g.customElementLoader.tryToLoadHairFile(resolve(v))
		"bg":
			g.customElementLoader.tryToLoadBGFile(resolve(v))
		"code":
			var menu = g.inGameMenu
			if mode == "full":
				menu.loadData(v)
			elif mode == "add":
				menu.loadData(menu.getSaveDataString() + ";" + v)
			else:
				# LOAD_CHARCODE: only what the code lists changes, other items stay on
				CharCode.keep_unlisted = true
				menu.loadData(v)
				CharCode.keep_unlisted = false
		"mod":
			g.customElementLoader.tryToLoadSwfMods([resolve(v)], false, false)
		"dialogue":
			var p := resolve(v)
			if FileAccess.file_exists(p):
				g.dialogueControl.loadCustomDialogue(Flash.bytes_to_string(FileAccess.get_file_as_bytes(p)))
			else:
				vars.dlog("dialogue file not found: " + p)


## da.dialogue.import: adds a dialogue file's lines to the current dialogue (no reset, no initial settings).
func _import_dialogue(name: String) -> void:
	var p := resolve(name)
	if not FileAccess.file_exists(p):
		vars.dlog("dialogue file not found: " + p)
		return
	var lib = g.dialogueControl.library
	var text := Flash.bytes_to_string(FileAccess.get_file_as_bytes(p)).replace("vigourous:", "vigorous:")
	text = RegEx.create_from_string("initial_settings:.*").sub(text, "", false)
	lib.outputLog("Importing custom dialogue.\n------------------------------")
	if lib._reAllClear.search(text):
		lib.allCleared = true
	if lib._reFinishClear.search(text):
		lib.finishesCleared = true
	var rest := ""
	var last := 0
	for m in lib._reFinishLine.search_all(text):
		rest += text.substr(last, m.get_start() - last)
		lib.customFinishPopulator(m.get_string(1), m.get_string(2))
		last = m.get_end()
	text = rest + text.substr(last)
	for m in lib._reLibraryLine.search_all(text):
		lib.customLibraryPopulator(m.get_string(1), m.get_string(2), m.get_string(3))
	lib.outputLog("Done.\n------------------------------")
	da._setup_line_types()


func _clear_lines(line_type: String) -> void:
	var lib = g.dialogueControl.library
	lib.customClears[line_type] = true
	lib.customLibrary[line_type] = []


# ---------------------------------------------------------------- relative values

## "+n" / "-n" change the current value; a plain number (or numeric text) sets it; NaN if not a number.
static func relative(current: float, v) -> float:
	if v is int or v is float:
		return float(v)
	if v is String and not AS3.isNaN(v):
		return current + AS3.Number(v) if (v.begins_with("+") or v.begins_with("-")) else AS3.Number(v)
	return NAN


# ---------------------------------------------------------------- clothes

func _cloth(type: String):
	var cc = g.characterControl
	match type:
		"top": return cc.braControl
		"tops": return cc.topControl
		"himFootwear":
			var b = g.him.currentBody
			return b.get("femaleFootwearControl") if b is HimFemaleBody else b.get("footwearControl")
		"himTop": return g.him.currentBody.get("topControl") if g.him.currentBody is HimMaleBody else null
		"himBottoms": return g.him.currentBody.get("bottomsControl") if g.him.currentBody is HimMaleBody else null
	return cc.get(type + "Control")


func _register_clothes() -> void:
	for t in CLOTHES:
		var type: String = t
		var base := "da.clothes." + type
		vars.register(base, func(): var c = _cloth(type); return c.getDataString() if c else "",
			func(v): _set_cloth_string(type, str(v)))
		vars.register(base + ".type", func(): var c = _cloth(type); return c.selectedName if c else "",
			func(v): _set_cloth_name(type, str(v)))
		for comp in ["r", "g", "b", "a"]:
			var k: String = comp
			for second in [false, true]:
				var two: bool = second
				vars.register(base + "." + k + ("2" if two else ""),
					func(): var c = _cloth(type); return (c.rgb2 if two else c.rgb1)[k] if c else 0,
					func(v): _set_cloth_colour(type, k, two, v))


func _set_cloth_name(type: String, name: String) -> void:
	var c = _cloth(type)
	if c == null:
		return
	var i: int = c.elementNameList.find(name)
	if i == -1:
		vars.dlog("no clothing piece %s for %s" % [name, type])
		return
	c.selection = i
	if c.associatedModType:
		g.customElementLoader.clearModTypes([c.associatedModType])
	c.resetElement()


func _set_cloth_colour(type: String, comp: String, second: bool, v) -> void:
	var c = _cloth(type)
	if c == null:
		return
	var rgb: Dictionary = c.rgb2 if second else c.rgb1
	var n := relative(AS3.Number(rgb.get(comp, 0)), v)
	if is_nan(n):
		rgb[comp] = v
	else:
		rgb[comp] = clampf(n, 0.0, 1.0 if comp == "a" else 255.0)
	c.resetFills()


## da.clothes.<type> = "Name,R,G,B,A,R2,G2,B2,A2" (or 3 / 4 / 6 colour values): unchanged parts keep their value.
func _set_cloth_string(type: String, value: String) -> void:
	var c = _cloth(type)
	if c == null:
		return
	var new := value.split(",")
	var cur: PackedStringArray = str(c.getDataString()).split(",")
	match new.size():
		9, 5, 4:
			for i in new.size():
				if i < cur.size():
					cur[i] = new[i]
		7:
			for i in 4:
				cur[i] = new[i]
			if cur.size() > 4:
				cur[4] = "1"
			for i in range(4, 7):
				if i + 1 < cur.size():
					cur[i + 1] = new[i]
			if cur.size() > 8:
				cur[8] = "1"
		_:
			vars.dlog("da.clothes.%s: expected 4, 5, 7 or 9 values, got %d" % [type, new.size()])
			return
	c.loadDataString(",".join(cur))


# ---------------------------------------------------------------- her and his body

func _register_body() -> void:
	var cc = g.characterControl
	var her = g.her
	var menu = g.inGameMenu
	vars.register("da.her.body.breasts", func(): return cc.breastSize, func(v):
		var n := relative(cc.breastSize, v)
		if is_nan(n): return
		cc.setBreasts(int(clampf(n, 0, 149)))
		g.strandControl.checkElementAnchors(her.torso.midLayer.rightBreast)
		menu.updateBreastSlider())
	vars.register("da.her.body.scale", func(): return her.bodySize, func(v):
		var n := relative(her.bodySize, v)
		if is_nan(n): return
		her.setBodyScaleFromSlider(maxf(n, 0))
		menu.updateBodySlider())
	vars.register("da.her.body.hair", func(): return menu.charNames[cc.currentHair], func(v): cc.findHair(str(v)); menu.updateHairList())
	vars.register("da.her.body.skin", func(): return menu.skinTypes[cc.currentSkin], func(v): cc.findSkin(str(v)); menu.updateSkinList())
	vars.register("da.her.body.ears", func(): return CharacterControl.earTypeList[cc.currentEar], func(v): cc.findEar(str(v)); menu.updateEarList())
	vars.register("da.her.body.nose", func(): return CharacterControl.noseTypeList[cc.currentNose], func(v): cc.findNose(str(v)); menu.updateNoseList())
	vars.register("da.her.body.iris", func(): return menu.irisTypes[cc.currentIris], func(v): cc.findIris(str(v)); menu.updateIrisList())
	vars.register("da.her.body.eyebrow", func(): return CharacterControl.eyebrowsTypeList[cc.currentEyebrows],
		func(v): cc.findEyebrows(str(v)); menu.updateEyebrowsList())
	vars.register("da.her.body.mascara", func(): return g.mascaraAmount, func(v):
		var n := relative(g.mascaraAmount, v)
		if is_nan(n): return
		g.mascaraAmount = clampf(n, 0, 100)
		menu.updateMascaraSlider())
	vars.register("da.her.body.freckles", func(): return g.frecklesAmount, func(v):
		var n := relative(g.frecklesAmount, v)
		if is_nan(n): return
		cc.setFreckleAmount(clampf(n, 0, 100))
		menu.updateFrecklesSlider())
	var tan = her.tan
	vars.register("da.her.body.tan", func(): return tan._tanNameList[tan._currentTanID], func(v):
		var i: int = tan._tanNameList.find(v)
		if i != -1: tan.setTan(i))
	vars.register("da.her.body.tan.amount", func(): return tan._currentTanAlpha, func(v):
		var n := relative(tan._currentTanAlpha, v)
		if is_nan(n): return
		tan.setTanAlpha(clampf(n, 0, 1))
		tan.updateAlphaSlider())
	var hp = her._penisControl
	vars.register("da.her.body.penis", func(): return hp.penisNameList[hp.currentPenisID], func(v):
		var i: int = hp.penisNameList.find(v)
		if i != -1: hp.penisControl.select(i))
	vars.register_read("da.her.body.penis.minSize", func(): return hp.MIN_PENIS_SIZE)
	vars.register_read("da.her.body.penis.maxSize", func(): return hp.MAX_PENIS_SIZE)
	vars.register("da.her.body.penis.length", func(): return hp.penis.scaleX, func(v):
		var n := relative(hp.penis.scaleX, v)
		if not is_nan(n): hp.loadPenisScales(n, hp.currentPenisWidthScale))
	vars.register("da.her.body.penis.width", func(): return hp.penis.scaleY, func(v):
		var n := relative(hp.penis.scaleY, v)
		if not is_nan(n): hp.loadPenisScales(hp.currentPenisLengthScale, n))
	for spec in [["da.her.body.iris.", "irisRGB", "setIrisFill"], ["da.her.body.sclera.", "scleraRGB", "setSclera"],
			["da.her.body.eyeshadow.", "eyeShadowRGB", "setEyeShadow"], ["da.her.body.lipstick.", "lipstickRGB", "setLipstick"],
			["da.her.body.eyebrow.outline.", "eyebrowLineRGB", "setEyebrowLine"], ["da.her.body.eyebrow.fill.", "eyebrowFillRGB", "setEyebrowFill"],
			["da.her.body.blush.", "blushRGB", "setBlush"], ["da.her.body.mascara.", "mascaraRGB", "setMascara"],
			["da.her.body.freckles.", "frecklesRGB", "setFreckles"], ["da.her.body.nailpolish.", "nailPolishRGB", "setNailPolish"]]:
		for comp in ["r", "g", "b", "a"]:
			var s: Array = spec
			var k: String = comp
			vars.register(s[0] + k, func(): return cc.get(s[1])[k], func(v): _set_colour(s[1], s[2], k, v, 1.0 if k == "a" else 255.0, 0.0))
	for spec in [["da.her.body.hair.", "hairHSL", "applyHairHSL"], ["da.her.body.skin.", "skinHSL", "applySkinHSL"],
			["da.him.body.skin.", "hisSkinHSL", "applyHisSkinHSL"]]:
		for comp in ["h", "s", "l", "c"]:
			var s: Array = spec
			var k: String = comp
			vars.register(s[0] + k, func(): return cc.get(s[1])[k],
				func(v): _set_colour(s[1], s[2], k, v, 180.0 if k == "h" else 4.0, -180.0 if k == "h" else 0.0))
	# him
	var him = g.him
	vars.register("da.him.body.penis", func(): return him.penisNameList[him.currentPenisID], func(v):
		var i: int = him.penisNameList.find(v)
		if i != -1: him.penisControl.select(i))
	vars.register_read("da.him.body.penis.minSize", func(): return him.MIN_PENIS_SIZE)
	vars.register_read("da.him.body.penis.maxSize", func(): return him.MAX_PENIS_SIZE)
	vars.register("da.him.body.penis.length", func(): return him.penis.scaleX, func(v):
		var n := relative(him.penis.scaleX, v)
		if not is_nan(n): him.loadPenisScales(n, him.currentPenisWidthScale))
	vars.register("da.him.body.penis.width", func(): return him.penis.scaleY, func(v):
		var n := relative(him.penis.scaleY, v)
		if not is_nan(n): him.loadPenisScales(him.currentPenisLengthScale, n))
	vars.register("da.him.body.balls", func(): return him.ballsNameArray[him.currentBalls], func(v):
		var i: int = him.ballsNameArray.find(v)
		if i != -1: him.setBalls(i))
	vars.register("da.him.body.balls.size", func(): return him.currentBallSize, func(v):
		var n := relative(him.currentBallSize, v)
		if not is_nan(n): him.setBallScale(n))
	vars.register("da.him.body.gender", func(): return him.bodyNameList[him.currentBodyID], func(v):
		var i: int = him.bodyNameList.find(v)
		if i != -1: him.setBody(i))
	vars.register("da.him.body.breasts", func(): return him.currentBody.breastSize if him.currentBody is HimFemaleBody else 0, func(v):
		if him.currentBody is HimFemaleBody:
			var n := relative(him.currentBody.breastSize, v)
			if not is_nan(n): him.currentBody.setBreasts(int(clampf(n, 0, 149))))
	vars.register("da.him.body.skin", func(): return him.currentBody.skinNameList[him.currentBody.currentSkinID], func(v):
		var b = him.currentBody
		var i: int = b.skinNameList.find(v)
		if i == -1: return
		if b is HimFemaleBody and b.has_method("setSkinx"): b.setSkinx(i)
		else: b.setSkin(i))


func _set_colour(field: String, setter: String, comp: String, v, hi: float, lo: float) -> void:
	var cc = g.characterControl
	var obj: Dictionary = cc.get(field).duplicate() if cc.get(field) is Dictionary else {}
	if obj.is_empty():
		var src = cc.get(field)
		for k in ["r", "g", "b", "a", "h", "s", "l", "c"]:
			if src != null and k in src:
				obj[k] = src.get(k)
	var n := relative(AS3.Number(obj.get(comp, 0)), v)
	if is_nan(n):
		vars.dlog("%s%s: not a number: %s" % [field, comp, v])
		return
	obj[comp] = clampf(n, lo, hi)
	cc.call(setter, obj)


func _randomize_body() -> void:
	var cc = g.characterControl
	var menu = g.inGameMenu
	var lips: Array = []
	for i in 2:
		lips.append(PaletteUtils.getHue(randf() * 190 + 170, randf(), randf() * 0.5 if randf() > 0.4 else randf()))
	cc.setHair(int(randf() * menu.charNames.size()))
	cc.randomCurrentElements()
	menu.updateHairList()
	cc.setBreasts(int(randf() * 150))
	menu.updateBreastSlider()
	cc.setIris(int(randf() * menu.irisTypes.size()))
	menu.updateIrisList()
	cc.setIrisFill(PaletteUtils.getHue(randf(), randf() * 0.8, PaletteUtils.midRandom() * 0.5))
	cc.setSkin(int(randf() * menu.skinTypes.size()))
	menu.updateSkinList()
	g.her.setBodyScaleFromSlider(randf())
	menu.customMenu.bodySlider.setPos(g.her.bodySize)
	cc.setLipstick(PaletteUtils.randomSwatch(lips))
	cc.setEyeShadow(PaletteUtils.randomSwatch(lips))
	cc.setNailPolish(PaletteUtils.randomSwatch(lips))
	g.saveData.saveCharData()


# ---------------------------------------------------------------- game options (da.sdtoptions.*)

func _register_options() -> void:
	for o in OPTIONS:
		var name: String = o
		vars.register("da.sdtoptions." + name, func(): return 1 if g.get(name) else 0, func(v):
			var want := AS3.Number(v) == 1 or str(v) == "true"
			if bool(g.get(name)) != want:
				g.inGameMenu.call("cb" + name[0].to_upper() + name.substr(1) + "Clicked", null))


# ---------------------------------------------------------------- dialogue buttons

func _register_buttons(t: Callable) -> void:
	for i in range(1, BUTTONS + 1):
		var n: int = i
		t.call("BUTTON%d_ON" % n, 0, func(_a): _button(n).visible = true)
		t.call("BUTTON%d_OFF" % n, 0, func(_a): _button(n).visible = false)
		vars.register_write("da.button%d.name" % n, func(v): _button(n).set_text(str(v)))
		vars.register_write("da.button%d.varname" % n, func(v): _button(n).set_text(vars.value_text(str(v))))
	t.call("BUTTONALL_ON", 0, func(_a):
		for b in _all_buttons():
			if b.text != "": b.visible = true)
	t.call("BUTTONALL_OFF", 0, func(_a):
		for b in _all_buttons(): b.visible = false)
	t.call("BUTTONALL_CLEAR", 0, func(_a):
		for b in _all_buttons():
			b.visible = false
			b.set_text(""))


func _all_buttons() -> Array:
	for i in range(1, BUTTONS + 1):
		_button(i)
	return buttons


## Button n (1-10), created on first use; buttons stack upwards from the bottom left, like DialogueActions'.
func _button(n: int):
	while buttons.size() < BUTTONS:
		var b := DAButton.new()
		var idx := buttons.size() + 1
		b.x = 0
		b.y = 335 - 35 * (idx - 1)
		b.visible = false
		b.on_click = func():
			g.dialogueControl.buildState("button%d" % idx, 130)
			da._clean_delay = da.CLEAN_INTERVAL
		g.container.addChild(b)
		buttons.append(b)
	return buttons[n - 1]


func remove() -> void:
	for b in buttons:
		if is_instance_valid(b) and b._flash_parent != null:
			b._flash_parent.removeChild(b)
	buttons.clear()


## A dialogue button: a blue rounded box with a label (the port's own drawing).
class DAButton:
	extends FlashSprite
	var on_click: Callable
	var text := ""
	var _label: FlashTextField
	var _state := 0   # 0 idle, 1 hover, 2 pressed

	func _init() -> void:
		buttonMode = true
		mouseChildren = false
		_label = FlashTextField.new()
		_label.mouseEnabled = false
		_label.selectable = false
		_label._box = Rect2(0, 0, 130, 32)
		_label.setTextFormat({"size": 14.0, "align": "center", "color": 0x000000})
		_label.y = 5
		addChild(_label)
		addEventListener(FlashEvent.MOUSE_OVER, func(_e): _state = 1; _draw_box())
		addEventListener(FlashEvent.MOUSE_OUT, func(_e): _state = 0; _draw_box())
		addEventListener(FlashEvent.MOUSE_DOWN, func(_e): _state = 2; _draw_box())
		addEventListener(FlashEvent.MOUSE_UP, func(_e):
			_state = 1
			_draw_box()
			if on_click.is_valid(): on_click.call())
		_draw_box()

	func set_text(t: String) -> void:
		text = t
		_label.text = t

	func _draw_box() -> void:
		var col: int = [0x8091D4, 0x9EABDE, 0xCCCCCC][_state]
		var gr := graphics
		gr.clear()
		gr.lineStyle(1, 0x333333, 1.0)
		gr.beginFill(col, 1.0)
		var w := 129.0
		var h := 32.0
		var r := 9.5
		gr.moveTo(r, 0)
		gr.lineTo(w - r, 0)
		gr.curveTo(w, 0, w, r)
		gr.lineTo(w, h - r)
		gr.curveTo(w, h, w - r, h)
		gr.lineTo(r, h)
		gr.curveTo(0, h, 0, h - r)
		gr.lineTo(0, r)
		gr.curveTo(0, 0, r, 0)
		gr.endFill()
		gr.lineStyle()
