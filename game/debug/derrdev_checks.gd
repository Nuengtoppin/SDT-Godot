extends RefCounted
## Checks for the derrdev workbench (Developer mode panel, the FPS counter beside panels) and the fixes it relied on
## (hover, sizes with tan, arm modes, tears). Uses the existing game loop and a disposable save.
## run_debug.bat -- --save-dir=<temporary folder> --mods-dir=<empty folder> --driver=res://debug/derrdev_checks.gd

var _phase := 0
var _t0 := 0
var _passed := 0
var _failed := 0
var _menu: SDTMenu


func _check(label: String, ok: bool, detail := "") -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
	print("DERRDEV CHECK %s %s%s" % ["ok" if ok else "FAIL", label, "" if ok or detail == "" else " (%s)" % detail])


func step(_frame: int) -> void:
	if not Extensions.started:
		return
	match _phase:
		0:
			(Flash.stage.getChildAt(0) as DT).playClicked()
			_t0 = Flash.tick_count
			_phase = 1
		1:
			if Flash.tick_count < _t0 + 15:
				return
			_menu = SDTMenu.instance
			_menu.open_menu()
			_menu.build_now()
			_menu.close_menu()
			_test_dev_mode()
			_test_behaviour()
			_test_body_start()
			_test_throat_rings()
			_test_penisrange()
			_test_swallowing()
			_test_swallow_points()
			_test_swallow_queue()
			_test_journal()
			_test_gulp_rows()
			_test_value_points()
			_test_hover()
			_test_tan_and_sizes()
			for i in Her.armPositions.size():
				g.her.setRightArmPosition(i)
				g.her.setLeftArmPosition(i)
			g.her.setRightArmPosition(4)
			g.her.setLeftArmPosition(4)
			_check("arm modes including Loose survive", g.her.currentRightArmPosition == 4)
			_test_tan_fill()
			g.tears = true
			_check("base tear bitmap size", g.her.tears.tearArea.size == Vector2i(120, 150))
			g.her.clearMascara()
			g.her.tears.clearTearSpots()
			g.her.tears.addTears()
			g.her.tears.releaseTears()
			_check("base tears are emitted", not g.her.tears.tearList.is_empty() or not g.her.tears.tearSpotList.is_empty())
			_t0 = Flash.tick_count
			_phase = 2
		2:
			if Flash.tick_count < _t0 + 10:
				return
			_test_body_end()
			_test_value_points_asked()
			_check("base tear limit is respected", g.her.tears.tearList.size() + g.her.tears.tearSpotList.size() <= g.her.tears.maxTears)
			g.her.clearMascara()
			g.her.tears.clearTearSpots()
			_check("base tears clear", g.her.tears.tearList.is_empty() and g.her.tears.tearSpotList.is_empty())
			print("DERRDEV CHECKS: %d passed, %d failed" % [_passed, _failed])
			_phase = 99
			Flash.get_tree().quit(1 if _failed else 0)


## Developer mode: off by default, a collapsed panel with the menu's layout on the other side, both panels open
## together, the FPS counter beside a left panel, switched off and remembered.
func _test_dev_mode() -> void:
	var cfg: ConfigFile = PortSettings._cfg
	_check("dev mode off by default", not SDTMenu.dev_mode_enabled() and SDTMenu.dev == null)
	PortSettings.set_value("menu", "side", "Right")
	_menu.side_setting_changed()
	SDTMenu.set_dev_mode(true)
	var dev = SDTMenu.dev
	_check("dev panel made", dev is DevMenu and dev._root != null)
	_check("dev mode remembered", bool(cfg.get_value("developer", "enabled", false)))
	_check("dev panel starts collapsed", not dev.is_open and not dev._dock.visible)
	_check("dev panel: search, sections, help line", dev._search != null and dev._nav_buttons.size() == 9 and dev._help != null)
	_check("dev tab says DEBUG", dev._tab.text.replace("\n", "") == "DEBUG")
	_check("menu right -> dev panel left", dev._left() and not _menu._left())
	dev.open_menu()
	dev.build_now()
	var root_w: float = dev._root.size.x
	_check("dev panel docked at the left edge", is_zero_approx(dev._dock.get_global_rect().position.x))
	_check("dev panel does not pause", not g.gamePaused)
	_check("FPS counter moves beside a left panel", is_equal_approx(SDTMenu.left_inset(), SDTMenu.WIDTH))
	dev.query = "frame rate"
	dev._show()
	_check("dev search finds its own options", dev._heading.text.begins_with("1 option"))
	dev.query = ""
	dev._show()
	_menu.open_menu()
	var in_dev := _press(dev._dock.get_global_rect().get_center())
	var on_scene := _press(Vector2(root_w * 0.5, 200))
	_check("clicking the dev panel keeps the menu open", not _menu.outside_click(in_dev) and not dev.outside_click(in_dev))
	_check("clicking the scene closes both", _menu.outside_click(on_scene) and dev.outside_click(on_scene))
	_menu.close_menu()
	PortSettings.set_value("menu", "side", "Left")
	_menu.side_setting_changed()
	_check("menu left -> dev panel right", not dev._left()
		and is_equal_approx(dev._dock.get_global_rect().end.x, root_w))
	_check("FPS counter back at the left with nothing open there", is_zero_approx(SDTMenu.left_inset()))
	_menu.open_menu()
	_check("FPS counter beside the menu on the left", is_equal_approx(SDTMenu.left_inset(), SDTMenu.WIDTH))
	_menu.close_menu()
	SDTMenu.set_dev_mode(false)
	_check("dev mode off closes the panel and hides its tab", not dev.is_open and not dev._tab.visible)
	_check("dev mode off remembered", not bool(cfg.get_value("developer", "enabled", true)))
	PortSettings.set_value("menu", "side", "Right")
	_menu.side_setting_changed()


## Behaviour tabs: a row per behaviour, automation off = a veto that the panel's own call passes, freeze / restore,
## remembering, and nothing left behind when Developer mode or the new menu goes off.
func _test_behaviour() -> void:
	var her = g.her
	SDTMenu.set_dev_mode(true)
	var dev = SDTMenu.dev
	_check("behaviour tabs: Eyes, Mouth, Fluids, State, Him", ["dev_eyes", "dev_mouth", "dev_fluids", "dev_state", "dev_him"]
		.all(func(id): return dev._nav_buttons.has(id)))
	dev.open_menu("dev_mouth")
	dev.build_now()
	_check("Mouth tab: All off/on and 6 rows (P051: Gulp, Gulp no squint)", dev._rows.size() == 7, str(dev._rows.size()))
	_check("everything on at first", DevBehaviour.off_count() == 0)
	DevBehaviour.set_auto(&"Her.swallow", false)
	her.swallowing = false
	her.swallow()
	_check("Swallow off: she does not swallow by herself", not her.swallowing)
	_check("Swallow off: the status names the veto", DevBehaviour.status(&"Her.swallow").contains("vetoed by Developer mode"),
		DevBehaviour.status(&"Her.swallow"))
	var free: bool = not her.passedOut and not her.speaking
	DevBehaviour.call_now(&"Her.swallow", func(): her.swallow())
	_check("Swallow off: the call button still works", not free or her.swallowing)
	_check("the button's call shows as called from here", not free or DevBehaviour.status(&"Her.swallow").contains("called from here"),
		DevBehaviour.status(&"Her.swallow"))
	her.swallowing = false
	DevBehaviour.set_all(false)
	_check("Freeze all switches off every behaviour", DevBehaviour.off_count() == DevBehaviour.hooks().size())
	DevBehaviour.set_all(true, "eyes")
	_check("All on in one tab", not DevBehaviour.is_off(&"Her.blink") and DevBehaviour.is_off(&"Her.swallow"))
	DevBehaviour.set_all(true)
	_check("Restore all", DevBehaviour.off_count() == 0 and not Hooks.registered().is_empty())
	var cfg: ConfigFile = PortSettings._cfg
	DevBehaviour.set_remember(true)
	DevBehaviour.set_auto(&"Him.ejaculate", false)
	_check("Remember on: switched-off automation saved", "Him.ejaculate" in cfg.get_value("dev_behaviour", "off", []))
	DevBehaviour.set_remember(false)
	_check("Remember off: nothing saved, the session keeps it", cfg.get_value("dev_behaviour", "off", ["x"]).is_empty()
		and DevBehaviour.is_off(&"Him.ejaculate"))
	SDTMenu.set_dev_mode(false)
	_check("Developer mode off: no vetoes or observers left", not Hooks.has(&"Him.ejaculate") and not Hooks.has(&"Her.swallow"))
	SDTMenu.set_dev_mode(true)
	_check("Developer mode back on: the session's switches return", Hooks.has(&"Him.ejaculate"))
	Extensions.set_vanilla_mode(true)
	_menu.apply_mode()
	_check("Vanilla mode: no vetoes or observers", not Hooks.has(&"Him.ejaculate"))
	Extensions.set_vanilla_mode(false)
	_menu.apply_mode()
	DevBehaviour.set_all(true)
	dev.close_menu()
	SDTMenu.set_dev_mode(false)


## Body tab: the neck's debug layers (DevBodyOverlay) - data from the live neck, drawn only in Developer mode.
func _test_body_start() -> void:
	SDTMenu.set_dev_mode(true)
	_check("Body tab", SDTMenu.dev._nav_buttons.has("dev_body"))
	for layer in DevBodyOverlay.LAYERS:
		DevBodyOverlay.set_on("neck", layer, true)
	_check("neck layers on, overlay made", DevBodyOverlay.instance != null and DevBodyOverlay.any_on())
	var d: Dictionary = DevBodyOverlay.neck()
	_check("neck data: node, outline, highlight, axis", d.get("node") == g.her.head.neck and d["base"].size() > 10
		and d["rendered2"].size() > 3 and d["axes"].size() == 1)


## Throat rings (ThroatRings), read only: the collar ring from the collar's picture, pressure stretches a ring and
## wears it down, rest brings it back, a stiff ring does not give; nothing in the game changes.
func _test_throat_rings() -> void:
	var her = g.her
	var n: Neck = her.head.neck
	var cc = g.characterControl.collarControl
	var was: int = cc.selection
	_check("throat rings work out only in Developer mode", ThroatRings.active())
	cc.select(0)
	_ring_tick(her)
	_check("no collar: no collar ring", not ThroatRings.collar["on"] and ThroatRings.entrance["on"])
	_check("entrance ring on the game's resistance zone", is_equal_approx(ThroatRings.entrance["top"], 75.0 / 400.0)
		and is_equal_approx(ThroatRings.entrance["bottom"], 150.0 / 400.0))
	cc.select(1)
	_ring_tick(her)
	var c: Dictionary = ThroatRings.collar
	var b: Rect2 = her.collarContainer.collar.getBounds(n)
	_check("leather collar: its edges as seen in the game by default", ThroatRings.collar_name == "Leather"
		and ThroatRings.collar_top_adjust == 0.005 and ThroatRings.collar_bottom_adjust == -0.05)
	_check("leather collar: ring at the collar's picture", c["on"]
		and is_equal_approx(c["top"], ThroatRings.depth_at_y(n, b.position.y) + ThroatRings.collar_top_adjust)
		and c["bottom"] > c["top"] and c["top"] > 0.3 and c["bottom"] < 0.95, "%s %s" % [c["top"], c["bottom"]])
	ThroatRings.adjust_collar(0.02, -0.03)
	var top: float = c["top"]
	_ring_tick(her)
	_check("collar edges move by hand", is_equal_approx(c["top"], top + 0.015))
	_check("collar edges kept in port.cfg for this collar",
		PortSettings.get_value(ThroatRings.SECTION, "edges_Leather") == [0.02, -0.03])
	cc.select(3)
	_ring_tick(her)
	_check("another collar: its own edges", ThroatRings.collar_name == "Gem Choker" and ThroatRings.collar_top_adjust == 0.03
		and ThroatRings.collar_bottom_adjust == -0.03)
	ThroatRings.set_stiffness(1.0)
	cc.select(1)
	_ring_tick(her)
	_check("back to the first collar: its hand fit comes back", ThroatRings.collar_top_adjust == 0.02
		and ThroatRings.collar_bottom_adjust == -0.03)
	_check("one stiffness for every collar, kept in port.cfg", ThroatRings.collar["stiff"] == 1.0
		and PortSettings.get_value(ThroatRings.SECTION, "stiffness") == 1.0)
	ThroatRings.set_stiffness(0.6)
	cc.select(2)
	_ring_tick(her)
	var tb: Rect2 = her.collarContainer.collar.getBounds(n)
	_check("tie: only the band counts, not the hanging tie", c["on"] and tb.size.y > ThroatRings.COLLAR_BAND
		and ThroatRings.collar_top_adjust == 0.04 and ThroatRings.collar_bottom_adjust == -0.085
		and is_equal_approx(c["bottom"], ThroatRings.depth_at_y(n, tb.position.y + ThroatRings.COLLAR_BAND) - 0.085))
	var game := [g.throatResistance, her.pos, n.throatBulgeAmount, her.collarContainer.collar.scaleX, n.swallowScale]
	# a ring of its own, pressed hard: it stretches, holds less, wears down and snaps; at rest it comes back
	var r := ThroatRings._ring("test", 0.2, 0.3, 0.8, 0.0, 5.0)
	ThroatRings.tip = 0.5
	ThroatRings.push = 1.0
	ThroatRings._step(r, 1.0, n)
	var hold0: float = r["hold"]
	for i in 30:
		ThroatRings._step(r, 1.0, n)
	_check("pressure stretches a ring and it holds less", r["stretch"] > 0.05 and r["hold"] < hold0 and r["pressure"] >= 1.0,
		"%s %s" % [r["stretch"], r["hold"]])
	_check("pressure wears a ring down until it would snap", r["snapped"] and r["hold"] == 0.0)
	ThroatRings.tip = 0.0
	var st: float = r["stretch"]
	ThroatRings._step(r, 1.0, n)
	_check("at rest a ring recovers", r["stretch"] < st and r["pressure"] == 0.0)
	var m := ThroatRings._ring("metal", 0.2, 0.3, 0.85, 1.0, INF)
	ThroatRings.tip = 0.5
	for i in 30:
		ThroatRings._step(m, 1.0, n)
	_check("a fully stiff ring does not give or break", m["stretch"] == 0.0 and not m["snapped"] and m["hold"] == 0.85)
	ThroatRings.set_stiffness(0.0)
	_check("stiffness 0 holds nothing; collars never break by default", c["tight"] == 0.0 and c["stiff"] == 0.0
		and not is_finite(c["max_durability"]))
	ThroatRings.collar_breaks = true
	ThroatRings._apply_stiffness()
	_check("collars may break: a soft band breaks easily", c["max_durability"] == 60.0 and c["durability"] == 60.0)
	ThroatRings.set_stiffness(1.0)
	_check("stiffness 1: metal holds fully and never breaks", c["tight"] == 1.0 and not is_finite(c["max_durability"]))
	var worn_tags: Dictionary = ThroatRings.collar_tags[ThroatRings.collar_name]   # the collar she wears (the tie here)
	worn_tags["stiffness"] = 0.2
	ThroatRings._apply_stiffness()
	_check("a collar's tags may set its own stiffness", c["stiff"] == 0.2)
	worn_tags.erase("stiffness")
	worn_tags["can_snap"] = false
	ThroatRings.set_stiffness(0.2)
	_check("a collar tagged not to snap never breaks", not is_finite(c["max_durability"]))
	worn_tags.erase("can_snap")
	ThroatRings.collar_breaks = false
	ThroatRings.set_stiffness(0.6)
	_ring_tick(her)
	_check("the rings change nothing in the game", game == [g.throatResistance, her.pos, n.throatBulgeAmount,
		her.collarContainer.collar.scaleX, n.swallowScale])
	DevBodyOverlay.set_on("throat", "zones", true)
	var d: Dictionary = DevBodyOverlay.throat()
	_check("overlay: two edges per ring", d.get("node") == n and d["zones"].size() == 4)
	cc.select(was)
	ThroatRings.reset_stretch()


## penisrange: off by default (the game's limits); on, wider limits, sizes kept as sizes; big sizes move the mask
## and the balls; off again, sizes and limits back inside the game's range.
func _test_penisrange() -> void:
	var x = Extensions.get_extension("penisrange")
	var him = g.him
	_check("penisrange: built in, off by default, the game's limits", x != null and x.enabled and not x.get_setting("on")
		and Him.MIN_PENIS_SIZE == 0.7 and Him.MAX_PENIS_SIZE == 1.2 and Him.MIN_BALL_SIZE == 0.5 and Him.MAX_BALL_SIZE == 1.3)
	var balls := Vector2(him.balls.x, him.balls.y)
	x.set_setting("on", true)
	_check("penisrange on: wider limits", Him.MAX_PENIS_SIZE == 3.0 and is_equal_approx(Him.MIN_PENIS_SIZE, 0.35)
		and is_equal_approx(Him.MAX_BALL_SIZE, 3.25) and is_equal_approx(Him.MIN_BALL_SIZE, 0.25))
	him.setPenisLength(1.0)
	_check("the length slider reaches the new largest size", is_equal_approx(him.currentPenisLengthScale, 3.0))
	him.loadPenisScales(2.5, 2.0)
	_check("sizes past the game's range load as they are", him.currentPenisLengthScale == 2.5 and him.currentPenisWidthScale == 2.0)
	him.setBallScale(2.0)
	x._tick()
	_check("big sizes: the mask follows his length", him.penisMask.scaleX == 2.5)
	_check("big balls move down and back", is_equal_approx(him.balls.y, balls.y + 0.7 * 22.0)
		and is_equal_approx(him.balls.x, balls.x + 0.7 * 20.0))
	him.loadPenisScales(1.0, 1.0)
	him.setBallScale(1.0)
	x._tick()
	_check("within the game's range: the game's mask and balls", him.penisMask.scaleX == 1.0 and him.balls.y == balls.y)
	him.loadPenisScales(2.5, 2.0)
	x.set_setting("on", false)
	_check("penisrange off: the game's limits, sizes brought back", Him.MAX_PENIS_SIZE == 1.2 and Him.MIN_PENIS_SIZE == 0.7
		and him.currentPenisLengthScale == 1.2 and him.currentPenisWidthScale == 1.2 and him.penisMask.scaleX == 1.0)
	him.loadPenisScales(1.0, 1.0)


## Swallowing (throatcumbulge, stage 2): off by default; per swallow, until empty, while he cums, bulge by amount;
## extra swallows go through Her.swallow, so a veto stops them.
func _test_swallowing() -> void:
	var x = Extensions.get_extension("throatcumbulge")
	var her = g.her
	var neck = her.head.neck
	_check("swallowing: all off by default", not x.get_setting("guzzle") and x.get_setting("pump") == "Off"
		and x.get_setting("per_swallow") == 0)
	her.swallowing = false
	her.speaking = false
	her.passedOut = false
	# a swallow's wave starts: the game took 7 of 20; with "per swallow" 3 it takes 3
	x.set_setting("per_swallow", 3)
	x._prev_cum = 20
	x._prev_wave = false
	x._prev_swallowing = false
	her.cumInMouth = 13
	neck.swallowing = true
	x._swallowing(her)
	_check("per swallow: takes what is set", her.cumInMouth == 17 and x.last_amount == 3)
	x.set_setting("per_swallow", 0)
	x._prev_cum = 20
	x._prev_wave = false
	her.cumInMouth = 13
	x._swallowing(her)
	_check("per swallow 0: the game's amount", her.cumInMouth == 13 and x.last_amount == 7)
	neck.swallowing = false
	# a swallow ends with cum left and her mouth free
	x.set_setting("guzzle", true)
	x._prev_swallowing = true
	her.swallowing = false
	her.penisInMouthDist = -50.0
	her.cumInMouth = 10
	x._swallowing(her)
	_check("until empty: she swallows again", her.swallowing)
	her.swallowing = false
	x._prev_swallowing = true
	var n := _vetoed(&"Her.swallow", func(): x._swallowing(her))
	_check("until empty: a veto on Her.swallow stops it", n == 1 and not her.swallowing)
	x.set_setting("guzzle", false)
	x._prev_swallowing = true
	x._swallowing(her)
	_check("until empty off: no extra swallow", not her.swallowing)
	# a spurt in her mouth
	her.mouthFull = true
	her.held = false
	her.cumInMouth = 25
	x._on_spurt()
	_check("while he cums Off: nothing", not her.swallowing)
	x.set_setting("pump", "When full")
	x._on_spurt()
	_check("while he cums When full: more than half full", her.swallowing)
	her.swallowing = false
	her.cumInMouth = 10
	x._on_spurt()
	_check("When full: not at a quarter", not her.swallowing)
	x.set_setting("pump", "Always")
	x._on_spurt()
	_check("Always: whenever there is cum", her.swallowing)
	her.swallowing = false
	her.held = true
	x._on_spurt()
	_check("held deep: no swallow (it goes down her throat)", not her.swallowing)
	her.held = false
	her.mouthFull = false
	x.set_setting("pump", "Off")
	# the bulge by amount
	x.set_setting("swallow_mode", "By amount")
	neck.swallowing = true
	x.last_amount = 10
	x._swallow_scale(her)
	var big: float = neck.swallowScale.x
	x.last_amount = 5
	x._swallow_scale(her)
	_check("bulge by amount: a bigger swallow, a bigger bulge", big > neck.swallowScale.x and is_equal_approx(big, 0.8 * 0.75 * 4))
	neck.swallowing = false
	x.set_setting("swallow_mode", "The game's")
	x._swallow_scale(her)
	her.cumInMouth = 0
	x._prev_cum = 0
	x._prev_swallowing = false


## P048: the swallow's own points - Her.swallow's after point (did it start), Her.gulp, Her.swallowSpeed and
## Her.swallowWince.
func _test_swallow_points() -> void:
	var her = g.her
	her.swallowing = false
	her.speaking = false
	her.passedOut = false
	var started := []
	var rec := func(c): started.append(c.result)
	Hooks.add_after(&"Her.swallow", rec, "derrdev_checks")
	her.swallow(0.8, false)
	her.swallow(0.8, false)
	Hooks.remove(&"Her.swallow", rec)
	_check("Her.swallow after: tells a started swallow from a dropped one", started == [true, false], str(started))
	var base: Dictionary = her.swallowSequence.duplicate()
	her.swallowing = false
	var sp := modify_test(&"Her.swallowSpeed", 2.0)
	her.swallow(0.8, false)
	Hooks.remove_modifier(sp)
	var seq: Dictionary = her.swallowSequence
	_check("Her.swallowSpeed 2: the swallow plays in half the ticks", seq["end"] == Maths.round(base["end"] / 2.0)
		and seq["build"] < seq["swallow"] and seq["swallow"] < seq["relax"] and seq["relax"] < seq["end"], "%s -> %s" % [base, seq])
	her.swallowing = false
	her.swallow(0.8, false)
	_check("Her.swallowSpeed unset: the game's lengths", her.swallowSequence == base)
	her.swallowing = false
	her.swallowTimer = 0
	her.cumInMouth = 20
	var n := _counted(&"Her.gulp", func(): her.gulp())
	_check("Her.gulp: once, takes from her mouth", n == 1 and her.cumInMouth < 20 and her.cumInMouth >= 11)
	her.cumInMouth = 20
	n = _vetoed(&"Her.gulp", func(): her.gulp())
	_check("Her.gulp vetoed: nothing leaves her mouth", n == 1 and her.cumInMouth == 20)
	n = _counted(&"Her.wince", func(): her.gulp())
	_check("Her.gulp: she squints (the game's)", n == 1)
	var nw := modify_test(&"Her.swallowWince", false)
	her.cumInMouth = 20
	n = _counted(&"Her.wince", func(): her.gulp())
	_check("Her.swallowWince false: the gulp without the squint", n == 0 and her.cumInMouth < 20)
	Hooks.remove_modifier(nw)
	her.cumInMouth = 0
	her.head.neck.swallowing = false
	her.swallowing = false
	her.swallowTimer = 0


## P049: throatcumbulge's swallow queue, speed and squint (the game's way by default).
func _test_swallow_queue() -> void:
	var x = Extensions.get_extension("throatcumbulge")
	var her = g.her
	_check("queue, speed, squint: the game's by default", x.get_setting("queue") == 0 and x.get_setting("speed") == 1.0
		and x.get_setting("wince") and not Hooks.has_value(&"Her.swallowSpeed") and not Hooks.has_value(&"Her.swallowWince"))
	her.swallowing = false
	her.speaking = false
	her.passedOut = false
	her.cumInMouth = 30
	her.swallow(0.8, false)
	her.swallow(0.8, false)
	_check("queue 0: a swallow asked for during one is dropped", x.queued == 0)
	x.set_setting("queue", 2)
	for i in 3:
		her.swallow(0.8, false)
	_check("queue 2: keeps two", x.queued == 2, str(x.queued))
	x.set_setting("queue_gap", 3)
	her.swallowing = false
	x._queue(her)
	x._queue(her)
	_check("queue: waits the pause after a swallow ends", not her.swallowing and x.queued == 2)
	x._queue(her)
	_check("queue: then the next swallow", her.swallowing and x.queued == 1)
	x._queue(her)
	_check("queue: none while she swallows", x.queued == 1)
	her.swallowing = false
	her.cumInMouth = 0
	x._gap = 0
	for i in 3:
		x._queue(her)
	_check("dry swallows on: the series goes on with her mouth empty", her.swallowing and x.queued == 0)
	her.swallowing = false
	x.queued = 2
	x.set_setting("dry", false)
	x._queue(her)
	_check("dry swallows off: an empty mouth ends the series", x.queued == 0 and not her.swallowing)
	x.set_setting("dry", true)
	x.queued = 2
	her.passedOut = true
	x._queue(her)
	_check("queue: passing out clears it", x.queued == 0)
	her.passedOut = false
	# a spurt while she swallows waits its turn with a queue
	x.set_setting("pump", "Always")
	her.swallowing = true
	her.mouthFull = true
	her.held = false
	her.cumInMouth = 10
	x._on_spurt()
	_check("while he cums + queue: the spurt's swallow waits", x.queued == 1)
	x.set_setting("pump", "Off")
	her.mouthFull = false
	x.set_setting("queue", 0)
	_check("queue 0 again: none wait", x.queued == 0)
	x.set_setting("speed", 2.0)
	x.set_setting("wince", false)
	_check("speed and squint set the value points", Hooks.value(&"Her.swallowSpeed", her, 1.0) == 2.0
		and Hooks.value(&"Her.swallowWince", her, true) == false)
	x.set_setting("speed", 1.0)
	x.set_setting("wince", true)
	_check("speed and squint back: no modifiers", not Hooks.has_value(&"Her.swallowSpeed") and not Hooks.has_value(&"Her.swallowWince"))
	her.swallowing = false
	her.swallowTimer = 0
	her.cumInMouth = 0
	x._prev_cum = 0
	x._prev_swallowing = false


## P051: the Mouth tab's gulp rows - Gulp (its automation switch vetoes Her.gulp), Gulp without the squint.
func _test_gulp_rows() -> void:
	var her = g.her
	var rows := DevBehaviour.entries().filter(func(e): return e[0] == "mouth").map(func(e): return e[1])
	_check("Mouth tab: Gulp and Gulp, no squint", "Gulp" in rows and "Gulp, no squint" in rows and &"Her.gulp" in DevBehaviour.hooks())
	var gulp: Array = DevBehaviour.entries().filter(func(e): return e[1] == "Gulp")[0]
	var plain: Array = DevBehaviour.entries().filter(func(e): return e[1] == "Gulp, no squint")[0]
	her.cumInMouth = 20
	var n := _counted(&"Her.wince", func(): DevBehaviour.call_now(gulp[2], gulp[3]))
	_check("Gulp: she squints, cum leaves her mouth", n == 1 and her.cumInMouth < 20)
	her.cumInMouth = 20
	n = _counted(&"Her.wince", func(): DevBehaviour.call_now(plain[2], plain[3]))
	_check("Gulp, no squint: no squint, cum leaves her mouth, the modifier gone", n == 0 and her.cumInMouth < 20
		and not Hooks.has_value(&"Her.swallowWince"))
	her.cumInMouth = 0
	her.head.neck.swallowing = false


## P050: the event log (Tools > Log): only while Developer mode is on, folding repeats, the swallow's points, the
## behaviour observer's vetoes, states once per tick, pause, filter, save, the last MAX lines, the tab.
func _test_journal() -> void:
	var her = g.her
	var dev_was: bool = SDTMenu.dev_mode_enabled()
	SDTMenu.set_dev_mode(false)
	_check("log: off without Developer mode", not Journal.active and not Hooks.has(&"Her.gulp"))
	var n0: int = Journal.lines.size()
	Journal.log("other", "nothing")
	_check("log: Journal.log does nothing while off", Journal.lines.size() == n0)
	SDTMenu.set_dev_mode(true)
	_check("log: on with Developer mode", Journal.active and Hooks.has(&"Her.gulp"))
	Journal.clear()
	Journal.log("other", "a")
	Journal.log("other", "a")
	Journal.log("other", "b")
	_check("log: the same line again is folded", Journal.lines.size() == 2 and Journal.lines[0][3] == 2
		and Journal.as_text().contains("a  x2"), Journal.as_text())
	Journal.clear()
	her.swallowing = false
	her.speaking = false
	her.passedOut = false
	her.cumInMouth = 20
	her.swallow(0.8, false)
	her.swallow(0.8, false)
	her.gulp()
	Journal._tick()
	var t := Journal.as_text()
	_check("log: swallow starts, a dropped request, the gulp", t.contains("Swallow starts (strength 0.80, 20 in her mouth)")
		and t.contains("Asked to swallow: dropped, already swallowing") and t.contains("Gulp: took ")
		and t.find("Swallow starts") < t.find("dropped") and t.find("dropped") < t.find("Gulp"), t)
	Journal.clear()
	her.swallowing = false   # it ended and the next starts in the same tick, before the log's tick saw the end
	her.swallow(0.8, false)
	t = Journal.as_text()
	_check("log: a swallow ending and the next starting in one tick: both lines", t.contains("Swallow ends")
		and t.find("Swallow ends") < t.find("Swallow starts"), t)
	var x = Extensions.get_extension("throatcumbulge")
	x.set_setting("queue", 1)
	Journal.clear()
	her.swallow(0.8, false)
	her.swallow(0.8, false)
	t = Journal.as_text()
	_check("log: the queue writes its own lines", t.contains("dropped, already swallowing") and t.contains("Queued: 1 waiting")
		and t.contains("Queue full (1)") and t.find("dropped") < t.find("Queued"), t)
	x.set_setting("queue", 0)
	Journal.clear()
	DevBehaviour.set_auto(&"Her.cough", false)
	her.cough()
	Journal._tick()
	DevBehaviour.set_auto(&"Her.cough", true)
	_check("log: a veto names who", Journal.as_text().contains("Cough vetoed by Developer mode"), Journal.as_text())
	Journal.clear()
	Journal._prev.clear()
	Journal._tick()
	var was: bool = her.breathing
	her.breathing = not was
	Journal._tick()
	_check("log: a state change waits HOLD ticks", Journal.lines.is_empty())
	Journal._since["breathing"][1] -= Journal.HOLD   # as if HOLD ticks went by
	Journal._tick()
	her.breathing = was
	Journal._tick()
	Journal._since["breathing"][1] -= Journal.HOLD
	Journal._tick()
	t = Journal.as_text()
	_check("log: a state change is one line each way", t.contains("Holds her breath") and t.contains("Breathes again")
		and Journal.lines.size() == 2, t)
	Journal.clear()
	her.breathing = not was
	Journal._tick()
	her.breathing = was
	Journal._tick()
	_check("log: a flicker shorter than HOLD makes no line", Journal.lines.is_empty(), Journal.as_text())
	Journal.log("breath", "Holds her breath")
	Journal.log("breath", "Breathes again")
	Journal.shown["breath"] = false
	_check("log: hidden groups are left out of the text", Journal.as_text() == "" and Journal.as_text(false) != "")
	Journal.shown["breath"] = true
	Journal.paused = true
	Journal.log("other", "paused")
	Journal.paused = false
	_check("log: nothing while paused", not Journal.as_text().contains("paused"))
	var path := Journal.save()
	_check("log: saved to a file", path != "" and FileAccess.get_file_as_string(path).contains("Holds her breath"), path)
	for i in Journal.MAX + 20:
		Journal.log("other", "line %d" % i)
	_check("log: keeps the last MAX lines", Journal.lines.size() == Journal.MAX and Journal.lines[-1][2] == "line %d" % (Journal.MAX + 19))
	var spec: Dictionary = DevJournalTab.group()["controls"][1]
	var row := MenuWidgets.build(spec, func(_s): pass)
	row.get_meta("refresh").call()
	var views := row.find_children("*", "TextEdit", true, false)
	_check("log tab: shows the lines", views.size() == 1 and (views[0] as TextEdit).text == Journal.as_text(true, true)
		and (views[0] as TextEdit).get_line(0) == Journal.line_text(Journal.lines[-1]))
	row.free()
	var tools: Dictionary = DevSchema.sections()[0]
	_check("log tab: in Tools", tools["groups"].any(func(gr): return gr["title"] == "Log"))
	Journal.clear()
	SDTMenu.set_dev_mode(false)
	_check("log: Developer mode off removes its hooks", not Journal.active and _hooks_of(Journal.OWNER) == 0)
	SDTMenu.set_dev_mode(dev_was)
	her.swallowing = false
	her.swallowTimer = 0
	her.cumInMouth = 0
	her.head.neck.swallowing = false
	x._prev_cum = 0
	x._prev_swallowing = false


## How many hook handlers `owner` has registered.
func _hooks_of(owner: String) -> int:
	var n := 0
	for name in Hooks._hooks:
		for phase in ["before", "after"]:
			n += Hooks._hooks[name][phase].filter(func(h): return h[4] == owner).size()
	return n


func modify_test(name: StringName, v) -> int:
	return Hooks.add_modifier(name, {"phase": Hooks.OVERRIDE, "op": "set", "value": v}, "derrdev_checks")


## Runs `fn` counting the calls of hook `name` (not vetoed); returns the count.
func _counted(name: StringName, fn: Callable) -> int:
	var n := [0]
	var count := func(_c): n[0] += 1
	Hooks.add_before(name, count, "derrdev_checks")
	fn.call()
	Hooks.remove(name, count)
	return n[0]


## Value points (upstream's Hooks.value): ours (neck, throat) are not set by default; the ring extensions' modifiers.
func _test_value_points() -> void:
	_check("value points: none of ours set by default", not Hooks.has_value(&"Neck.throatBulge")
		and not Hooks.has_value(&"Her.resistance") and not Hooks.has_value(&"Neck.pointBulge"))
	_test_entrance_ring()
	_test_collar_ring()
	# the game asks its points every tick (checked after a few ticks), with the entrance ring acting: one neck render
	# per tick (the mod drew the neck a second time)
	Extensions.get_extension("throatresiststretch").set_setting("on", true)
	_asked_from = Flash.tick_count
	_resist0 = [g.throatResistance, g.her.resistance["boundary"]]
	for p in [&"Neck.throatBulge", &"Neck.bulgeCap", &"Her.pushBack"]:
		Hooks.add_modifier(p, {"op": "fn", "fn": func(x, _o): _asked[p] = _asked.get(p, 0) + 1; return x}, "derrdev_checks")


## The throat entrance ring acting (throatresiststretch "Throat loosens"): it lowers the entrance's share of the
## resistance and keeps the neck drawn stretched, through value points; off, nothing is left.
func _test_entrance_ring() -> void:
	var x = Extensions.get_extension("throatresiststretch")
	var her = g.her
	var e: Dictionary = ThroatRings.entrance
	x.set_setting("on", true)
	var owners: Array = _vp_owned("throatresiststretch")
	_check("throat loosens on: the entrance ring acts on resistance and neck depth", owners.has(&"Her.resistance") and owners.has(&"Neck.depth"))
	e["stretch"] = 0.5
	ThroatRings.tip = 0.3
	var upper: float = her.resistance["upper"]
	_check("a stretched entrance lowers its share of the resistance",
		is_equal_approx(Hooks.value(&"Her.resistance", her, upper + 0.05), upper + 0.025))
	ThroatRings.tip = 0.5
	_check("past the entrance the resistance is the game's", Hooks.value(&"Her.resistance", her, 0.0) == 0.0)
	_check("a stretched entrance keeps the neck drawn as deep as the stretch", Hooks.value(&"Neck.depth", her.head.neck, 0.1) == 0.5
		and Hooks.value(&"Neck.depth", her.head.neck, 0.7) == 0.7)
	x.set_setting("recover", 0.5)
	ThroatRings.tip = 0.0
	ThroatRings._step(e, 1.0, her.head.neck)
	_check("the throat tightens back at the set speed", is_equal_approx(e["stretch"], 0.5 - ThroatRings.RECOVER_RATE * 0.5 * (1.0 - 0.5 * e["stiff"])))
	x.set_setting("recover", 0.25)
	x.set_setting("on", false)
	_check("throat loosens off: nothing left", not not _vp_owned("throatresiststretch").is_empty()
		and e["stretch"] == 0.0)


## The collar ring acting (chokercollarresistance): past its top edge her head is pushed back and pushing in is
## harder by what it holds, the bulge stops at it until it stretches, its picture widens; off, nothing is left.
func _test_collar_ring() -> void:
	var x = Extensions.get_extension("chokercollarresistance")
	var her = g.her
	var cc = g.characterControl.collarControl
	var was: int = cc.selection
	var c: Dictionary = ThroatRings.collar
	_check("collar holds: off by default", x != null and not x.get_setting("on")
		and not not _vp_owned("chokercollarresistance").is_empty())
	cc.select(1)
	ThroatRings._tick_done = -1
	_ring_tick(her)
	x.set_setting("on", true)
	var pts: Array = _vp_owned("chokercollarresistance")
	_check("collar holds on: push back, resistance (awake and passed out), the band on her neck", pts.has(&"Her.pushBack")
		and pts.has(&"Her.resistance") and pts.has(&"Her.limpResistance")
		and pts.has(&"Neck.pointBulge"))
	ThroatRings.set_stiffness(0.6)
	ThroatRings.reset_stretch()
	ThroatRings.repair()
	var band: float = c["bottom"] - c["top"]
	ThroatRings.tip = c["top"] + 0.05
	c["hold"] = c["tight"]
	_check("in the collar's band her head is pushed back by what it holds",
		is_equal_approx(Hooks.value(&"Her.pushBack", her, 0.0), 0.05 * 400.0 * 0.0015 * c["tight"]))
	_check("in the band going deeper gets harder, like her throat entrance",
		is_equal_approx(Hooks.value(&"Her.resistance", her, 0.0), 0.3 * c["tight"] * 0.05 / band))
	ThroatRings.tip = c["bottom"] - 0.0001
	_check("at its bottom edge the collar is a wall (0.3 x what it holds)", absf(x.wall() - 0.3 * c["tight"]) < 0.001)
	ThroatRings.tip = c["bottom"] + 0.2
	ThroatRings.set_wall(0.25)
	ThroatRings.tip = c["bottom"] - 0.0001
	_check("Collar resistance sets the wall on its own", absf(x.wall() - 0.25) < 0.001 and ThroatRings.collar_wall == 0.25
		and PortSettings.get_value(ThroatRings.SECTION, "wall") == 0.25)
	_check("passed out she is still held by the collar", is_equal_approx(Hooks.value(&"Her.limpResistance", her, 0.0), x.wall()))
	ThroatRings.set_stiffness(0.2)
	_check("setting the stiffness sets the wall to match (0.3 x stiffness)", is_equal_approx(ThroatRings.collar_wall, 0.06))
	ThroatRings.set_stiffness(0.6)
	c["hold"] = c["tight"]
	ThroatRings.tip = c["bottom"] + 0.2
	_check("through it: only a squeeze, no more push back than the band's",
		is_equal_approx(x.wall(), 0.03 * c["tight"])
		and is_equal_approx(Hooks.value(&"Her.pushBack", her, 0.0), band * 400.0 * 0.0015 * c["tight"]))
	ThroatRings.tip = c["top"] + 0.05
	var neck = her.head.neck
	var mid: float = (c["top"] + c["bottom"]) / 2.0
	var at := func(f: float) -> float:
		neck.bulgePointDepth = f
		x.refresh_band()
		return Hooks.value(&"Neck.pointBulge", neck, 30.0)
	var give: float = 6.0 * 0.4 / 0.6
	_check("a softer collar gives way at once, before it stretches", is_equal_approx(x.room(), give))
	x.push_px = 0.0
	_check("between the collar's edges her neck pushes out only as far as the collar gives", is_equal_approx(at.call(mid), 2.0 + 3.0))
	_check("well above and below the collar it is free", at.call(c["top"] - 0.1) == 30.0 and at.call(c["bottom"] + 0.1) == 30.0)
	var step: float = at.call(c["top"] - 0.02)
	var step2: float = at.call(c["top"] - 0.05)
	_check("past each edge the band blends into the free bulge", step > 5.0 and step < step2 and step2 < 30.0, "%s %s" % [step, step2])
	c["stretch"] = 1.0
	x.push_px = 30.0
	_check("stretched it gives further", is_equal_approx(at.call(mid), 2.0 + give + 70.0 * 0.25))
	x.push_px = 0.0
	x.set_setting("widen", false)
	_check("picture not widening: the band stays tight", at.call(mid) == 2.0)
	x.set_setting("widen", true)
	ThroatRings.set_stiffness(1.0)
	c["stretch"] = 0.0
	c["hold"] = c["tight"]
	_check("metal does not give", x.room() == 0.0 and at.call(mid) == 2.0)
	ThroatRings.set_stiffness(0.0)
	c["hold"] = c["tight"]
	_check("stiffness 0: it holds nothing and rides along with her neck", x.rides_free() and at.call(mid) == 30.0
		and x.wall() == 0.0 and Hooks.value(&"Her.pushBack", her, 0.0) == 0.0 and not is_finite(x.room()))
	ThroatRings.set_stiffness(1.0)
	c["hold"] = c["tight"]
	# drawn: deep, a big bulge - the outline under a metal collar stays in, above it bulges
	var was_bulge: float = neck.throatBulgeAmount
	neck.throatBulgeAmount = 1.5
	x.refresh_band()
	neck.render(0.95)
	var pts_r: Array = neck.renderedPoints
	var n: int = neck.frontEndPoint
	var i_mid := int(round(mid * n))
	var i_above := int(floor((c["top"] - 0.1) * n))
	var out_mid: float = (pts_r[i_mid] - neck.neckPoints[i_mid]).x
	var out_above: float = (pts_r[i_above] - neck.neckPoints[i_above]).x
	_check("drawn: under the collar the neck stays in, above it bulges", out_mid <= 2.001 and out_above > 5.0,
		"%s %s" % [out_mid, out_above])
	neck.throatBulgeAmount = was_bulge
	ThroatRings.set_stiffness(0.6)
	var cont = her.collarContainer
	var col = cont.collar
	var before: Rect2 = col.getBounds(cont)
	x.push_px = 12.0
	x._widen(her)
	var after: Rect2 = col.getBounds(cont)
	_check("her throat pushes the collar's front out by as much", absf((after.end.x - before.end.x) - 12.0) < 0.5, "%s -> %s" % [before, after])
	_check("it widens to the front only: the back (her nape) stays put", absf(after.position.x - before.position.x) < 0.5)
	# the collar follows her throat fast, with a little spring, and settles back when her throat does
	var neck2 = her.head.neck
	c["stretch"] = 1.0
	x.push_px = 0.0
	neck2.throatBulgeAmount = 1.5
	x.refresh_band()
	neck2.render(0.95)
	var push0: float = x._throat_push(neck2, c)
	x.push_speed = 0.0
	x._spring(push0, c)
	_check("the collar's front is a spring: it moves part of the way at first", push0 > 0.0 and x.push_px > 0.0 and x.push_px < push0,
		"%s %s" % [push0, x.push_px])
	x._spring(push0, c)
	x._spring(push0, c)
	_check("it is fast: nearly there in 3 ticks", absf(x.push_px - push0) < 0.15 * push0, "%s %s" % [push0, x.push_px])
	var peak := 0.0
	for i in 60:
		x._spring(push0, c)
		peak = maxf(peak, x.push_px)
	_check("it overshoots a little, then settles where her throat pushes it", peak > push0 and peak < 1.2 * push0
		and absf(x.push_px - push0) < 0.2, "%s peak %s at %s" % [push0, peak, x.push_px])
	x.refresh_band()
	neck2.render(0.0)
	_check("her throat relaxed: nothing pushes the collar", x._throat_push(neck2, c) == 0.0)
	neck2.throatBulgeAmount = 1.0
	x.push_px = 0.0
	ThroatRings.tip = c["top"] - 0.05
	_check("above the collar nothing", Hooks.value(&"Her.pushBack", her, 0.0) == 0.0 and x.wall() == 0.0)
	# breaking: off by default; on, a worn out collar snaps, rides free, and the button repairs it
	_check("collar can break: off by default", not x.get_setting("breaks") and not is_finite(c["max_durability"]))
	x.set_setting("breaks", true)
	_check("collar can break on: the collar wears down", ThroatRings.collar_breaks and is_finite(c["max_durability"]))
	c["snapped"] = true
	ThroatRings.tip = c["top"] + 0.05
	_check("a snapped collar holds nothing and rides along", Hooks.value(&"Her.pushBack", her, 0.0) == 0.0
		and at.call(mid) == 30.0 and x.wall() == 0.0 and x.rides_free())
	ThroatRings.repair()
	var st: float = c["stretch"]
	ThroatRings._tick_done = -1
	ThroatRings.tick(her)
	var once: float = c["stretch"]
	ThroatRings.tick(her)
	_check("the rings are worked out once per game tick", c["stretch"] == once and once != st or c["stretch"] == once)
	_check("repaired: it holds again", not c["snapped"] and not x.rides_free())
	x.set_setting("breaks", false)
	_check("collar can break off: never breaks again", not ThroatRings.collar_breaks and not is_finite(c["max_durability"]))
	x.set_setting("on", false)
	_check("collar holds off: nothing left, the picture as it was", not not _vp_owned("chokercollarresistance").is_empty()
		and her.collarContainer.collar.scaleX == 1.0)
	ThroatRings.set_stiffness(0.6)
	# the neck follows his size
	var tb = Extensions.get_extension("throatcumbulge")
	tb.set_setting("follow_size", true)
	g.him.loadPenisScales(1.0, 1.2)
	_check("neck follows his size: the bulge limit grows with his width",
		is_equal_approx(Hooks.value(&"Neck.bulgeCap", her.head.neck, 35.0), 35.0 * g.him.getPenisWidthWithTwitch()))
	tb.set_setting("follow_size", false)
	g.him.loadPenisScales(1.0, 1.0)
	_check("neck follows his size off: the game's limit", not Hooks.has_value(&"Neck.bulgeCap"))
	ThroatRings.reset_stretch()
	cc.select(was)


## The value points `owner` has modifiers on (upstream's Hooks.value).
func _vp_owned(owner: String) -> Array:
	return Hooks._modifiers.values().filter(func(m): return m.owner == owner).map(func(m): return m.name)


func _vp_ids(owner: String) -> Array:
	return Hooks._modifiers.values().filter(func(m): return m.owner == owner).map(func(m): return m.id)


## The ring model works a game tick out once; these checks run several in one tick.
func _ring_tick(her) -> void:
	ThroatRings._tick_done = -1
	ThroatRings.tick(her)


var _asked_from := 0
var _resist0 := []


var _asked := {}


func _test_value_points_asked() -> void:
	var ticks := Flash.tick_count - _asked_from
	_check("the game asks its value points every tick", _asked.get(&"Neck.throatBulge", 0) > 3 and _asked.get(&"Neck.bulgeCap", 0) > 3
		and _asked.get(&"Her.pushBack", 0) > 3, str(_asked))
	_check("throat loosens: the neck is drawn once per tick", _asked.get(&"Neck.throatBulge", 0) <= ticks + 1, "%s in %d ticks" % [_asked, ticks])
	_check("throat loosens: her throat resistance setting is never changed", _resist0 == [g.throatResistance, g.her.resistance["boundary"]])
	Extensions.get_extension("throatresiststretch").set_setting("on", false)
	for id in _vp_ids("derrdev_checks"):
		Hooks.remove_modifier(id)
	_check("value points: all of ours off again", _vp_owned("derrdev_checks").is_empty() and not Hooks.has_value(&"Neck.throatBulge")
		and not Hooks.has_value(&"Her.resistance"))


## Runs `fn` with a counting veto on hook `name`; returns how many times the veto was asked.
func _vetoed(name: StringName, fn: Callable) -> int:
	var n := [0]
	var veto := func(c): n[0] += 1; c.cancel()
	Hooks.add_before(name, veto, "derrdev_checks")
	fn.call()
	Hooks.remove(name, veto)
	return n[0]


func _test_body_end() -> void:
	var n: Neck = g.her.head.neck
	_check("the neck keeps its rendered outline", n.renderedPoints.size() == n.neckPoints.size())
	_check("overlay drawn while Developer mode is on", DevBodyOverlay.instance._canvas.visible)
	SDTMenu.set_dev_mode(false)
	DevBodyOverlay.instance._process(0.0)
	_check("overlay hidden when Developer mode is off", not DevBodyOverlay.instance._canvas.visible)
	DevBodyOverlay.clear()
	_check("Hide all layers", not DevBodyOverlay.any_on())


func _press(pos: Vector2) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = pos
	return e


func _test_hover() -> void:
	var old := FlashSprite.new()
	Flash._mouse_over = old
	old.free()
	Flash._update_mouse_over()
	_check("freed hover cache recovers", is_instance_valid(Flash._mouse_over) or Flash._mouse_over == null)


func _test_tan_and_sizes() -> void:
	for style in 5:
		g.her.tan.setTan(style)
		g.her.tan.setTanAlpha(0.5)
		for size in [0.0, 30.0, 100.0, 50.0]:
			g.characterControl.breastSize = size
			g.characterControl.setBreasts()
			_check("tan %d survives size %d" % [style, int(size)], is_instance_valid(g.her.torso.midLayer.chest))
			_check("size texture is ready", _textures_ready(g.her.torso.midLayer.chest))


## derrdev tan fix: the Full style recolours her chest skin (no second layer); None leaves it plain.
func _test_tan_fill() -> void:
	var tan = g.her.tan
	tan.setTan(1)
	tan.setTanAlpha(0.5)
	var chest = g.her.torso.midLayer.chest
	_check("tan Full: chest skin carries the tan strength", _skin_tan(chest) > 0.0)
	_check("tan Full: chest overlay layer hidden", not chest.tan.visible if chest.get("tan") != null else true)
	tan.setTan(0)
	_check("tan None: chest skin plain", _skin_tan(chest) == 0.0)


func _skin_tan(owner) -> float:
	for child in owner._children:
		if child is FlashShape and child.material is ShaderMaterial:
			var v = child.material.get_shader_parameter("skin_tan_strength")
			if v != null and float(v) > 0.0:
				return float(v)
	return 0.0


func _textures_ready(root: FlashDisplayObject) -> bool:
	if root is FlashShape:
		return not root._entry.has("img") or (root._texture != null and root._draw_entry == root._entry)
	if root is FlashSprite:
		for child in root._children:
			if not _textures_ready(child):
				return false
	return true
