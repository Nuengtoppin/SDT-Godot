class_name FolderPathEntry
extends FlashMovieClip
## Port of obj.ui.FolderPathEntry: an editable default-mod-folder row with a delete button.

var textBackground: FlashMovieClip
var mbDelete
var pathTF: FlashTextField

var folderPath: String:
	get: return pathTF.text


func _init(path: String = "") -> void:
	super()
	pathTF.text = path
	mbDelete.addEventListener(FlashEvent.CLICK, deleteClicked)
	pathTF.addEventListener(FlashEvent.KEY_UP, pathTyped)
	pathTF.addEventListener(FlashEvent.FOCUS_IN, textFieldFocusIn)
	pathTF.addEventListener(FlashEvent.FOCUS_OUT, textFieldFocusOut)


func kill() -> void:
	mbDelete.removeEventListener(FlashEvent.CLICK, deleteClicked)
	pathTF.removeEventListener(FlashEvent.FOCUS_IN, textFieldFocusIn)
	pathTF.removeEventListener(FlashEvent.FOCUS_OUT, textFieldFocusOut)
	parent.removeChild(self)


func deleteClicked(_e = null) -> void:
	dispatchEvent(FlashEvent.new("DELETE_CLICKED"))


func textFieldFocusIn(_e = null) -> void:
	g.inTextField = true


func textFieldFocusOut(_e = null) -> void:
	g.inTextField = false


func pathTyped(e: FlashEvent) -> void:
	if e.charCode == 13:
		dispatchEvent(FlashEvent.new("ENTER_PRESSED"))
	dispatchEvent(FlashEvent.new("UPDATED"))
