class_name ValuePoints
extends RefCounted
## derrdev: value points - numbers the game reads every tick that extensions add to, in phases, instead of writing
## the game's variable themselves (and fighting over it). The maintainer's design (Hooks.value with phases MOOD ->
## OVERRIDE -> CLAMP -> FINAL), made small and kept apart here so it can be swapped for his core when it lands; for
## now only her throat and neck use it (the throat ring work). Each point in game code is two guarded lines:
##
##     var amount := throatBulgeAmount
##     if ValuePoints.has(&"Neck.throatBulge"):                              # VALUE
##         amount = ValuePoints.value(&"Neck.throatBulge", amount, self)
##
## - With no handler for a point the game's own number is used as it is (one dictionary lookup).
## - Handlers run by phase, then priority (lower first), then registration order. Each is fn(v: float, base: float,
##   obj: Object) -> float: v is the value so far, base the game's own number, obj the object asking.
##     MOOD      lasting additions and factors (moods, a stretched ring, a cum bulge)
##     OVERRIDE  timed commands that set the value outright (dialogue, triggers)
##     CLAMP     limits (a collar holding the throat)
##     FINAL     last word (developer tools)
## - While a point's handlers run, has() is false for it, so a handler can ask for the game's number itself.
## - `owner` (an extension id) lets remove_owner() take all of an extension's handlers off; Extensions does that when
##   an extension is switched off.
## - last[name] = [base, result] of the latest ask, for the developer panel.
## Every value point in game code is marked with `# VALUE`.

const MOOD := 0
const OVERRIDE := 1
const CLAMP := 2
const FINAL := 3
const PHASE_NAMES := ["mood", "override", "clamp", "final"]

## name -> [[phase, priority, seq, Callable, owner], ...] sorted
static var _points: Dictionary = {}
static var _running: Dictionary = {}
static var _seq := 0
static var last: Dictionary = {}


static func has(name: StringName) -> bool:
	return _points.has(name) and not _running.has(name)


## The value of point `name`: the game's own number `base` after every handler, in order.
static func value(name: StringName, base: float, obj: Object = null) -> float:
	var v := base
	_running[name] = true
	for h in _points[name]:
		v = float(h[3].call(v, base, obj))
	_running.erase(name)
	last[name] = [base, v]
	return v


static func add(name: StringName, fn: Callable, owner := "", phase := MOOD, priority := 0) -> void:
	_seq += 1
	var list: Array = _points.get(name, [])
	list.append([phase, priority, _seq, fn, owner])
	list.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and (a[1] < b[1] or (a[1] == b[1] and a[2] < b[2]))))
	_points[name] = list


static func remove(name: StringName, fn: Callable) -> void:
	if not _points.has(name):
		return
	_points[name] = _points[name].filter(func(h): return h[3] != fn)
	_drop_if_empty(name)


static func remove_owner(owner: String) -> void:
	for name in _points.keys():
		_points[name] = _points[name].filter(func(h): return h[4] != owner)
		_drop_if_empty(name)


## [[name, phase name, owner], ...] of every handler, for the developer panel.
static func registered() -> Array:
	var out: Array = []
	for name in _points:
		for h in _points[name]:
			out.append([name, PHASE_NAMES[h[0]], h[4]])
	return out


static func _drop_if_empty(name: StringName) -> void:
	if _points[name].is_empty():
		_points.erase(name)
		last.erase(name)
