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
	ThroatRings.tick(her)
	_check("no collar: no collar ring", not ThroatRings.collar["on"] and ThroatRings.entrance["on"])
	_check("entrance ring on the game's resistance zone", is_equal_approx(ThroatRings.entrance["top"], 75.0 / 400.0)
		and is_equal_approx(ThroatRings.entrance["bottom"], 150.0 / 400.0))
	cc.select(1)
	ThroatRings.tick(her)
	var c: Dictionary = ThroatRings.collar
	var b: Rect2 = her.collarContainer.collar.getBounds(n)
	_check("leather collar: its edges as seen in the game by default", ThroatRings.collar_name == "Leather"
		and ThroatRings.collar_top_adjust == 0.005 and ThroatRings.collar_bottom_adjust == -0.05)
	_check("leather collar: ring at the collar's picture", c["on"]
		and is_equal_approx(c["top"], ThroatRings.depth_at_y(n, b.position.y) + ThroatRings.collar_top_adjust)
		and c["bottom"] > c["top"] and c["top"] > 0.3 and c["bottom"] < 0.95, "%s %s" % [c["top"], c["bottom"]])
	ThroatRings.adjust_collar(0.02, -0.03)
	var top: float = c["top"]
	ThroatRings.tick(her)
	_check("collar edges move by hand", is_equal_approx(c["top"], top + 0.015))
	_check("collar edges kept in port.cfg for this collar",
		PortSettings.get_value(ThroatRings.SECTION, "edges_Leather") == [0.02, -0.03])
	cc.select(3)
	ThroatRings.tick(her)
	_check("another collar: its own edges", ThroatRings.collar_name == "Gem Choker" and ThroatRings.collar_top_adjust == 0.0)
	ThroatRings.set_collar_material("Metal")
	cc.select(1)
	ThroatRings.tick(her)
	_check("back to the first collar: its edges and material come back", ThroatRings.collar_top_adjust == 0.02
		and ThroatRings.collar_bottom_adjust == -0.03 and ThroatRings.collar_material == "Leather")
	cc.select(3)
	ThroatRings.tick(her)
	_check("material kept for each collar", ThroatRings.collar_material == "Metal"
		and PortSettings.get_value(ThroatRings.SECTION, "material_Gem_Choker") == "Metal")
	cc.select(2)
	ThroatRings.tick(her)
	var tb: Rect2 = her.collarContainer.collar.getBounds(n)
	_check("tie: only the band counts, not the hanging tie", c["on"] and tb.size.y > ThroatRings.COLLAR_BAND
		and is_equal_approx(c["bottom"], ThroatRings.depth_at_y(n, tb.position.y + ThroatRings.COLLAR_BAND)))
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
	ThroatRings.tick(her)
	_check("the rings change nothing in the game", game == [g.throatResistance, her.pos, n.throatBulgeAmount,
		her.collarContainer.collar.scaleX, n.swallowScale])
	DevBodyOverlay.set_on("throat", "zones", true)
	var d: Dictionary = DevBodyOverlay.throat()
	_check("overlay: two edges per ring", d.get("node") == n and d["zones"].size() == 4)
	cc.select(was)
	ThroatRings.reset_stretch()


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
