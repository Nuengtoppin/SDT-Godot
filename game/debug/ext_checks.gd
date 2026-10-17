extends RefCounted
## Checks of the extension system (src/ext): hooks, extension lifecycle, tick order, settings, Vanilla mode.
## Run by tools/regress.sh (main.gd --driver); prints "EXT CHECKS: n passed, m failed" and quits.

var _pass := 0
var _fail := 0
var _phase := 0
var _start_tick := 0
var _order: Array = []
var _ext: TestExt = null
var _listener_obj: FlashSprite = null


## A class with one hooked method, written like a hook point in game code.
class Probe:
	extends RefCounted
	var calls := 0

	func calc(x: int) -> int:
		if Hooks.has(&"Probe.calc"):   # HOOK
			var h := Hooks.before(&"Probe.calc", self, [x])
			if h.cancelled:
				return h.result
			x = h.args[0]
		calls += 1
		var r := x * 2
		if Hooks.has(&"Probe.calc"):   # HOOK
			r = Hooks.after(&"Probe.calc", self, [x], r).result
		return r


class TestExt:
	extends SDTExtension
	var ticks := 0
	var late_ticks := 0
	var enabled_calls := 0
	var disabled_calls := 0
	var changed: Array = []
	var order: Array = []
	var slow := false
	var value = "abc"
	var late_value := ""
	var loads: Array = []   # [value, kind] per setter / reset call
	var mods_events := 0

	func _init() -> void:
		id = "test"
		title = "Test"

	func _setup() -> void:
		setting("flag", false, {"label": "Flag"})
		setting("amount", 0.5, {"min": 0.0, "max": 1.0})
		setting("count", 3, {"min": 1, "max": 10})
		setting("mode", "a", {"options": ["a", "b"]})

	func _enable() -> void:
		enabled_calls += 1
		on_late_tick(_late)
		on_tick(_early)
		hook_before(&"Probe.calc", func(c): c.args[0] += 100)
		charcode_field("testField", func(): return value,
			func(v, l): value = v; loads.append([v, l.kind]),
			func(l): value = "default"; loads.append(["reset", l.kind]))
		charcode_field("testLate", func(): return late_value if late_value != "" else null,
			func(v, _l): late_value = v, Callable(), true)
		on_event("mods_loaded", func(): mods_events += 1)

	func _disable() -> void:
		disabled_calls += 1

	func _setting_changed(key: String, value) -> void:
		changed.append([key, value])

	func _early() -> void:
		ticks += 1
		order.append("early")
		if slow:
			OS.delay_usec(3000)

	func _late() -> void:
		late_ticks += 1
		order.append("late")


func _check(name: String, ok: bool, detail := "") -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
	print("CHECK %s %s%s" % ["ok  " if ok else "FAIL", name, "" if ok or detail == "" else " (%s)" % detail])


func step(_frame: int) -> void:
	if not Extensions.started:
		return
	match _phase:
		0:
			_hook_checks()
			_lifecycle_start()
			_phase = 1
		1:
			if Flash.tick_count >= _start_tick + 5:
				_tick_checks()
				_phase = 2
		2:
			_ext.slow = true
			_start_tick = Flash.tick_count
			_phase = 3
		3:
			if Flash.tick_count > _start_tick:
				_check("profiler names the extension", Flash._slowest_listener.begins_with("ext:test."), Flash._slowest_listener)
				_ext.slow = false
				_settings_checks()
				_charcode_checks()
				_disable_checks()
				_plugin_checks()
				print("EXT CHECKS: %d passed, %d failed" % [_pass, _fail])
				Flash.get_tree().quit(1 if _fail > 0 else 0)
				_phase = 4


func _hook_checks() -> void:
	var p := Probe.new()
	_check("no handler: original runs", p.calc(3) == 6 and not Hooks.has(&"Probe.calc"))
	var f1 := func(c): c.args[0] = c.args[0] + 1
	Hooks.add_before(&"Probe.calc", f1, "t")
	_check("before changes args", p.calc(3) == 8)
	Hooks.add_after(&"Probe.calc", func(c): c.result = c.result + 1000, "t")
	_check("after replaces result", p.calc(3) == 1008)
	var seen: Array = []
	Hooks.add_before(&"Probe.calc", func(_c): seen.append("late"), "t", 5)
	Hooks.add_before(&"Probe.calc", func(_c): seen.append("early"), "t", -5)
	p.calc(1)
	_check("priority order", seen == ["early", "late"], str(seen))
	var calls_before := p.calls
	Hooks.add_before(&"Probe.calc", func(c): c.cancel(-1), "t2", 1)
	_check("cancel skips original and returns result", p.calc(3) == -1 and p.calls == calls_before)
	Hooks.remove_owner("t2")
	var other := Probe.new()
	Hooks.add_before(&"Probe.calc", func(c): c.cancel(42), "t3", -10, other)
	_check("target filter", p.calc(0) != 42 and other.calc(0) == 42)
	Hooks.remove_owner("t3")
	var inner: Array = []
	Hooks.add_before(&"Probe.calc", func(c): inner.append(c.obj.calc(10)), "t4", 10)
	p.calc(0)
	_check("handler can call the original", inner == [20], str(inner))
	Hooks.remove_owner("t4")
	Hooks.remove_owner("t")
	_check("remove_owner clears the hook", not Hooks.has(&"Probe.calc") and p.calc(3) == 6)


func _lifecycle_start() -> void:
	_ext = TestExt.new()
	_check("add extension", Extensions.add(_ext))
	_check("default off", not _ext.enabled and _ext.enabled_calls == 0)
	_check("duplicate id rejected", not Extensions.add(TestExt.new()))
	Extensions.set_enabled("test", true)
	_check("enable", _ext.enabled and _ext.enabled_calls == 1)
	_check("hook registered by extension", Probe.new().calc(1) == 202)
	_listener_obj = FlashSprite.new()
	_listener_obj.addEventListener(FlashEvent.ENTER_FRAME, func(): _ext.order.append("game"))
	_ext.order.clear()
	_start_tick = Flash.tick_count


func _tick_checks() -> void:
	_check("tick runs every tick", _ext.ticks >= 4 and _ext.late_ticks >= 4, "%d/%d" % [_ext.ticks, _ext.late_ticks])
	var o: Array = _ext.order.slice(_ext.order.find("early"))
	_check("tick order: before game, game, after", o.slice(0, 3) == ["early", "game", "late"], str(o.slice(0, 6)))


func _settings_checks() -> void:
	_ext.set_setting("amount", 5.0)
	_check("setting clamped to max", is_equal_approx(_ext.get_setting("amount"), 1.0))
	_ext.set_setting("mode", "zzz")
	_check("setting options enforced", _ext.get_setting("mode") == "a")
	_ext.set_setting("flag", "true")
	_check("setting type coerced", _ext.get_setting("flag") == true)
	_check("setting change callback", [["amount", 1.0], ["flag", true]] == _ext.changed, str(_ext.changed))
	var cfg := ConfigFile.new()
	var path := FlashSharedObject.save_dir.path_join(Extensions.CONFIG_FILE)
	_check("settings saved next to the save files", cfg.load(path) == OK and cfg.get_value("test", "flag", false) == true
		and cfg.get_value("enabled", "test", false) == true, path)
	_check("data_dir under save dir", _ext.data_dir().begins_with(FlashSharedObject.save_dir) and DirAccess.dir_exists_absolute(_ext.data_dir()))
	# a fresh extension with the same id picks the saved values up again
	Extensions.remove("test")
	var again := TestExt.new()
	Extensions.add(again)
	_check("saved settings and on/off restored", again.enabled and again.get_setting("flag") == true
		and is_equal_approx(again.get_setting("amount"), 1.0))
	_ext = again


func _charcode_checks() -> void:
	var menu = g.inGameMenu
	var e := _ext
	var code: String = menu.getSaveDataString(false)
	var n := code.split(";").size()
	_check("vanilla code is a full code (%d pairs)" % n, n > CharCode.PARTIAL_PAIRS)
	_check("field written", ";testField:abc" in code and not "testLate" in code, code.right(80))
	var base := code.replace(";testField:abc", "")
	e.loads.clear()
	menu.loadData(base + ";testField:xyz", false)
	_check("field loaded from a full code", e.value == "xyz" and e.loads == [["xyz", CharCode.Kind.FULL]], str(e.loads))
	e.loads.clear()
	menu.loadData(base, false)
	_check("full code without the field resets it", e.value == "default" and e.loads == [["reset", CharCode.Kind.FULL]], str(e.loads))
	e.loads.clear()
	menu.loadData("mood:Happy;testField:p", false)
	_check("partial code sets the field", e.value == "p" and e.loads == [["p", CharCode.Kind.PARTIAL]], str(e.loads))
	e.loads.clear()
	menu.loadData("mood:Happy", false)
	_check("partial code without the field keeps it", e.value == "p" and e.loads.is_empty(), str(e.loads))
	e.loads.clear()
	CharCode.loading_mod_chardata = true
	menu.loadData(base, false)
	CharCode.loading_mod_chardata = false
	_check("a mod's charData does not reset", e.value == "p" and e.loads.is_empty(), str(e.loads))
	e.loads.clear()
	menu.onlyLoadCostume = true
	menu.loadData(base, false)
	menu.onlyLoadCostume = false
	_check("costume-only load does not reset", e.value == "p" and e.loads.is_empty(), str(e.loads))
	menu.loadData(base + ";loaderThing:1,2:3", false)
	var saved: String = menu.getSaveDataString(false)
	_check("unknown field kept (with ':' in the value)", ";loaderThing:1,2:3" in saved, saved.right(80))
	menu.loadData("mood:Happy;otherThing:x", false)
	saved = menu.getSaveDataString(false)
	_check("partial code adds unknown fields", ";loaderThing:1,2:3" in saved and ";otherThing:x" in saved)
	menu.loadData(base, false)
	_check("full code replaces unknown fields", not "loaderThing" in menu.getSaveDataString(false))
	e.value = "a;b"
	_check("value with ';' is not written", not "testField" in menu.getSaveDataString(false))
	e.value = "keepme"
	# after_mods: held back while mods load, applied when they finish
	var cel = g.customElementLoader
	var events := e.mods_events
	cel.readingMods = true
	menu.loadData(base + ";testLate:late1", false)
	var held := e.late_value == ""
	cel.readingMods = false
	CharCode.mods_loaded()
	_check("after_mods field waits for mods", held and e.late_value == "late1", e.late_value)
	_check("mods_loaded event", e.mods_events == events + 1)
	e.value = "keepme"   # the full code above reset it
	_check("vanilla key cannot be registered", not CharCode.add_field("mood", "x", func(): return "", func(_v, _l): pass))
	# disabling keeps the extension's values in the code
	Extensions.set_enabled("test", false)
	saved = menu.getSaveDataString(false)
	_check("disabled extension's field kept", ";testField:keepme" in saved and ";testLate:late1" in saved, saved.right(80))
	Extensions.set_enabled("test", true)
	menu.loadData(base + ";testField:back", false)
	_check("re-enabled extension reads its field", e.value == "back")


## The test plugins in tests/plugins (regress.sh copies them into the run's Mods/Plugins and leaves a loading
## marker for "crashy", as if it had crashed the previous start).
func _plugin_checks() -> void:
	var P := Extensions.plugins
	if not P.has("example"):
		_check("test plugins present (run through tools/regress.sh)", false)
		return
	var ex = Extensions.get_extension("example")
	_check("plugin loaded and on by default", P["example"]["error"] == "" and ex != null and ex.enabled and not ex.builtin)
	_check("plugin manifest read", ex.title == "Example plugin" and ex.author == "tests" and ex.folder.ends_with("example"))
	_check("plugin helper script", ex.helper != null and ex.helper.answer() == 42)
	_check("dependency loaded after its dependency", Extensions.all.find(Extensions.get_extension("needs_example")) > Extensions.all.find(ex))
	_check("broken plugin skipped", P["broken"]["error"] != "" and Extensions.get_extension("broken") == null)
	_check("class_name plugin refused", P["classname"]["error"] != "" and Extensions.get_extension("classname") == null
		and g.her.get_script() == Her)
	_check("missing dependency reported", "missing dependency" in P["missing_dep"]["error"] and Extensions.get_extension("missing_dep") == null)
	var crashy = Extensions.get_extension("crashy")
	_check("plugin that crashed last start is off", crashy != null and not crashy.enabled)
	var dt = Flash.stage.getChildAt(0)
	var e := FlashEvent.new(FlashEvent.KEY_DOWN)
	e.keyCode = 120
	dt.keyPressed(e)
	g.inTextField = true
	dt.keyPressed(e)
	g.inTextField = false
	_check("plugin hotkey (not while typing)", ex.key_presses == 1, str(ex.key_presses))
	_check("plugin menu button", ex.button != null and ex.button._flash_parent == g.inGameMenu.optionsMenu)
	g.her.passOut()
	_check("Her.passOut hook", ex.passouts == 1)
	var b: ExtButton = ex.button
	Extensions.set_enabled("example", false)
	g.her.passOut()
	dt.keyPressed(e)
	_check("disabled plugin: button, hook and key removed", b._flash_parent == null and ex.passouts == 1 and ex.key_presses == 1)


func _disable_checks() -> void:
	var d := _ext.disabled_calls
	Extensions.set_vanilla_mode(true)
	var t := _ext.ticks
	_check("vanilla mode disables", not _ext.enabled and _ext.disabled_calls == d + 1 and not Hooks.has(&"Probe.calc"))
	Extensions._run_ticks(Extensions._ticks, "tick")
	_check("no ticks while disabled", _ext.ticks == t)
	Extensions.set_vanilla_mode(false)
	_check("leaving vanilla mode re-enables", _ext.enabled and Hooks.has(&"Probe.calc"))
	Extensions.set_enabled("test", false)
	_check("disable", not _ext.enabled and not Hooks.has(&"Probe.calc"))
	Extensions.remove("test")
	_listener_obj.free()
