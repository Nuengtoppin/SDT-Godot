class_name DialogueEditorLine
extends FlashMovieClip
## Port of obj.dialogue.DialogueEditorLine: one editable row in the dialogue editor.

static var _lineCountStatic: int = 0

var background: FlashMovieClip
var triggerLabel: FlashTextField
var lineWindow: FlashMovieClip
var mbPreview
var spot: FlashMovieClip
var hitbox: FlashMovieClip
var moodIcon: FlashMovieClip
var dialogueLine: FlashTextField
var _lineID: int
var _selected := false
var _clickCallback: Callable
var _changeCallback: Callable
var _trigger: String = ""
var _style: String = ""
var _mood: String = ""
var _nextLine: String = ""
var _held: String = ""
var _sourceLine: DialogueLine
var _wildcard: bool
var _finish := false
var _lineCount: int = 1
var _lastCaret: int = -1
var showing := true


func _init(src: DialogueLine = null, pTrigger: String = "", clickCb: Callable = Callable(),
		changeCb: Callable = Callable(), wildcard: bool = false) -> void:
	super()
	background.gotoAndStop("normal")
	spot.gotoAndStop("speaking")
	moodIcon.gotoAndStop("none")
	dialogueLine.autoSize = "left"
	dialogueLine.wordWrap = true
	if src == null:
		_sourceLine = DialogueLine.new("")
		dialogueLine.text = ""
	else:
		_sourceLine = src
		dialogueLine.text = src.phrase
		style = src.style
		mood = src.mood
		held = src.held
		nextLine = src.nextLine
	_wildcard = wildcard
	trigger = pTrigger
	_clickCallback = clickCb
	_changeCallback = changeCb
	_lineID = _lineCountStatic
	_lineCountStatic += 1
	mbPreview.visible = not _wildcard
	_lineCount = dialogueLine.numLines
	updateHeight()
	addEventListener(FlashEvent.CLICK, clicked)
	hitbox.addEventListener(FlashEvent.MOUSE_DOWN, pressed)
	hitbox.addEventListener(FlashEvent.MOUSE_UP, released)
	hitbox.addEventListener(FlashEvent.ROLL_OVER, rolledOver)
	hitbox.addEventListener(FlashEvent.ROLL_OUT, rolledOut)
	dialogueLine.addEventListener(FlashEvent.KEY_UP, typed)
	dialogueLine.addEventListener(FlashEvent.CLICK, lineClicked)


func typed(_e = null) -> void:
	lineChanged()


func lineClicked(_e = null) -> void:
	if dialogueLine.caretIndex != _lastCaret:
		_lastCaret = dialogueLine.caretIndex
		checkSelection()


## Clicking inside an [ACTION] selects the whole action.
func checkSelection() -> void:
	if _lastCaret == -1:
		return
	var close := ""
	var open := ""
	var r := _lastCaret
	var l := _lastCaret
	var goRight := true
	var goLeft := true
	var t := dialogueLine.text
	while goRight or goLeft:
		if goRight:
			if r < dialogueLine.length - 1:
				r += 1
				if t[r] == "]":
					close = "]"
					goRight = false
				elif t[r] == "[":
					goRight = false
			else:
				goRight = false
		if goLeft:
			if l > 0:
				l -= 1
				if t[l] == "[":
					open = "["
					goLeft = false
				elif t[l] == "]":
					goLeft = false
			else:
				goLeft = false
	if close and open:
		dialogueLine.setSelection(l, r + 1)


func lineChanged() -> void:
	var n := dialogueLine.numLines
	if n != _lineCount:
		_lineCount = n
		updateHeight()
		_changeCallback.call(self)


func updateHeight() -> void:
	background.height = 20 + 13 * (_lineCount - 1)
	hitbox.height = background.height
	lineWindow.height = 20 + 13 * (_lineCount - 1) - 2
	lineWindow.y = ceil(lineWindow.height * 0.5) + 1


var lineHeight: float:
	get: return 20 + 13 * (_lineCount - 1) + 1


func matchesFilter(f: String) -> bool:
	var re := RegEx.create_from_string("(?i)" + f)
	if re == null or not re.is_valid():
		return false
	if phrase and re.search(phrase):
		return true
	if trigger and re.search(trigger):
		return true
	if _style and re.search(_style):
		return true
	return false


func takeFocus() -> void:
	stage.focus = dialogueLine
	dialogueLine.setSelection(dialogueLine.caretIndex, dialogueLine.caretIndex)


func insert(s: String) -> void:
	dialogueLine.replaceText(dialogueLine.caretIndex, dialogueLine.caretIndex, s)
	lineChanged()


var trigger: String:
	get: return _trigger
	set(value):
		_trigger = value
		triggerLabel.text = _trigger
		if _trigger.to_lower().contains("finish"):
			finish = true

var nextLine: String:
	get: return _nextLine
	set(value): _nextLine = value

var phrase: String:
	get: return dialogueLine.text

var wildcard: bool:
	get: return _wildcard

var finish: bool:
	get: return _finish
	set(value): _finish = value

var style: String:
	get: return _style
	set(value):
		_style = value
		match _style:
			DialogueLine.THOUGHT_STYLE:
				spot.gotoAndStop("thought")
			DialogueLine.HIM_STYLE:
				spot.gotoAndStop("him")
			_:
				spot.gotoAndStop("speaking")

var mood: String:
	get: return _mood
	set(value):
		_mood = value
		moodIcon.gotoAndStop(_mood if _mood else "none")

var held: String:
	get: return _held
	set(value): _held = value

var selected: bool:
	get: return _selected

var id: int:
	get: return _lineID


func getDialogueLine() -> DialogueLine:
	var s := {}
	if _style:
		s["style"] = _style
	if _mood:
		s["mood"] = _mood
	if _nextLine:
		s["next"] = _nextLine
	if _held:
		s["held"] = _held
	if _sourceLine.settings.get("set"):
		s["set"] = _sourceLine.settings["set"]
	if _sourceLine.settings.get("check"):
		s["check"] = _sourceLine.settings["check"]
	return DialogueLine.new(phrase, s)


func select(v: bool = true) -> void:
	_selected = v
	background.gotoAndStop("down" if _selected else "normal")


func pressed(_e = null) -> void:
	background.gotoAndStop("down")


func released(_e = null) -> void:
	background.gotoAndStop("down" if _selected else "normal")


func rolledOver(_e = null) -> void:
	background.gotoAndStop("over")


func rolledOut(_e = null) -> void:
	background.gotoAndStop("down" if _selected else "normal")


func clicked(_e = null) -> void:
	_clickCallback.call(self)


func traceOut() -> String:
	return trigger + ": \"" + phrase + "\" " + ("style: " + _style if _style else "") \
		+ (", mood: " + _mood if _mood else "") + (", nextLine: " + _nextLine if _nextLine else "") \
		+ (", held: " + _held if _held else "")
