class_name HimFemaleBody
extends HimMaleBody
## Port of obj.him.bodies.HimFemaleBody: female "him" body (breasts, skin tones, heels).
## The original's private footwearControl / footwearNameList are renamed here (GDScript has no private
## shadowing).

var breastSize: int = 130
const breastOffset := [2, 152, 302, 452, 602]
var currentBreastOffset: float = 0.0
var leftBreastController: BreastController = null
var rightBreastController: BreastController = null
var femaleFootwearControl: CharacterElementHelper
var femaleFootwearNameList := ["None", "Highheel"]
var herSwatch: Array = []


func _init(him: Him) -> void:
	super(him)
	skinNameList = g.characterControl.skinNameList


func loadDataPairs(pairs: Array) -> void:
	for pair in pairs:
		match pair[0]:
			"hisSkin":
				setSkin(int(pair[1]))
			"hisBreasts":
				setBreasts(maxi(1, mini(149, int(pair[1]))))
				updateBreastSlider()
			"hisFootwear":
				femaleFootwearControl.loadDataString(pair[1])


func getDataString() -> String:
	return "hisSkin:%s;hisBreasts:%s;hisFootwear:%s" % [currentSkinID, breastSize, femaleFootwearControl.getDataString()]


func move(p: float, hand: float, yp: float) -> void:
	super.move(p, hand, yp)
	leftBreastController.update(xMovement * 0.001)
	rightBreastController.update(xMovement * 0.001)


func initElements() -> void:
	rightLegIK = IKController.new(_him, _him.rightLeg, _him.rightLeg.calf, _him.rightLeg.calf.foot)
	rightLegIK.newTarget(g.animationControl.getHisRightFootTarget(), g.sceneLayer, true)
	rightLegIK.rescale(0.9)
	leftLegIK = IKController.new(_him, _him.leftLeg, _him.leftLeg.calf, _him.leftLeg.calf.foot)
	leftLegIK.newTarget(g.animationControl.getHisLeftFootTarget(), g.sceneLayer, true)
	rightArmIK = IKController.new(_him, _him.armContainer.arm, _him.armContainer.arm.upperArm, _him.armContainer.arm.upperArm.shoulderPoint)
	rightArmIK.newTarget(shoulderPoint, _him, true)
	leftArmIK = IKController.new(_him, _him.leftArmContainer.arm, _him.leftArmContainer.arm.foreArm, _him.leftArmContainer.arm.foreArm.hand, true)
	leftArmIK.newTarget(leftArmTarget, _him, true)
	femaleFootwearControl = CharacterElementHelper.new(femaleFootwearNameList, setFootwear, setFootwearFill)
	femaleFootwearControl.setStartRGB(AlphaRGBObject.new(1, 0, 0, 0))


func initMenu() -> void:
	_bodyMenu = Flash.create("HimFemaleBodyMenu")
	herSwatch = [
		{"r": 22, "g": 8, "b": 0, "a": 1}, {"r": 82, "g": 0, "b": 6, "a": 1}, {"r": 255, "g": 126, "b": 167, "a": 1},
		{"r": 0, "g": 26, "b": 114, "a": 1}, {"r": 63, "g": 118, "b": 162, "a": 1}, {"r": 238, "g": 242, "b": 245, "a": 1},
		{"r": 27, "g": 29, "b": 29, "a": 1}, {"r": 0, "g": 0, "b": 0, "a": 1}, {"r": 255, "g": 255, "b": 255, "a": 1}]
	_bodyMenu.breastSlider.setRangeEnd(100)
	_bodyMenu.breastSlider.addEventListener("handleReleased", breastSliderReleased)
	_bodyMenu.breastSlider.addEventListener("sliderChanged", breastSliderChanged)
	_bodyMenu.mlSkin.leftArrow.addEventListener(FlashEvent.CLICK, hisSkinLeftClicked)
	_bodyMenu.mlSkin.rightArrow.addEventListener(FlashEvent.CLICK, hisSkinRightClicked)
	updateSkinList()
	femaleFootwearControl.registerMenuList(_bodyMenu.mlFootwear)
	femaleFootwearControl.registerRGBButton(_bodyMenu.rgbFootwear, herSwatch, 489, false)


func animationChanged() -> void:
	var r: Vector2 = g.animationControl.getHisRightFootTarget()
	var l: Vector2 = g.animationControl.getHisLeftFootTarget()
	if femaleFootwearControl.selectedName == "Highheel":
		r += Vector2(-140, -60)
		l += Vector2(100, -60)
	rightLegIK.newTarget(r, g.sceneLayer, true)
	leftLegIK.newTarget(l, g.sceneLayer, true)
	updateLegs()


func toggleBodySettings() -> void:
	if g.him.currentPenisID == 2:
		if currentSkinID == skinNameList.size() - 1:
			g.him.penisControl.select(0)
			setSkin(0)
		else:
			setSkin(currentSkinID + 1)
	elif currentSkinID == skinNameList.size() - 1:
		g.him.penisControl.select(g.him.currentPenisID + 1)
		setSkin(0)
	else:
		setSkin(currentSkinID + 1)


func shuffle() -> void:
	g.him.penisControl.select(int(floor(randf() * 3)))
	var c: AlphaRGBObject = PaletteUtils.getHue(randf() * 360.0, PaletteUtils.midRandom(), PaletteUtils.midRandom() if randf() > 0.6 else 0.0)
	g.him.penisControl.setFill(c, "rgbFill")
	setSkin(int(floor(randf() * skinNameList.size())))


func setupElements() -> void:
	if leftBreastController == null:
		leftBreastController = BreastController.new(_him.torsoLayer.leftBreastContainer.leftBreast)
		rightBreastController = BreastController.new(_him.torsoLayer.rightBreastContainer.rightBreast)
	setSkin(currentSkinID)
	setBreasts(breastSize)
	updateBreastSlider()
	_him.torsoLayer.leftBreastContainer.leftBreast.tan.visible = false
	_him.torsoLayer.rightBreastContainer.rightBreast.tan.visible = false
	_him.torsoLayer.leftBreastContainer.leftBreast.nipple.tan.visible = false
	_him.torsoLayer.rightBreastContainer.rightBreast.nipple.tan.visible = false
	for t in [g.him.topBack, g.him.overLayer.torso.costume, g.him.rightLegCostume, g.him.rightLegCostume.calf,
			g.him.leftLegCostume, g.him.leftLegCostume.calf, g.him.midLayer.hips]:
		CharacterControl.tryToSetFrameLabel(t, "None")


func setupAnimation() -> void:
	rightLegIK.newSegments(_him.rightLeg, _him.rightLeg.calf, _him.rightLeg.calf.foot)
	leftLegIK.newSegments(_him.leftLeg, _him.leftLeg.calf, _him.leftLeg.calf.foot)
	rightArmIK.newSegments(_him.armContainer.arm, _him.armContainer.arm.upperArm, _him.armContainer.arm.upperArm.shoulderPoint)
	leftArmIK.newSegments(_him.leftArmContainer.arm, _him.leftArmContainer.arm.foreArm, _him.leftArmContainer.arm.foreArm.hand)
	femaleFootwearControl.resetElement()


func hisSkinLeftClicked(_e = null) -> void:
	setSkin(maxi(0, mini(skinNameList.size() - 1, currentSkinID - 1)))
	g.saveData.saveCharData()


func hisSkinRightClicked(_e = null) -> void:
	setSkin(maxi(0, mini(skinNameList.size() - 1, currentSkinID + 1)))
	g.saveData.saveCharData()


func updateSkinList() -> void:
	_bodyMenu.mlSkin.itemLabel.text = skinNameList[currentSkinID]


func breastSliderReleased(_e = null) -> void:
	g.saveData.saveCharData()


func breastSliderChanged(_e = null) -> void:
	setBreasts(int(_bodyMenu.breastSlider.currentValue(149)))


func updateBreastSlider() -> void:
	_bodyMenu.breastSlider.setPos(breastSize / 149.0)


func setFootwear(_id: int = 0) -> void:
	CharacterControl.tryToSetFrameLabel(g.him.rightLegCostume.calf.foot, femaleFootwearControl.selectedName)
	CharacterControl.tryToSetFrameLabel(g.him.leftLegCostume.calf.foot, femaleFootwearControl.selectedName)
	animationChanged()
	setFeet()


func setFootwearFill(c, fillName: String = "rgbFill") -> void:
	var ct := HimMaleBody._fill(c)
	CharacterControl.tryToSetFill(g.him.rightLegCostume.calf.foot, fillName, ct)
	CharacterControl.tryToSetFill(g.him.leftLegCostume.calf.foot, fillName, ct)


func setBreasts(size: int = -1) -> void:
	if size == -1:
		size = breastSize
	breastSize = size
	var lb = _him.torsoLayer.leftBreastContainer.leftBreast
	var rb = _him.torsoLayer.rightBreastContainer.rightBreast
	setBreastFrame(lb)
	setBreastFrame(rb)
	if lb.nipple.getChildByName("leftNipple"):
		lb.nipple.gotoAndStop("None")
	else:
		lb.nipple.gotoAndStop(String(skinNameList[currentSkinID]).to_lower())
	if rb.nipple.getChildByName("rightNipple"):
		rb.nipple.gotoAndStop("None")
	else:
		rb.nipple.gotoAndStop(String(skinNameList[currentSkinID]).to_lower())
	if leftBreastController:
		leftBreastController.updateFirmness(size)
		rightBreastController.updateFirmness(size)
	lb.nipple.tan.visible = false
	rb.nipple.tan.visible = false


func setBreastFrame(b) -> void:
	var inner = b.getChildByName(b.flash_name)
	if inner:
		b.gotoAndStop(breastOffset[4])
		if inner is FlashMovieClip:
			setChildrenFrame(inner, 2 + breastSize)
	else:
		setChildrenFrame(b, 2 + breastSize)
		b.gotoAndStop(int(currentBreastOffset + breastSize))


func setChildrenFrame(target, frame: int) -> void:
	for i in target.numChildren:
		var c = target.getChildAt(i)
		if c is FlashMovieClip:
			c.gotoAndStop(frame)
			setChildrenFrame(c, frame)


func setSkin(id: int) -> void:
	currentSkinID = id
	currentBreastOffset = breastOffset[currentSkinID]
	g.himSkinType = "Female" + skinNameList[currentSkinID]
	setBreasts()
	g.him.updatePenis()
	g.him.balls.setSkin(g.himSkinType)
	g.him.updateArm()
	g.him.torsoLayer.torso.gotoAndStop(g.himSkinType)
	g.him.leftLeg.gotoAndStop(g.himSkinType)
	g.him.leftLeg.calf.gotoAndStop(g.himSkinType)
	g.him.rightLeg.gotoAndStop(g.himSkinType)
	g.him.rightLeg.calf.gotoAndStop(g.himSkinType)
	setFeet()
	updateSkinList()


func setFeet() -> void:
	var suffix := "Highheel" if femaleFootwearControl.selectedName == "Highheel" else ""
	g.him.leftLeg.calf.foot.gotoAndStop(g.himSkinType + suffix)
	g.him.rightLeg.calf.foot.gotoAndStop(g.himSkinType + suffix)
