class_name FlashSoundChannel
extends FlashEventDispatcher
## flash.media.SoundChannel: one playing instance of a FlashSound.

var _player: AudioStreamPlayer = null
var _sound: FlashSound
var _loops_left: int = 0
var _start_pos: float = 0.0
var _transform: FlashSoundTransform = FlashSoundTransform.new()


func _start(sound: FlashSound, start_pos: float, plays: int, st: FlashSoundTransform) -> void:
	_sound = sound
	_start_pos = start_pos
	_loops_left = plays - 1
	Flash._active_channels[self] = true
	_player = Flash._get_audio_player()
	_player.set_meta("busy", true)
	_player.stream = sound.stream
	if st != null:
		_transform = st.clone()
	_apply_transform()
	if not _player.finished.is_connected(_on_finished):
		_player.finished.connect(_on_finished)
	_player.play(start_pos)


func _apply_transform() -> void:
	if _player != null:
		_player.volume_db = linear_to_db(maxf(_transform.volume, 0.00001))
		Flash.set_player_pan(_player, _transform.pan)


func _on_finished() -> void:
	if _loops_left > 0:
		_loops_left -= 1
		_player.play(_start_pos)
		return
	_release()
	dispatchEvent(FlashEvent.new(FlashEvent.SOUND_COMPLETE))


func _release() -> void:
	if _player != null:
		if _player.finished.is_connected(_on_finished):
			_player.finished.disconnect(_on_finished)
		_player.remove_meta("busy")
		_player = null
	Flash._active_channels.erase(self)


func stop() -> void:
	if _player != null:
		_player.stop()
		_release()


## Playback position in milliseconds.
var position: float:
	get:
		return _player.get_playback_position() * 1000.0 if _player != null else 0.0


var soundTransform: FlashSoundTransform:
	get:
		return _transform.clone()
	set(value):
		_transform = value.clone() if value != null else FlashSoundTransform.new()
		_apply_transform()
