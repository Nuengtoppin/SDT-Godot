class_name Dropdown
extends FlashMovieClip
## Port of obj.ui.Dropdown: label + arrow button that opens an animated, masked, scrolling list of items.
## (Sprite in AS3; a MovieClip here so the DropdownButton / DropdownMenu symbols bind their children.)

var currentSelection: String = ""
var selectedLine: DropdownMenuItem
var showSelectionInLabel := true
var itemLines: Array = []
var lineScroller: ScrollingArea
var windowContainer: FlashSprite
var windowMask: FlashSprite
var lineContainer: FlashSprite
var animateWindow: int = 0
var menuOpen := false
var selectionListeners: Array = []
var arrowButton: FlashDisplayObject
var _dropdownWindow: FlashDisplayObject
var _dropdownLabel: FlashTextField

var selection: String:
	get: return currentSelection


func _init() -> void:
	arrowButton = getArrowButton()
	_dropdownWindow = getDropdownWindow()
	_dropdownLabel = getDropdownLabel()
	_dropdownWindow.visible = true
	_dropdownLabel.mouseEnabled = false
	arrowButton.addEventListener(FlashEvent.CLICK, arrowClicked)
	windowContainer = FlashSprite.new()
	windowContainer.x = _dropdownWindow.x
	windowContainer.y = _dropdownWindow.y
	_dropdownWindow.x = 0
	_dropdownWindow.y = 0
	removeChild(_dropdownWindow)
	windowContainer.addChild(_dropdownWindow)
	lineContainer = FlashSprite.new()
	windowContainer.addChild(lineContainer)
	windowMask = FlashSprite.new()
	windowMask.graphics.beginFill(0, 1)
	windowMask.graphics.drawRect(0, 0, windowContainer.width + 20, 100)
	windowMask.x = windowContainer.x - 10
	windowMask.y = windowContainer.y
	windowMask.height = 1
	addChild(windowMask)
	windowContainer.mask = windowMask
	addChild(windowContainer)
	windowContainer.alpha = 0
	addEventListener(FlashEvent.ENTER_FRAME, tick)


func getArrowButton() -> FlashDisplayObject:
	return get("dropdownButton")


func getDropdownWindow() -> FlashDisplayObject:
	return get("dropdownWindow")


func getDropdownLabel() -> FlashTextField:
	return get("dropdownLabel")


func tick() -> void:
	if animateWindow == 1:
		windowContainer.alpha = minf(1, windowContainer.alpha + 0.2)
		windowMask.height += maxf(5, (windowContainer.height + 10 - windowMask.height) * 0.5)
		if windowContainer.alpha == 1 and windowMask.height > windowContainer.height + 9:
			windowMask.height = windowContainer.height + 10
			animateWindow = 0
	elif animateWindow == -1:
		windowContainer.alpha = maxf(0, windowContainer.alpha - 0.2)
		windowMask.height += minf(-5, (1 - windowMask.height) * 0.5)
		if windowContainer.alpha == 0 and windowMask.height < 2:
			windowMask.height = 1
			animateWindow = 0


func addSelectionListener(fn: Callable) -> void:
	selectionListeners.append(fn)


func setLabel(s: String, fixed: bool = false) -> void:
	_dropdownLabel.text = s
	showSelectionInLabel = not fixed


func setItems(items: Array) -> void:
	for l in itemLines:
		lineContainer.removeChild(l)
	itemLines = []
	var n := items.size()
	for i in n:
		var l := DropdownMenuItem.new(str(items[i]), itemClicked)
		l.y = 20 * i
		lineContainer.addChild(l)
		itemLines.append(l)
	_dropdownWindow.height = 20 * mini(10, n)
	if not lineScroller:
		lineScroller = ScrollingArea.new(_dropdownWindow.width - 5, _dropdownWindow.height, lineContainer)
		windowContainer.addChild(lineScroller)
	lineScroller.updateContent()


func select(s: String) -> void:
	if showSelectionInLabel:
		_dropdownLabel.text = s
	for l in itemLines:
		if l.labelText == s:
			l.select()
			selectedLine = l
			currentSelection = l.labelText
		else:
			l.select(false)


func arrowClicked(_e = null) -> void:
	if menuOpen:
		closeMenu()
	else:
		openMenu()


func itemClicked(item: DropdownMenuItem) -> void:
	currentSelection = item.labelText
	selectedLine = item
	closeMenu()
	if showSelectionInLabel:
		_dropdownLabel.text = item.labelText
		for l in itemLines:
			l.select(false)
		item.select(true)
	for fn in selectionListeners:
		fn.call(currentSelection)


func globalClick(e: FlashEvent) -> void:
	if not contains(e.target):
		closeMenu()


func openMenu() -> void:
	if not menuOpen:
		animateWindow = 1
		menuOpen = true
		if selectedLine:
			lineScroller.jumpTo(selectedLine)
		stage.addEventListener(FlashEvent.CLICK, globalClick)


func closeMenu() -> void:
	if menuOpen:
		animateWindow = -1
		stage.removeEventListener(FlashEvent.CLICK, globalClick)
		menuOpen = false
