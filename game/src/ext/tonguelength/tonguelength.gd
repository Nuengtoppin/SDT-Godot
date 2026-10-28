extends SDTExtension
## Built-in reimplementation of the Loader mod tonguelength (sby, V1): a longer tongue (Her > Face, "Tongue
## length", 1 = the game's, up to 5). The longer it is, the more it tilts down; it pulls in and shortens as she closes
## her mouth so it does not show through her lips. Saved in the character code as "tongueLength:n" like the mod
## (a full code without it is 1). Written from its source. Port change: at length 1 the game's own tongue movement
## is left alone (the mod placed the tongue itself every frame even then, close to but not exactly the game's).

const MULTIPLIER := 4.0
const LOOP_FRAMES := [1, 3, 34, 54, 77, 116, 140, 166, 190]

var length := 1.0
var _moved := false


func _init() -> void:
	id = "tonguelength"
	title = "tonguelength"
	description = "tonguelength (sby): a longer tongue (Her > Face)."
	default_enabled = true


func _enable() -> void:
	on_late_tick(_tick)
	charcode_field("tongueLength", func(): return "%.3f" % length if length != 1.0 else null,
		func(v, _l): set_length(v.split(",")[0].to_float()), func(_l): set_length(1.0))
	menu_control("her", "Face", {"type": "slider", "label": "Tongue length",
		"tip": "1 is the game's. Longer tongues tilt down and pull in as she closes her mouth.",
		"min": 1.0, "max": 1.0 + MULTIPLIER, "step": 0.05, "get": func(): return length,
		"set": func(v: float): set_length(v), "release": func(): g.saveData.saveCharData(),
		"reset": func(): set_length(1.0); g.saveData.saveCharData(),
		"format": func(v): return str(snappedf(v, 0.01))})


func _disable() -> void:
	set_length(1.0)


func set_length(v: float) -> void:
	length = clampf(v, 1.0, 1.0 + MULTIPLIER) if not is_nan(v) else 1.0
	if length == 1.0:
		_restore()


## The tongue back where its container's timeline puts it, at its own size.
func _restore() -> void:
	if not _moved or g.her == null:
		return
	_moved = false
	var t = g.her.tongue
	var parent = t._flash_parent
	if parent is FlashMovieClip and t._place_index >= 0:
		var m = parent._sym["places"][t._place_index].get("m")
		if m != null:
			t.set_flash_matrix(m)
			return
	t.scaleX = 1
	t.scaleY = 1


func _tick() -> void:
	var her = g.her
	if length == 1.0 or her == null or not g.tongue:
		return
	var t = her.tongue
	var frame: int = t.currentFrame
	var s: float
	if frame in LOOP_FRAMES:
		s = 1.0
	elif frame == 2:
		s = 0.0
	elif frame > 54 and frame < 78:
		s = maxf(0, 62 - frame) / 8.0
	elif frame > 77 and frame < 117:
		s = maxf(0, 91 - frame) / 12.0
	elif frame > 2 and frame < 27:
		s = minf(1, (frame - 2) / 24.0)
	else:
		s = 1.0
	s *= length - 1.0
	var jaw: float = her.head.jaw.rotation_degrees
	var open := 1.0 - clampf(minf(0, jaw + 6) / minf(0, her.closedJawAngle + 7), 0, 1)
	s *= open
	var rot := minf(34, -7.77 + s * 13)
	t.scaleX = s + 1
	t.scaleY = 1 - s / 5 if s < 1.5 else 0.7 + (s - 1.5) / 20
	var closed := maxf(0, (1 - open) - 0.4) * 5 / 3
	t.x = 127.6 - closed * 35 * t.scaleX
	if frame < 54 or frame > 115:
		rot -= closed * 12
	t.rotation_degrees = rot
	var y := 49.55
	y += 10.0 / 3 * s if s < 1.5 else 5 - 5 * (minf(3.5, s) - 1.5)
	y += 2 * minf(0, jaw)
	y -= closed * 9
	t.y = y
	_moved = true
