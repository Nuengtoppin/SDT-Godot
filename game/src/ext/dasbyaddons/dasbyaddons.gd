extends SDTExtension
## Built-in reimplementation of the Loader mod DA_sbyAddons (sby, v2.1): "ProgressivePleasure" dialogue lines that
## play in order as his pleasure rises. Needs DialogueActions. Written from its documentation and behaviour.
##
## Line types ProgressivePleasure000 ... ProgressivePleasure100 (any of them; each is the pleasure percentage it
## waits for). They play lowest first, each once, and stay built until they play; a line can write
## {"set":{"pleasurelinereset":1}} to start again from the lowest.

const LINE := "ProgressivePleasure"

var _levels: Array = []   # the levels the dialogue has lines for, ascending
var _next := 0            # index into _levels of the next line to play
var _waiting := ""        # line type built and waiting to play
var _delay := 0
var _dirty := true        # the dialogue changed: look for the lines again


func _init() -> void:
	id = "dasbyaddons"
	title = "DA_sbyAddons"
	description = "ProgressivePleasure000-100 dialogue lines, played in order as his pleasure rises (needs DialogueActions)."
	default_enabled = true


func _setup() -> void:
	setting("pleasurelinelife", 400, {"label": "Line build life", "min": 0, "max": 2000})
	setting("pleasurelinepriority", 5, {"label": "Line priority", "min": 0, "max": 10,
		"desc": "The game's line types have 0 (general) to 2 (cum)."})
	setting("pleasurelinedelay", 30, {"label": "Ticks between lines", "min": 0, "max": 600})
	setting("pleasurelineresetdelay", 180, {"label": "Ticks before the first line after a reset", "min": 0, "max": 1200})


func _enable() -> void:
	for h in [&"Dialogue.loadCustomDialogue", &"DialogueLibrary.loadDialogueMod", &"DialogueLibrary.loadFromDialogueEditor"]:
		hook_after(h, func(_c): _dirty = true)
	on_dialogueactions(func(da): da.vars.add_listener("pleasurelinereset", func(_old, new): _reset_written(new)))
	on_late_tick(_tick)
	_dirty = true


## His pleasure in percent, as the pleasure counter shows it.
static func pleasure_percent() -> int:
	var him = g.him
	var p := int(him.pleasure / (him.ejacPleasure / 97.0 * 100.0) * 100.0)
	if p >= 97:
		p += int(him.maxPleasureTimer / 20.0)
	return mini(100, p)


func _update_lines() -> void:
	_dirty = false
	var dc = g.dialogueControl
	dc.advancedController._dialogueDataStore["pleasurelinereset"] = 0
	_levels.clear()
	_waiting = ""
	_next = 0
	for i in 101:
		var t := "%s%03d" % [LINE, i]
		if dc.library.customLibrary.has(t):
			dc.states[t] = DialogueState.new(get_setting("pleasurelinelife"), get_setting("pleasurelinepriority"))
			_levels.append(i)
		else:
			dc.states.erase(t)


func _reset_written(v) -> void:
	if str(v) != "1" and not ((v is float or v is int) and v == 1):
		return
	g.dialogueControl.advancedController._dialogueDataStore["pleasurelinereset"] = 0
	_next = 0
	_delay = maxi(_delay, get_setting("pleasurelineresetdelay"))
	_waiting = ""


func _tick() -> void:
	var dc = g.dialogueControl
	if dc == null or g.him == null:
		return
	if _dirty:
		_update_lines()
	if _waiting != "":
		var s: DialogueState = dc.states.get(_waiting)
		if s == null or s.build == 0:   # played (or gone)
			_waiting = ""
			_next += 1
		else:
			dc.buildState(_waiting, 8000)
		return
	if _delay > 0:
		_delay -= 1
		return
	if _next < _levels.size() and pleasure_percent() >= _levels[_next]:
		var t := "%s%03d" % [LINE, _levels[_next]]
		if dc.states.has(t) and dc.states[t]._noBuildDelay == 0:
			dc.buildState(t, 8000)
			_waiting = t
			_delay = get_setting("pleasurelinedelay")
