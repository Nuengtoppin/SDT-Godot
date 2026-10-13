class_name AudioMod
extends RefCounted
## Port of obj.AudioMod: a sound replacement loaded from a mod, with its volume.

var _audio: FlashSound
var _volume: float

var audio: FlashSound:
	get: return _audio
var volume: float:
	get: return _volume


func _init(a: FlashSound, v: float) -> void:
	_audio = a
	_volume = maxf(0, minf(1, v))
