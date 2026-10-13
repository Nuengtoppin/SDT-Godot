class_name Tan
extends RefCounted
## Port of obj.her.Tan: tan-line overlays on her body parts, with style and strength settings.

var _standardTanItems: Array = []
var _multiPartTanItems: Array = []
var _skinAlphaScaling: Dictionary = {}
var _tanNameList: Array = ["None", "Full", "Bikini", "Swimsuit", "Swimsuit-T"]
var _currentTanID: int = 0
var _preModTanID: int = 0
var _currentAlphaScaling: float = 1.0
var _currentTanAlpha: float = 0.0
var _menuList = null
var _alphaSlider = null


func _init() -> void:
	prepItems()
	prepScalingDictionary()


func registerMenuItems(menuList, slider) -> void:
	_menuList = menuList
	_menuList.leftArrow.addEventListener(FlashEvent.CLICK, tanLeftClicked)
	_menuList.rightArrow.addEventListener(FlashEvent.CLICK, tanRightClicked)
	_alphaSlider = slider
	_alphaSlider.setRangeEnd(119)
	_alphaSlider.addEventListener("handleReleased", alphaSliderReleased)
	_alphaSlider.addEventListener("sliderChanged", alphaSliderChanged)
	updateMenuList()
	updateAlphaSlider()


func updateSkin(skin: String = "") -> void:
	if skin:
		_currentAlphaScaling = float(_skinAlphaScaling.get(skin, 0.0))
	setTan()


func hideForMods() -> void:
	setTan(0, false)


func getDataString() -> String:
	return "herTan:" + g.dataName(_tanNameList[_currentTanID]) + "," + str(_currentTanAlpha)


func loadDataPairs(pairs: Array) -> void:
	var found := false
	for pair in pairs:
		match pair[0]:
			"herTan":
				var vals: PackedStringArray = String(pair[1]).split(",")
				if vals.size() == 2:
					CharacterControl.findName(vals[0], _tanNameList, setTan)
					updateMenuList()
					if vals[1].is_valid_float():
						setTanAlpha(maxf(0.0, minf(1.0, float(vals[1]))))
						updateAlphaSlider()
					found = true
	if not found:
		setTan(0)


func setTan(id: int = -1, store: bool = true) -> void:
	if id != -1 and store:
		_currentTanID = id
	for item in _standardTanItems:
		var t = item.get("tan")
		if t:
			CharacterControl.tryToSetFrameLabel(t, _tanNameList[_currentTanID])
			t.visible = _currentTanID != 0
	g.her.ear.tan.visible = _currentTanID != 0
	for item in _multiPartTanItems:
		item.visible = _currentTanID != 0
	g.characterControl.setBreasts()
	setTanAlpha()
	updateMenuList()


func setTanAlpha(v: float = -1.0) -> void:
	if v != -1:
		_currentTanAlpha = v
	var a := _currentTanAlpha * _currentAlphaScaling
	var cmf := FlashFilter.colorMatrix([1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, a, 0])
	for item in _standardTanItems:
		var t = item.get("tan")
		if t:
			if a > 0 and _currentTanID != 0:
				t.visible = true
				t.alpha = a
			else:
				t.visible = false
	g.her.ear.tan.alpha = a
	for item in _multiPartTanItems:
		if a > 0 and _currentTanID != 0:
			item.filters = [cmf]
			item.visible = true
		else:
			item.filters = []
			item.visible = false


func tanLeftClicked(_e = null) -> void:
	setTan(maxi(0, mini(_tanNameList.size() - 1, _currentTanID - 1)))
	g.saveData.saveCharData()


func tanRightClicked(_e = null) -> void:
	setTan(maxi(0, mini(_tanNameList.size() - 1, _currentTanID + 1)))
	g.saveData.saveCharData()


func updateMenuList() -> void:
	if _menuList:
		_menuList.itemLabel.text = _tanNameList[_currentTanID]


func alphaSliderReleased(_e = null) -> void:
	g.saveData.saveCharData()


func alphaSliderChanged(_e = null) -> void:
	setTanAlpha(_alphaSlider.currentValue(100) * 0.01)


func updateAlphaSlider() -> void:
	if _alphaSlider:
		_alphaSlider.setPos(_currentTanAlpha)


func prepItems() -> void:
	var h: Her = g.her
	_standardTanItems = [h.leftLegContainer.leg.calf, h.leftLegContainer.leg.thigh, h.torsoBack.leftShoulder,
		h.torsoBack.chestBack, h.torsoBack.leftBreast, h.torsoBack.leftBreast.nipple, h.eye.eyebrowUnderMask,
		h.torso.midLayer.chest, h.torso.midLayer.rightBreast, h.torso.midLayer.rightBreast.nipple,
		h.torso.midLayer.leftArm, h.torso.behindBackRightArm, h.torso.leg.thigh, h.torso.back,
		h.torso.rightCalfContainer.calf, h.rightArmContainer.upperArm, h.rightForeArmContainer.upperArm.foreArm.hand,
		h.rightForeArmContainer.upperArm.foreArm, h.leftArmContainer.upperArm.foreArm.hand,
		h.leftArmContainer.upperArm.foreArm, h.leftArmContainer.upperArm, h.leftHandOver.hand.grip, h.head.neck,
		h.torsoBack.backside, h.torso.backside]
	h.torso.back.tan.blendMode = "overlay"
	_multiPartTanItems = [h.head.headTan]


func prepScalingDictionary() -> void:
	_skinAlphaScaling[SkinPalette.LIGHT_SKIN] = 0.995
	_skinAlphaScaling[SkinPalette.PALE_SKIN] = 0.995
	_skinAlphaScaling[SkinPalette.TAN_SKIN] = 0.6
	_skinAlphaScaling[SkinPalette.DARK_SKIN] = 0.5
