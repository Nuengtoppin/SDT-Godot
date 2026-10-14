extends Node2D
## Main scene: puts the Flash stage in the scene tree and starts the game's document class (DT).
## Debug options (after `--` on the command line): --shot=<file.png> [--frames=N] [--click=x,y@frame ...]
## saves a screenshot after N frames and quits; --click simulates a left click at stage coordinates.

var _shot := ""
var _frames := 60
var _clicks: Array = []
var _frame := 0
var _dump := ""
var _picks: Array = []
var _hide: Array = []
var _counter: Label = null


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			_shot = a.substr(7)
		elif a.begins_with("--pick="):
			var pxy := a.substr(7).split(",")
			_picks.append(Vector2(float(pxy[0]), float(pxy[1])))
		elif a.begins_with("--hide="):
			_hide.append(a.substr(7))
		elif a.begins_with("--dump="):
			_dump = a.substr(7)
		elif a.begins_with("--frames="):
			_frames = int(a.substr(9))
		elif a.begins_with("--move="):
			var mp := a.substr(7).split("@")
			var mxy := mp[0].split(",")
			_clicks.append([int(mp[1]) if mp.size() > 1 else 10, Vector2(float(mxy[0]), float(mxy[1])), true])
		elif a.begins_with("--click="):
			var parts := a.substr(8).split("@")
			var xy := parts[0].split(",")
			_clicks.append([int(parts[1]) if parts.size() > 1 else 10, Vector2(float(xy[0]), float(xy[1]))])
	if "--counter" in OS.get_cmdline_user_args():
		_counter = Label.new()
		_counter.z_index = 100
		_counter.add_theme_font_size_override("font_size", 40)
		add_child(_counter)
	Flash.attach_stage(self)
	Flash.stage.addChild(DT.new())


func _process(_delta: float) -> void:
	if _shot == "" and _clicks.is_empty():
		return
	_frame += 1
	if _counter:
		_counter.text = str(_frame)
		move_child(_counter, get_child_count() - 1)
	if _frame % 60 == 0:
		print("frame %d nodes=%d objects=%d" % [_frame, Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_COUNT)])
	for c in _clicks:
		if c[0] == _frame:
			if c.size() > 2:
				_move(c[1])
			else:
				_click(c[1])
	if _frame == 150 and not _hide.is_empty():
		_hide_matching(Flash.stage)
	if _frame >= 150 and _frame < 156 and not _hide.is_empty():
		await RenderingServer.frame_post_draw
		var im := get_viewport().get_texture().get_image()
		var dt = Flash.stage._children[0]
		print("f%d px=%s dt_vis=%s in_tree=%s" % [_frame, im.get_pixel(im.get_width() / 2, im.get_height() / 2), dt.visible, dt.is_visible_in_tree()])
	if _shot != "" and _frame >= _frames:
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png(_shot)
		for pk in _picks:
			print("PICK ", pk)
			_pick(Flash.stage, pk, "")
		if _dump != "":
			var f := FileAccess.open(_dump, FileAccess.WRITE)
			_dump_obj(f, Flash.stage, 0)
			f.store_line("---- godot tree (depth 4)")
			_dump_godot(f, get_tree().root, 0)
			f.store_line("---- proxies")
			_dump_proxies(f, Flash.stage)
		get_tree().quit()


func _click(p: Vector2) -> void:
	var screen: Vector2 = get_viewport().get_final_transform() * p
	Input.warp_mouse(screen)
	var m := InputEventMouseMotion.new()
	m.position = screen
	m.global_position = screen
	Input.parse_input_event(m)
	await get_tree().physics_frame
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = screen
		e.global_position = screen
		Input.parse_input_event(e)
		await get_tree().physics_frame


## Writes the Flash display list (names, classes, frames, visibility, transforms) for debugging.
func _dump_obj(f: FileAccess, o: FlashDisplayObject, depth: int) -> void:
	var cls := String(o.get_script().get_global_name()) if o.get_script() else o.get_class()
	var line := "%s%s [%s#%d]" % ["  ".repeat(depth), o.flash_name, cls, o._char_id]
	if o is FlashMovieClip:
		line += " f=%d/%d" % [o.currentFrame, o.totalFrames]
		if o.currentLabel != "":
			line += " '%s'" % o.currentLabel
	if not o.visible:
		line += " HIDDEN"
	if o.alpha != 1.0:
		line += " a=%.2f" % o.alpha
	line += " pos=(%.1f,%.1f) sc=(%.2f,%.2f) rot=%.1f" % [o.x, o.y, o.scaleX, o.scaleY, o.rotation_degrees]
	if o.blendMode != "normal":
		line += " blend=" + o.blendMode
	if o.mask != null:
		line += " mask=%s(%s)" % [o.mask.flash_name, o._tree_node().get_class() if not o._tree_node().get_script() else o._tree_node().get_script().get_global_name()]
	if not o._filters.is_empty():
		line += " filters=%d node=%s" % [o._filters.size(), o._tree_node().get_path()]
	var ct: FlashColorTransform = o.colorTransform
	if ct.redMultiplier != 1 or ct.greenMultiplier != 1 or ct.blueMultiplier != 1 or ct.redOffset != 0 or ct.greenOffset != 0 or ct.blueOffset != 0:
		line += " ct=(%.2f,%.2f,%.2f|%d,%d,%d)" % [ct.redMultiplier, ct.greenMultiplier, ct.blueMultiplier, ct.redOffset, ct.greenOffset, ct.blueOffset]
	f.store_line(line)
	if o is FlashSprite:
		for c in o._children:
			_dump_obj(f, c, depth + 1)


func _move(p: Vector2) -> void:
	var screen: Vector2 = get_viewport().get_final_transform() * p
	Input.warp_mouse(screen)
	var m := InputEventMouseMotion.new()
	m.position = screen
	m.global_position = screen
	Input.parse_input_event(m)


## Prints every visible shape covering stage point p (bottom to top), with its display-list path.
func _pick(o: FlashDisplayObject, p: Vector2, path: String) -> void:
	if not o.visible or o.alpha <= 0.0:
		return
	var here := path + "/" + (o.flash_name if o.flash_name != "" else "#%d" % o._char_id)
	if o is FlashShape:
		if o.hitTestPoint(p.x, p.y, true):
			print("  ", here)
	elif o is FlashSprite:
		for c in o._children:
			if c._masking.is_empty():
				_pick(c, p, here)


func _dump_proxies(f: FileAccess, n: Node) -> void:
	if n is FlashProxy:
		var names: Array = []
		for c in n.content_parent().get_children():
			names.append(String(c.name) + ("(%s)" % c.flash_name if c is FlashDisplayObject else ""))
		f.store_line("%s rect=%s vis=%s vp=%s mask=%s content=%s" % [n.get_path(), n._rect, n.is_visible_in_tree(), n._vp.size, n._mask_obj.flash_name if n._mask_obj else "-", names])
	for c in n.get_children():
		_dump_proxies(f, c)


## Hides display objects whose name, class or path index matches a --hide value (debug bisection).
func _hide_matching(o: FlashDisplayObject) -> void:
	var cls := String(o.get_script().get_global_name()) if o.get_script() else ""
	if _hide.has(o.flash_name) or _hide.has(cls) or _hide.has("#%d" % o._char_id):
		o.visible = false
		print("hid ", o.flash_name, " ", cls, " #", o._char_id)
	if o is FlashSprite:
		for c in o._children:
			_hide_matching(c)


func _dump_godot(f: FileAccess, n: Node, depth: int) -> void:
	if depth > 5:
		return
	var extra := ""
	if n is FlashDisplayObject:
		extra = " flash=%s#%d" % [n.flash_name, n._char_id]
	if n is CanvasItem and not n.visible:
		extra += " HIDDEN"
	f.store_line("%s%s [%s]%s" % ["  ".repeat(depth), n.name, n.get_script().get_global_name() if n.get_script() else n.get_class(), extra])
	for c in n.get_children():
		_dump_godot(f, c, depth + 1)
