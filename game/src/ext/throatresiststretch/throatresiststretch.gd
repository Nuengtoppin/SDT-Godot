extends SDTExtension
## Built-in reimplementation of the Loader mod throatResistStretch (sby, V3): with vigorous or deep use her throat
## loosens (her neck shows it stretched) and her throat resistance drops, then slowly recovers (Behaviour >
## Resistance, "Throat loosens", off by default like the mod). The throat resistance slider sets the most it can be.
## A setting for all characters, like the mod's own default.
## The loosening is the throat entrance ring of ThroatRings (throat_rings.gd), not the mod's own counter. The ring stretches under his pressure (his width past the entrance, more while he
## pushes in) and tightens back at the speed set here. While it is stretched, through value points (Hooks.value):
##   - Her.resistance: the throat entrance's share of the resistance drops with the stretch (none when fully
##     stretched), as the mod lowered the throat resistance;
##   - Neck.depth: the neck is drawn at least as deep as the stretch, as the mod drew it (it rendered the neck a
##     second time each tick for this; now the game's one render does it).
## Her throat resistance setting itself is never changed (the mod's lowered value used to end up in the character
## code). The ring is also worked out, read only, while Developer mode is on (for its Body section).

var loose := 0.0          # the throat entrance ring's stretch, 0..1 (the mod's vigourthroat), for display
var _resist_fn := Callable()
var _depth_fn := Callable()


func _init() -> void:
	id = "throatresiststretch"
	title = "throatResistStretch"
	description = "throatResistStretch (sby): her throat loosens with vigorous or deep use and recovers (Behaviour > Resistance)."
	default_enabled = true


func _setup() -> void:
	setting("on", false, {"label": "Throat loosens",
		"desc": "Vigorous or deep use stretches her throat and lowers its resistance; it recovers slowly."})
	setting("recover", 0.25, {"label": "Throat recovers", "min": 0.05, "max": 2.0, "step": 0.05,
		"desc": "How fast her loosened throat tightens back (1: as fast as a collar; 0.25: about a minute and a half from fully loose)."})


func _enable() -> void:
	_resist_fn = func(v, her) -> float:
		var e: Dictionary = ThroatRings.entrance
		if ThroatRings.tip <= e["top"] or ThroatRings.tip >= e["bottom"]:
			return v
		var upper: float = her.resistance["upper"]
		return upper + (v - upper) * (1.0 - e["stretch"])
	_depth_fn = func(v, _neck) -> float:
		return maxf(v, ThroatRings.entrance["stretch"])
	on_late_tick(_tick)
	var on := func(): return get_setting("on")
	menu_control("behaviour", "Resistance", MenuSchema.setting_control(self, "on", {"after": "Throat resistance"}))
	menu_control("behaviour", "Resistance", MenuSchema.setting_control(self, "recover", {"after": "Throat resistance", "visible": on}))
	_apply()


func _disable() -> void:
	_release()


func _setting_changed(_key: String, _value) -> void:
	_apply()


func _apply() -> void:
	ThroatRings.entrance["recover"] = float(get_setting("recover"))
	unmodify()
	if get_setting("on"):
		modify(&"Her.resistance", {"phase": Hooks.MOOD, "op": "fn", "fn": _resist_fn})
		modify(&"Neck.depth", {"phase": Hooks.MOOD, "op": "fn", "fn": _depth_fn})
	else:
		_release()


func _release() -> void:
	unmodify()
	ThroatRings.entrance["stretch"] = 0.0
	loose = 0.0


func _tick() -> void:
	var her = g.her
	if her == null or g.gamePaused or not (get_setting("on") or ThroatRings.active()):
		return
	ThroatRings.tick(her)
	loose = ThroatRings.entrance["stretch"]

