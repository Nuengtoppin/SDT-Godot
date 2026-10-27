class_name DevTuning
extends RefCounted
## derrdev (P054): hand settings for the behaviour tabs of the developer panel - how her behaviours run, for testing
## and for later automation. Each is a modifier on one of the game's value points (owner "devtuning") while it is
## not the game's; for this session only (back to the game's at the next start), whether Developer mode is on or not.
## The controls appear under a tab's rows (DevBehaviour.sections).

const OWNER := "devtuning"

## value point -> modifier id, for the tunings that differ from the game
static var _mods := {}
## "Clench time" in seconds; 0: the game's (2 to 6 s)
static var clench_s := 0.0
static var clench_taps := true


static func _set_mod(name: StringName, on: bool, spec: Dictionary) -> void:
	if _mods.has(name):
		Hooks.remove_modifier(_mods[name])
		_mods.erase(name)
	if on:
		_mods[name] = Hooks.add_modifier(name, spec, OWNER)


static func set_clench_time(s: float) -> void:
	clench_s = maxf(0.0, s)
	_set_mod(&"Her.clenchTime", clench_s > 0.0, {"phase": Hooks.OVERRIDE, "op": "set",
		"value": maxi(1, int(round(clench_s * Flash.frame_rate)))})


static func set_clench_taps(on: bool) -> void:
	clench_taps = on
	_set_mod(&"Her.clenchTaps", not on, {"phase": Hooks.OVERRIDE, "op": "set", "value": false})


## All back to the game's.
static func reset() -> void:
	set_clench_time(0.0)
	set_clench_taps(true)


## The tab's hand settings, under its rows.
static func controls(group: String) -> Array:
	match group:
		"mouth":
			return [MenuSchema.note("Hand settings, for this session (back to the game's at the next start)."),
				{"type": "slider", "label": "Clench time", "tip": "How long she keeps her teeth clenched. 0: the game's, 2 to 6 s at random.",
					"min": 0.0, "max": 20.0, "step": 0.5, "get": func(): return clench_s, "set": func(v: float): set_clench_time(v),
					"format": func(v): return "game" if v <= 0.0 else "%.1f s" % v, "reset": func(): set_clench_time(0.0)},
				MenuSchema.toggle("Taps when clenching", "She taps him as she clenches her teeth (the game's). Off: she clenches them without it; Tap hands stays its own.",
					func(): return clench_taps, func(on: bool): set_clench_taps(on))]
	return []
