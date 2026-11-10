extends SDTExtension
## Built-in reimplementation of the Loader's shortcuts (sby's Loader 5.45, Shortcuts.txt): keys for her eye, tongue,
## gaze and tears, his pleasure, a cum strand drawn with the mouse, keeping cum from fading, holding her and bukkake
## mode. They are rebindable in Settings › Hotkeys. Written from its decompiled code.
##
## Adapted: Eye Direction is a Her.lookTarget modifier, and Auto Hold a Her.pullOff / Her.pullOffPower modifier, so
## both combine with moods and dialogue. Keep Cum stops the strands' ageing (the Loader set every age to 0 each frame,
## so a strand that had started to fade jumped back). Pleasure + / - are on Numpad 1 / 3: the Loader's Numpad 7 / 9
## are armoverhaul's arm keys. Left out: Play Recording (no recordings in the port) and Cycle Custom (the Loader's
## character folders; the game's own keys cycle the characters). The Loader's status line has no counterpart.

const KEY_0 := 48
const KEY_1 := 49
const KEY_2 := 50
const KEY_3 := 51
const KEY_4 := 52
const KEY_5 := 53
const KEY_6 := 54
const KEY_7 := 55
const KEY_NUMPAD_1 := 97
const KEY_NUMPAD_3 := 99
const PLEASURE_STEP := 10.0   # the Loader's Settings.txt, pleasureInc
const PLEASURE_OVER := 10.0   # how far past his limit the key goes

enum Look {DEFAULT, UP, FORWARD}

var look := Look.DEFAULT
var hold := false
var keep_cum := false
var _strand = null            # the strand the mouse is drawing
var _strand_start := Vector2()


func _init() -> void:
	id = "loadershortcuts"
	title = "Loader shortcuts"
	description = "The Loader's shortcuts: keys for her eye, gaze, tongue and tears, his pleasure, cum and holding her."
	default_enabled = true


func _enable() -> void:
	on_key(KEY_1, toggle_eye, "open / close her eye", "eye")
	on_key(KEY_2, next_look, "her gaze: default, up, forward", "look")
	on_key(KEY_0, toggle_tongue, "her tongue out", "tongue")
	on_key(KEY_7, tear, "add a tear", "tear")
	on_key(KEY_3, toggle_cum_gen, "cum from the mouse", "cum_gen")
	on_key(KEY_4, func(): keep_cum = not keep_cum, "keep cum from fading", "keep_cum")
	on_key(KEY_5, func(): hold = not hold, "hold her", "auto_hold")
	on_key(KEY_6, func(): g.inGameMenu.cbBukkakeModeClicked(), "bukkake mode", "bukkake")
	on_key(KEY_NUMPAD_1, func(): add_pleasure(PLEASURE_STEP), "his pleasure +", "pleasure_up")
	on_key(KEY_NUMPAD_3, func(): add_pleasure(-PLEASURE_STEP), "his pleasure -", "pleasure_down")
	modify(&"Her.lookTarget", {"phase": Hooks.OVERRIDE, "op": "fn", "when": func(_her): return look != Look.DEFAULT,
		"fn": func(_point, her): return her.hisFace if look == Look.UP else her.eyesDown})
	modify(&"Her.pullOffPower", {"phase": Hooks.FINAL, "op": "set", "value": {"start": 0.0, "increase": 0.0, "max": 0.0},
		"when": func(_her): return hold})
	modify(&"Her.pullOff", {"phase": Hooks.FINAL, "op": "set", "value": {"pull": 0.0, "power": 0.0},
		"when": func(_her): return hold})
	on_tick(_tick)


func _disable() -> void:
	if _strand != null:
		toggle_cum_gen()
	look = Look.DEFAULT
	hold = false
	keep_cum = false


func _tick() -> void:
	if g.her == null or not g.gameRunning or g.gamePaused:
		return
	if hold:
		g.her.activeHold(false)
	if _strand != null:
		_draw_strand()
	if keep_cum:
		var n: int = g.strandControl.strand_count(true)
		if n > 0:
			var back := PackedInt32Array()
			back.resize(n)
			back.fill(-1)
			g.strandControl.add_strand_ages(true, back)


func toggle_eye() -> void:
	if g.her.eyelidMotion["isClosed"]:
		g.her.openEye()
	else:
		g.her.closeEye()


func next_look() -> void:
	look = ((look + 1) % Look.size()) as Look


func toggle_tongue() -> void:
	if g.her.tongue.hangingOut:
		g.her.tongue.stopHangingOut()
	else:
		g.her.tongue.hangOut()


func tear() -> void:
	g.her.tears.addTearSpot()
	g.her.tears.releaseTears()


func add_pleasure(amount: float) -> void:
	var him = g.him
	var top: float = maxf(him.pleasure, him.ejacPleasure + PLEASURE_OVER)
	him.pleasure = clampf(him.pleasure + amount, 0.0, top)   # direct: a one-off change by the player, as in the Loader


func toggle_cum_gen() -> void:
	if _strand == null:
		_strand_start = _mouse()
		_strand = g.strandControl.newCumStrand(_strand_start, g.her)
		_strand.myGravity = g.gravity / 2.0
		_strand.collisionFree = 1
	else:
		_strand.detachSourceLink(Vector2.ZERO, 0)
		g.strandControl.checkElementAnchors(g.her)
		_strand = null


func _draw_strand() -> void:
	if _strand is NativeStrand and not _strand.alive:   # cleared (the clear key, a new character)
		_strand = null
		return
	_strand.insertLink((_mouse() - _strand_start) / 100.0, 2, g.randomCumMass() * 1.3)


func _mouse() -> Vector2:
	return g.her.globalToLocal(Flash.mouse_position())
