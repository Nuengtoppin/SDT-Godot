class_name ModPackage
extends FlashMovieClip
## Port of SDTMods.ModPackage, the SDT mod kit's document class: the main timeline of a mod .swf. The mod's own
## frame-1 script (interpreted from its ActionScript, see FlashSwfMod) calls registerMod / registerDialogue /
## setupDialogue and sets modName, modCreator and charData; the game then reads them (CustomElementLoader.parseMod).
## The kit's debug checks (checkMod) and splash screen are left out.

var MOD_VERSION: String = "SDTMOD_0.2"
var modType: String = ModTypes.MOD_PACKAGE
var _mods: Array = []
var modName: String = ""
var modCreator: String = "anon"
var charData = null
var dialogueName: String = ""
var clearAllDialogue: bool = false
var targetElement = null
var overwrite: bool = false


func _init() -> void:
	super()


func registerMod(m) -> void:
	_mods.append(m)


func registerDialogue(lineType: String, dialogueLine: String, soundName = null, vol: float = 0.8) -> void:
	var audio = null
	if soundName != null and str(soundName) != "" and _library != null and _library.mod != null:
		var id: int = _library.mod._class_id(str(soundName))
		if id >= 0 and _library.get_char(id).get("t") == "sound":
			audio = FlashSound.from_library(_library, id)
		else:
			push_warning("Mod %s: no audio file called %s" % [modName, soundName])
	_mods.append(DialogueMod.new(lineType, dialogueLine, audio, vol))


func setupDialogue(n: String, clearAll: bool = true) -> void:
	dialogueName = n
	clearAllDialogue = clearAll


var mods: Array:
	get:
		return _mods
