class_name ModFilePathEntry
extends FlashMovieClip
## Port of obj.ui.ModFilePathEntry: one mod / custom image path row in the save-character panel. Unfound paths are
## editable and retried against the default mod folders.

const labelScrollDelay := 30

var mbRecheck
var textBackground: FlashMovieClip
var pathTF: FlashTextField
var elementLabel: FlashTextField
var modType: String
var enteredPath: String = ""
var modPackage: LoadedModPackage
var editable := false
var checkDefaultFolders := false
var defaultFolder: int = 0
var redGlow := FlashFilter.glow(14168624, 1, 4, 4, 2, 2)
var greenGlow := FlashFilter.glow(7864151, 1, 4, 4, 2, 2)
var labelWidth: float = 0.0
var scrollingLabel := false
var labelScrollSpeed: float = 0.0
var labelScrollTicker: int = 0

var pathOkay: bool:
	get: return modPackage.hasFilePath()


func _init(pType: String = "", pkg: LoadedModPackage = null) -> void:
	super()
	if pkg == null:
		return
	modType = pType
	modPackage = pkg
	if modPackage.titleString:
		elementLabel.text = modPackage.titleString
	else:
		elementLabel.text = modType + " Filepath"
	elementLabel.autoSize = "left"
	labelWidth = elementLabel.textWidth
	if labelWidth > 100:
		labelScrollTicker = labelScrollDelay
		labelScrollSpeed = -1
		scrollingLabel = true
		addEventListener(FlashEvent.ENTER_FRAME, scrollLabel)
	pathTF.addEventListener(FlashEvent.FOCUS_IN, textFieldFocusIn)
	pathTF.addEventListener(FlashEvent.FOCUS_OUT, textFieldFocusOut)
	if modPackage.hasFilePath():
		enteredPath = modPackage.path
		pathTF.text = enteredPath
		pathTF.type = "dynamic"
		textBackground.filters = [greenGlow]
		mbRecheck.visible = false
	else:
		enteredPath = modPackage.fileName
		pathTF.text = enteredPath
		textBackground.filters = [redGlow]
		mbRecheck.addEventListener(FlashEvent.CLICK, mbRecheckClicked)
		pathTF.addEventListener(FlashEvent.KEY_UP, pathTyped)
		editable = true
		checkDefaultFolders = true
		recheck()


func scrollLabel() -> void:
	if labelScrollTicker > 0:
		labelScrollTicker -= 1
	else:
		elementLabel.x += labelScrollSpeed
		if (labelScrollSpeed < 0 and elementLabel.x <= -labelWidth + 90) or (labelScrollSpeed > 0 and elementLabel.x >= 0):
			labelScrollSpeed = -labelScrollSpeed
			labelScrollTicker = labelScrollDelay


func dataString() -> String:
	return modPackage.dataString()


func kill() -> void:
	if editable:
		makeUneditable()
	if scrollingLabel:
		removeEventListener(FlashEvent.ENTER_FRAME, scrollLabel)
	pathTF.removeEventListener(FlashEvent.FOCUS_IN, textFieldFocusIn)
	pathTF.removeEventListener(FlashEvent.FOCUS_OUT, textFieldFocusOut)
	modPackage = null
	parent.removeChild(self)
	Flash.dispose_later(self)


func recheckWithFolders() -> void:
	checkDefaultFolders = true
	recheck()


func makeUneditable() -> void:
	mbRecheck.visible = false
	pathTF.type = "dynamic"
	mbRecheck.removeEventListener(FlashEvent.CLICK, mbRecheckClicked)
	pathTF.removeEventListener(FlashEvent.KEY_UP, pathTyped)


func textFieldFocusIn(_e = null) -> void:
	g.inTextField = true


func textFieldFocusOut(_e = null) -> void:
	g.inTextField = false


func mbRecheckClicked(_e = null) -> void:
	checkDefaultFolders = false
	recheck()


func pathTyped(e: FlashEvent) -> void:
	enteredPath = pathTF.text
	if e.charCode == 13:
		checkDefaultFolders = false
		recheck()


func recheck() -> void:
	if modPackage == null:
		return
	if checkDefaultFolders and g.defaultModFolders.size() > 0:
		var p: String = g.defaultModFolders[defaultFolder] + enteredPath
		pathTF.text = "Trying " + p
		modPackage.tryToLoadFilePath(p, errorHandler, successHandler)
	else:
		pathTF.text = "Trying " + enteredPath
		modPackage.tryToLoadFilePath(enteredPath, errorHandler, successHandler)


func errorHandler(_e = null) -> void:
	if modPackage == null:
		return
	if checkDefaultFolders:
		defaultFolder += 1
		if defaultFolder >= g.defaultModFolders.size():
			checkDefaultFolders = false
		recheck()
	pathTF.text = enteredPath
	dispatchEvent(FlashEvent.new("UPDATED"))
	textBackground.filters = [redGlow]


func successHandler(_e = null) -> void:
	if modPackage == null:
		return
	if checkDefaultFolders:
		pathTF.text = g.defaultModFolders[defaultFolder] + enteredPath
	else:
		pathTF.text = enteredPath
	dispatchEvent(FlashEvent.new("UPDATED"))
	makeUneditable()
	textBackground.filters = [greenGlow]
