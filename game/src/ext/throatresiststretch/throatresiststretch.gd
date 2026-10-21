extends SDTExtension
## Built-in reimplementation of the Loader mod throatResistStretch (sby, V3): with vigorous or deep use her throat
## loosens (her neck shows it stretched) and her throat resistance drops, then slowly recovers (Behaviour >
## Resistance, "Throat loosens", off by default like the mod). The throat resistance slider sets the most it can be.
## A setting for all characters, like the mod's own default. Values from its settings file as shipped. Written from
## its source. Port fix: the loosened resistance is not stored as her throat resistance (the mod's lower value went
## into the character code whenever she was saved while loose); the slider keeps showing the value you set.

const INCREASE := 0.0015         # per tick while vigorous enough
const DECREASE := 0.0002
const DEPTH_INCREASE := 0.0004   # per tick while he is deeper than the current loosening
const DEPTH_DECREASE := 0.0001
const MAX_PERCENT := 1.0
const MIN_PERCENT := 0.0
const MIN_RESIST := 0.0

var loose := 0.0          # the mod's vigourthroat, 0..1
var max_resist := 50.0    # her throat resistance as set (slider / character code)
var _setting := false


func _init() -> void:
	id = "throatresiststretch"
	title = "throatResistStretch"
	description = "throatResistStretch (sby): her throat loosens with vigorous or deep use and recovers (Behaviour > Resistance)."
	default_enabled = true


func _setup() -> void:
	setting("on", false, {"label": "Throat loosens",
		"desc": "Vigorous or deep use stretches her throat and lowers its resistance; it recovers slowly."})


func _enable() -> void:
	max_resist = g.throatResistance
	hook_after(&"Her.setThroatResistance", func(_c):
		if not _setting:
			max_resist = g.throatResistance
			loose = 0.0)
	on_late_tick(_tick)
	menu_control("behaviour", "Resistance", MenuSchema.setting_control(self, "on", {"after": "Throat resistance"}))


func _disable() -> void:
	_release()


func _setting_changed(_key: String, value) -> void:
	if value:
		loose = 0.0
	else:
		_release()


func _release() -> void:
	loose = 0.0
	if g.her != null:
		_setting = true
		g.her.setThroatResistance(max_resist)
		_setting = false


func _tick() -> void:
	var her = g.her
	if not get_setting("on") or her == null or g.gamePaused:
		return
	var vigorous: float = her.vigour / her.VIGOUR_WINCE_LEVEL * 2.0
	var depth: float = her.penisInMouthDist / her.hiltDistance if her.hiltDistance != 0 else 0.0
	var deeper: bool = depth > loose and not g.penisOut
	if her.held and vigorous > loose and not g.penisOut:
		loose = minf(loose + INCREASE, MAX_PERCENT)
	elif not deeper:
		loose = maxf(loose - DECREASE, MIN_PERCENT)
	if her.held and deeper:
		loose = minf(loose + DEPTH_INCREASE, MAX_PERCENT)
	elif vigorous < loose:
		loose = maxf(loose - DEPTH_DECREASE, MIN_PERCENT)
	if loose > 0 and not (her.mouthFull and her.penisInMouthDist / 400.0 > loose):
		her.head.neck.render(loose)
	if her.mouthFull:
		_setting = true
		her.setThroatResistance((1 - loose) * maxf(0, max_resist - MIN_RESIST) + MIN_RESIST)
		g.throatResistance = max_resist   # (port fix, see above)
		_setting = false
