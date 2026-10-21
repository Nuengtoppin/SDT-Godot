extends SDTExtension
## Built-in reimplementation of the Loader mod throatcumbulge (sby, V6), in Behaviour > Reactions under Throat bulge:
##   - the throat bulge setting is saved per character, in the character code as "throatvanillabulge:n" like the mod;
##   - "Cum bulge": while he cums down her held throat it bulges more, with the cum's volume, then settles back
##     (off by default; its strength slider);
##   - "Swallow bulge": the game's, by how big the swallow is, by a slider, or the larger of the two (the game's by
##     default).
## Settings for all characters, like the mod's own default. Values from its settings file as shipped. Written from its
## source (its replacement of the neck drawing is the port's Neck.swallowScale).

const MAX_BULGE := 1.5
const CHANGE_SPEED := 0.7
const SOUND_TRACK_SPEED := 0.5
const RETURN_RATE := 0.025
const INTENSITY_MIN := 0.4
const INTENSITY_MAX := 1.2
const SWALLOW_MIN := 0.2
const SWALLOW_MAX := 0.75
const SWALLOW_MODES := ["The game's", "By swallow", "By slider", "Larger of both"]

var _cumming := false
var _base := 1.0     # the throat bulge setting while it is raised
var _volume := 0.0


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
		{"after": "Throat bulge", "visible": func(): return get_setting("swallow_mode") in SWALLOW_MODES.slice(2)}))


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
	var k: float = by_swallow if mode == SWALLOW_MODES[1] else (slider if mode == SWALLOW_MODES[2] else maxf(by_swallow, slider))
	# the mod's smoothlargeswallow: big swallows push out more than down
	neck.swallowScale = Vector2(0.8 * k * 4, 0.5 * minf(1, by_swallow * -16.0 / 3 + 4.0 / 3))
