extends RefCounted
## Checks for the Channels plugin (Mods/Plugins/channels, P026): owner rules, automatic release, the gaze holder
## winning over moremoods, and the blink / look-change switches. Needs the plugin in the mods folder:
## run_debug.bat -- --save-dir=<temporary folder> --mods-dir=<folder with Plugins/channels> --driver=res://debug/channels_checks.gd

var _phase := 0
var _t0 := 0
var _passed := 0
var _failed := 0
var _ch: SDTExtension
var _blinks := 0
var _events: Array = []
var _lost: Array = []


func _check(label: String, ok: bool) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
	print("CHANNELS CHECK %s %s" % ["ok" if ok else "FAIL", label])


func _wait(ticks: int) -> bool:
	return Flash.tick_count - _t0 >= ticks


func _next() -> void:
	_t0 = Flash.tick_count
	_phase += 1


func _expected_eye_target(her, target: Vector2) -> float:
	var local: Vector2 = her.globalToLocal(g.sceneLayer.localToGlobal(target))
	var d := Vector2(local.x - her.eyeAim.x, local.y - her.eyeAim.y)
	return minf(110.0, maxf(75.0, g.getAngle(d.x, d.y)))


func step(_frame: int) -> void:
	if not Extensions.started:
		return
	var her = g.her
	match _phase:
		0:
			(Flash.stage.getChildAt(0) as DT).playClicked()
			_next()
		1:
			if not _wait(30):
				return
			_ch = Extensions.get_extension("channels")
			_check("plugin loaded and on", _ch != null and _ch.enabled)
			if _ch == null or not _ch.enabled:
				_finish()
				return
			_check("defaults: automation on, nobody holds anything",
				_ch.get_setting("auto_blink") and _ch.get_setting("auto_look") and _ch.owner_of(&"gaze") == ""
				and _ch.owner_of(&"blink") == "")
			Hooks.add_after(&"Her.blink", func(_c): _blinks += 1, "channels_checks")
			_ch.add_listener(func(c, o, n, r): _events.append([c, o, n, r]))
			_test_levels()
			Extensions.set_enabled("moremoods", true)
			her.setMood("Smug")
			_next()
		2:
			if not _wait(30):
				return
			# control: in moremoods' Smug mood she keeps looking at his face
			_check("control: moremoods Smug points her gaze at his face", her.currentLookTarget == her.hisFace)
			_check("gaze claim at MOD level", _ch.look_at("checks", "down", _ch.MOD))
			_next()
		3:
			if not _wait(60):
				return
			_check("gaze holder wins over moremoods' mood look", her.currentLookTarget == her.eyesDown)
			var want := _expected_eye_target(her, her.eyesDown)
			_check("iris aimed with the game's own lookAt maths (%.2f vs %.2f)" % [her.eyeMotion["target"], want],
				absf(her.eyeMotion["target"] - want) < 0.01 + her.passOutFactor)
			her.lookChangeTimer = -1
			her.changeLookTarget(her.hisFace, 0, 1)
			_check("look changes refused while the gaze is held", her.lookChangeTimer == -1)
			_check("a point target replaces the named one", _ch.look_at("checks", Vector2(820, -100)))
			_next()
		4:
			if not _wait(30):
				return
			_check("point target used", her.currentLookTarget == Vector2(820, -100))
			_check("release by its holder", _ch.release(&"gaze", "checks"))
			_next()
		5:
			if not _wait(30):
				return
			_check("released: moremoods' Smug look is back", her.currentLookTarget == her.hisFace)
			Extensions.set_enabled("moremoods", false)
			her.setMood("Normal")
			_ch.look_at("checks", "down", _ch.MOD)
			_next()
		6:
			if not _wait(60):
				return
			_check("gaze holder works with moremoods off", her.currentLookTarget == her.eyesDown
				and absf(her.eyeMotion["target"] - _expected_eye_target(her, her.eyesDown)) < 0.01 + her.passOutFactor)
			_ch.release(&"gaze", "checks")
			# time limit
			_events.clear()
			_ch.look_at("checks", "his_face", _ch.DIALOGUE, 10)
			_next()
		7:
			if not _wait(12):
				return
			_check("ttl: released when its time runs out", _ch.owner_of(&"gaze") == ""
				and _events.any(func(e): return e[0] == &"gaze" and e[3] == "time ran out"))
			# owner extension switched off
			Extensions.set_enabled("coughhotkey", true)
			_check("claim for an extension id", _ch.claim(&"blink", "coughhotkey", _ch.MOD))
			Extensions.set_enabled("coughhotkey", false)
			_next()
		8:
			if not _wait(2):
				return
			_check("released when the owner extension is switched off", _ch.owner_of(&"blink") == "")
			# full character load
			_ch.claim(&"gaze", "checks", _ch.MANUAL)
			g.inGameMenu.loadData(g.inGameMenu.getSaveDataString())
			_next()
		9:
			if not _wait(5):
				return
			_check("released when a full character is loaded", _ch.owner_of(&"gaze") == "")
			# automatic blinking off
			_ch.set_setting("auto_blink", false)
			_blinks = 0
			_next()
		10:
			if not _wait(400):
				return
			_check("auto blink off: no blinks in 400 ticks (%d)" % _blinks, _blinks == 0)
			_check("blink_now still blinks", _ch.blink_now() and _blinks == 1)
			_ch.set_setting("auto_blink", true)
			_blinks = 0
			_next()
		11:
			if not _wait(200):
				return
			_check("auto blink on again: she blinks (%d)" % _blinks, _blinks > 0)
			_check("blink channel claim", _ch.claim(&"blink", "checks", _ch.MOD))
			_blinks = 0
			_next()
		12:
			if not _wait(300):
				return
			_check("blink held: no blinks by herself (%d)" % _blinks, _blinks == 0)
			_check("blink_now refused for another owner", not _ch.blink_now("other"))
			_check("blink_now allowed for the holder", _ch.blink_now("checks") and _blinks == 1)
			_ch.release(&"blink", "checks")
			# automatic look changes off
			_ch.set_setting("auto_look", false)
			her.lookChangeTimer = -1
			her.changeLookTarget(her.hisFace, 0, 1)
			_check("auto look off: look changes refused", her.lookChangeTimer == -1)
			_ch.set_setting("auto_look", true)
			her.changeLookTarget(her.hisFace, 0, 1)
			_check("auto look on: look changes work", her.lookChangeTimer >= 0 or her.passOutFactor >= 5
				or her.eyelidMotion["isClosed"])
			# switching the plugin off releases everything
			_ch.claim(&"gaze", "checks", _ch.MANUAL)
			Extensions.set_enabled("channels", false)
			_check("plugin off: everything released", _ch.owner_of(&"gaze") == "")
			Extensions.set_enabled("channels", true)
			_check("plugin on again", _ch.enabled)
			_finish()


func _test_levels() -> void:
	_lost.clear()
	var on_lost := func(c, r): _lost.append([c, r])
	_check("free channel: claim", _ch.claim(&"gaze", "a", _ch.MOD, {"target": "down"}, -1, on_lost))
	_check("same level, other owner: refused", not _ch.claim(&"gaze", "b", _ch.MOD))
	_check("higher level takes it", _ch.claim(&"gaze", "c", _ch.DIALOGUE))
	_check("the old holder is told", _lost.size() == 1 and _lost[0][1] == "taken by c")
	_check("lower level refused", not _ch.claim(&"gaze", "a", _ch.MOD))
	_check("only the holder can release", not _ch.release(&"gaze", "a") and _ch.release(&"gaze", "c"))
	_check("unknown channel refused", not _ch.claim(&"hands", "a", _ch.MOD))
	_check("snapshot lists both channels", _ch.snapshot().size() == 2)


func _finish() -> void:
	Hooks.remove_owner("channels_checks")
	print("CHANNELS CHECKS: %d passed, %d failed" % [_passed, _failed])
	Flash.get_tree().quit(1 if _failed else 0)
