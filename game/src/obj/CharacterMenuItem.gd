class_name CharacterMenuItem
extends FlashMovieClip
## Port of obj.CharacterMenuItem: one character in the character menu (built-in or custom slot).

var costumeButton
var editButton
var hitbox: FlashMovieClip
var thumb: FlashMovieClip
var itemLabel: FlashTextField
var box: FlashMovieClip
var selected := false
var isOver := false
var charShot: FlashBitmap
var haveCharShot := false
var _isBaseChar := false
var _baseCharID: int = 0
var _customChar: CustomCharacter
var _charName: String = ""

var charName: String:
	get: return _charName
var isBaseChar: bool:
	get: return _isBaseChar
var baseCharID: int:
	get: return _baseCharID
var customChar: CustomCharacter:
	get: return _customChar


func _init() -> void:
	super()
	addEventListener(FlashEvent.ROLL_OVER, rolledOver)
	addEventListener(FlashEvent.ROLL_OUT, rolledOut)


func setBaseChar(id: int) -> void:
	_isBaseChar = true
	_baseCharID = id
	_charName = g.characterControl.getCharName(_baseCharID)


func setCustomChar(c: CustomCharacter) -> void:
	_isBaseChar = false
	_customChar = c
	_charName = _customChar.charName


func giveCharShot(b: FlashBitmap) -> void:
	thumb.gotoAndStop("Blank")
	if haveCharShot:
		thumb.removeChild(charShot)
	charShot = b
	thumb.addChild(charShot)
	haveCharShot = true


func removeCharShot() -> void:
	if haveCharShot:
		thumb.removeChild(charShot)
		haveCharShot = false


func select() -> void:
	selected = true
	box.gotoAndStop("Selected")


func deselect() -> void:
	selected = false
	box.gotoAndStop("Highlighted" if isOver else "Normal")


func rolledOver(_e = null) -> void:
	isOver = true
	if not selected:
		box.gotoAndStop("Highlighted")


func rolledOut(_e = null) -> void:
	isOver = false
	box.gotoAndStop("Selected" if selected else "Normal")
