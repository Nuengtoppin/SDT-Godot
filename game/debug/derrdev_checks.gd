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
	_check("Mouth tab: All off/on and 4 rows", dev._rows.size() == 5, str(dev._rows.size()))
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
	ThroatRings.set_collar_material("Metal")
	cc.select(1)
	_ring_tick(her)
	_check("back to the first collar: its edges and material come back", ThroatRings.collar_top_adjust == 0.02
		and ThroatRings.collar_bottom_adjust == -0.03 and ThroatRings.collar_material == "Leather")
	cc.select(3)
	_ring_tick(her)
	_check("material kept for each collar", ThroatRings.collar_material == "Metal"
		and PortSettings.get_value(ThroatRings.SECTION, "material_Gem_Choker") == "Metal")
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
	ThroatRings.set_collar_material("Band")
	_check("material sets the collar ring", c["tight"] == 0.35 and c["max_durability"] == 60.0 and c["durability"] == 60.0)
	ThroatRings.set_collar_material("Leather")
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


## Value points: the game's number when nothing is added; handlers by phase, then priority; owners come off.
func _test_value_points() -> void:
	_check("value points: none set by default", not ValuePoints.has(&"Neck.throatBulge") and not ValuePoints.has(&"Her.resistance"))
	var order := []
	var clamp := func(v, _b, _o): order.append("clamp"); return minf(v, 3.0)
	var mood2 := func(v, _b, _o): order.append("mood2"); return v * 2.0
	var mood1 := func(v, _b, _o): order.append("mood1"); return v + 1.0
	ValuePoints.add(&"test.v", clamp, "t1", ValuePoints.CLAMP)
	ValuePoints.add(&"test.v", mood2, "t2", ValuePoints.MOOD, 5)
	ValuePoints.add(&"test.v", mood1, "t1", ValuePoints.MOOD, 0)
	var v := ValuePoints.value(&"test.v", 1.0)
	_check("value points: by phase, then priority", order == ["mood1", "mood2", "clamp"] and v == 3.0, "%s %s" % [order, v])
	var inner := [false]
	ValuePoints.add(&"test.v", func(x, _b, _o): inner[0] = ValuePoints.has(&"test.v"); return x, "t3", ValuePoints.FINAL)
	ValuePoints.value(&"test.v", 1.0)
	_check("value points: not re-entered from a handler", not inner[0] and ValuePoints.last[&"test.v"] == [1.0, 3.0])
	ValuePoints.remove_owner("t1")
	ValuePoints.remove_owner("t3")
	_check("value points: an owner's handlers come off", ValuePoints.value(&"test.v", 1.0) == 2.0)
	ValuePoints.remove(&"test.v", mood2)
	_check("value points: the last handler off, the point is gone", not ValuePoints.has(&"test.v"))
	_test_entrance_ring()
	_test_collar_ring()
	# the game asks its points every tick (checked after a few ticks), with the entrance ring acting: one neck render
	# per tick (the mod drew the neck a second time)
	Extensions.get_extension("throatresiststretch").set_setting("on", true)
	_asked_from = Flash.tick_count
	_resist0 = [g.throatResistance, g.her.resistance["boundary"]]
	for p in [&"Neck.throatBulge", &"Neck.bulgeCap", &"Her.pushBack"]:
		ValuePoints.add(p, func(x, _b, _o): _asked[p] = _asked.get(p, 0) + 1; return x, "derrdev_checks")


## The throat entrance ring acting (throatresiststretch "Throat loosens"): it lowers the entrance's share of the
## resistance and keeps the neck drawn stretched, through value points; off, nothing is left.
func _test_entrance_ring() -> void:
	var x = Extensions.get_extension("throatresiststretch")
	var her = g.her
	var e: Dictionary = ThroatRings.entrance
	x.set_setting("on", true)
	var owners: Array = ValuePoints.registered().filter(func(r): return r[2] == "throatresiststretch").map(func(r): return r[0])
	_check("throat loosens on: the entrance ring acts on resistance and neck depth", owners.has(&"Her.resistance") and owners.has(&"Neck.depth"))
	e["stretch"] = 0.5
	ThroatRings.tip = 0.3
	var upper: float = her.resistance["upper"]
	_check("a stretched entrance lowers its share of the resistance",
		is_equal_approx(ValuePoints.value(&"Her.resistance", upper + 0.05, her), upper + 0.025))
	ThroatRings.tip = 0.5
	_check("past the entrance the resistance is the game's", ValuePoints.value(&"Her.resistance", 0.0, her) == 0.0)
	_check("a stretched entrance keeps the neck drawn as deep as the stretch", ValuePoints.value(&"Neck.depth", 0.1, her.head.neck) == 0.5
		and ValuePoints.value(&"Neck.depth", 0.7, her.head.neck) == 0.7)
	x.set_setting("recover", 0.5)
	ThroatRings.tip = 0.0
	ThroatRings._step(e, 1.0, her.head.neck)
	_check("the throat tightens back at the set speed", is_equal_approx(e["stretch"], 0.5 - ThroatRings.RECOVER_RATE * 0.5 * (1.0 - 0.5 * e["stiff"])))
	x.set_setting("recover", 0.25)
	x.set_setting("on", false)
	_check("throat loosens off: nothing left", not ValuePoints.registered().any(func(r): return r[2] == "throatresiststretch")
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
		and not ValuePoints.registered().any(func(r): return r[2] == "chokercollarresistance"))
	cc.select(1)
	ThroatRings._tick_done = -1
	_ring_tick(her)
	x.set_setting("on", true)
	var pts: Array = ValuePoints.registered().filter(func(r): return r[2] == "chokercollarresistance").map(func(r): return r[0])
	_check("collar holds on: push back, resistance, the band on her neck", pts.has(&"Her.pushBack") and pts.has(&"Her.resistance")
		and pts.has(&"Neck.pointBulge"))
	ThroatRings.reset_stretch()
	ThroatRings.repair()
	ThroatRings.tip = c["top"] + 0.05
	c["hold"] = c["tight"]
	_check("past the collar's top her head is pushed back by what it holds",
		is_equal_approx(ValuePoints.value(&"Her.pushBack", 0.0, her), 0.05 * 400.0 * 0.0015 * c["tight"]))
	_check("past the collar's top pushing in is harder", is_equal_approx(ValuePoints.value(&"Her.resistance", 0.0, her), 0.15 * c["tight"]))
	var neck = her.head.neck
	var mid: float = (c["top"] + c["bottom"]) / 2.0
	var at := func(f: float) -> float:
		neck.bulgePointDepth = f
		return ValuePoints.value(&"Neck.pointBulge", 30.0, neck)
	_check("between the collar's edges her neck pushes out only a little", at.call(mid) == 2.0)
	_check("well above and below the collar it is free", at.call(c["top"] - 0.1) == 30.0 and at.call(c["bottom"] + 0.1) == 30.0)
	var step: float = at.call(c["top"] - 0.02)
	_check("a soft step at the collar's edge", step > 2.0 and step < 30.0, str(step))
	c["stretch"] = 1.0
	_check("fully stretched: the band holds as wide as the widened picture", is_equal_approx(at.call(mid), 2.0 + 70.0 * 0.25))
	x.set_setting("widen", false)
	_check("picture not widening: the band stays tight", at.call(mid) == 2.0)
	x.set_setting("widen", true)
	# drawn: deep, a big bulge - the outline under the collar stays in, above it bulges
	c["stretch"] = 0.0
	var was_bulge: float = neck.throatBulgeAmount
	neck.throatBulgeAmount = 1.5
	neck.render(0.95)
	var pts_r: Array = neck.renderedPoints
	var n: int = neck.frontEndPoint
	var i_mid := int(round(mid * n))
	var i_above := int(floor((c["top"] - 0.08) * n))
	var out_mid: float = (pts_r[i_mid] - neck.neckPoints[i_mid]).x
	var out_above: float = (pts_r[i_above] - neck.neckPoints[i_above]).x
	_check("drawn: under the collar the neck stays in, above it bulges", out_mid <= 2.001 and out_above > 5.0,
		"%s %s" % [out_mid, out_above])
	neck.throatBulgeAmount = was_bulge
	c["stretch"] = 0.5
	x._tick()
	_check("the collar's picture widens with the stretch", is_equal_approx(her.collarContainer.collar.scaleX, 1.0 + 0.5 * 0.25))
	ThroatRings.tip = c["top"] - 0.05
	_check("above the collar nothing", ValuePoints.value(&"Her.pushBack", 0.0, her) == 0.0)
	c["snapped"] = true
	ThroatRings.tip = c["top"] + 0.05
	_check("a snapped collar holds nothing", ValuePoints.value(&"Her.pushBack", 0.0, her) == 0.0 and at.call(mid) == 30.0)
	ThroatRings.repair()
	var st: float = c["stretch"]
	ThroatRings._tick_done = -1
	ThroatRings.tick(her)
	var once: float = c["stretch"]
	ThroatRings.tick(her)
	_check("the rings are worked out once per game tick", c["stretch"] == once and once != st or c["stretch"] == once)
	x.set_setting("on", false)
	_check("collar holds off: nothing left, the picture as it was", not ValuePoints.registered().any(func(r): return r[2] == "chokercollarresistance")
		and her.collarContainer.collar.scaleX == 1.0)
	ThroatRings.set_collar_tight(0.7)
	_check("collar tightness kept for each collar", PortSettings.get_value(ThroatRings.SECTION, "tight_Leather") == 0.7)
	ThroatRings.set_collar_material("Leather")
	# the neck follows his size
	var tb = Extensions.get_extension("throatcumbulge")
	tb.set_setting("follow_size", true)
	g.him.loadPenisScales(1.0, 1.2)
	_check("neck follows his size: the bulge limit grows with his width",
		is_equal_approx(ValuePoints.value(&"Neck.bulgeCap", 35.0, her.head.neck), 35.0 * g.him.getPenisWidthWithTwitch()))
	tb.set_setting("follow_size", false)
	g.him.loadPenisScales(1.0, 1.0)
	_check("neck follows his size off: the game's limit", not ValuePoints.has(&"Neck.bulgeCap"))
	ThroatRings.reset_stretch()
	cc.select(was)


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
	ValuePoints.remove_owner("derrdev_checks")
	_check("value points: all off again", ValuePoints.registered().is_empty())


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
