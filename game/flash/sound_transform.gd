class_name FlashSoundTransform
extends RefCounted
## flash.media.SoundTransform (volume 0..1, pan -1..1).

var volume: float = 1.0
var pan: float = 0.0


func _init(p_volume: float = 1.0, p_pan: float = 0.0) -> void:
	volume = p_volume
	pan = p_pan


func clone() -> FlashSoundTransform:
	return FlashSoundTransform.new(volume, pan)
