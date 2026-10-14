class_name CharacterMenu
extends FlashMovieClip
## Port of obj.CharacterMenu: the horizontally scrolling strip of character thumbnails (built-in and stored),
## with search, drag-to-reorder and inertial scrolling.

const SCROLL_AREA_SIZE := 548.0
const SPACING := 105.0

var thumbLayer: FlashMovieClip
var scrollBar: FlashMovieClip
var searchTF: FlashTextField
var closeButton
var mbResetSearch
var scrollArea: FlashMovieClip
var menuButton
var buttonCharShot: FlashBitmap
var showingStoredCharShot := false
var baseLength: int = 0
var baseCharOrder: Array = []
var storedCharsStart: int = 0
var charNames: Array
var chars: int = 0
var charRange: int = 0
var thumbs: Array = []
var selected: CharacterMenuItem = null
var lastSelectedID: int = 0
var scrollTarget: float = 0.0
var scrollPos: float = 0.0
var scrollSpeed: float = 0.0
var inertialScrolling := false
var draggingScroll := false
var dragOffset: float = 0.0
var thumbTarget: Dictionary = {}
var draggedThumb: CharacterMenuItem
var draggingThumb := false
var dragDelay: int = 0
var dragStartPos := Vector2()
var thumbDragOffset := Vector2()
var draggingDropShadow: FlashFilter
var searchThumbTarget: Dictionary = {}
var searching := false
var searchRange: int = 0
var cancelCharSelect := false


func _init() -> void:
	super()
	charNames = g.characterControl.getCharacterList()
	draggingDropShadow = FlashFilter.dropShadow(0, 0, 9030, 1, 6, 6, 1, 3)
	scrollBar.addEventListener(FlashEvent.MOUSE_DOWN, scrollDragged)
	scrollArea.addEventListener(FlashEvent.CLICK, scrollAreaClicked)
	searchTF.addEventListener(FlashEvent.CHANGE, searchChanged)
	searchTF.addEventListener(FlashEvent.CLICK, searchFieldClicked)
	searchTF.addEventListener(FlashEvent.FOCUS_IN, textFieldFocusIn)
	searchTF.addEventListener(FlashEvent.FOCUS_OUT, textFieldFocusOut)
	mbResetSearch.addEventListener(FlashEvent.CLICK, resetSearch)
	searchTF.restrict = "A-Z a-z 0-9 !?"
	addEventListener(FlashEvent.ROLL_OVER, rolledOver)
	addEventListener(FlashEvent.ROLL_OUT, rolledOut)
	addEventListener(FlashEvent.ADDED_TO_STAGE, addedToStage)
	addEventListener(FlashEvent.ENTER_FRAME, tick)


func addedToStage(_e = null) -> void:
	removeEventListener(FlashEvent.ADDED_TO_STAGE, addedToStage)
	stage.addEventListener(FlashEvent.MOUSE_UP, mouseReleased)
	stage.addEventListener(FlashEvent.MOUSE_MOVE, mouseMoved)


func rolledOver(_e = null) -> void:
	g.overScrollArea = self


func rolledOut(_e = null) -> void:
	if g.overScrollArea == self:
		g.overScrollArea = null


func _range() -> float:
	return float(mini(searchRange, charRange))


func mouseWheelScroll(d: float) -> void:
	scrollBar.x = maxf(1, minf(SCROLL_AREA_SIZE + 1, scrollBar.x - d * 2))
	scrollPos = (scrollBar.x - 1) / SCROLL_AREA_SIZE
	scrollTarget = scrollPos
	thumbLayer.x = _range() * -SPACING * scrollPos + 19
	scrollBar.x = scrollPos * SCROLL_AREA_SIZE + 1


func textFieldFocusIn(_e = null) -> void:
	g.inTextField = true


func textFieldFocusOut(_e = null) -> void:
	g.inTextField = false


func searchChanged(_e = null) -> void:
	if searchTF.text == "":
		resetSearch()
	else:
		if not searching:
			searching = true
			searchRange = charRange
		setSearchThumbTargets()


func searchFieldClicked(_e = null) -> void:
	searchTF.setSelection(0, searchTF.text.length())


func resetSearch(_e = null) -> void:
	searching = false
	searchRange = charRange
	searchTF.text = ""
	for t in thumbs:
		t.visible = true
		t.x = thumbTarget[t]


func instanceBaseChars(names: Array) -> void:
	var n := names.size()
	setBaseLength(n)
	storedCharsStart = baseLength
	thumbs = []
	for i in n:
		var item := CharacterMenuItem.new()
		item.setBaseChar(i)
		item.editButton.visible = false
		if g.characterControl.characters[i].defaultCostume != "":
			item.costumeButton.addEventListener(FlashEvent.CLICK, getBaseCharCostumeHandler(i))
		else:
			item.costumeButton.visible = false
		item.x = i * SPACING
		item.itemLabel.text = names[i]
		item.thumb.gotoAndStop(names[i])
		thumbLayer.addChild(item)
		item.hitbox.addEventListener(FlashEvent.CLICK, getBaseCharHandler(i))
		thumbs.append(item)
		thumbTarget[item] = item.x
		SaveData._setAt(baseCharOrder, i, i)
		item.hitbox.addEventListener(FlashEvent.MOUSE_DOWN, thumbPressed)


func getBaseCharHandler(id: int) -> Callable:
	return func(_e = null):
		if cancelCharSelect:
			cancelCharSelect = false
		else:
			g.customElementLoader.cancelLoading()
			g.characterControl.setChar(id)


func getBaseCharCostumeHandler(id: int) -> Callable:
	return func(_e = null):
		g.customElementLoader.cancelLoading()
		g.inGameMenu.onlyLoadingCostume = true
		g.inGameMenu.loadData(g.characterControl.characters[id].defaultCostume)
		g.inGameMenu.onlyLoadingCostume = false


func getStoredCharHandler(c: CustomCharacter) -> Callable:
	return func(_e = null):
		g.characterControl.loadStoredChar(c.ID)


func thumbPressed(e: FlashEvent) -> void:
	draggedThumb = e.currentTarget.parent
	dragDelay = 10
	dragStartPos = Vector2(mouseX, mouseY)
	thumbDragOffset = Vector2(draggedThumb.mouseX, draggedThumb.mouseY)
	cancelCharSelect = false


func mouseMoved(_e = null) -> void:
	if draggedThumb and not draggingThumb and (absf(mouseX - dragStartPos.x) > 5 or absf(mouseY - dragStartPos.y) > 5):
		startThumbDrag()


func setThumbTargets() -> void:
	thumbs.sort_custom(func(a, b): return a.x < b.x)
	var pos := 0.0
	for t in thumbs:
		thumbTarget[t] = pos
		pos += SPACING


func setSearchThumbTargets() -> void:
	var re := RegEx.create_from_string("(?i)" + searchTF.text)
	for t in thumbs:
		searchThumbTarget[t] = thumbTarget[t]
		t.visible = re != null and re.is_valid() and re.search(t.charName) != null
	var pos := 0.0
	searchRange = 0
	for t in thumbs:
		searchThumbTarget[t] = pos
		pos += SPACING if t.visible else 0.0
		searchRange += 1 if t.visible else 0
	scrollTarget = 0
	scrollPos = 0
	searchRange = maxi(0, searchRange - 6)


func startThumbDrag() -> void:
	if not searching:
		draggedThumb.parent.setChildIndex(draggedThumb, draggedThumb.parent.numChildren - 1)
		draggingThumb = true
		draggedThumb.filters = [draggingDropShadow]
	else:
		resetSearch()


func giveButton(b) -> void:
	menuButton = b


func storeChar(c: CustomCharacter, doSelect: bool = true, save: bool = true) -> void:
	resetSearch()
	g.storedChars.append(c)
	c.ID = g.storedChars.size() - 1
	setLength(chars + 1)
	var item := CharacterMenuItem.new()
	item.x = thumbs.size() * SPACING
	item.itemLabel.text = c.charName
	item.setCustomChar(c)
	c.menuPosition = thumbs.size()
	item.editButton.visible = true
	item.costumeButton.visible = false
	item.editButton.addEventListener(FlashEvent.CLICK, getEditCharFunc(c))
	if c.charShot != null:
		item.giveCharShot(FlashBitmap.new(c.charShot, "auto", true))
	else:
		item.thumb.gotoAndStop("Custom")
	thumbLayer.addChild(item)
	item.hitbox.addEventListener(FlashEvent.CLICK, getStoredCharHandler(c))
	item.hitbox.addEventListener(FlashEvent.MOUSE_DOWN, thumbPressed)
	thumbs.append(item)
	thumbTarget[item] = item.x
	if doSelect:
		select(g.storedChars.size() - 1, false, true)
	if save:
		g.saveData.saveCustomChar(g.storedChars.size() - 1)


func updateChar(c: CustomCharacter) -> void:
	for t in thumbs:
		if not t.isBaseChar and t.customChar == c:
			t.giveCharShot(FlashBitmap.new(c.charShot, "auto", true))
			t.itemLabel.text = c.charName
			break
	g.characterControl.loadStoredChar(c.ID)
	g.saveData.saveCustomChar(c.ID)


func deleteChar(c: CustomCharacter) -> void:
	resetSearch()
	for t in thumbs:
		if not t.isBaseChar and t.customChar == c:
			thumbLayer.removeChild(t)
			thumbs.erase(t)
			break
	g.storedChars.remove_at(c.ID)
	for i in range(c.ID, g.storedChars.size()):
		g.storedChars[i].ID -= 1
	setThumbTargets()
	setLength(chars - 1)
	g.saveData.deleteStoredChar(c.ID)


func getEditCharFunc(c: CustomCharacter) -> Callable:
	return func(_e = null):
		g.inGameMenu.editChar(c)
		cancelCharSelect = true


func clearStoredChars() -> void:
	setLength(baseLength)
	for t in thumbs.duplicate():
		if not t.isBaseChar:
			thumbLayer.removeChild(t)
			thumbs.erase(t)
	setThumbTargets()
	g.storedChars = []


func loadCustomChars(list: Array, save: bool = true) -> void:
	storedCharsStart = thumbs.size() - 1
	for o in list:
		var c := CustomCharacter.new(str(o.get("name", "")), str(o.get("data", "")))
		if o.get("dialogue") != null:
			c.dialogue = str(o["dialogue"])
		var bytes = o.get("shotBytes")
		if bytes is PackedByteArray and bytes.size() > 0:
			var raw: PackedByteArray = bytes.decompress(70 * 60 * 4, FileAccess.COMPRESSION_DEFLATE)
			if raw.size() == 70 * 60 * 4:
				var bd := FlashBitmapData.new(70, 60)
				bd.setPixels(Rect2i(0, 0, 70, 60), raw)
				c.giveCharShot(bd)
		storeChar(c, false, false)
	if save:
		g.saveData.clearStoredChars()
		for i in g.storedChars.size():
			g.saveData.saveCustomChar(i)
		scrollToStoredChars()


func updateCharOrder(baseOrder: Array, customOrder = null) -> void:
	var n: int = g.storedChars.size()
	if customOrder is Array and n == customOrder.size():
		for i in n:
			g.storedChars[i].menuPosition = int(customOrder[i])
	var extra: Array = []
	if baseLength >= baseOrder.size():
		for t in thumbs:
			if t.isBaseChar:
				if t.baseCharID < baseOrder.size():
					t.x = int(baseOrder[t.baseCharID]) * SPACING
				else:
					extra.append(t)
			else:
				t.x = t.customChar.menuPosition * SPACING
	var k := 1
	for t in extra:
		t.x = (baseLength - extra.size() + k) * SPACING
		k += 1
	setThumbTargets()


func getCharOrderObject() -> Dictionary:
	var custom: Array = []
	for c in g.storedChars:
		custom.append(c.menuPosition)
	return {"baseCharOrder": baseCharOrder, "customCharOrder": custom}


func setBaseLength(n: int) -> void:
	baseLength = n
	setLength(baseLength)


func setLength(n: int) -> void:
	chars = n
	charRange = maxi(0, chars - 6)
	searchRange = charRange


func scrollToStoredChars() -> void:
	if g.storedChars.size() > 0:
		scrollTo(storedCharsStart)


func select(id: int, custom: bool = false, stored: bool = false) -> void:
	if showingStoredCharShot:
		menuButton.thumb.removeChild(buttonCharShot)
		showingStoredCharShot = false
	if custom:
		selected = null
		menuButton.labelContainer.buttonLabel.text = "Custom"
		menuButton.thumb.gotoAndStop("Custom")
	else:
		var idx := 0
		if stored:
			var c: CustomCharacter = g.storedChars[id]
			menuButton.labelContainer.buttonLabel.text = c.charName
			if c.haveCharShot:
				menuButton.thumb.gotoAndStop("Blank")
				buttonCharShot = FlashBitmap.new(c.charShot, "auto", true)
				menuButton.thumb.addChild(buttonCharShot)
				showingStoredCharShot = true
			else:
				menuButton.thumb.gotoAndStop("Custom")
			for t in thumbs:
				if not t.isBaseChar and t.customChar == c:
					idx = thumbs.find(t)
					break
		else:
			menuButton.labelContainer.buttonLabel.text = charNames[id]
			menuButton.thumb.gotoAndStop(charNames[id])
			for t in thumbs:
				if t.isBaseChar and t.baseCharID == id:
					idx = thumbs.find(t)
					break
		scrollTo(idx)
		lastSelectedID = idx
		selected = thumbs[idx]
	for t in thumbs:
		if t == selected:
			t.select()
		else:
			t.deselect()


func selectNextCharacter() -> void:
	resetSearch()
	lastSelectedID += 1
	if lastSelectedID >= thumbs.size():
		lastSelectedID = 0
	triggerSelect(lastSelectedID)


func selectPrevCharacter() -> void:
	resetSearch()
	if lastSelectedID > 0:
		lastSelectedID -= 1
	else:
		lastSelectedID = thumbs.size() - 1
	triggerSelect(lastSelectedID)


func triggerSelect(i: int) -> void:
	if thumbs[i].isBaseChar:
		g.customElementLoader.cancelLoading()
		g.characterControl.setChar(thumbs[i].baseCharID)
	else:
		g.characterControl.loadStoredChar(thumbs[i].customChar.ID)


func scrollTo(i: int) -> void:
	scrollTarget = (i - 2.57) / _range()
	scrollTarget = maxf(0, minf(1, scrollTarget))
	scrollSpeed = 0
	inertialScrolling = false


func scrollDragged(_e = null) -> void:
	draggingScroll = true
	dragOffset = mouseX - scrollBar.x


func mouseReleased(_e = null) -> void:
	draggingScroll = false
	inertialScrolling = true
	if draggedThumb:
		cancelCharSelect = draggingThumb
		draggedThumb.filters = []
		draggedThumb = null
		draggingThumb = false
		setThumbTargets()
		saveOrder()


func saveOrder() -> void:
	for i in thumbs.size():
		if thumbs[i].isBaseChar:
			SaveData._setAt(baseCharOrder, thumbs[i].baseCharID, i)
		else:
			thumbs[i].customChar.menuPosition = i
	g.saveData.saveCharacterListOrder(baseCharOrder)


func scrollAreaClicked(_e = null) -> void:
	var p := maxf(1, minf(SCROLL_AREA_SIZE + 1, mouseX - scrollBar.width / 2))
	scrollTarget = (p - 1) / SCROLL_AREA_SIZE
	scrollSpeed = 0
	inertialScrolling = false


func tick() -> void:
	if draggingScroll:
		var prev := scrollPos
		scrollBar.x = maxf(1, minf(SCROLL_AREA_SIZE + 1, mouseX - dragOffset))
		scrollPos = (scrollBar.x - 1) / SCROLL_AREA_SIZE
		scrollSpeed = scrollPos - prev
		scrollTarget = scrollPos
		thumbLayer.x = _range() * -SPACING * scrollPos + 19
	else:
		scrollPos += (scrollTarget - scrollPos) * 0.25
		if inertialScrolling:
			scrollPos = maxf(0, minf(1, scrollPos + scrollSpeed))
			scrollTarget = scrollPos
			scrollSpeed *= 0.5
		thumbLayer.x = _range() * -SPACING * scrollPos + 19
		scrollBar.x = scrollPos * SCROLL_AREA_SIZE + 1
	if draggingThumb:
		draggedThumb.x = draggedThumb.parent.mouseX - thumbDragOffset.x
		if mouseX > SCROLL_AREA_SIZE - 50:
			scrollSpeed = 0.2 / thumbs.size() * minf(1, (mouseX - SCROLL_AREA_SIZE + 50) / 50)
		elif mouseX < 50:
			scrollSpeed = -0.2 / thumbs.size() * minf(1, (50 - mouseX) / 50)
		setThumbTargets()
	elif draggedThumb:
		if dragDelay > 0:
			dragDelay -= 1
		else:
			startThumbDrag()
			setThumbTargets()
	for t in thumbs:
		if searching:
			t.x += (searchThumbTarget[t] - t.x) * 0.8
		elif t != draggedThumb:
			t.x += (thumbTarget[t] - t.x) * 0.3
