class_name FlashSound
extends RefCounted
## flash.media.Sound: a library sound (by AS3 class name or character id) or an external file.

var stream: AudioStream = null

## Length in milliseconds.
var length: float:
	get:
		return stream.get_length() * 1000.0 if stream != null else 0.0


static func from_library(lib: FlashLibrary, id: int) -> FlashSound:
	var c: Dictionary = lib.get_char(id)
	if not c.has("file"):
		return null
	var s := FlashSound.new()
	s.stream = _load_stream(lib.file_path(c["file"]))
	return s


## new sfxGag1() -> FlashSound.named("sfxGag1")
static func named(as3_class: String) -> FlashSound:
	var found: Array = Flash.find_class_symbol(as3_class)
	if found.is_empty():
		push_error("FlashSound: no sound class %s" % as3_class)
		return null
	return from_library(found[0], found[1])


## Library sounds stay loaded once used: otherwise every play after the last reference went away reloads the
## file (a disk read mid-game). The base game's sounds take a few MB.
static var _stream_cache: Dictionary = {}


static func _load_stream(p: String) -> AudioStream:
	if p.begins_with("res://"):
		var cached: AudioStream = _stream_cache.get(p)
		if cached == null:
			cached = load(p)
			_stream_cache[p] = cached
			Flash.hitch_note("sound load")
		return cached
	if p.get_extension().to_lower() == "mp3":
		return AudioStreamMP3.load_from_file(p)
	if p.get_extension().to_lower() == "wav":
		return AudioStreamWAV.load_from_file(p)
	return null


## start_time in ms; loops = number of additional plays (Flash semantics: loops=0 or 1 plays once).
func play(start_time: float = 0.0, loops: int = 0, soundTransform: FlashSoundTransform = null) -> FlashSoundChannel:
	if stream == null:
		return null
	var ch := FlashSoundChannel.new()
	ch._start(self, start_time / 1000.0, maxi(loops, 1), soundTransform)
	return ch
