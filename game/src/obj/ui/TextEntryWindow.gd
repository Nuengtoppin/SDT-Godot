class_name TextEntryWindow
extends FlashMovieClip
## Port of obj.ui.TextEntryWindow: small popup asking for one line of text; closes on Done / Enter / outside click.

var caption: FlashTextField
var mbDoneButton
var dialogueLibraryName: FlashTextField
var closeButton
var entryField: FlashTextField
var _callback: Callable
var _openedOnClickDone := false
var _match: RegEx = null
var _default: String = ""


func _init(pCaption: String = "", doneLabel: String = "", cb: Callable = Callable(), pDefault: String = "") -> void:
	caption.text = pCaption
	mbDoneButton.labelContainer.buttonLabel.text = doneLabel
	_callback = cb
	entryField.text = pDefault
	_default = pDefault
	entryField.addEventListener(FlashEvent.KEY_UP, typed)
	closeButton.addEventListener(FlashEvent.CLICK, closeClicked)
	mbDoneButton.addEventListener(FlashEvent.CLICK, doneClicked)
	addEventListener(FlashEvent.ADDED_TO_STAGE, added)


func setMatch(re: RegEx) -> void:
	_match = re


func added(_e = null) -> void:
	removeEventListener(FlashEvent.ADDED_TO_STAGE, added)
	stage.addEventListener(FlashEvent.CLICK, globalClick)
	stage.focus = entryField
	entryField.setSelection(entryField.length, entryField.length)


func globalClick(e: FlashEvent) -> void:
	if _openedOnClickDone:
		if not contains(e.target):
			removeListeners()
			parent.removeChild(self)
	else:
		_openedOnClickDone = true


func removeListeners() -> void:
	entryField.removeEventListener(FlashEvent.KEY_UP, typed)
	closeButton.removeEventListener(FlashEvent.CLICK, closeClicked)
	mbDoneButton.removeEventListener(FlashEvent.CLICK, doneClicked)
	stage.removeEventListener(FlashEvent.CLICK, globalClick)


func closeClicked(_e = null) -> void:
	removeListeners()
	parent.removeChild(self)


func doneClicked(_e = null) -> void:
	sendEntry()


func typed(e: FlashEvent) -> void:
	if e.charCode == 13:
		sendEntry()


func sendEntry() -> void:
	if _match:
		if not _match.search(entryField.text):
			entryField.text = _default
			stage.focus = entryField
			entryField.setSelection(entryField.text.length(), entryField.text.length())
			return
	if _callback.is_valid():
		_callback.call(entryField.text)
	removeListeners()
	parent.removeChild(self)
