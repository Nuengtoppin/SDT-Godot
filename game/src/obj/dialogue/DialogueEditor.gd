class_name DialogueEditor
extends FlashMovieClip
## Port of obj.dialogue.DialogueEditor: the in-game dialogue editor (line list, toolbar of dropdowns, preview,
## log, help, save / load to text files).

const EDIT_WILDCARDS := "Edit wildcards..."
const EDIT_DIALOGUE := "Edit dialogue..."
const ADD_CUSTOM := "Add custom..."
const MOOD_DEFAULT := "Mood..."
const MOOD_CANCEL := "(CANCEL)"
const NEXT_LINE_DEFAULT := "Trigger line..."
const NEXT_LINE_CANCEL := "(CANCEL)"
const HELD_DEFAULT := "Held..."
const HELD_CANCEL := "(CANCEL)"
const INT_MAX := 2147483647

var help: FlashMovieClip
var toolbar: FlashMovieClip
var mbDeleteLine
var lineLayer: FlashMovieClip
var previewFrame: FlashMovieClip
var wildcardDropdown
var mbSortLines
var mbToggleEditMode
var mbLog
var filterField: FlashTextField
var mbSave
var dialogueLog: FlashMovieClip
var mbAddLine
var dialogueLibraryName: FlashTextField
var actionDropdown
var closeButton
var drawerArrow: FlashMovieClip
var mbResetFilter
var mbHelp
var mbLoad
var lineContainer: FlashSprite
var lineScroller: ScrollingArea
var helpScroller: ScrollingArea
var logScroller: ScrollingArea
var logCount: int = 0
## The log is kept as lines and joined when shown (appending to one growing string made every dialogue load slower).
var _logLines := PackedStringArray()
var logCache: String:
	get:
		return "\n".join(_logLines)
var editingWildcards := false
var lines: Array = []
var selectedLines: Array = []
var lastSelectedLine: int = -1
var standardTriggers: Array
var wildcardTriggers: Array
var customTriggers: Array = []
var customFinishes: Array = []
var gameQuality: int = 0
var slideDown := false
var slideUp := false
var lineToSpeak: DialogueEditorLine
var selectedTrigger: String = ""
var selectedStyle: String = ""
var selectedNextLine: String = ""
var selectedMood: String = ""
var selectedHeld: String = ""
var dialogueFile: FlashFileReference
var savingDialogue := false
var browsingForDialogue := false


func _init() -> void:
	super()
	lineContainer = FlashSprite.new()
	addChild(lineContainer)
	helpScroller = ScrollingArea.new(645, 450, help)
	helpScroller.x = 25
	helpScroller.y = 75
	addChild(helpScroller)
	helpScroller.visible = false
	var hc := Flash.create("PickerCloseButton")
	hc.x = 637
	hc.y = 8
	helpScroller.addChild(hc)
	hc.addEventListener(FlashEvent.CLICK, helpClicked)
	logScroller = ScrollingArea.new(645, 450, dialogueLog)
	logScroller.x = 25
	logScroller.y = 75
	addChild(logScroller)
	logScroller.visible = false
	var lc := Flash.create("PickerCloseButton")
	lc.x = 637
	lc.y = 8
	logScroller.addChild(lc)
	lc.addEventListener(FlashEvent.CLICK, logClicked)
	toolbar.mouseEnabled = false
	toolbar.mouseChildren = false
	standardTriggers = DialogueLibrary.allDialogueTypes.duplicate()
	standardTriggers.erase(Dialogue.COUGH)
	standardTriggers.erase(Dialogue.INTERRUPT)
	wildcardTriggers = [Dialogue.COUGH, Dialogue.INTERRUPT, "finish1", "finish2", "finish3", "finish4", "finish5",
		"finish6", "finish7", "finish8", "finish9", "finish10", "finishOther"]
	actionDropdown.setLabel("Insert Action...", true)
	actionDropdown.setItems(["SWALLOW", "DROOL", "COUGH", "CLENCH_TEETH", "SHOCK", "WINCE", "CLOSE_EYES", "OPEN_EYES",
		"BLINK", "LOOK_UP", "LOOK_DOWN", "ADD_TEARS", "TAP_HANDS", "EJACULATE", "NORMAL_STYLE", "FACE_FUCK_STYLE",
		"NORMAL_MOOD", "HAPPY_MOOD", "ANGRY_MOOD", "AHEGAO_MOOD", "HOLD", "RELEASE", "ARMS_BACK", "ARMS_LEGS",
		"ARMS_HIS_LEGS", "ARMS_HAND_JOB", "ARMS_LOOSE", "LEFT_ARM_BACK", "LEFT_ARM_LEGS", "LEFT_ARM_HIS_LEGS",
		"LEFT_ARM_HAND_JOB", "LEFT_ARM_LOOSE", "RIGHT_ARM_BACK", "RIGHT_ARM_LEGS", "RIGHT_ARM_HIS_LEGS",
		"RIGHT_ARM_HAND_JOB", "RIGHT_ARM_LOOSE"])
	actionDropdown.addSelectionListener(actionSelected)
	wildcardDropdown.setLabel("Insert Wildcard...", true)
	wildcardDropdown.setItems(["FINISHES", "YOUR", "YOU", "ME", "MY"])
	wildcardDropdown.addSelectionListener(wildcardSelected)
	toolbar.triggerDropdown.setLabel("Trigger", false)
	toolbar.triggerDropdown.addSelectionListener(triggerSelected)
	toolbar.styleDropdown.setLabel("Style", false)
	toolbar.styleDropdown.setItems([DialogueLine.SPEAKING_STYLE, DialogueLine.THOUGHT_STYLE, DialogueLine.HIM_STYLE])
	toolbar.styleDropdown.addSelectionListener(styleSelected)
	toolbar.moodDropdown.setLabel(MOOD_DEFAULT, false)
	toolbar.moodDropdown.setItems([MOOD_CANCEL, Her.NORMAL_MOOD, Her.HAPPY_MOOD, Her.ANGRY_MOOD, Her.AHEGAO_MOOD])
	toolbar.moodDropdown.addSelectionListener(moodSelected)
	toolbar.heldDropdown.setLabel(HELD_DEFAULT, false)
	toolbar.heldDropdown.setItems([HELD_CANCEL, "true", "false"])
	toolbar.heldDropdown.addSelectionListener(heldSelected)
	toolbar.nextLineDropdown.setLabel(NEXT_LINE_DEFAULT, false)
	toolbar.nextLineDropdown.addSelectionListener(nextLineSelected)
	updateTriggerDropdowns()
	wildcardDropdown.setLabel("Insert Wildcard...", true)
	mbToggleEditMode.labelContainer.buttonLabel.text = EDIT_WILDCARDS
	mbToggleEditMode.addEventListener(FlashEvent.CLICK, toggleEditModeClicked)
	mbLog.labelContainer.buttonLabel.text = "Log"
	mbLog.addEventListener(FlashEvent.CLICK, logClicked)
	mbResetFilter.addEventListener(FlashEvent.CLICK, resetFilterClicked)
	filterField.addEventListener(FlashEvent.CHANGE, filterChanged)
	mbSave.labelContainer.buttonLabel.text = "Save..."
	mbSave.addEventListener(FlashEvent.CLICK, saveDialogueClicked)
	mbLoad.labelContainer.buttonLabel.text = "Load..."
	mbLoad.addEventListener(FlashEvent.CLICK, loadDialogueClicked)
	mbHelp.labelContainer.buttonLabel.text = "Help"
	mbHelp.addEventListener(FlashEvent.CLICK, helpClicked)
	visible = false
	closeButton.addEventListener(FlashEvent.CLICK, closeClicked)
	mbDeleteLine.labelContainer.buttonLabel.text = "Delete line"
	mbDeleteLine.addEventListener(FlashEvent.CLICK, deleteClicked)
	mbAddLine.labelContainer.buttonLabel.text = "Add line"
	mbAddLine.addEventListener(FlashEvent.CLICK, addLineClicked)
	mbSortLines.labelContainer.buttonLabel.text = "Sort lines"
	mbSortLines.addEventListener(FlashEvent.CLICK, sortLinesClicked)
	dialogueFile = FlashFileReference.new()
	dialogueFile.start_dir = Flash.mods_dir("Dialogue")
	dialogueFile.addEventListener(FlashEvent.COMPLETE, dialogueCompleteHandler)
	dialogueFile.addEventListener(FlashEvent.SELECT, dialogueSelectHandler)
	dialogueFile.addEventListener(FlashEvent.CANCEL, dialogueCancelHandler)
	addEventListener(FlashEvent.ENTER_FRAME, tick)


func open() -> void:
	visible = true
	g.gamePaused = true
	g.controlLocked = true
	g.inTextField = true
	gameQuality = g.qualitySetting
	g.inGameMenu.setQualityTo(2)
	g.freezeScreen()


func close() -> void:
	outputDialogue()
	for l in lines:
		lineContainer.removeChild(l)
	lines = []
	visible = false
	g.gamePaused = false
	g.controlLocked = false
	g.inTextField = false
	g.inGameMenu.setQualityTo(gameQuality)
	g.thawScreen()
	stage.removeEventListener(FlashEvent.CLICK, globalClick)


func appendLog(s: String, _p2: bool = true) -> void:
	_logLines.append(str(logCount) + ": " + s)
	logCount += 1


func tick() -> void:
	if slideDown:
		y = minf(534, y + 100)
		if y >= 530:
			slideDown = false
			g.dialogueControl.startSpeakingPhrase(lineToSpeak.getDialogueLine())
			stage.addEventListener(FlashEvent.CLICK, globalClick)
			cacheAsBitmap = false
		previewFrame.y = 300 - y
	elif slideUp:
		y = maxf(0, y - 100)
		if y <= 10:
			slideUp = false
			cacheAsBitmap = false
		previewFrame.y = 300 - y


func helpClicked(_e = null) -> void:
	helpScroller.visible = not helpScroller.visible


func logClicked(_e = null) -> void:
	logScroller.visible = not logScroller.visible
	if logScroller.visible:
		dialogueLog.logField.text = logCache
		dialogueLog.logField.height = dialogueLog.logField.textHeight + 10
		dialogueLog.background.height = maxf(450, dialogueLog.logField.height + 40)
		logScroller.updateContent()
		logScroller.scrollTo(1)


func toggleEditModeClicked(_e = null) -> void:
	editingWildcards = not editingWildcards
	updateEditMode()


func updateEditMode() -> void:
	mbToggleEditMode.labelContainer.buttonLabel.text = EDIT_DIALOGUE if editingWildcards else EDIT_WILDCARDS
	lastSelectedLine = -1
	selectedLines = []
	for l in lines:
		l.select(false)
	actionDropdown.visible = not editingWildcards
	wildcardDropdown.visible = not editingWildcards
	toolbar.optionalLabel.visible = not editingWildcards
	toolbar.styleDropdown.visible = not editingWildcards
	toolbar.nextLineDropdown.visible = not editingWildcards
	toolbar.moodDropdown.visible = not editingWildcards
	toolbar.heldDropdown.visible = not editingWildcards
	updateTriggerDropdowns()
	updateLines()
	toolbar.triggerDropdown.setLabel("Trigger", false)


func updateTriggerDropdowns() -> void:
	if editingWildcards:
		var list: Array = wildcardTriggers + customFinishes
		list.sort_custom(func(a, b): return wildcardSort(a, b) < 0)
		toolbar.triggerDropdown.setItems(list + [ADD_CUSTOM])
	else:
		toolbar.triggerDropdown.setItems(getAvailableTriggers() + [ADD_CUSTOM])
	toolbar.nextLineDropdown.setItems([NEXT_LINE_CANCEL] + getAvailableTriggers() + [ADD_CUSTOM])


func getAvailableTriggers() -> Array:
	return standardTriggers + customTriggers


func _inMode(l: DialogueEditorLine) -> bool:
	return (l.wildcard and editingWildcards) or (not l.wildcard and not editingWildcards)


func deleteClicked(_e = null) -> void:
	for l in selectedLines:
		lineContainer.removeChild(l)
		lines.erase(l)
	updateLines()
	lastSelectedLine = mini(lines.size() - 1, lastSelectedLine)
	# port: the original loop only stepped back over lines of the other mode and never exited otherwise (a
	# hang); stop at the first line in the current mode instead.
	while lastSelectedLine > -1 and not _inMode(lines[lastSelectedLine]):
		lastSelectedLine -= 1
	selectLines()
	if lastSelectedLine > -1:
		lineScroller.jumpTo(lines[lastSelectedLine])


func _newLine(src: DialogueLine, trig: String, wildcard: bool = false) -> DialogueEditorLine:
	return DialogueEditorLine.new(src, trig, dialogueLineClicked, lineChanged, wildcard)


func addLineClicked(_e = null) -> void:
	var nl: DialogueEditorLine
	var sel: DialogueEditorLine = null if lastSelectedLine == -1 else lines[lastSelectedLine]
	if sel and _inMode(sel):
		nl = _newLine(null, sel.trigger, editingWildcards)
		if sel.mood:
			nl.mood = sel.mood
		if sel.style:
			nl.style = sel.style
	elif editingWildcards:
		nl = _newLine(null, Dialogue.INTERRUPT, true)
	else:
		nl = _newLine(null, Dialogue.GENERAL)
	lines.append(nl)
	lineContainer.addChild(nl)
	nl.mbPreview.addEventListener(FlashEvent.CLICK, previewClicked)
	_sortLines()
	updateLines()
	lastSelectedLine = lines.find(nl)
	selectLines()
	lineScroller.jumpTo(nl)
	nl.takeFocus()
	updateToolbar()


func _sortLines() -> void:
	lines.sort_custom(func(a, b): return lineSort(a, b) < 0)


func sortLinesClicked(_e = null) -> void:
	_sortLines()
	updateLines()
	if lastSelectedLine != -1 and lastSelectedLine < lines.size():
		lineScroller.jumpTo(lines[lastSelectedLine])


func filterChanged(_e = null) -> void:
	if filterField.text == "":
		for l in lines:
			l.showing = true
	else:
		for l in lines:
			l.showing = l.matchesFilter(filterField.text)
	updateLines()


func resetFilterClicked(_e = null) -> void:
	filterField.text = ""
	for l in lines:
		l.showing = true
	updateLines()


func actionSelected(s: String) -> void:
	if lastSelectedLine < 0:
		return
	lines[lastSelectedLine].insert("[" + s + "]")
	lines[lastSelectedLine].takeFocus()


func wildcardSelected(s: String) -> void:
	if lastSelectedLine < 0:
		return
	lines[lastSelectedLine].insert("*" + s + "*")
	lines[lastSelectedLine].takeFocus()


func triggerSelected(s: String) -> void:
	if s == ADD_CUSTOM:
		var w: TextEntryWindow
		if editingWildcards:
			w = TextEntryWindow.new("Enter finish number:", "Done", customTriggerEntered, "finish")
			w.setMatch(RegEx.create_from_string("finish\\d+"))
		else:
			w = TextEntryWindow.new("Enter trigger name:", "Done", customTriggerEntered)
		w.x = toolbar.triggerDropdown.x + toolbar.x + 75
		w.y = toolbar.triggerDropdown.y + toolbar.y + 51
		addChild(w)
		toolbar.triggerDropdown.select(selectedTrigger)
	else:
		var last: DialogueEditorLine = null
		for l in selectedLines:
			l.trigger = s
			last = l
		_sortLines()
		updateLines()
		if last:
			lineScroller.jumpTo(last)


func customTriggerEntered(s: String) -> void:
	if not standardTriggers.has(s) and not wildcardTriggers.has(s) and not customTriggers.has(s) \
			and not customFinishes.has(s):
		if RegEx.create_from_string("finish(.+)").search(s):
			customFinishes.append(s)
		else:
			customTriggers.append(s)
		toolbar.triggerDropdown.select(s)
		updateTriggerDropdowns()


func styleSelected(s: String) -> void:
	for l in selectedLines:
		l.style = s


func moodSelected(s: String) -> void:
	if s == MOOD_CANCEL:
		for l in selectedLines:
			l.mood = ""
		toolbar.moodDropdown.select(MOOD_DEFAULT)
	else:
		for l in selectedLines:
			l.mood = s


func heldSelected(s: String) -> void:
	if s == HELD_CANCEL:
		for l in selectedLines:
			l.held = ""
		toolbar.heldDropdown.select(HELD_DEFAULT)
	else:
		for l in selectedLines:
			l.held = s


func nextLineSelected(s: String) -> void:
	if s == NEXT_LINE_CANCEL:
		for l in selectedLines:
			l.nextLine = ""
		toolbar.nextLineDropdown.select(NEXT_LINE_DEFAULT)
	elif s == ADD_CUSTOM:
		var w := TextEntryWindow.new("Enter trigger name:", "Done", customTriggerEntered)
		w.x = toolbar.nextLineDropdown.x + toolbar.x + 75
		w.y = toolbar.nextLineDropdown.y + toolbar.y + 51
		addChild(w)
		toolbar.nextLineDropdown.select(NEXT_LINE_DEFAULT)
	else:
		for l in selectedLines:
			l.nextLine = s


func _merge(current: String, v: String) -> String:
	if not current:
		return v
	if current != v:
		return "..."
	return current


func updateToolbar() -> void:
	if selectedLines.size() > 0:
		toolbar.mouseEnabled = true
		toolbar.mouseChildren = true
		toolbar.alpha = 1
		mbDeleteLine.mouseEnabled = true
		mbDeleteLine.alpha = 1
		selectedTrigger = ""
		selectedStyle = ""
		selectedNextLine = ""
		selectedMood = ""
		selectedHeld = ""
		for l in selectedLines:
			selectedTrigger = _merge(selectedTrigger, l.trigger)
			selectedStyle = _merge(selectedStyle, l.style)
			selectedNextLine = _merge(selectedNextLine, l.nextLine)
			selectedMood = _merge(selectedMood, l.mood)
			selectedHeld = _merge(selectedHeld, l.held)
		if not selectedStyle:
			selectedStyle = DialogueLine.SPEAKING_STYLE
		if not selectedNextLine:
			selectedNextLine = NEXT_LINE_DEFAULT
		if not selectedMood:
			selectedMood = MOOD_DEFAULT
		if not selectedHeld:
			selectedHeld = HELD_DEFAULT
		toolbar.triggerDropdown.select(selectedTrigger)
		toolbar.styleDropdown.select(selectedStyle)
		toolbar.nextLineDropdown.select(selectedNextLine)
		toolbar.moodDropdown.select(selectedMood)
		toolbar.heldDropdown.select(selectedHeld)
	else:
		toolbar.mouseEnabled = false
		toolbar.mouseChildren = false
		toolbar.alpha = 0.5
		mbDeleteLine.mouseEnabled = false
		mbDeleteLine.alpha = 0.5


func closeClicked(_e = null) -> void:
	close()


func showDialogue(dialogue: Dictionary, fin: Dictionary) -> void:
	lastSelectedLine = -1
	for l in lines:
		if lineContainer.parent:
			lineContainer.removeChild(l)
	lines = []
	if not lineScroller:
		lineScroller = ScrollingArea.new(645, 290, lineContainer)
		lineLayer.addChild(lineScroller)
	customTriggers = []
	customFinishes = []
	for k in dialogue:
		if dialogue[k] == null:
			continue
		for src in dialogue[k]:
			var wild: bool = k == Dialogue.COUGH or k == Dialogue.INTERRUPT
			var l := _newLine(src, k, wild)
			lines.append(l)
			lineContainer.addChild(l)
			if not wild and not standardTriggers.has(k) and not customTriggers.has(k):
				customTriggers.append(k)
			if not wild:
				l.mbPreview.addEventListener(FlashEvent.CLICK, previewClicked)
	for k in fin:
		for src in fin[k]:
			var n := AS3.Number(k)
			var t := "finish" + str(k)
			if not customFinishes.has(t) and not wildcardTriggers.has(t) and n > 10:
				customFinishes.append(t)
			var l := _newLine(src, t, true)
			lines.append(l)
			lineContainer.addChild(l)
			l.finish = true
	editingWildcards = false
	_sortLines()
	dialogueLibraryName.text = g.dialogueControl.getCurrentLibraryName()
	selectedLines = []
	updateToolbar()
	updateEditMode()


func updateLines() -> void:
	var n := lines.size()
	var shown := 0
	var ypos := 0.0
	for i in n:
		var l: DialogueEditorLine = lines[i]
		if l.showing and _inMode(l):
			l.y = ypos + 1
			l.visible = true
			lineContainer.setChildIndex(l, n - 1 - shown)
			ypos += l.lineHeight
			shown += 1
		else:
			l.y = 0
			l.visible = false
			lineContainer.setChildIndex(l, 0)
	lineScroller.updateContent()


func _sortKey(trigger: String) -> int:
	var i := standardTriggers.find(trigger)
	if i == -1:
		if trigger.contains("finish"):
			var n := AS3.Number(trigger.replace("finish", ""))
			i = 0 if is_nan(n) else int(n)
		else:
			i = INT_MAX
	return i


func lineSort(a: DialogueEditorLine, b: DialogueEditorLine) -> int:
	var ka := _sortKey(a.trigger)
	var kb := _sortKey(b.trigger)
	if ka > kb:
		return 1
	if ka < kb:
		return -1
	if a.trigger > b.trigger:
		return 1
	if a.trigger < b.trigger:
		return -1
	if a.phrase > b.phrase or (a.phrase == "" and b.phrase != ""):
		return 1
	if a.phrase < b.phrase or (a.phrase != "" and b.phrase == ""):
		return -1
	if a.id > b.id:
		return 1
	if a.id < b.id:
		return -1
	return 0


func wildcardSort(a: String, b: String) -> int:
	var ka := -1
	var kb := -1
	if a.contains("finish"):
		var n := AS3.Number(a.replace("finish", ""))
		ka = 0 if is_nan(n) else int(n)
	if b.contains("finish"):
		var n := AS3.Number(b.replace("finish", ""))
		kb = 0 if is_nan(n) else int(n)
	if ka > kb:
		return 1
	if ka < kb:
		return -1
	return 0


func dialogueLineClicked(l: DialogueEditorLine) -> void:
	var i := lines.find(l)
	if g.ctrlDown:
		if lines[i].selected:
			lines[i].select(false)
			# Array.splice(index) with no count removes everything from index on.
			var at := selectedLines.find(lines[i])
			selectedLines.resize(at if at >= 0 else maxi(0, selectedLines.size() - 1))
		else:
			lines[i].select()
			selectedLines.append(lines[i])
	elif g.shiftDown:
		selectLines(i)
	else:
		lastSelectedLine = i
		selectLines()
	updateToolbar()


func lineChanged(_l = null) -> void:
	updateLines()


func selectLines(other: int = -1) -> void:
	selectedLines = []
	var inRange := false
	var lo := mini(other, lastSelectedLine)
	var hi := maxi(other, lastSelectedLine)
	for i in lines.size():
		lines[i].select(false)
		if i == lo:
			lines[i].select()
			selectedLines.append(lines[i])
			inRange = true
		elif inRange:
			lines[i].select()
			selectedLines.append(lines[i])
		if i == hi:
			if not lines[i].selected:
				lines[i].select()
				selectedLines.append(lines[i])
			inRange = false
	updateToolbar()


func previewClicked(e: FlashEvent) -> void:
	g.gamePaused = false
	g.currentPos.x = 0
	g.currentPos.y = 0
	g.inGameMenu.setQualityTo(gameQuality)
	g.thawScreen()
	lineToSpeak = e.target.parent
	outputDialogue()
	cacheAsBitmap = true
	drawerArrow.gotoAndPlay("FadeIn")
	previewFrame.visible = true
	slideDown = true


func globalClick(_e = null) -> void:
	g.dialogueControl.instantStop()
	g.gamePaused = true
	g.inGameMenu.setQualityTo(2)
	g.freezeScreen()
	slideUp = true
	slideDown = false
	cacheAsBitmap = true
	stage.removeEventListener(FlashEvent.CLICK, globalClick)
	drawerArrow.gotoAndStop("Hidden")
	previewFrame.visible = false


func outputDialogue() -> void:
	g.dialogueControl.resetCustomDialogue(false)
	g.inGameMenu.setDialogueLibraryName(dialogueLibraryName.text)
	g.dialogueControl.setDialogueLibraryName(dialogueLibraryName.text)
	g.dialogueControl.loadFromDialogueEditor(lines)


func saveDialogueClicked(_e = null) -> void:
	outputDialogue()
	var out: String = g.dialogueControl.exportDialogue()
	var fileName := dialogueLibraryName.text
	dialogueFile.save(out, fileName + ".txt")
	savingDialogue = true
	browsingForDialogue = false


func loadDialogueClicked(_e = null) -> void:
	browsingForDialogue = true
	savingDialogue = false
	dialogueFile.browse()


func dialogueSelectHandler(_e = null) -> void:
	if browsingForDialogue:
		dialogueFile.load()


func dialogueCompleteHandler(_e = null) -> void:
	if browsingForDialogue:
		var text := Flash.bytes_to_string(dialogueFile.data)
		if text == "" and dialogueFile.data.size() > 0:
			g.showError("Error loading dialogue file. Check encoding is UTF-8")
			return
		g.dialogueControl.loadCustomDialogue(text)
		showDialogue(g.dialogueControl.getCurrentDialogue(), g.dialogueControl.getCurrentFinishes())
	elif savingDialogue:
		savingDialogue = false


func dialogueCancelHandler(_e = null) -> void:
	browsingForDialogue = false
	savingDialogue = false
