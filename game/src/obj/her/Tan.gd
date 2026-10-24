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
	# Existing character notification, not a new per-frame update.
	g.characterControl.addBreastSizeChangeListener(_refreshAfterSizeChange)


## Timeline size changes may replace tan nodes and skin shapes while the style stays unchanged.
func _refreshAfterSizeChange() -> void:
	prepItems()
	for item in _standardTanItems:
		var t = item.get("tan")
		if t:
			CharacterControl.tryToSetFrameLabel(t, _tanNameList[_currentTanID])
	setTanAlpha()
	# P008 stores tan on the owner. A new skin shape can arrive with unchanged
	# owner metadata, so explicitly rebuild its material after frame selection.
	var chest = g.her.torso.midLayer.chest
	if chest._library == Flash.base_library and chest._char_id == 1435:
		for child in chest._children:
			if child is FlashShape:
				child._render_state_changed()


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
	for t in _modTanItems():
		CharacterControl.tryToSetFrameLabel(t, _tanNameList[_currentTanID])
	for item in _multiPartTanItems:
		item.visible = _currentTanID != 0
	g.characterControl.setBreasts()
	setTanAlpha()
	updateMenuList()


func setTanAlpha(v: float = -1.0) -> void:
	if v != -1:
		_currentTanAlpha = v
	var a := _currentTanAlpha * _currentAlphaScaling
	for item in _standardTanItems:
		var t = item.get("tan")
		if t:
			if _setSkinTanFill(item, t, a):
				continue
			if a > 0 and _currentTanID != 0:
				t.visible = true
				t.alpha = a
			else:
				t.visible = false
			_setTanIsolation(t, a > 0 and _currentTanID != 0)
	g.her.ear.tan.alpha = a
	for t in _modTanItems():
		t.visible = a > 0 and _currentTanID != 0
		t.alpha = a
	_setTanIsolation(g.her.ear.tan, a > 0 and _currentTanID != 0)
	for item in _multiPartTanItems:
		# ColorMatrix alpha is folded into individual leaf materials by this renderer.
		# That accumulates opacity at overlaps. Apply strength once to the flattened
		# tan group instead, matching the standard tan layers (including the brow).
		item.filters = []
		item.alpha = a
		item.visible = a > 0 and _currentTanID != 0
		_setTanIsolation(item, a > 0 and _currentTanID != 0)

# Recolour selected vanilla skin fills before applying coverage. Torso cutouts
# sample the existing style silhouettes in owner-local coordinates, normalized
# by Full coverage so the outer antialiasing is not applied a second time.
func _setSkinTanFill(item: FlashSprite, tan_layer: FlashDisplayObject, strength: float) -> bool:
	var is_brow: bool = item == g.her.eye.eyebrowUnderMask and item._char_id == 1230
	var is_torso: bool = (item == g.her.torso.back and item._char_id == 1535) or (item == g.her.torso.midLayer.chest and item._char_id == 1435)
	if item._library != Flash.base_library or not (is_brow or is_torso):
		return false
	var skin_shapes: Array = []
	for child in item._children:
		if child is FlashShape:
			if child._library != Flash.base_library:
				return false
			skin_shapes.append(child)
	if skin_shapes.is_empty():
		return false
	var mask_id: int = 0
	var has_tan: bool = _currentTanID != 0
	if is_torso:
		# Slots: None, Full, Bikini, Swimsuit, Swimsuit-T. A zero mask
		# for an active style means uniform Full; negative means no fill.
		var profiles: Array = [0, 0, 1394, -1, -1] if item._char_id == 1435 else [0, 0, 1527, 1528, 1529]
		mask_id = int(profiles[_currentTanID])
		has_tan = has_tan and mask_id >= 0
	var amount: float = clampf(strength, 0.0, 1.0) if has_tan else 0.0
	mask_id = maxi(mask_id, 0) if amount > 0.0 else 0
	if float(item.get_meta("sdt_skin_tan_strength", -1.0)) != amount or int(item.get_meta("sdt_skin_tan_mask", -1)) != mask_id:
		item.set_meta("sdt_skin_tan_strength", amount)
		item.set_meta("sdt_skin_tan_mask", mask_id)
		for shape in skin_shapes:
			shape._render_state_changed()
	tan_layer.visible = false
	_setTanIsolation(tan_layer, false)
	return true


# Isolate the overlay's internal fills and ERASE/ALPHA operations from the skin backdrop.
# The existing FlashGroupProxy applies the outer Overlay once, after flattening.
# Release this opt-in when tan is disabled rather than retaining extra hidden viewports.
func _setTanIsolation(target: FlashDisplayObject, active: bool) -> void:
	if not is_instance_valid(target):
		return
	var wanted: bool = active and target._blend_mode == "overlay"
	if bool(target.get_meta("flash_isolate_composite", false)) == wanted:
		return
	target.set_meta("flash_isolate_composite", wanted)
	FlashProxy.update_for(target)


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


func _modTanItems() -> Array:
	var out: Array = []
	for m in g.customElementLoader.instancedModElements:
		if m.modType == ModTypes.BODY and m._mod != null and is_instance_valid(m._mod):
			for p in [m._mod] + (range(m._mod.numChildren).map(func(i): return m._mod.getChildAt(i)) if m._mod is FlashSprite else []):
				var t = p.getChildByName("tan") if p is FlashSprite else null
				if t is FlashMovieClip:
					out.append(t)
	return out
