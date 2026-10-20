class_name CharacterElementHelper
extends RefCounted
## Port of obj.CharacterElementHelper: one selectable costume / body element (name list, frame selection on its
## components, one or two RGB fills, menu list and colour-picker wiring, save-data strings).

var elementNameList: Array
var findFunction: Callable
var selectFunction: Callable
var fillFunction: Callable
var selection: int = 0
var nameDictionary: Dictionary = {}
var defaultRGB: Dictionary = {}
var defaultRGB2: Dictionary = {}
var haveMenuList := false
var menuList = null
## No-op until a menu list is registered (the original would throw).
var updateMenuList: Callable = func(_n: String = "") -> void: pass
var haveRGBFill := false
var haveRGBFill2 := false
var rgbButton = null
var rgbButton2 = null
var rgb1 = {"r": 0, "g": 0, "b": 0, "a": 1}
var rgb2 = {"r": 0, "g": 0, "b": 0, "a": 1}
var components: Array = []
var associatedModType := ""
var listeners: Array = []
## Port extension: mod items from the Mods folders offered after the built-in options (see ModCatalog), and the
## one currently applied through this picker (-1: a built-in option is selected).
var modEntries: Array = []
var modEntryIndex := -1


func _init(names: Array, selecter: Callable = Callable(), filler: Callable = Callable(), finder: Callable = Callable()) -> void:
	elementNameList = names
	selectFunction = selecter
	fillFunction = filler
	for n in elementNameList:
		nameDictionary[n] = true
	if finder.is_valid():
		findFunction = finder
	else:
		findFunction = func(n: String) -> void: CharacterControl.findName(n, elementNameList, select)
	selection = 0


func registerComponents(newComponents: Array, modType: String = "", addClickListener: bool = true) -> void:
	components = newComponents.duplicate()
	associatedModType = modType
	if addClickListener:
		for item in newComponents:
			item.addEventListener(FlashEvent.CLICK, componentClicked)
			item.mouseChildren = false
	if not selectFunction.is_valid():
		selectFunction = func(_i: int) -> void:
			for c in components:
				tryToSetFrameLabel(c, selectedName)
	if not fillFunction.is_valid():
		fillFunction = defaultFillFunction


func hideAll() -> void:
	for c in components:
		c.visible = false


func showAll() -> void:
	for c in components:
		c.visible = true


func defaultFillFunction(c, fillName: String = "rgbFill") -> void:
	var ct := FlashColorTransform.new(1, 1, 1, c.a, c.r, c.g, c.b)
	for comp in components:
		tryToSetFill(comp, fillName, ct)


func shuffle(c1: AlphaRGBObject, c2: AlphaRGBObject, noneChance: float = -1.0) -> void:
	var i := int(floor(randf() * (elementNameList.size() - 1))) + 1
	if noneChance != -1 and randf() < noneChance:
		i = 0
	select(i)
	if haveRGBFill:
		setFill(c1, "rgbFill")
	if haveRGBFill2:
		setFill(c2, "rgbFill2")


func componentClicked(_e = null) -> void:
	if g.shiftDown:
		findName("None")
		if associatedModType:
			g.customElementLoader.clearModTypes([associatedModType])
		updateMenuList.call()
		g.saveData.saveCharData()


func prepForMod(title: String, overwrite: bool = false) -> void:
	if overwrite:
		findName("None")
		if associatedModType:
			g.customElementLoader.clearModTypes([associatedModType])
	updateMenuList.call(title)


static func tryToSetFrameLabel(mc, label: String) -> void:
	if mc:
		for fl in mc.currentLabels:
			if fl["name"] == label:
				mc.gotoAndStop(label)
				return
		mc.gotoAndStop("None")


static func tryToSetFill(mc, fillName: String, ct: FlashColorTransform) -> void:
	if mc:
		tryToSetFillChildren(mc, fillName, ct)


static func tryToSetFillChildren(mc, fillName: String, ct: FlashColorTransform) -> void:
	for i in mc.numChildren:
		var c = mc.getChildAt(i)
		if c.flash_name == fillName:
			c.colorTransform = ct
		if c is FlashSprite:
			tryToSetFillChildren(c, fillName, ct)


func registerListener(fn: Callable) -> void:
	listeners.append(fn)


func setStartRGB(c) -> void:
	rgb1 = c


func setDefaultRGB(n: String, c1 = null, c2 = null) -> void:
	if nameDictionary.get(n):
		defaultRGB[g.dataName(n)] = c1
		defaultRGB2[g.dataName(n)] = c2


func updateList() -> void:
	if haveMenuList:
		updateMenuList.call()


func beingUsed() -> bool:
	return selectedName != "None"


## Port: a built-in item or a clothing mod is worn (a mod sets the built-in item to "None").
func inUse() -> bool:
	return beingUsed() or modEntryIndex >= 0


func getOptionalDataString(key: String) -> String:
	if inUse():   # port fix: a mod's colours are saved too
		return ";" + key + ":" + getDataString()
	return ""


static func _rgbString(c) -> String:
	return ",%s,%s,%s,%s" % [c.r, c.g, c.b, g.sigRound(3, c.a)]


func getDataString() -> String:
	return g.dataName(elementNameList[selection]) + (_rgbString(rgb1) if haveRGBFill else "") + (_rgbString(rgb2) if haveRGBFill2 else "")


func loadDataString(s: String) -> void:
	var vals := s.split(",")
	findFunction.call(String(vals[0]))
	if vals.size() == 5:
		readRGB(Array(vals.slice(1, 5)), "rgbFill")
		if haveRGBFill2 and getDefaultRGB2():
			setFill(getDefaultRGB2(), "rgbFill2")
	elif vals.size() == 9:
		readRGB(Array(vals.slice(1, 5)), "rgbFill")
		readRGB(Array(vals.slice(5)), "rgbFill2")


func getDefaultRGB():
	return defaultRGB.get(g.dataName(elementNameList[selection]))


func getDefaultRGB2():
	return defaultRGB2.get(g.dataName(elementNameList[selection]))


func readRGB(vals: Array, fillName: String) -> void:
	# AS3 Number(): "" is 0, spaces and hex are accepted; anything else (or a missing value) is NaN = rejected
	var v: Array = []
	for i in 4:
		var x := AS3.Number(vals[i]) if i < vals.size() and vals[i] != null else NAN
		if is_nan(x):
			return
		v.append(x)
	var r := Maths.round(maxf(0.0, minf(255.0, v[0])))
	var gg := Maths.round(maxf(0.0, minf(255.0, v[1])))
	var b := Maths.round(maxf(0.0, minf(255.0, v[2])))
	var a := maxf(0.0, minf(1.0, v[3]))
	setFill({"r": int(r), "g": int(gg), "b": int(b), "a": a}, fillName)


func registerMenuList(ml) -> void:
	haveMenuList = true
	menuList = ml
	menuList.itemLabel.autoSize = "center"
	updateMenuList = func(n: String = "") -> void:
		if not n:
			n = String(elementNameList[selection])
			modEntryIndex = -1
		setPickerLabel(menuList, n)
	menuList.leftArrow.addEventListener(FlashEvent.CLICK, func(_e = null) -> void: _step(-1))
	menuList.rightArrow.addEventListener(FlashEvent.CLICK, func(_e = null) -> void: _step(1))


## Shows 'n' in a picker's label, shrunk to fit.
static func setPickerLabel(ml, n: String) -> void:
	var label = ml.itemLabel
	label.text = n
	label.scaleX = 1
	label.scaleY = 1
	label.y = -7
	if label.textWidth > 82:
		label.scaleX = 82.0 / label.textWidth
		label.scaleY = label.scaleX
		label.y = 2 - label.textHeight * 0.5
	label.x = 19 - label.width * 0.5


func _step(d: int) -> void:
	var n := elementNameList.size()
	var cur := n + modEntryIndex if modEntryIndex >= 0 else selection
	var i := maxi(0, mini(n + modEntries.size() - 1, cur + d))
	if i == cur and i >= n:
		return
	if associatedModType:
		g.customElementLoader.clearModTypes([associatedModType])
	if modEntryIndex >= 0 and modEntryIndex < modEntries.size():
		g.modCatalog.remove(modEntries[modEntryIndex])
	modEntryIndex = -1
	if i < n:
		select(i)
		updateMenuList.call()
	else:
		findName("None")
		g.modCatalog.apply(modEntries[i - n])
		modEntryIndex = i - n
		updateMenuList.call(modEntries[i - n]["title"])
	g.saveData.saveCharData()


func registerRGBButton(button, swatch: Array, xPos: float, showAlpha: bool = true) -> void:
	rgbButton = button
	haveRGBFill = true
	rgbButton.addEventListener(FlashEvent.CLICK, func(_e = null) -> void:
		g.inGameMenu.openRGBPicker(xPos, -157, swatch, rgb1, setFill, showAlpha, "rgbFill"))


func registerSecondaryRGBButton(button, swatch: Array, xPos: float, showAlpha: bool = true) -> void:
	rgbButton2 = button
	haveRGBFill2 = true
	rgbButton2.addEventListener(FlashEvent.CLICK, func(_e = null) -> void:
		g.inGameMenu.openRGBPicker(xPos, -157, swatch, rgb2, setFill, showAlpha, "rgbFill2"))


func select(i: int) -> void:
	selection = i
	selectFunction.call(selection)
	if haveRGBFill:
		setFill(getDefaultRGB() if getDefaultRGB() else rgb1, "rgbFill")
	if haveRGBFill2:
		setFill(getDefaultRGB2() if getDefaultRGB2() else rgb2, "rgbFill2")
	if haveMenuList:
		updateMenuList.call()
	for fn in listeners:
		fn.call(elementNameList[selection])


func setFill(c, fillName: String) -> void:
	if c:
		if fillFunction.is_valid():
			fillFunction.call(c, fillName)
		if fillName == "rgbFill":
			rgb1 = c
		elif fillName == "rgbFill2":
			rgb2 = c


func findName(n: String) -> void:
	findFunction.call(n)


func resetElement() -> void:
	select(selection)


func resetFills() -> void:
	if haveRGBFill:
		setFill(rgb1, "rgbFill")
	if haveRGBFill2:
		setFill(rgb2, "rgbFill2")


var nameList: Array:
	get:
		return elementNameList

var selectedName: String:
	get:
		return elementNameList[selection]
