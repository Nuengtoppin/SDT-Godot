class_name DialogueMod
extends RefCounted
## Port of the SDT mod kit's DialogueMod (private to ModPackage): one dialogue line registered by a mod, with an
## optional sound.

var _lineType: String
var _dialogueLine: String
var _audio = null
var _volume: float


func _init(lineType: String, dialogueLine: String, audio = null, volume: float = 0.8) -> void:
	_lineType = lineType
	_dialogueLine = dialogueLine
	_audio = audio
	_volume = maxf(0.0, minf(1.0, volume))


var name: String:
	get: return _dialogueLine

var modType: String:
	get: return ModTypes.DIALOGUE

var lineType: String:
	get: return _lineType

var dialogueLine: String:
	get: return _dialogueLine

var audio:
	get: return _audio

var volume: float:
	get: return _volume


## The game checks optional fields with hasOwnProperty (audio only exists when a sound was found).
func hasOwnProperty(n: String) -> bool:
	match n:
		"audio", "volume":
			return _audio != null
		"name", "modType", "lineType", "dialogueLine":
			return true
	return false
