extends SDTExtension
## Built-in reimplementation of the Loader mod headwearland (sby, V4): moves, turns and resizes her headwear by hand
## instead of the game's landing on the hair (Clothes > Head and neck, while she wears headwear). Saved in the
## character code as "headwearland:set,y,x,angle,scaleX,scaleY" like the Loader mod (written only once it is set;
## a full code without it goes back to the game's landing). By default a change of hair goes back to the landing
## too (the mod's resetlandonhairchange), a change of headwear does not (resetlandonheadwearchange).
## Written from its source. Port fix: going back to the landing also undoes the turn and size (the mod only redid
## the height).

var manually_set := false
var y := 0
var x := 0
var angle := 0
var scale_x := 1.0
var scale_y := 1.0
var _last_hair := ""
var _last_wear := ""
var _moved := false   # the headwear has a transform of ours on it


func _init() -> void:
	id = "headwearland"
	title = "headwearland"
	description = "headwearland (sby): move, turn and resize her headwear (Clothes > Head and neck)."
	default_enabled = true


func _setup() -> void:
	setting("reset_on_hair", true, {"label": "New hair resets the headwear",
		"desc": "A change of hair puts the headwear back on the hair the game's way."})
	setting("reset_on_headwear", false, {"label": "New headwear resets its placement",
		"desc": "A change of headwear puts it back on the hair the game's way."})


func _enable() -> void:
	hook_after(&"CharacterControl.tryToLandHeadwear", func(_cc): _landed())
	charcode_field("headwearland", _code, func(v, l): _load_code(v, l), func(_l): _from_code_reset(), true)
	var worn := func(): return g.characterControl.headwearControl.inUse()
	var row := func(label: String, tip: String, lo: float, hi: float, step: float, get_fn: Callable, set_fn: Callable):
		menu_control("clothes", "Head and neck", {"type": "slider", "label": label, "tip": tip, "min": lo, "max": hi,
			"step": step, "get": get_fn, "visible": worn, "after": "Headwear colours", "release": func(): g.saveData.saveCharData(),
			"set": func(v: float): _touch(); set_fn.call(v); apply(),
			"format": func(v): return str(int(v)) if step >= 1 else str(snappedf(v, 0.01))})
	row.call("Headwear height", "Up (−) or down (+) from where it sits.", -300, 300, 1,
		func(): return float(y), func(v): y = int(v))
	row.call("Headwear sideways", "Left (−) or right (+).", -300, 300, 1, func(): return float(x), func(v): x = int(v))
	row.call("Headwear turn", "Degrees, clockwise.", -180, 180, 1, func(): return float(angle), func(v): angle = int(v))
	row.call("Headwear width", "", 0.1, 3, 0.01, func(): return scale_x, func(v): scale_x = snappedf(v, 0.01))
	row.call("Headwear height scale", "", 0.1, 3, 0.01, func(): return scale_y, func(v): scale_y = snappedf(v, 0.01))
	menu_control("clothes", "Head and neck", MenuSchema.actions("", "", [["Reset headwear placement", func():
		reset(); g.saveData.saveCharData(), "Back on the hair the game's way."]], {"visible": worn, "after": "Headwear colours"}))


func _disable() -> void:
	reset()


## Puts the headwear back on the hair the game's way.
func reset() -> void:
	_reset_values()
	_unmove()
	if g.characterControl != null:
		g.characterControl.waitToSetHeadwearPosition()


func _reset_values() -> void:
	manually_set = false
	y = 0
	x = 0
	angle = 0
	scale_x = 1.0
	scale_y = 1.0


## A hand change: first the mod's reset check, then the current hair and headwear become the ones it is set for.
func _touch() -> void:
	_check_reset()
	_last_hair = _hair()
	_last_wear = _wear()
	manually_set = true


func _check_reset() -> void:
	if (get_setting("reset_on_headwear") and _wear() != _last_wear) \
			or (get_setting("reset_on_hair") and _hair() != _last_hair):
		_reset_values()


func _landed() -> void:
	_check_reset()
	if manually_set:
		apply()
	else:
		_unmove()


func apply() -> void:
	var r := deg_to_rad(angle)
	var tx := 21 - (21 * cos(r) - 106 * sin(r))
	var ty := 106 - (106 * cos(r) + 21 * sin(r))
	# the mod's offsets: keep the headwear's own point (21, 106) in place while it turns, and its top while it grows
	var ox := sin(r) * -300 * (scale_y - 1) - 2 * tx
	var oy := cos(r) * 300 * (scale_y - 1) - 2 * ty
	for hw in [g.hairCostumeOver.headwear, g.hairCostumeBack.headwear]:
		hw.x = x + ox
		hw.y = y + oy
		hw.rotation_degrees = angle
		hw.scaleX = scale_x
		hw.scaleY = scale_y
	_moved = true


func _unmove() -> void:
	if not _moved or g.hairCostumeOver == null:
		return
	for hw in [g.hairCostumeOver.headwear, g.hairCostumeBack.headwear]:
		hw.x = 0
		hw.rotation_degrees = 0
		hw.scaleX = 1
		hw.scaleY = 1
	_moved = false


func _hair() -> String:
	return g.dataName(g.inGameMenu.charNames[g.characterControl.currentHair])


func _wear() -> String:
	return g.characterControl.headwearControl.getDataString().split(",")[0]


func _code():
	if not manually_set:
		return null
	return "1,%d,%d,%d,%.2f,%.2f" % [y, x, angle, scale_x, scale_y]


func _from_code_reset() -> void:
	_last_hair = ""
	_last_wear = ""
	reset()


func _load_code(v: String, l: CharCode.Load) -> void:
	if l.is_full():
		_reset_values()
		_last_hair = ""
		_last_wear = ""
	var p := v.split(",")
	manually_set = _int(p[0]) == 1
	if p.size() > 1:
		y = _int(p[1])
	if p.size() > 2:
		x = _int(p[2])
	if p.size() > 3:
		angle = _int(p[3])
	if p.size() > 5:
		scale_x = p[4].to_float()
		scale_y = p[5].to_float()
	if l.pairs.has("hair"):
		_last_hair = g.dataName(l.pairs["hair"].split(",")[0])
	if l.pairs.has("headwear"):
		_last_wear = g.dataName(l.pairs["headwear"].split(",")[0])
	if manually_set:
		apply()
	else:
		reset()


## AS3 int(String): the number, cut to a whole one ("1.5" is 1; String.to_int would read 15).
static func _int(s: String) -> int:
	return int(s.to_float())
