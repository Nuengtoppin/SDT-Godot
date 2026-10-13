class_name DialogueLine
extends RefCounted
## Port of obj.dialogue.DialogueLine: one phrase plus its settings (style, mood, held, next, set, check).

const SPEAKING_STYLE := "Speak"
const THOUGHT_STYLE := "Thought"
const HIM_STYLE := "Him"

static var advancedController: AdvancedDialogueController

var _settings: Dictionary
var _style: String = ""
var _mood: String = ""
var _held: String = ""
var _nextLine: String = ""
var _phrase: String

var phrase: String:
	get: return _phrase
var settings: Dictionary:
	get: return _settings
var style: String:
	get: return _style if _style else SPEAKING_STYLE
var mood: String:
	get: return _mood
var held: String:
	get: return _held
var nextLine: String:
	get: return _nextLine


func _init(p: String, s = null) -> void:
	_phrase = p
	if s:
		_settings = s
		if s.get("style"):
			_style = str(s["style"])
			if _style == SPEAKING_STYLE.to_lower():
				_style = SPEAKING_STYLE
			if _style == THOUGHT_STYLE.to_lower():
				_style = THOUGHT_STYLE
			if _style == HIM_STYLE.to_lower():
				_style = HIM_STYLE
		if s.get("mood"):
			_mood = str(s["mood"])
		if s.get("held"):
			_held = str(s["held"])
		if s.get("next"):
			_nextLine = str(s["next"])
	else:
		_settings = {}


var canPlay: bool:
	get:
		if advancedController and not advancedController.canPlay(self):
			return false
		if g.her.passedOut and _style == THOUGHT_STYLE:
			return false
		if (not _style or _style == SPEAKING_STYLE) and not g.her.canSpeak():
			return false
		if _mood and g.her.mood != _mood:
			return false
		if _held:
			if _held == "true" and Him.armPositions[g.him.currentArmPosition] != "Holding":
				return false
			if _held == "false" and Him.armPositions[g.him.currentArmPosition] != "Free":
				return false
		return true


func export() -> String:
	var o := {}
	if _style and _style != SPEAKING_STYLE:
		o["style"] = _style
	if _mood:
		o["mood"] = _mood
	if _nextLine:
		o["next"] = _nextLine
	if _held:
		o["held"] = _held
	if _settings.get("set"):
		o["set"] = _settings["set"]
	if _settings.get("check"):
		o["check"] = _settings["check"]
	var s := AS3JSON.encode(o)
	if s == "{}":
		s = ""
	return "\"" + _phrase + "\"" + s
