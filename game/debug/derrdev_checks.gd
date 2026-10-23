extends RefCounted
## Checks for the derrdev workbench (Debug Lab) and the fixes it relied on (hover, sizes with tan, arm modes,
## tears). Uses the existing game loop and a disposable save.
## run_debug.bat -- --save-dir=<temporary folder> --mods-dir=<empty folder> --driver=res://debug/derrdev_checks.gd

var _phase := 0
var _t0 := 0
var _passed := 0
var _failed := 0
var _menu: SDTMenu


func _check(label: String, ok: bool) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
	print("DERRDEV CHECK %s %s" % ["ok" if ok else "FAIL", label])


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
			_check("Lab off by default", not SDTMenu.debug_lab_enabled() and not _menu._debug_lab.visible)
			SDTMenu.set_debug_lab_enabled(true)
			_check("Lab builds and is visible", is_instance_valid(_menu._debug_lab) and _menu._debug_lab.visible)
			_check("Lab has its tool area", _menu._debug_lab.tools_root.get_child_count() == 1)
			PortSettings.set_value("debug_lab", "side", "Right")
			_menu._layout_debug_lab()
			_check("Lab docks on the right", _menu._debug_lab.position.x >= _menu._root.size.x * 0.5)
			PortSettings.set_value("debug_lab", "side", "Left")
			_menu._layout_debug_lab()
			_check("Lab docks on the left", _menu._debug_lab.position.x == 0.0)
			PortSettings.set_value("debug_lab", "side", "Right")
			_menu.close_menu()
			SDTMenu.set_debug_lab_enabled(false)
			_check("Lab hidden when switched off", not _menu._debug_lab.visible)
			_test_hover()
			_test_tan_and_sizes()
			for i in Her.armPositions.size():
				g.her.setRightArmPosition(i)
				g.her.setLeftArmPosition(i)
			g.her.setRightArmPosition(4)
			g.her.setLeftArmPosition(4)
			_check("arm modes including Loose survive", g.her.currentRightArmPosition == 4)
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
			_check("base tear limit is respected", g.her.tears.tearList.size() + g.her.tears.tearSpotList.size() <= g.her.tears.maxTears)
			g.her.clearMascara()
			g.her.tears.clearTearSpots()
			_check("base tears clear", g.her.tears.tearList.is_empty() and g.her.tears.tearSpotList.is_empty())
			print("DERRDEV CHECKS: %d passed, %d failed" % [_passed, _failed])
			_phase = 99
			Flash.get_tree().quit(1 if _failed else 0)


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


func _textures_ready(root: FlashDisplayObject) -> bool:
	if root is FlashShape:
		return not root._entry.has("img") or (root._texture != null and root._draw_entry == root._entry)
	if root is FlashSprite:
		for child in root._children:
			if not _textures_ready(child):
				return false
	return true
