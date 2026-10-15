class_name LoadedMod
extends RefCounted
## Port of obj.LoadedMod: one element (costume, background, sound, ...) contributed by a loaded mod package.

var _active := true
var _modType: String
var _overwrite: bool
var _mod
var _sourceModPackage

var active: bool:
	get: return _active
var modType: String:
	get: return _modType
var overwrite: bool:
	get: return _overwrite
var sourcePackage:
	get: return _sourceModPackage
var modElement:
	get: return _mod


func _init(pkg, settings, element) -> void:
	_sourceModPackage = pkg
	_modType = settings["modType"]
	_overwrite = settings.get("overwrite", false)
	_mod = element
	if _mod is CostumeElement:
		_mod.addEventListener("toggled", costumeElementToggled)


func costumeElementToggled(_e = null) -> void:
	_active = _mod.showing


func kill() -> void:
	if _mod:
		if _mod is CostumeElement:
			_mod.removeEventListener("toggled", costumeElementToggled)
			_mod.kill()
		elif not (_mod is FlashSound):
			_mod.parent.removeChild(_mod)
			if _mod is FlashDisplayObject:
				Flash.dispose_later(_mod)
		_active = false
		_mod = null
		_sourceModPackage.removeElement(self)
