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
	var moods_seen: Array = []

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
		on_event("mood_changed", func(m): moods_seen.append(m))

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
			_value_checks()
			_lifecycle_start()
			_ext.modify(&"T.ext", {"op": "set", "value": 1.0})
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
				_check("value modifier lifetime ends after its ms", not Hooks.has_value(&"T.t")
					and Hooks.value(&"T.t", null, 7.0) == 7.0)
				_ext.slow = false
				_veto_checks()
				_settings_checks()
				_poll_veto_checks()
				_charcode_checks()
				_mood_checks()
				_blink_veto_checks()
				_template_checks()
				_extramod_checks()
				_shock_spray_veto_checks()
				_extramodhim_checks()
				_leglayer_checks()
				_aimpenis_checks()
				_regulaterandom_checks()
				_swallow_veto_checks()
				_disable_checks()
				_plugin_checks()
				print("EXT CHECKS: %d passed, %d failed" % [_pass, _fail])
				Flash.get_tree().quit(1 if _fail > 0 else 0)
				_phase = 4


## Her.swallow: a vetoed swallow restarts the wait with cum in her mouth (it would be retried every tick) and
## changes nothing else; a handler can change the arguments.
func _swallow_veto_checks() -> void:
	var her = g.her
	var calls := [0]
	var veto := func(c): calls[0] += 1; c.cancel()
	Hooks.add_before(&"Her.swallow", veto, "test")
	her.swallowing = false
	her.startSwallowTimer = 999
	var cough: float = her.coughBuild
	var wet: float = her.wetGenerate
	her.swallow()
	_check("vetoed swallow: no swallow", calls[0] == 1 and not her.swallowing)
	_check("vetoed swallow: the wait starts over", her.startSwallowTimer == 0)
	_check("vetoed swallow: cough and wetness untouched", her.coughBuild == cough and her.wetGenerate == wet)
	Hooks.remove(&"Her.swallow", veto)
	var change := func(c): c.args[0] = 0.9
	Hooks.add_before(&"Her.swallow", change, "test")
	var free: bool = not her.passedOut and not her.speaking
	her.swallow()
	_check("swallow: a handler can change the intensity", not free or (her.swallowing
		and is_equal_approx(float(her.swallowSequence["intensity"]), 0.9)), str(her.swallowSequence.get("intensity")))
	Hooks.remove(&"Her.swallow", change)


## TemplateExtension: the alternate loader template's mod types, its over-top layer and extra hair layer.
func _template_checks() -> void:
	var te: SDTExtension = Extensions.get_extension("templateextension")
	_check("TemplateExtension on by default", te != null and te.enabled)
	if te == null or not te.enabled:
		return
	var helpers: Dictionary = g.customElementLoader.modTargetHelpers
	var missing: Array = []
	for t in te.TYPES:
		if not helpers.has(t) or helpers[t].targetDictionary.size() != te.TYPES[t].size():
			missing.append(t)
	_check("mod types registered with all their parts", missing.is_empty(), str(missing))
	_check("over-top layer: 8 parts above the top's", te._layers.size() == 8 and helpers.has("CostumeOverTop")
		and helpers.has("costumeovertop") and te._layers.values().all(func(l): return l._flash_parent != null))
	_check("over-top breast moves with her breast", g.her.rightBreastController._costumeLayers.has(te._layers["rightBreast"]))
	var hl: FlashSprite = te.hair_over_extended
	_check("extra hair layer under his arm", hl != null and hl._flash_parent == g.frontLayer
		and g.frontLayer.getChildIndex(hl) < g.frontLayer.getChildIndex(g.himOverLayer))
	g.characterControl.applyHairHSL({"h": 30, "s": 0, "l": 0, "c": 0})
	_check("extra hair layer takes the hair colour", hl.filters.size() == g.hairBetweenLayer.filters.size()
		and hl.filters.size() > 0)
	g.characterControl.removeHairHSL()
	Extensions.set_enabled("templateextension", false)
	var layers_left: bool = g.her.rightBreastController._costumeLayers.any(func(l): return l.flash_name.ends_with("OverTop"))
	_check("TemplateExtension off: types and layers gone", not helpers.has("CostumeArmwear") and not helpers.has("CostumeBra")
		and hl._flash_parent == null and not layers_left)
	Extensions.set_enabled("templateextension", true)
	_check("TemplateExtension on again", helpers.has("CostumeArmwear") and te._layers.size() == 8)


## ExtraMod (stage 1: her head and eyes): types, containers next to her parts, a clear that changes nothing.
func _extramod_checks() -> void:
	var em: SDTExtension = Extensions.get_extension("extramod")
	_check("ExtraMod on by default", em != null and em.enabled)
	if em == null or not em.enabled:
		return
	var helpers: Dictionary = g.customElementLoader.modTargetHelpers
	_check("ExtraMod head and eye types", helpers.has("BodyHead") and helpers.has("BodyEye")
		and helpers["BodyHead"].targetDictionary.size() == em.HEAD_PARTS.size()
		and helpers["BodyEye"].targetDictionary.size() == em.EYE_PARTS.size(),
		"%d %d" % [helpers["BodyHead"].targetDictionary.size(), helpers["BodyEye"].targetDictionary.size()])
	var her = g.her
	_check("ExtraMod containers beside her parts", em.c.size() == em.CONTAINERS.size()
		and em.c["uppereyelid"]._flash_parent == her.eye.upperEyelid._flash_parent
		and em.c["uppereyelidmask"].blendMode == "erase")
	var skull_vis: bool = her.head.face.skull.getChildAt(0).visible
	g.customElementLoader.clearInstancedMods()
	_check("ExtraMod: clearing without its mods changes nothing", her.head.face.skull.getChildAt(0).visible == skull_vis
		and her.eye.ball.upperEyelidMask.visible)
	var cat = g.modCatalog
	_check("ExtraMod's list of mods in the catalog", cat.picker_entries.has("extramod")
		and cat.picker_types.get("BodyHead") == "extramod")
	Extensions.set_enabled("extramod", false)
	_check("ExtraMod off: types, containers and list gone", not helpers.has("BodyHead") and em.c.is_empty()
		and not cat.picker_entries.has("extramod"))
	Extensions.set_enabled("extramod", true)
	_check("ExtraMod on again", helpers.has("BodyEye") and em.c.size() == em.CONTAINERS.size()
		and cat.picker_entries.has("extramod"))


## ExtraModHim (his body and penis so far): types registered, follow his body change, off removes them.
func _extramodhim_checks() -> void:
	var emh: SDTExtension = Extensions.get_extension("extramodhim")
	_check("ExtraModHim on by default", emh != null and emh.enabled)
	if emh == null or not emh.enabled:
		return
	var helpers: Dictionary = g.customElementLoader.modTargetHelpers
	# his breast containers exist on his futa body only
	var expected: int = emh.BODY_PARTS.size() - (emh.BREASTS.size() if g.him.currentBodyID == 0 else 0)
	_check("ExtraModHim body and penis types", helpers.has("HimBody") and helpers.has("HimPenis")
		and helpers["HimBody"].targetDictionary.size() == expected, str(helpers["HimBody"].targetDictionary.size()))
	var body: int = g.him.currentBodyID
	g.him.setBody(1 - body)
	_check("ExtraModHim targets follow his body change", helpers["HimBody"].targetDictionary["hisTorso"] == g.him.torsoLayer.torso)
	g.him.setBody(body)
	Extensions.set_enabled("extramodhim", false)
	_check("ExtraModHim off: types gone", not helpers.has("HimBody"))
	Extensions.set_enabled("extramodhim", true)
	_check("ExtraModHim on again", helpers.has("HimBody"))


## regulaterandom: its defaults are the game's shuffle; with every part off a shuffle changes nothing (also not
## moremoods' mood).
func _regulaterandom_checks() -> void:
	var rr: SDTExtension = Extensions.get_extension("regulaterandom")
	var seen := []
	var spy := func(c): seen.append([c.args[0].duplicate(), c.args[1].duplicate()])
	Hooks.add_after(&"InGameMenu.shuffle", spy, "test")
	g.inGameMenu.shuffle()
	var defaults_ok: bool = seen.size() == 1 and seen[0][0] == InGameMenu.SHUFFLE_PARTS and seen[0][1].keys().all(
		func(k): return seen[0][1][k] == InGameMenu.SHUFFLE_ALPHA.get(k, false))
	for p in rr.PARTS:
		rr.set_setting(p[0], false)
	var mood: String = g.her.currentMood
	var before: String = g.inGameMenu.getSaveDataString()
	g.inGameMenu.shuffle()
	var after: String = g.inGameMenu.getSaveDataString()
	var mood_after: String = g.her.currentMood
	for p in rr.PARTS:
		rr.set_setting(p[0], InGameMenu.SHUFFLE_PARTS.get(p[0], false))
	Hooks.remove(&"InGameMenu.shuffle", spy)
	_check("regulaterandom defaults: the game's shuffle", defaults_ok, str(seen[0]) if not seen.is_empty() else "")
	_check("regulaterandom all off: shuffle changes nothing", before == after and mood == mood_after,
		"" if before == after else "%s\n%s" % [before, after])


## aimpenis: the aim goes into his tilt target and the wider limits into his angle, only while it is on and he is out
## of her mouth.
func _aimpenis_checks() -> void:
	var ap: SDTExtension = Extensions.get_extension("aimpenis")
	var him = g.him
	var was := [him.inMouth, him.penisTilt, g.currentPos.y, g.bukkakeMode]
	him.inMouth = false
	him.penisTilt = 60.0
	g.currentPos.y = -1.0
	g.bukkakeMode = false
	var off := [Hooks.value(&"Him.penisTiltTarget", him, 10.0), Hooks.value(&"Him.penisAngle", him, 25.0)]
	ap.set_setting("on", true)
	var up := [Hooks.value(&"Him.penisTiltTarget", him, 10.0), Hooks.value(&"Him.penisAngle", him, 25.0)]
	him.inMouth = true
	var mouth := [Hooks.value(&"Him.penisTiltTarget", him, 10.0), Hooks.value(&"Him.penisAngle", him, 25.0)]
	Extensions.key_pressed(77)
	var key_off: bool = not ap.get_setting("on")
	Extensions.key_pressed(77)
	var key_on: bool = ap.get_setting("on")
	ap.set_setting("on", false)
	him.inMouth = was[0]
	him.penisTilt = was[1]
	g.currentPos.y = was[2]
	g.bukkakeMode = was[3]
	_check("aimpenis off: the game's tilt", off == [10.0, 25.0], str(off))
	_check("aimpenis on, mouse up: aims up, up to 35", up[0] > 40.0 and up[1] == 35.0, str(up))
	_check("aimpenis in her mouth: the game's tilt", mouth == [10.0, 25.0], str(mouth))
	_check("aimpenis: M switches it off and on", key_off and key_on)


## Port fixes from sby's Loader patches (in the game code).
func _leglayer_checks() -> void:
	var leg = g.her.leftLegContainer.leg
	var on: Array = range(leg.numChildren).map(func(i): return str(leg.getChildAt(i).flash_name))
	_check("leglayermove: calf pieces under the thigh", on.find("cuffs") < on.find("thigh") and on.find("leftCalfBottoms") < on.find("thigh")
		and on.find("thigh") < on.find("leftThighCostume"), str(on))
	var fl: FlashSprite = g.frontLayer
	_check("hairlayerpatch: her forearm under the hair", fl.getChildIndex(g.her.rightForeArmContainer) < fl.getChildIndex(g.hairOverContainer))
	g.gamePaused = true
	var breathing: bool = g.her.breathing
	g.gamePaused = false
	_check("pausedbreathpatch: no breathing while paused", not breathing)


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
	var hc := Hooks.before(&"Probe.calc", p, [3])
	_check("cancelled_by names the cancelling owner", hc.cancelled and hc.cancelled_by == "t2", hc.cancelled_by)
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


## Value points: phases, folding rules, hold, generator, ordering independent of load order, lifetimes (checked
## a few ticks later), removal with the owner.
func _value_checks() -> void:
	var o := Probe.new()
	_check("value point without modifiers is unchanged", Hooks.value(&"T.v", o, 5.0) == 5.0 and not Hooks.has_value(&"T.v"))
	Hooks.add_modifier(&"T.v", {"phase": Hooks.MOOD, "op": "set", "value": 10.0}, "va")
	Hooks.add_modifier(&"T.v", {"phase": Hooks.MOOD, "op": "bias", "value": 1.0}, "vb")
	_check("set then bias within a phase", Hooks.value(&"T.v", o, 5.0) == 11.0)
	Hooks.add_modifier(&"T.v", {"phase": Hooks.OVERRIDE, "op": "set", "value": 20.0}, "vc")
	_check("a later phase wins", Hooks.value(&"T.v", o, 5.0) == 20.0)
	Hooks.add_modifier(&"T.v", {"phase": Hooks.CLAMP, "op": "clamp", "min": 0.0, "max": 15.0}, "vd")
	Hooks.add_modifier(&"T.v", {"phase": Hooks.CLAMP, "op": "clamp", "min": 3.0, "max": 12.0}, "ve")
	_check("clamps intersect", Hooks.value(&"T.v", o, 5.0) == 12.0)
	var chain := Hooks.explain(&"T.v")
	Hooks.value(&"T.v", o, 5.0)
	_check("explain records the chain", Hooks.explain(&"T.v").size() > 0 and chain is Array)
	Hooks.add_modifier(&"T.g", {"phase": Hooks.GENERATE, "op": "fn", "fn": func(v, _o): return v * 3.0}, "vf")
	Hooks.add_modifier(&"T.g", {"phase": Hooks.MOOD, "op": "bias", "value": 1.0}, "vf")
	_check("generator, then later phases", Hooks.value(&"T.g", o, 2.0) == 7.0)
	var on := [true]
	Hooks.add_modifier(&"T.h", {"phase": Hooks.FINAL, "op": "hold", "when": func(_o): return on[0]}, "vg")
	var h1 = Hooks.value(&"T.h", o, 1.0)
	var h2 = Hooks.value(&"T.h", o, 2.0)
	on[0] = false
	var h3 = Hooks.value(&"T.h", o, 3.0)
	on[0] = true
	var h4 = Hooks.value(&"T.h", o, 4.0)
	_check("hold keeps the captured value while it applies", [h1, h2, h3, h4] == [1.0, 1.0, 3.0, 4.0], str([h1, h2, h3, h4]))
	Hooks.add_modifier(&"T.o1", {"op": "set", "value": 1.0}, "y")
	Hooks.add_modifier(&"T.o1", {"op": "set", "value": 2.0}, "x")
	Hooks.add_modifier(&"T.o2", {"op": "set", "value": 2.0}, "x")
	Hooks.add_modifier(&"T.o2", {"op": "set", "value": 1.0}, "y")
	_check("order does not depend on load order", Hooks.value(&"T.o1", o, 0.0) == Hooks.value(&"T.o2", o, 0.0))
	_check("two owners setting one phase warn once", Hooks._warned.has("T.o1|x|y"))
	Hooks.add_modifier(&"T.vec", {"op": "bias", "value": Vector2(1, 2)}, "vh")
	_check("vector values", Hooks.value(&"T.vec", o, Vector2(10, 10)) == Vector2(11, 12))
	var id := Hooks.add_modifier(&"T.r", {"op": "set", "value": 9.0}, "vi")
	var had := Hooks.has_modifier(id)
	Hooks.remove_modifier(id)
	_check("remove_modifier", had and not Hooks.has_modifier(id) and not Hooks.has_value(&"T.r"))
	Hooks.add_modifier(&"T.u1", {"op": "set", "value": 1.0}, "vu")
	Hooks.add_modifier(&"T.u2", {"op": "set", "value": 2.0}, "vu")
	Hooks.add_modifier(&"T.u2", {"op": "bias", "value": 1.0}, "vv")
	Hooks.remove_modifiers("vu", &"T.u2")
	var one_point: bool = Hooks.has_value(&"T.u1") and Hooks.value(&"T.u2", o, 5.0) == 6.0
	Hooks.remove_modifiers("vu")
	_check("remove_modifiers: one point, then all of an owner's", one_point and not Hooks.has_value(&"T.u1")
		and Hooks.has_value(&"T.u2"))
	Hooks.remove_owner("vv")
	for owner in ["va", "vb", "vc", "vd", "ve", "vf", "vg", "vh", "x", "y"]:
		Hooks.remove_owner(owner)
	var left := Hooks.value_points().filter(func(n): return str(n).begins_with("T."))
	_check("remove_owner removes modifiers", left.is_empty(), str(left))
	Hooks.add_modifier(&"T.t", {"op": "set", "value": 1.0, "ms": 100.0}, "vt")
	_check("timed modifier applies", Hooks.value(&"T.t", o, 7.0) == 1.0)


## Her.shock (startled: eyes wide, maybe a blink) and Her.lastSpurt (cum from her nose when her mouth overflows at
## his last spurt): a veto changes nothing; a handler can change the shock's strength.
func _shock_spray_veto_checks() -> void:
	var her = g.her
	var veto := func(c): c.cancel()
	Hooks.add_before(&"Her.shock", veto, "shock")
	her.eyelidMotion["shock"] = 0
	her.blinkTimer = 0
	her.shock(50)
	_check("vetoed shock: eyes and eyelids untouched", her.eyelidMotion["shock"] == 0 and her.blinkTimer == 0)
	Hooks.remove(&"Her.shock", veto)
	var weaker := func(c): c.args[0] = 20
	Hooks.add_before(&"Her.shock", weaker, "shock")
	her.shock(50)
	_check("shock: a handler can change the strength", her.eyelidMotion["shock"] == 20)
	Hooks.remove(&"Her.shock", weaker)
	her.eyelidMotion["shock"] = 0
	var was: bool = g.nostrilSpray
	g.nostrilSpray = true
	her.cumInMouth = her.fullCumInMouth + her.minNostrilSpray + 1
	her.nostrilSpraying = false
	Hooks.add_before(&"Her.lastSpurt", veto, "shock")
	her.lastSpurt()
	_check("vetoed last spurt: no cum from her nose, no shock", not her.nostrilSpraying and her.eyelidMotion["shock"] == 0)
	Hooks.remove(&"Her.lastSpurt", veto)
	her.cumInMouth = 0
	g.nostrilSpray = was


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


## Her.passOut, Her.wakeUp, Her.cough: their callers ask every tick, so a veto restarts the action's own wait, unless
## the handler replaced the action (did it itself, or set its own wait).
func _poll_veto_checks() -> void:
	var her = g.her
	var veto := func(c): c.cancel()
	Hooks.add_before(&"Her.passOut", veto, "poll")
	her.passedOut = false
	her.passOutFactor = her.passOutMax
	her.passOut()
	_check("vetoed pass-out: still awake, next try in 150 ticks", not her.passedOut
		and is_equal_approx(her.passOutFactor, her.passOutMax - 7.5), str(her.passOutFactor))
	her.passOutFactor = 0.0
	her.passOut()
	_check("vetoed pass-out called early: nothing changes", her.passOutFactor == 0.0)
	Hooks.remove(&"Her.passOut", veto)
	var replace := func(c): c.cancel(); her.passedOut = true
	Hooks.add_before(&"Her.passOut", replace, "poll")
	her.passOutFactor = her.passOutMax
	her.passOut()
	_check("pass-out replaced by a handler: left as the handler made it", her.passedOut and her.passOutFactor == her.passOutMax)
	Hooks.remove(&"Her.passOut", replace)
	Hooks.add_before(&"Her.wakeUp", veto, "poll")
	her.passOutFactor = 0.0
	her.wakeUp()
	_check("vetoed wake-up: still out, next try in 80 ticks", her.passedOut and her.passOutFactor == her.passOutMax)
	Hooks.remove(&"Her.wakeUp", veto)
	her.passedOut = false
	her.passOutFactor = 0.0
	Hooks.add_before(&"Her.cough", veto, "poll")
	her.nextCoughTime = 0
	her.cough()
	_check("vetoed cough: next try after a normal wait", her.nextCoughTime >= 30 and her.nextCoughTime < 240, str(her.nextCoughTime))
	Hooks.remove(&"Her.cough", veto)
	var own := func(c): c.cancel(); her.nextCoughTime = 500
	Hooks.add_before(&"Her.cough", own, "poll")
	her.nextCoughTime = 0
	her.cough()
	_check("cough replaced with its own wait: kept", her.nextCoughTime == 500)
	Hooks.remove(&"Her.cough", own)
	her.nextCoughTime = 0


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
## Before-hooks on one-off actions: a vetoed action changes nothing, apart from restarting its own timer where the
## caller would otherwise ask again on every tick.
func _veto_checks() -> void:
	_veto_clench_teeth()
	_veto_waggle_eyebrows()
	_veto_open_eye()
	_veto_tear_spot()
	_veto_release_tears()
	_veto_random_strand()
	_veto_spit_drool()
	_veto_cum_drool()
	_veto_ejaculate()
	_veto_sweat()
	Hooks.remove_owner("veto")   # (end of the veto checks)


## Runs `fn` with a counting veto on hook `name`; returns how many times the veto was asked.
func _vetoed(name: StringName, fn: Callable) -> int:
	var n := [0]
	var veto := func(c): n[0] += 1; c.cancel()
	Hooks.add_before(name, veto, "veto")
	fn.call()
	Hooks.remove(name, veto)
	return n[0]


func _veto_clench_teeth() -> void:
	var her = g.her
	her.clenchTeeth = false
	var time: int = her.clenchedTeethTime
	var free: bool = not her.gagged and not her.mouthFull
	var n := _vetoed(&"Her.startClenchingTeeth", her.startClenchingTeeth)
	_check("vetoed clenching: teeth not clenched", n == 1 and not her.clenchTeeth and her.clenchedTeethTime == time and free)


func _veto_waggle_eyebrows() -> void:
	var her = g.her
	var queued: int = her.eyebrowOffsets.size()
	var n := _vetoed(&"Her.waggleEyebrows", her.waggleEyebrows)
	_check("vetoed eyebrow waggle: nothing queued", n == 1 and her.eyebrowOffsets.size() == queued)


func _veto_open_eye() -> void:
	var her = g.her
	her.closeEye()
	her.eyelidMotion["closedTimer"] = 1200
	var n := _vetoed(&"Her.openEye", her.openEye)
	_check("vetoed eye opening: the eye stays closed", n == 1 and her.eyelidMotion["isClosed"])
	_check("vetoed eye opening: the 40 s check starts over", her.eyelidMotion["closedTimer"] == 0)
	her.openEye()
	_check("eye opens without the veto", not her.eyelidMotion["isClosed"])


func _veto_tear_spot() -> void:
	var tears = g.her.tears
	var was: bool = g.tears
	g.tears = true
	tears.clearTearSpots()
	var n := _vetoed(&"Tears.addTearSpot", tears.addTearSpot)
	_check("vetoed tear spot: none added", n == 1 and tears.tearSpotList.is_empty())
	tears.clearTearSpots()
	g.tears = was


func _veto_release_tears() -> void:
	var tears = g.her.tears
	var was: bool = g.tears
	g.tears = true
	tears.clearTearSpots()
	for i in 4:
		tears.addTearSpot()
	var spots: int = tears.tearSpotList.size()
	var falling: int = tears.tearList.size()
	var n := _vetoed(&"Tears.releaseTears", tears.releaseTears)
	_check("vetoed tear release: the spots stay", n == 1 and spots > 0 and tears.tearSpotList.size() == spots
		and tears.tearList.size() == falling)
	tears.clearTearSpots()
	g.tears = was


func _veto_random_strand() -> void:
	var was: bool = g.spit
	g.spit = true
	var count := func(): return g.strandFrontLayer.numChildren + g.strandBackLayer.numChildren
	var before: int = count.call()
	var n := _vetoed(&"Her.generateRandomStrand", g.her.generateRandomStrand.bind("front", true))
	_check("vetoed spit strand: none made", n == 1 and count.call() == before)
	g.spit = was


func _veto_spit_drool() -> void:
	var her = g.her
	var was: bool = g.spit
	g.spit = true
	her.droolingSpit = false
	var timer: int = her.spitDroolTimer
	var n := _vetoed(&"Her.randomSpitDrool", her.randomSpitDrool)
	_check("vetoed spit drool: no drool", n == 1 and not her.droolingSpit and her.spitDroolTimer == timer)
	g.spit = was


func _veto_cum_drool() -> void:
	var her = g.her
	her.cumInMouth = 0
	var asked := _vetoed(&"Her.startDroolingCum", her.startDroolingCum.bind(false))
	_check("cum drool: not asked when it would not start", asked == 0)
	var n := _vetoed(&"Her.startDroolingCum", her.startDroolingCum.bind(true))
	_check("vetoed forced cum drool: no cum added, no drool", n == 1 and her.cumInMouth == 0 and not her.droolingCum)


func _veto_ejaculate() -> void:
	var him = g.him
	var finishes: int = g.totalFinishes
	var n := _vetoed(&"Him.ejaculate", him.ejaculate)
	_check("vetoed ejaculation: none", n == 1 and not him.ejaculating and g.totalFinishes == finishes)
	# the automatic one: at full pleasure for 60 ticks; a veto keeps his pleasure and restarts the wait
	him.pleasure = him.ejacPleasure + 10.0
	him.maxPleasureTimer = 60
	n = _vetoed(&"Him.ejaculate", func(): him.move(0.0, 0.0, 0.0))
	_check("vetoed automatic ejaculation: pleasure kept, wait restarted", n == 1 and not him.ejaculating
		and him.pleasure >= him.ejacPleasure and him.maxPleasureTimer == 0, "%s %s" % [him.pleasure, him.maxPleasureTimer])
	him.pleasure = 0.0
	him.maxPleasureTimer = 0


func _veto_sweat() -> void:
	var before: int = Sweat.droplet_count()
	var seen := [0]
	var see := func(c): seen[0] = c.args.size()
	Hooks.add_before(&"Sweat.spawn", see, "veto", -1)
	var n := _vetoed(&"Sweat.spawn", func(): Sweat.spawn(g.her.head, Vector2(21, -65), Vector2(150, 100), []))
	Hooks.remove(&"Sweat.spawn", see)
	_check("vetoed sweat: no droplet", n == 1 and Sweat.droplet_count() == before and seen[0] == 4)


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


func _mood_checks() -> void:
	var e := _ext
	var her = g.her
	e.moods_seen.clear()
	her.setMood("Happy")
	_check("vanilla mood", Moods.current() == "Happy" and not Moods.is_extended() and e.moods_seen == ["Happy"], str(e.moods_seen))
	# an extended mood the way moremoods does it: take over setMood, set a vanilla mood underneath
	Moods.register("Upset", "test")
	var take_over := func(c):
		if c.args[0] == "Upset":
			c.cancel()
			her.setMood("Normal")       # runs the original (the hook is inactive while its handlers run)
			Moods.set_extended("Upset")
	Hooks.add_before(&"Her.setMood", take_over, "test")
	e.moods_seen.clear()
	her.setMood("Upset")
	_check("extended mood", Moods.current() == "Upset" and her.currentMood == "Normal" and e.moods_seen == ["Upset"], str(e.moods_seen))
	_check("extension sees the extended mood", e.mood() == "Upset" and "Upset" in Moods.all())
	e.moods_seen.clear()
	her.setMood("Angry")
	_check("vanilla mood clears the extended one", Moods.current() == "Angry" and e.moods_seen == ["Angry"], str(e.moods_seen))
	her.setMood("Upset")
	Hooks.remove(&"Her.setMood", take_over)
	Moods.unregister_owner("test")
	_check("unregistered extended mood is cleared", Moods.current() == "Normal")
	her.setMood("Normal")


## Her.blink: a vetoed blink waits a normal interval before the next try (updateBlink would retry every tick) and
## leaves the eyelids alone.
func _blink_veto_checks() -> void:
	var her = g.her
	var calls := [0]
	var veto := func(c): calls[0] += 1; c.cancel()
	Hooks.add_before(&"Her.blink", veto, "test")
	her.blinkTime = 0
	her.blinkTimer = 0
	for i in 30:
		her.updateBlink()
	_check("vetoed blink: tried once, not every tick", calls[0] == 1, str(calls[0]))
	# 90..149 ticks from the veto, minus the 29 calls after it
	_check("vetoed blink: next try after a normal wait", her.blinkTime >= 60 and her.blinkTime <= 120, str(her.blinkTime))
	_check("vetoed blink: eyelids not closed", her.blinkTimer == 0)
	Hooks.remove(&"Her.blink", veto)
	her.blinkTime = 0
	her.updateBlink()
	_check("blink runs again without the veto", her.blinkTimer == 2)


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
	_check("disable removes the extension's value modifiers", not Hooks.has_value(&"T.ext"))
	Extensions.remove("test")
	_listener_obj.free()
