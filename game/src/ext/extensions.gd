class_name Extensions
extends RefCounted
## Port extension (not in the original game): loads, enables and runs extensions (see SDTExtension).
##
## - Built-in extensions are listed in BUILTIN; plugins from Mods/Plugins are added with add() (plugin loading
##   comes later).
## - Which extensions are on, and their settings, are kept in extensions.cfg next to the save files
##   (FlashSharedObject.save_dir, so --save-dir test runs use their own copy).
## - "Vanilla mode" (setting, or --vanilla on the command line) keeps every extension off.
## - Tick callbacks run at two fixed points of the game tick (Flash.tick_before / tick_after), in extension load
##   order; their time shows in --profile and in HITCH lines as "ext:<id>".

## Built-in extensions (script paths), in load order.
const BUILTIN: Array[String] = []

const CONFIG_FILE := "extensions.cfg"

static var all: Array[SDTExtension] = []
static var by_id: Dictionary = {}
static var vanilla_mode := false
static var started := false

static var _config: ConfigFile = null
static var _ticks: Array = []        # [extension, Callable], before the game's tick
static var _late_ticks: Array = []   # [extension, Callable], after it
static var _installed := false
static var _events: Dictionary = {}   # event name -> [[extension, Callable]]

## Events extensions can listen to with SDTExtension.on_event(): name -> description.
const EVENTS := {
	"mods_loaded": "a character's .swf mods (or mods chosen in a picker) finished loading",
}


## Called once the game is built (end of DT.initGame): loads the built-in extensions and enables those that are on.
static func start() -> void:
	if started:
		return
	started = true
	_load_config()
	vanilla_mode = "--vanilla" in OS.get_cmdline_user_args() or bool(_config.get_value("extensions", "vanilla_mode", false))
	_install_tick()
	for path in BUILTIN:
		var scr = load(path)
		if scr == null:
			push_error("extensions: cannot load %s" % path)
			continue
		add(scr.new())


## Adds an extension (built in or a plugin): declares its settings, loads saved values, enables it if it is on.
static func add(ext: SDTExtension) -> bool:
	if ext.id == "" or by_id.has(ext.id):
		push_error("extensions: missing or duplicate id '%s'" % ext.id)
		return false
	if _config == null:
		_load_config()
	all.append(ext)
	by_id[ext.id] = ext
	ext._setup()
	for s in ext.settings():
		if _config.has_section_key(ext.id, s["key"]):
			ext._settings[s["key"]]["value"] = ext._coerce(s, _config.get_value(ext.id, s["key"]))
	if is_on(ext.id):
		_enable(ext)
	return true


## Removes an extension entirely (disables it first). Used by tests and when a plugin is unloaded.
static func remove(ext_id: String) -> void:
	var ext: SDTExtension = by_id.get(ext_id)
	if ext == null:
		return
	if ext.enabled:
		_disable(ext)
	all.erase(ext)
	by_id.erase(ext_id)


static func get_extension(ext_id: String) -> SDTExtension:
	return by_id.get(ext_id)


## Whether the extension with this id is (or would be) enabled: the player's choice, else its default.
static func is_on(ext_id: String) -> bool:
	if vanilla_mode:
		return false
	var ext: SDTExtension = by_id.get(ext_id)
	var dflt := ext.default_enabled if ext != null else false
	return bool(_config.get_value("enabled", ext_id, dflt)) if _config != null else dflt


## Switches an extension on or off and remembers the choice.
static func set_enabled(ext_id: String, on: bool) -> void:
	var ext: SDTExtension = by_id.get(ext_id)
	if ext == null:
		return
	_config.set_value("enabled", ext_id, on)
	_save_config()
	if vanilla_mode:
		return
	if on and not ext.enabled:
		_enable(ext)
	elif not on and ext.enabled:
		_disable(ext)


## Turns Vanilla mode on (all extensions off) or off (each back to its own on/off choice).
static func set_vanilla_mode(on: bool) -> void:
	vanilla_mode = on
	_config.set_value("extensions", "vanilla_mode", on)
	_save_config()
	for ext in all:
		var want := is_on(ext.id)
		if want and not ext.enabled:
			_enable(ext)
		elif not want and ext.enabled:
			_disable(ext)


## Folder for extension files, next to the save files.
static func data_root() -> String:
	return FlashSharedObject.save_dir.path_join("extensions")


# ---------------------------------------------------------------- internals

static func _enable(ext: SDTExtension) -> void:
	ext.enabled = true
	ext._enable()


static func _disable(ext: SDTExtension) -> void:
	ext.enabled = false
	Hooks.remove_owner(ext.id)
	CharCode.remove_owner(ext.id)
	for name in _events:
		_events[name] = _events[name].filter(func(e): return e[0] != ext)
	_ticks = _ticks.filter(func(t): return t[0] != ext)
	_late_ticks = _late_ticks.filter(func(t): return t[0] != ext)
	ext._disable()


## Calls every listener of event `name` (see EVENTS) with `args`.
static func emit(name: String, args: Array = []) -> void:
	for e in _events.get(name, []).duplicate():
		var fn: Callable = e[1]
		if fn.is_valid():
			fn.callv(args)


static func _add_event(ext: SDTExtension, name: String, fn: Callable) -> void:
	if not EVENTS.has(name):
		push_error("extension %s: unknown event '%s'" % [ext.id, name])
		return
	if not _events.has(name):
		_events[name] = []
	_events[name].append([ext, fn])
	_events[name].sort_custom(func(a, b): return all.find(a[0]) < all.find(b[0]))


static func _add_tick(ext: SDTExtension, fn: Callable, late: bool) -> void:
	var list := _late_ticks if late else _ticks
	list.append([ext, fn])
	# keep extension load order, whatever order the callbacks were registered in
	list.sort_custom(func(a, b): return all.find(a[0]) < all.find(b[0]))


static func _install_tick() -> void:
	if _installed:
		return
	_installed = true
	Flash.tick_before.append(func(): _run_ticks(_ticks, "tick"))
	Flash.tick_after.append(func(): _run_ticks(_late_ticks, "late_tick"))


static func _run_ticks(list: Array, phase: String) -> void:
	if list.is_empty():
		return
	for t in list.duplicate():
		var fn: Callable = t[1]
		if not fn.is_valid():
			continue
		var ts := Time.get_ticks_usec()
		fn.call()
		Flash.account_listener("ext:%s.%s" % [t[0].id, phase], Time.get_ticks_usec() - ts)


static func _load_config() -> void:
	_config = ConfigFile.new()
	var path := FlashSharedObject.save_dir.path_join(CONFIG_FILE)
	if FileAccess.file_exists(path) and _config.load(path) != OK:
		push_warning("extensions: cannot read %s, using defaults" % path)
		_config = ConfigFile.new()


static func _save_config() -> void:
	var err := _config.save(FlashSharedObject.save_dir.path_join(CONFIG_FILE))
	if err != OK:
		push_warning("extensions: cannot save %s (error %d)" % [CONFIG_FILE, err])


static func _save_setting(ext: SDTExtension, key: String, value) -> void:
	if _config == null:
		_load_config()
	_config.set_value(ext.id, key, value)
	_save_config()
