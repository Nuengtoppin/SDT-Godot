class_name Hooks
extends RefCounted
## Port extension (not in the original game): hook points that let extensions run code before or after a game
## method, like the Loader's lProxy did for Loader mods. GDScript cannot replace methods at runtime, so each method
## an extension needs gets two guarded lines, named after the original AS3 class and method:
##
##     func lookAt(target: Vector2) -> void:
##         if Hooks.has(&"Her.lookAt"):                     # HOOK
##             var h := Hooks.before(&"Her.lookAt", self, [target])
##             if h.cancelled:
##                 return
##             target = h.args[0]
##         ...original code, unchanged...
##         if Hooks.has(&"Her.lookAt"):                     # HOOK
##             Hooks.after(&"Her.lookAt", self, [target])
##
## - Hooks.has() is a single dictionary lookup, so an unused hook point costs next to nothing, even in methods that
##   run every tick.
## - Before-handlers run in priority order (lower first, then registration order). Each gets the Call: it may change
##   call.args (the hook point copies them back), or call cancel(result) to skip the original method; the remaining
##   before-handlers and all after-handlers are then skipped too.
## - After-handlers get the same kind of Call, with call.result holding the method's return value; they may replace
##   it (the hook point returns call.result when the method returns something).
## - While a hook's handlers run, Hooks.has() is false for that hook, so a handler can call the hooked method itself
##   to run the original code (what a Loader mod did by calling the proxied function from inside its proxy).
## - A handler registered with a `target` only runs when the hooked object is that object (lProxy hooked one object;
##   a hook name covers every instance of the class).
## - Every hook point in game code is marked with `# HOOK`, so `grep -rn "# HOOK" game/src` lists them.

## One call of a hooked method, passed to every handler.
class Call:
	extends RefCounted
	var name: StringName
	var obj: Object
	var args: Array
	var result = null
	var cancelled := false

	## Skips the original method (and the handlers after this one); `value` becomes the method's return value.
	func cancel(value = null) -> void:
		cancelled = true
		result = value


## hook name -> {"before": [handler], "after": [handler]}; handler = [priority, seq, Callable, target, owner]
static var _hooks: Dictionary = {}
static var _running: Dictionary = {}   # hook names whose handlers are running (re-entrancy guard)
static var _seq := 0


## True if any handler is registered for `name` (and its handlers are not already running).
static func has(name: StringName) -> bool:
	return _hooks.has(name) and not _running.has(name)


## Registers `fn(call: Hooks.Call)` to run before the method `name` ("Class.method"). `owner` (usually the
## extension id) lets remove_owner() take all of an extension's handlers off again.
static func add_before(name: StringName, fn: Callable, owner := "", priority := 0, target: Object = null) -> void:
	_add(name, "before", fn, owner, priority, target)


static func add_after(name: StringName, fn: Callable, owner := "", priority := 0, target: Object = null) -> void:
	_add(name, "after", fn, owner, priority, target)


static func remove(name: StringName, fn: Callable) -> void:
	if not _hooks.has(name):
		return
	for phase in ["before", "after"]:
		var list: Array = _hooks[name][phase]
		for i in range(list.size() - 1, -1, -1):
			if list[i][2] == fn:
				list.remove_at(i)
	_drop_if_empty(name)


## Removes every handler registered with `owner`.
static func remove_owner(owner: String) -> void:
	for name in _hooks.keys():
		for phase in ["before", "after"]:
			var list: Array = _hooks[name][phase]
			for i in range(list.size() - 1, -1, -1):
				if list[i][4] == owner:
					list.remove_at(i)
		_drop_if_empty(name)


static func before(name: StringName, obj: Object, args: Array = []) -> Call:
	return _run(name, "before", obj, args, null)


static func after(name: StringName, obj: Object, args: Array = [], result = null) -> Call:
	return _run(name, "after", obj, args, result)


## Calls `fn` with the hook `name` inactive, so the game method runs its original code (what a Loader mod got by
## calling the function it had replaced, e.g. "tapHands_l").
static func without(name: StringName, fn: Callable):
	var was := _running.has(name)
	_running[name] = true
	var r = fn.call()
	if not was:
		_running.erase(name)
	return r


## Hook names with handlers, for debugging.
static func registered() -> Array:
	return _hooks.keys()


static func _add(name: StringName, phase: String, fn: Callable, owner: String, priority: int, target: Object) -> void:
	if not _hooks.has(name):
		_hooks[name] = {"before": [], "after": []}
	_seq += 1
	var list: Array = _hooks[name][phase]
	list.append([priority, _seq, fn, target, owner])
	list.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))


static func _drop_if_empty(name: StringName) -> void:
	if _hooks.has(name) and _hooks[name]["before"].is_empty() and _hooks[name]["after"].is_empty():
		_hooks.erase(name)


static func _run(name: StringName, phase: String, obj: Object, args: Array, result) -> Call:
	var c := Call.new()
	c.name = name
	c.obj = obj
	c.args = args
	c.result = result
	var entry = _hooks.get(name)
	if entry == null:
		return c
	_running[name] = true
	for h in entry[phase].duplicate():
		if h[3] != null and h[3] != obj:
			continue
		var fn: Callable = h[2]
		if not fn.is_valid():
			continue
		fn.call(c)
		if c.cancelled:
			break
	_running.erase(name)
	return c
