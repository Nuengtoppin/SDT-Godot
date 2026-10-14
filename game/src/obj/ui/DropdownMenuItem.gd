class_name DropdownMenuItem
extends FlashMovieClip
## Port of obj.ui.DropdownMenuItem: one selectable line in a dropdown list.

var label: FlashTextField
var _selected := false
var _clickCallback: Callable
var _labelText: String = ""

var labelText: String:
	get: return _labelText


func _init(text: String = "", cb: Callable = Callable()) -> void:
	super()
	label.text = text
	_labelText = text
	_clickCallback = cb
	addEventListener(FlashEvent.CLICK, clicked)
	addEventListener(FlashEvent.MOUSE_DOWN, pressed)
	addEventListener(FlashEvent.MOUSE_UP, released)
	addEventListener(FlashEvent.ROLL_OVER, rolledOver)
	addEventListener(FlashEvent.ROLL_OUT, rolledOut)
	gotoAndStop("normal")


func select(v: bool = true) -> void:
	_selected = v
	gotoAndStop("down" if _selected else "normal")


func pressed(_e = null) -> void:
	gotoAndStop("down")


func released(_e = null) -> void:
	gotoAndStop("down" if _selected else "normal")


func rolledOver(_e = null) -> void:
	gotoAndStop("over")


func rolledOut(_e = null) -> void:
	gotoAndStop("down" if _selected else "normal")


func clicked(_e = null) -> void:
	_clickCallback.call(self)
