class_name SDTExtension
extends RefCounted
## Port extension (not in the original game): base class of every extension, built in (src/ext/<name>/) or a
## plugin (Mods/Plugins/<name>/). Extensions change the game only through this API (hooks, tick callbacks,
## settings), so all of them can be switched off at once ("Vanilla mode") and the 1:1 game code stays as it was.
##
## A minimal extension:
##
##     extends SDTExtension
##
##     func _init() -> void:
##         id = "example"
##         title = "Example"
##
##     func _setup() -> void:                       # declare settings (called once, before loading saved values)
##         setting("strength", 0.5, {"label": "Strength", "min": 0.0, "max": 1.0})
##
##     func _enable() -> void:                      # register hooks and tick callbacks
##         on_tick(_tick)
##         hook_after(&"Her.passOut", func(c): print("passed out"))
##
##     func _tick() -> void:
##         pass
##
## Everything registered with on_tick / on_late_tick / hook_before / hook_after is removed automatically when the
## extension is disabled; _disable() only has to undo changes it made to the game itself.

var id := ""
var title := ""
var description := ""
var author := ""
var version := ""
## Built-in extensions ship with the game; plugins come from Mods/Plugins.
var builtin := true
## Whether the extension is on when the player has not chosen yet.
var default_enabled := false
## Set by Extensions while the extension is on.
var enabled := false

var _settings: Dictionary = {}   # key -> {"value", "default", "label", "desc", "min", "max", "step", "options"}
var _setting_order: Array = []


# ---------------------------------------------------------------- overridable

## Declare settings here with setting().
func _setup() -> void:
	pass


## Called when the extension is switched on (at startup if it is enabled).
func _enable() -> void:
	pass


## Called when the extension is switched off, after its hooks and tick callbacks were removed.
func _disable() -> void:
	pass


## Called after a setting changed (from the options screen or set_setting()).
func _setting_changed(_key: String, _value) -> void:
	pass


# ---------------------------------------------------------------- tick and hooks

## Runs `fn` every game tick, before the game's own tick (timelines, then the game's ENTER_FRAME logic).
func on_tick(fn: Callable) -> void:
	Extensions._add_tick(self, fn, false)


## Runs `fn` every game tick, after the game's own logic (before masks follow moved objects).
func on_late_tick(fn: Callable) -> void:
	Extensions._add_tick(self, fn, true)


## Runs `fn(call: Hooks.Call)` before the game method `name` ("Class.method"); see Hooks.
func hook_before(name: StringName, fn: Callable, priority := 0, target: Object = null) -> void:
	Hooks.add_before(name, fn, id, priority, target)


func hook_after(name: StringName, fn: Callable, priority := 0, target: Object = null) -> void:
	Hooks.add_after(name, fn, id, priority, target)


# ---------------------------------------------------------------- settings

## Declares a setting. The default's type is the setting's type (bool, int, float, String). `info` keys, all
## optional: "label", "desc", "min", "max", "step" (numbers), "options" (Array of allowed values). The options
## screen is generated from these declarations.
func setting(key: String, default, info: Dictionary = {}) -> void:
	var s := info.duplicate()
	s["default"] = default
	s["value"] = default
	if not _settings.has(key):
		_setting_order.append(key)
	_settings[key] = s


func get_setting(key: String):
	var s = _settings.get(key)
	if s == null:
		push_error("extension %s: unknown setting '%s'" % [id, key])
		return null
	return s["value"]


## Changes a setting, saves it and calls _setting_changed().
func set_setting(key: String, value) -> void:
	var s = _settings.get(key)
	if s == null:
		push_error("extension %s: unknown setting '%s'" % [id, key])
		return
	value = _coerce(s, value)
	if typeof(value) == typeof(s["value"]) and value == s["value"]:
		return
	s["value"] = value
	Extensions._save_setting(self, key, value)
	_setting_changed(key, value)


## Setting keys in declaration order, with their info ("value", "default", "label", ...).
func settings() -> Array:
	var out := []
	for k in _setting_order:
		var s: Dictionary = _settings[k].duplicate()
		s["key"] = k
		out.append(s)
	return out


func _coerce(s: Dictionary, value):
	match typeof(s["default"]):
		TYPE_BOOL:
			value = bool(value) if not value is String else value.to_lower() in ["1", "true", "yes", "on"]
		TYPE_INT:
			value = int(value)
		TYPE_FLOAT:
			value = float(value)
		TYPE_STRING:
			value = str(value)
	if (value is int or value is float) and s.has("min"):
		value = maxf(value, s["min"]) if value is float else maxi(value, s["min"])
	if (value is int or value is float) and s.has("max"):
		value = minf(value, s["max"]) if value is float else mini(value, s["max"])
	if s.has("options") and not value in s["options"]:
		value = s["default"]
	return value


# ---------------------------------------------------------------- files

## Folder for this extension's own files (created on first use). It lives with the save files, so test runs
## with --save-dir never touch the player's data.
func data_dir() -> String:
	var d := Extensions.data_root().path_join(id)
	DirAccess.make_dir_recursive_absolute(d)
	return d
