extends SDTExtension
## Built-in reimplementation of the Loader mod penisrange (sby, V8), "Extended size range" in Him > Penis: his penis
## can be longer, wider and smaller than the game allows (by default up to 3, down to half the game's least, like the
## mod's settings file), his balls bigger and smaller (x3, /2). Off by default, so the game's sliders keep their range.
## Written from its source.
## While a size is outside the game's own range: the mask that hides him inside her mouth follows how far his tip is
## past her lips (the game's mask is made for the game's lengths), his in-mouth smoothing eases off for big sizes
## (the mod's flexible constraint smoothing, against shaking), and big balls move down and back. Within the game's
## range nothing changes. Sizes stay in the character code as sizes, as before; switched off, a size past the game's
## range is brought back into it.
## Not taken: the mod's per-character size file (the character code keeps sizes), its tilt options (off in its
## settings file), its strap-on colour field.
## Limits of the game's geometry, not of this port (tested here): her head moves back only as far as the game's
## lengths need, so past a length of about 2 his tip is already past her lips with her head all the way back and she
## takes him as poking her face, not as entering; auto mode moves her head in the game's range and gets stuck there
## with a long penis. The neck's bulge stops growing at 35 px.
## Side effect of the wider range: whatever reads Him.MIN/MAX_* sees it - MoreTriggers' size triggers step over the
## wider range (each step is larger), and DialogueActions' minSize / maxSize report it. The Loader mod did the same.

const GAME_MIN := 0.7      # the game's limits (Him.MIN_PENIS_SIZE etc. as shipped)
const GAME_MAX := 1.2
const GAME_BALL_MIN := 0.5
const GAME_BALL_MAX := 1.3
const MASK_OFFSET := 140.0   # how far past her lips (screen px at zoom 1) the mask starts to uncover him
const MASK_LENGTH := 300.0   # mask travel per unit of length

var _on := false   # the wider limits apply (the value point modifiers' condition)


func _init() -> void:
	id = "penisrange"
	title = "penisrange"
	description = "penisrange (sby): his penis and balls bigger and smaller than the game allows (Him > Penis)."
	default_enabled = true


func _setup() -> void:
	setting("on", false, {"label": "Extended size range",
		"desc": "Penis length and width and ball size past the game's limits. Very big sizes do not fit her mouth and neck yet."})
	setting("max_size", 3.0, {"label": "Largest size", "min": 1.2, "max": 4.0, "step": 0.1,
		"desc": "The longest and widest he can be (the game's: 1.2). Balls: 1.3 x this / 1.2."})
	setting("min_factor", 2.0, {"label": "Smallest size ÷", "min": 1.0, "max": 3.0, "step": 0.25,
		"desc": "The game's smallest sizes divided by this (1: the game's)."})


func _enable() -> void:
	# value points of Him (see the header): the mask, the in-mouth smoothing, where big balls sit
	modify(&"Him.penisMask", {"phase": Hooks.MOOD, "op": "fn", "when": func(him): return _on and _outside(him),
		"fn": func(m, him): return _mask(m, him)})
	modify(&"Him.mouthSmoothing", {"phase": Hooks.MOOD, "op": "fn",
		"when": func(him): return _on and _outside(him) and g.her.mouthFull and not g.gamePaused,
		"fn": func(_v, him): return 0.6 - 0.95 * clampf((him.penis.scaleX + him.penis.scaleY - 1.2) / 3.6, 0.0, 1.0)})
	modify(&"Him.ballsOffset", {"phase": Hooks.MOOD, "op": "fn", "when": func(_him): return _on,
		"fn": func(v, him): return v + Vector2(20.0, 22.0) * maxf(0.0, him.currentBallSize - GAME_BALL_MAX)})
	var on := func(): return get_setting("on")
	menu_control("him", "Penis", MenuSchema.setting_control(self, "on", {"after": "Width"}))
	menu_control("him", "Penis", MenuSchema.setting_control(self, "max_size", {"after": "Width", "visible": on, "wide": true}))
	menu_control("him", "Penis", MenuSchema.setting_control(self, "min_factor", {"after": "Width", "visible": on, "wide": true}))
	_apply()


func _disable() -> void:
	_apply_limits(false)


func _setting_changed(_key: String, _value) -> void:
	_apply()


func _apply() -> void:
	_apply_limits(get_setting("on"))


## Sets the limits and brings the current sizes inside them; the sliders follow.
func _apply_limits(on: bool) -> void:
	var him = g.him
	var f: float = get_setting("min_factor") if on else 1.0
	var top: float = maxf(GAME_MAX, get_setting("max_size")) if on else GAME_MAX
	_on = on
	Him.MIN_PENIS_SIZE = GAME_MIN / f
	Him.MAX_PENIS_SIZE = top
	Him.MIN_BALL_SIZE = GAME_BALL_MIN / f
	Him.MAX_BALL_SIZE = GAME_BALL_MAX * top / GAME_MAX
	if him == null:
		return
	him.loadPenisScales(him.currentPenisLengthScale, him.currentPenisWidthScale)   # clamps, updates the sliders
	him.setBallScale(him.currentBallSize)   # also places his balls (Him.ballsOffset)
	g.inGameMenu.updateBallSizeSlider()


## A size outside the game's own range.
func _outside(him) -> bool:
	var length: float = him.currentPenisLengthScale
	var width: float = him.currentPenisWidthScale
	return length > GAME_MAX or width > GAME_MAX or length < GAME_MIN or width < GAME_MIN


## The mod's mask (Him.penisMask): uncovered by how far his tip is past her lips, scaled to his length.
func _mask(_m: Dictionary, him) -> Dictionary:
	var her = g.her
	var length: float = him.currentPenisLengthScale
	if not her.mouthFull:
		return {"x": -100.0, "scale": length}
	var dist: float = her.localToGlobal(her.topLipA).distance_to(him.getPenisTipPoint(0, 0))
	var zoom: float = g.sceneLayer.currentZoom
	var lo: float = MASK_OFFSET * zoom
	var hi: float = MASK_LENGTH * length * zoom + lo
	var full: float = MASK_LENGTH * length
	var x: float = clampf(full * (dist - lo) / (hi - lo), 0.0, full)
	return {"x": -100.0 if x == 0.0 else x, "scale": length}
