class_name CharacterStoring
extends FlashMovieClip
## Port of obj.CharacterStoring: the "save character" panel (name, thumbnail, mod file paths, default folders).

var statusTF: FlashTextField
var mbDeleteChar
var mbDeleteConfirm
var mbStoreChar
var charThumb: FlashMovieClip
var charNameTF: FlashTextField
var mbDeleteCancel
var closeButton
var mbRetakeShot
var charData: String = ""
var charShotData: FlashBitmapData
var charShot: FlashBitmap
var haveCharShot := false
var filePaths: Array = []
var filePathsContainer: FlashSprite
var filePathsScroller: ScrollingArea
var defaultFolders: Array = []
var defaultFoldersContainer: FlashSprite
var defaultFoldersScroller: ScrollingArea
var defaultFoldersAdd: FlashDisplayObject
var editingChar := false
var charBeingEdited: CustomCharacter
var tryingDefaultPath := false
var allPathsFound := false
var currentStatusPriority: int = 0
var deletingDefaultFolderLine := false


func _init() -> void:
	super()
	statusTF.mouseEnabled = false
	charNameTF.restrict = "a-z A-Z 0-9"
	mbStoreChar.labelContainer.buttonLabel.text = "Save Character"
	mbStoreChar.addEventListener(FlashEvent.CLICK, storeCharClicked)
	charThumb.gotoAndStop("Blank")
	mbRetakeShot.addEventListener(FlashEvent.CLICK, retakeShotClicked)
	mbDeleteChar.labelContainer.buttonLabel.text = "Delete Character"
	mbDeleteConfirm.labelContainer.buttonLabel.text = "Confirm"
	mbDeleteCancel.labelContainer.buttonLabel.text = "Cancel"
	mbDeleteChar.addEventListener(FlashEvent.CLICK, deleteClicked)
	mbDeleteConfirm.addEventListener(FlashEvent.CLICK, deleteConfirmClicked)
	mbDeleteCancel.addEventListener(FlashEvent.CLICK, deleteCancelClicked)
	charNameTF.addEventListener(FlashEvent.FOCUS_IN, textFieldFocusIn)
	charNameTF.addEventListener(FlashEvent.FOCUS_OUT, textFieldFocusOut)
	filePathsContainer = FlashSprite.new()
	filePathsScroller = ScrollingArea.new(350, 70, filePathsContainer, 10)
	filePathsScroller.x = 146
	filePathsScroller.y = 5
	addChild(filePathsScroller)
	defaultFoldersContainer = FlashSprite.new()
	defaultFoldersAdd = Flash.create("MenuAddButton")
	defaultFoldersAdd.x = 235
	defaultFoldersAdd.y = 14
	defaultFoldersContainer.addChild(defaultFoldersAdd)
	defaultFoldersAdd.addEventListener(FlashEvent.CLICK, addDefaultFolderClicked)
	defaultFoldersScroller = ScrollingArea.new(248, 61, defaultFoldersContainer, 10)
	defaultFoldersScroller.x = 248
	defaultFoldersScroller.y = 80
	addChild(defaultFoldersScroller)


func _addPathEntry(kind: String, pkg: LoadedModPackage, row: int) -> void:
	var e := ModFilePathEntry.new(kind, pkg)
	e.y = row * 20
	filePathsContainer.addChild(e)
	filePaths.append(e)
	e.addEventListener("UPDATED", filePathUpdated)


func populateMods() -> void:
	for e in filePaths:
		e.removeEventListener("UPDATED", filePathUpdated)
		e.kill()
	filePaths = []
	var row := 0
	if g.customElementLoader.proxyHairPackage:
		_addPathEntry("Hair", g.customElementLoader.proxyHairPackage, row)
		row += 1
	if g.customElementLoader.proxyBGPackage:
		_addPathEntry("BG", g.customElementLoader.proxyBGPackage, row)
		row += 1
	for pkg in g.customElementLoader.getLoadedModPackages():
		_addPathEntry("Swf", pkg, row)
		row += 1
	checkPathStatus()
	filePathsScroller.updateContent()


func addDefaultFolder(f: String, removeEmpty: bool = false) -> void:
	if removeEmpty:
		while g.defaultModFolders.has(""):
			g.defaultModFolders.erase("")
	g.defaultModFolders.append(f)
	populateDefaultFolders()


func populateDefaultFolders() -> void:
	for e in defaultFolders:
		e.kill()
	defaultFolders = []
	var row := 0
	for f in g.defaultModFolders:
		var e := FolderPathEntry.new(f)
		e.addEventListener("DELETE_CLICKED", deleteDefaultFolderClicked)
		e.addEventListener("UPDATED", defaultFoldersUpdated)
		e.addEventListener("ENTER_PRESSED", defaultFolderEntered)
		e.y = row * 20
		defaultFoldersContainer.addChild(e)
		defaultFolders.append(e)
		row += 1
	defaultFoldersAdd.y = row * 20 + 14
	defaultFoldersScroller.updateContent()


func defaultFoldersUpdated(_e = null) -> void:
	g.defaultModFolders = []
	for e in defaultFolders:
		g.defaultModFolders.append(e.folderPath)


func defaultFolderEntered(_e = null) -> void:
	g.saveData.saveFolders()
	for e in filePaths:
		e.recheckWithFolders()


func addDefaultFolderClicked(_e = null) -> void:
	addDefaultFolder("", true)
	defaultFoldersScroller.scrollTo(1)
	stage.focus = defaultFolders[defaultFolders.size() - 1].pathTF


func deleteDefaultFolderClicked(e: FlashEvent) -> void:
	deletingDefaultFolderLine = true
	var path: String = e.target.pathTF.text
	var i: int = g.defaultModFolders.find(path)
	if i != -1:
		g.defaultModFolders.remove_at(i)
		populateDefaultFolders()
	g.saveData.saveFolders()


var deletingFolderLine: bool:
	get:
		if deletingDefaultFolderLine:
			deletingDefaultFolderLine = false
			return true
		return false


func filePathUpdated(_e = null) -> void:
	checkPathStatus()


func textFieldFocusIn(_e = null) -> void:
	g.inTextField = true


func textFieldFocusOut(_e = null) -> void:
	g.inTextField = false


func _showShot(data: FlashBitmapData) -> void:
	if haveCharShot:
		charThumb.removeChild(charShot)
	charShotData = data
	charShot = FlashBitmap.new(charShotData, "auto", true)
	charThumb.addChild(charShot)
	haveCharShot = true


func retakeShotClicked(_e = null) -> void:
	_showShot(g.generateCharacterShot())


func deleteClicked(_e = null) -> void:
	mbDeleteChar.visible = false
	mbDeleteConfirm.visible = true
	mbDeleteCancel.visible = true
	setStatus("Are you sure?", 3, true)


func deleteConfirmClicked(_e = null) -> void:
	if editingChar:
		g.inGameMenu.characterMenu.deleteChar(charBeingEdited)
		dispatchEvent(FlashEvent.new("CHAR_DELETED"))


func deleteCancelClicked(_e = null) -> void:
	mbDeleteChar.visible = true
	mbDeleteConfirm.visible = false
	mbDeleteCancel.visible = false
	setStatus("", 3, true)


func setEditing(editing: bool, c: CustomCharacter = null) -> void:
	editingChar = editing
	if editing:
		charNameTF.text = c.charName
		_showShot(c.charShot)
		charData = c.charData
		charBeingEdited = c
		mbStoreChar.labelContainer.buttonLabel.text = "Update Character"
		mbDeleteChar.visible = true
	else:
		mbStoreChar.labelContainer.buttonLabel.text = "Save Character"
		mbDeleteChar.visible = false
	mbDeleteConfirm.visible = false
	mbDeleteCancel.visible = false


func setupChar(data: String) -> void:
	charData = data
	_showShot(g.generateCharacterShot())
	if not editingChar:
		charNameTF.text = "Custom Name"
		mbStoreChar.labelContainer.buttonLabel.text = "Save Character"
		mbDeleteChar.visible = false
		mbDeleteConfirm.visible = false
		mbDeleteCancel.visible = false
	setStatus("", 3, true)
	checkPathStatus()


func setStatus(s: String, priority: int, force: bool = false) -> void:
	if force or priority <= currentStatusPriority:
		statusTF.text = s
		currentStatusPriority = priority


func checkPathStatus() -> void:
	allPathsFound = true
	for e in filePaths:
		if not e.pathOkay:
			allPathsFound = false
	mbStoreChar.visible = allPathsFound
	if allPathsFound:
		setStatus("All paths found successfully.", 1)
	else:
		setStatus("Please enter missing paths manually.", 1)


func haveModType(t: String) -> bool:
	for e in filePaths:
		if e.modType == t and e.pathOkay:
			return true
	return false


func storeCharClicked(_e = null) -> void:
	if not allPathsFound:
		return
	if editingChar:
		var hasHair := haveModType("Hair")
		var hasBG := haveModType("BG")
		var parts: Array = Array(charData.split(";"))
		var n := parts.size()
		var i := 0
		while i < n:
			var kv: PackedStringArray = str(parts[i]).split(":")
			if hasHair and kv[0] == "customHair":
				parts.remove_at(i)
				i -= 1
				n -= 1
			if hasBG and kv[0] == "customBG":
				parts.remove_at(i)
				i -= 1
				n -= 1
			if kv[0] == "swfMod":
				parts.remove_at(i)
				i -= 1
				n -= 1
			i += 1
		charData = ";".join(parts)
		for e in filePaths:
			charData += ";" + e.dataString()
		charBeingEdited.charName = charNameTF.text
		charBeingEdited.charData = charData
		charBeingEdited.giveCharShot(charShotData)
		charBeingEdited.dialogue = g.dialogueControl.exportDialogue()
		g.inGameMenu.characterMenu.updateChar(charBeingEdited)
		dispatchEvent(FlashEvent.new("CHAR_STORED"))
	else:
		for e in filePaths:
			charData += ";" + e.dataString()
		var c := CustomCharacter.new(charNameTF.text, charData)
		c.giveCharShot(charShotData)
		c.dialogue = g.dialogueControl.exportDialogue()
		g.inGameMenu.characterMenu.storeChar(c)
		dispatchEvent(FlashEvent.new("CHAR_STORED"))
