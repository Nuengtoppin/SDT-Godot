extends SDTExtension
## Built-in reimplementation of the Loader mod throatcumbulge (sby, V6), in Behaviour > Reactions under Throat bulge:
##   - the throat bulge setting is saved per character, in the character code as "throatvanillabulge:n" like the mod;
##   - "Cum bulge": while he cums down her held throat it bulges more, with the cum's volume, then settles back
##     (off by default; its strength slider);
##   - "Swallow bulge": the game's, by how big the swallow is, by a slider, or the larger of the two (the game's by
##     default).
## Settings for all characters, like the mod's own default. Values from its settings file as shipped. Written from its
## source (its replacement of the neck drawing is the port's Neck.swallowScale).
## Swallowing, after sby's swallowguzzle but on the game's own swallow (so the Her.swallow veto and the developer
## panel's switch still apply), all off by default:
##   - "Swallow until empty": when a swallow ends with cum left and her mouth free, she swallows again;
##   - "Swallow while he cums": on each spurt in her mouth (not held deep: that goes down her throat anyway), when her
##     mouth is more than half full, or whenever there is cum in it, she swallows if not already swallowing;
##   - "Per swallow": how much one swallow takes (0: the game's 5-9);
##   - swallow bulge "By amount": the swallow's bulge follows how much she swallowed.
## Extra swallows say nothing (no SWALLOW dialogue line each time).

const MAX_BULGE := 1.5
const CHANGE_SPEED := 0.7
const SOUND_TRACK_SPEED := 0.5
const RETURN_RATE := 0.025
const INTENSITY_MIN := 0.4
const INTENSITY_MAX := 1.2
const SWALLOW_MIN := 0.2
const SWALLOW_MAX := 0.75
const SWALLOW_MODES := ["The game's", "By swallow", "By slider", "Larger of both", "By amount"]
const PUMP_MODES := ["Off", "When full", "Always"]
const AMOUNT_FULL := 10.0   # a swallow of this much gives the largest bulge of "By swallow" (SWALLOW_MAX)

var _cumming := false
var _base := 1.0     # the throat bulge setting while it is raised
var _volume := 0.0
var _prev_cum := 0
var _prev_wave := false
var _prev_swallowing := false
var last_amount := 0          # how much the last swallow took


func _init() -> void:
	id = "throatcumbulge"
	title = "throatcumbulge"
	description = "throatcumbulge (sby): her throat bulges with his cum and her swallows; the throat bulge is saved per character (Behaviour > Reactions)."
	default_enabled = true


func _setup() -> void:
	setting("cum_bulge", false, {"label": "Cum bulge", "desc": "Her throat bulges while he cums down it."})
	setting("cum_amount", 0.5, {"label": "Cum bulge strength", "min": 0, "max": 1, "step": 0.01})
	setting("swallow_mode", SWALLOW_MODES[0], {"label": "Swallow bulge", "options": SWALLOW_MODES,
		"desc": "How much her throat bulges when she swallows."})
	setting("swallow_amount", 0.25, {"label": "Swallow bulge size", "min": 0, "max": 1, "step": 0.01,
		"desc": "0.25 is about the game's."})
	setting("guzzle", false, {"label": "Swallow until empty",
		"desc": "When a swallow ends with cum left and her mouth free, she swallows again until it is empty."})
	setting("pump", PUMP_MODES[0], {"label": "Swallow while he cums", "options": PUMP_MODES,
		"desc": "On each spurt in her mouth she swallows: when her mouth is more than half full, or whenever there is cum in it."})
	setting("per_swallow", 0, {"label": "Per swallow", "min": 0, "max": 20, "step": 1,
		"desc": "How much one swallow takes (0: the game's, 5 to 9). Less: more swallows to empty her mouth."})


func _enable() -> void:
	_base = g.throatBulgeAmount
	on_late_tick(_tick)
	charcode_field("throatvanillabulge", func(): return "%.5f" % (_base if _cumming else g.throatBulgeAmount),
		func(v, _l): _set_bulge(v.split(",")[0].to_float()))
	var after := {"after": "Throat bulge"}
	menu_control("behaviour", "Reactions", MenuSchema.setting_control(self, "cum_bulge", after))
	menu_control("behaviour", "Reactions", MenuSchema.setting_control(self, "cum_amount",
		{"after": "Throat bulge", "visible": func(): return get_setting("cum_bulge")}))
	menu_control("behaviour", "Reactions", MenuSchema.setting_control(self, "swallow_mode",
		{"after": "Throat bulge", "wide": true}))
	menu_control("behaviour", "Reactions", MenuSchema.setting_control(self, "swallow_amount",
		{"after": "Throat bulge", "visible": func(): return get_setting("swallow_mode") in SWALLOW_MODES.slice(2, 4)}))
	for key in ["guzzle", "pump", "per_swallow"]:
		menu_control("behaviour", "Reactions", MenuSchema.setting_control(self, key, {"after": "Throat bulge", "wide": key in ["pump", "per_swallow"]}))
	hook_after(&"Him.nextSpurt", func(_c): _on_spurt())
	_prev_cum = g.her.cumInMouth if g.her != null else 0


func _disable() -> void:
	if _cumming:
		_set_bulge(_base)
	_cumming = false
	if g.her != null:
		g.her.head.neck.swallowScale = Vector2(0.8, 0.5)


func _set_bulge(v: float) -> void:
	if is_nan(v):
		return
	g.throatBulgeAmount = v
	if g.her != null:
		g.her.throatBulgeChanged()
	g.inGameMenu.updateThroatBulgeSlider()


func _tick() -> void:
	var her = g.her
	if her == null:
		return
	_cum_bulge(her)
	_swallowing(her)
	_swallow_scale(her)


func _cum_bulge(her) -> void:
	if not (get_setting("cum_bulge") or _cumming):
		_base = g.throatBulgeAmount
		return
	if her.held and g.him.ejaculating:
		if not _cumming:
			_cumming = true
			_base = g.throatBulgeAmount
		if g.soundControl.currentCumVolume > 0:
			_volume += (minf(g.soundControl.currentCumVolume / 0.6, 1) - _volume) * SOUND_TRACK_SPEED
		var target: float = MAX_BULGE * get_setting("cum_amount") * _volume
		var inc: float = (target + _base - g.throatBulgeAmount) * CHANGE_SPEED
		_set_bulge(maxf(minf(g.throatBulgeAmount + inc, MAX_BULGE), _base))
	elif _cumming:
		_volume = 0.0
		if _base != g.throatBulgeAmount:
			_set_bulge(maxf(_base, g.throatBulgeAmount - RETURN_RATE))
		else:
			_cumming = false
	else:
		_base = g.throatBulgeAmount


func _swallow_scale(her) -> void:
	var mode: String = get_setting("swallow_mode")
	var neck = her.head.neck
	if mode == SWALLOW_MODES[0] or not neck.swallowing:
		neck.swallowScale = Vector2(0.8, 0.5)
		return
	var intensity: float = float(her.swallowSequence.get("intensity", INTENSITY_MIN))
	var by_swallow := clampf(SWALLOW_MIN + (intensity - INTENSITY_MIN) / (INTENSITY_MAX - INTENSITY_MIN)
		* (SWALLOW_MAX - SWALLOW_MIN), SWALLOW_MIN, SWALLOW_MAX)
	var slider: float = get_setting("swallow_amount")
	var by_amount := minf(1.5, SWALLOW_MIN + (SWALLOW_MAX - SWALLOW_MIN) * last_amount / AMOUNT_FULL)
	var k: float = by_swallow if mode == SWALLOW_MODES[1] else (slider if mode == SWALLOW_MODES[2] else
		(by_amount if mode == SWALLOW_MODES[4] else maxf(by_swallow, slider)))
	# the mod's smoothlargeswallow: big swallows push out more than down
	neck.swallowScale = Vector2(0.8 * k * 4, 0.5 * minf(1, by_swallow * -16.0 / 3 + 4.0 / 3))


# ---------------------------------------------------------------- swallowing

## After the game's tick: a swallow's wave just started (the game took 5-9 from her mouth on that tick) - set how much
## it took; a swallow just ended - swallow again if "until empty".
func _swallowing(her) -> void:
	var neck = her.head.neck
	if neck.swallowing and not _prev_wave:
		var took: int = _prev_cum - her.cumInMouth
		var per: int = get_setting("per_swallow")
		if per > 0 and took > 0:
			took = mini(per, _prev_cum)
			her.cumInMouth = _prev_cum - took
		last_amount = maxi(0, took)
	if _prev_swallowing and not her.swallowing and get_setting("guzzle") and her.cumInMouth > 0 \
			and her.penisInMouthDist < 0 and not her.passedOut:
		her.swallow(0.0, false)
	_prev_wave = neck.swallowing
	_prev_swallowing = her.swallowing
	_prev_cum = her.cumInMouth


## A spurt starts: swallow during it if "while he cums" says so.
func _on_spurt() -> void:
	var her = g.her
	var mode: String = get_setting("pump")
	if mode == PUMP_MODES[0] or her == null or not her.mouthFull or her.held or g.penisOut or her.swallowing:
		return
	if her.cumInMouth > (her.maxCumInMouth / 2 if mode == PUMP_MODES[1] else 0):
		her.swallow(0.0, false)
