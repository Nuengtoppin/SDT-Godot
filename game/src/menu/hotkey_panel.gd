class_name HotkeyPanel
extends CanvasLayer
## Port addition: the hotkey editor of the new menu (Settings › Hotkeys › Edit hotkeys…), a panel on the menu's side
## like the dialogue editor. Groups on the left (all keys, changed ones, clashes, the game, each extension with
## keys), the actions of the picked group on the right with their key. Click a key, press the new one (Shift, Ctrl or
## Alt with it if wanted); Esc cancels, Delete leaves the action without a key. A key more than one action uses is
## red, with the others named under the action. Changes are saved at once (Hotkeys, port.cfg [hotkeys]); Undo takes
## them back. The game's keys do nothing while the panel is open.

const MAX_WIDTH := 600.0   # stage units
const GROUPS_W := 150.0
const KEY_W := 92.0
const MAX_UNDO := 50
const ALL := "*all"
const CHANGED := "*changed"
const CLASHES := "*clashes"

static var instance: HotkeyPanel = null

var is_open := false
var group := ALL          # ALL / CHANGED / CLASHES / an owner (Hotkeys.GAME or an extension id)
var query := ""
var waiting := ""          # the action whose key button waits for a key
var _undo: Array = []      # {action id: binding} before each change
var _root: Control
var _dock: PanelContainer
var _search: LineEdit
var _undo_btn: Button
var _hint: Label
var _groups: VBoxContainer
var _rows: VBoxContainer
var _scroll: ScrollContainer
var _version := -1         # Hotkeys.version the lists were built for


static func open_editor() -> void:
	if instance == null:
		instance = HotkeyPanel.new()
		instance.name = "HotkeyPanel"
		Flash.add_child(instance)
	instance.open()


func _ready() -> void:
	layer = 55


func _exit_tree() -> void:
	_stop_waiting()   # (no Callable into the panel left in Hotkeys)
	if instance == self:
		instance = null


func open() -> void:
	if is_open:
		return
	if _root == null:
		_build()
	is_open = true
	_root.visible = true
	_undo.clear()
	waiting = ""
	g.controlLocked = true
	g.inTextField = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_layout()
	_show()


func close() -> void:
	if not is_open:
		return
	_stop_waiting()
	is_open = false
	_root.visible = false
	Presentation.reserve(0)
	g.controlLocked = false
	g.inTextField = false
	if not g.showMouse and g.gameRunning:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


## Flash input skips the mouse over the panel.
func blocks_mouse() -> bool:
	return is_open and _dock.get_global_rect().has_point(_root.get_global_mouse_position())


# ---------------------------------------------------------------- actions

## The owners with actions, in registration order (the game first).
func _owners() -> Array:
	var out: Array = [Hotkeys.GAME]
	for a in Hotkeys.actions:
		if not out.has(a["owner"]):
			out.append(a["owner"])
	return out


static func owner_title(o: String) -> String:
	if o == Hotkeys.GAME:
		return "Game"
	var ext: SDTExtension = Extensions.by_id.get(o)
	return ext.title if ext != null and ext.title != "" else o


static func label_of(a: Dictionary) -> String:
	var l: String = a["label"]
	return l.substr(0, 1).to_upper() + l.substr(1)


## "Mute (Game)" / "Aim with the mouse (Aim Penis)".
static func action_name(a: Dictionary) -> String:
	return "%s (%s)" % [label_of(a), owner_title(a["owner"])]


func _changed(a: Dictionary) -> bool:
	return Hotkeys.binding(a["id"]) != int(a["default"])


func _in_group(a: Dictionary, grp: String) -> bool:
	match grp:
		ALL:
			return true
		CHANGED:
			return _changed(a)
		CLASHES:
			return not Hotkeys.clashes(a["id"]).is_empty()
	return a["owner"] == grp


func _matches(a: Dictionary) -> bool:
	if query == "":
		return true
	var q := query.to_lower()
	return label_of(a).to_lower().contains(q) or owner_title(a["owner"]).to_lower().contains(q) \
		or Hotkeys.key_name(Hotkeys.binding(a["id"])).to_lower() == q


## The actions shown: the group's (all groups while searching), in registration order, the game's first.
func shown_actions() -> Array:
	var out: Array = []
	for o in _owners():
		for a in Hotkeys.actions:
			if a["owner"] == o and (query != "" or _in_group(a, group)) and _matches(a):
				out.append(a)
	return out


# ---------------------------------------------------------------- changing keys

func _snapshot() -> void:
	var s := {}
	for a in Hotkeys.actions:
		s[a["id"]] = Hotkeys.binding(a["id"])
	_undo.append(s)
	if _undo.size() > MAX_UNDO:
		_undo.pop_front()


func undo() -> void:
	if _undo.is_empty():
		return
	_stop_waiting()
	var s: Dictionary = _undo.pop_back()
	for id in s:
		Hotkeys.set_binding(id, s[id])
	_show()


func set_key(id: String, b: int) -> void:
	if Hotkeys.binding(id) == b:
		return
	_snapshot()
	Hotkeys.set_binding(id, b)
	_show()


func reset_key(id: String) -> void:
	var a: Dictionary = Hotkeys.by_id.get(id, {})
	if not a.is_empty():
		set_key(id, int(a["default"]))


## Every shown action (the group's, or the search's) back to its default key.
func reset_shown() -> void:
	var ids: Array = shown_actions().filter(func(a): return _changed(a)).map(func(a): return a["id"])
	if ids.is_empty():
		return
	_stop_waiting()
	_snapshot()
	for id in ids:
		Hotkeys.reset(id)
	_show()


func _key_clicked(id: String) -> void:
	if waiting == id:
		_stop_waiting()
		_show()
		return
	_stop_waiting()
	waiting = id
	_search.release_focus()
	Hotkeys.begin_capture(func(b: int):
		waiting = ""
		set_key(id, b)
		_show())
	_show()


func _stop_waiting() -> void:
	if waiting != "":
		waiting = ""
		Hotkeys.cancel_capture()


# ---------------------------------------------------------------- build

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = MenuTheme.get_theme()
	add_child(_root)
	_dock = PanelContainer.new()
	_dock.add_theme_stylebox_override("panel", MenuTheme.box(MenuTheme.PANEL, Color(0, 0, 0, 0), 0, 0, 0))
	_dock.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_dock)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	_dock.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 5)
	v.add_child(_margin(head, 7, 6, 7, 6))
	var title := Label.new()
	title.text = "Hotkeys"
	title.add_theme_font_size_override("font_size", MenuTheme.TITLE)
	head.add_child(title)
	_search = LineEdit.new()
	_search.placeholder_text = "Search actions, extensions or a key"
	_search.clear_button_enabled = true
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_changed.connect(func(t):
		query = t.strip_edges()
		_show())
	head.add_child(_search)
	_undo_btn = _button("Undo", "Takes back the last change (Ctrl+Z).", undo)
	head.add_child(_undo_btn)
	head.add_child(_button("Reset shown", "The shown actions back to their default keys.", reset_shown))
	var x := _button("×", "Close (Esc)", close)
	x.custom_minimum_size = Vector2(18, 18)
	head.add_child(x)
	v.add_child(_hline())
	_hint = Label.new()
	_hint.add_theme_color_override("font_color", MenuTheme.MUTED)
	_hint.add_theme_font_size_override("font_size", MenuTheme.SMALL + 1)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_margin(_hint, 8, 4, 8, 4))
	v.add_child(_hline())

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 0)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)
	var gscroll := ScrollContainer.new()
	gscroll.custom_minimum_size.x = GROUPS_W
	gscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_groups = VBoxContainer.new()
	_groups.add_theme_constant_override("separation", 1)
	_groups.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gscroll.add_child(_margin(_groups, 4, 4, 4, 6, true))
	body.add_child(gscroll)
	body.add_child(_vline())
	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 2)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_margin(_rows, 8, 6, 10, 8, true))
	body.add_child(_scroll)
	get_viewport().size_changed.connect(_layout)


func _button(text: String, tip: String, fn = null) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	if fn is Callable:
		b.pressed.connect(fn)
	return b


func _margin(c: Control, l: int, t: int, r: int, b: int, expand := false) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", l)
	m.add_theme_constant_override("margin_top", t)
	m.add_theme_constant_override("margin_right", r)
	m.add_theme_constant_override("margin_bottom", b)
	if expand:
		m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.add_child(c)
	return m


func _hline() -> ColorRect:
	var l := ColorRect.new()
	l.color = MenuTheme.LINE
	l.custom_minimum_size.y = 1
	return l


func _vline() -> ColorRect:
	var l := ColorRect.new()
	l.color = MenuTheme.LINE
	l.custom_minimum_size.x = 1
	return l


func _layout() -> void:
	if _root == null:
		return
	var vw: float = _root.get_viewport_rect().size.x
	var w := clampf(vw - 160.0, 420.0, MAX_WIDTH)
	var left := SDTMenu.on_left()
	_dock.anchor_top = 0
	_dock.anchor_bottom = 1
	_dock.offset_top = 0
	_dock.offset_bottom = 0
	_dock.anchor_left = 0 if left else 1
	_dock.anchor_right = 0 if left else 1
	_dock.offset_left = 0.0 if left else -w
	_dock.offset_right = w if left else 0.0
	if is_open:
		Presentation.reserve(w if not left else -w)   # the game beside it


# ---------------------------------------------------------------- lists

func _show() -> void:
	if _root == null or not is_open:
		return
	_version = Hotkeys.version
	if group != ALL and group != CHANGED and group != CLASHES and not _owners().has(group):
		group = ALL
	_undo_btn.disabled = _undo.is_empty()
	if waiting != "":
		_hint.text = "Press the new key for “%s” (with Shift, Ctrl or Alt if you like). Esc: cancel · Delete: no key." \
			% label_of(Hotkeys.by_id.get(waiting, {"label": ""}))
		_hint.add_theme_color_override("font_color", MenuTheme.ACCENT)
	else:
		_hint.text = "Click a key, then press the new one. A key in red is used by more than one action: all of them run. Changes are saved at once."
		_hint.add_theme_color_override("font_color", MenuTheme.MUTED)
	_show_groups()
	_show_rows()


func _show_groups() -> void:
	for c in _groups.get_children():
		_groups.remove_child(c)
		c.queue_free()
	var bg := ButtonGroup.new()
	var n_changed := Hotkeys.actions.filter(func(a): return _changed(a)).size()
	var n_clash := Hotkeys.actions.filter(func(a): return not Hotkeys.clashes(a["id"]).is_empty()).size()
	_group_button(bg, ALL, "All keys", Hotkeys.actions.size(), MenuTheme.TEXT)
	_group_button(bg, CHANGED, "Changed", n_changed, MenuTheme.TEXT)
	_group_button(bg, CLASHES, "Shared keys", n_clash, MenuTheme.WARN if n_clash > 0 else MenuTheme.TEXT)
	var sep := _hline()
	_groups.add_child(_margin(sep, 2, 4, 2, 4))
	for o in _owners():
		var n := Hotkeys.actions.filter(func(a): return a["owner"] == o).size()
		if n > 0:
			_group_button(bg, o, owner_title(o), n, MenuTheme.TEXT if o == Hotkeys.GAME else MenuTheme.PLUGIN)


func _group_button(bg: ButtonGroup, id: String, text: String, n: int, c: Color) -> void:
	var b := Button.new()
	b.toggle_mode = true
	b.button_group = bg
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = true
	b.text = "%s  %d" % [text, n]
	b.tooltip_text = text
	b.button_pressed = id == group and query == ""
	b.add_theme_stylebox_override("normal", MenuTheme.box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 4, 6, 2))
	b.add_theme_color_override("font_color", c)
	b.add_theme_color_override("font_hover_color", c.lightened(0.2))
	b.set_meta("group", id)
	b.pressed.connect(func():
		group = id
		if query != "":
			_search.text = ""   # (text_changed is not emitted for a set text)
			query = ""
		_show())
	_groups.add_child(b)


func _show_rows() -> void:
	for c in _rows.get_children():
		_rows.remove_child(c)
		c.queue_free()
	var list := shown_actions()
	if list.is_empty():
		var l := Label.new()
		l.text = "No keys match." if query != "" else ("No changed keys." if group == CHANGED
			else ("No key is shared." if group == CLASHES else "No keys."))
		l.add_theme_color_override("font_color", MenuTheme.MUTED)
		_rows.add_child(l)
		return
	var last := ""
	for a in list:
		if a["owner"] != last and (group == ALL or group == CHANGED or group == CLASHES or query != ""):
			_rows.add_child(_heading(a["owner"], last != ""))
		last = a["owner"]
		_rows.add_child(_row(a))


func _heading(o: String, gap: bool) -> Control:
	var l := Label.new()
	l.text = owner_title(o).to_upper()
	l.add_theme_font_size_override("font_size", MenuTheme.HEADING)
	l.add_theme_color_override("font_color", MenuTheme.MUTED if o == Hotkeys.GAME else MenuTheme.PLUGIN)
	return _margin(l, 0, 8 if gap else 0, 0, 2)


func _row(a: Dictionary) -> Control:
	var id: String = a["id"]
	var bind := Hotkeys.binding(id)
	var others: Array = Hotkeys.clashes(id)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", MenuTheme.box(MenuTheme.CARD, Color(0, 0, 0, 0), 4, 8, 3))
	p.set_meta("action", id)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	p.add_child(h)
	var txt := VBoxContainer.new()
	txt.add_theme_constant_override("separation", 0)
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(txt)
	var l := Label.new()
	l.text = label_of(a)
	l.clip_text = true
	l.tooltip_text = label_of(a)
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	txt.add_child(l)
	if not others.is_empty():
		var c := Label.new()
		c.text = "Also on this key: " + ", ".join(others.map(func(o): return action_name(o)))
		c.add_theme_color_override("font_color", MenuTheme.WARN)
		c.add_theme_font_size_override("font_size", MenuTheme.SMALL)
		c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		txt.add_child(c)
	elif bind != int(a["default"]):
		var c := Label.new()
		c.text = "Default: " + (Hotkeys.key_name(a["default"]) if int(a["default"]) != 0 else "no key")
		c.add_theme_color_override("font_color", MenuTheme.MUTED)
		c.add_theme_font_size_override("font_size", MenuTheme.SMALL)
		txt.add_child(c)
	var r := _button("↺", "Back to the default key (%s)" % (Hotkeys.key_name(a["default"]) if int(a["default"]) != 0
		else "no key"), func(): reset_key(id))
	r.custom_minimum_size = Vector2(18, 18)
	r.modulate.a = 1.0 if bind != int(a["default"]) else 0.0   # (kept in the row: the key buttons stay in line)
	r.disabled = bind == int(a["default"])
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(r)
	var b := _button("", "Click, then press the new key.", func(): _key_clicked(id))
	b.custom_minimum_size = Vector2(KEY_W, 0)
	b.clip_text = true
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.set_meta("key", true)
	if waiting == id:
		b.text = "Press a key…"
		b.add_theme_stylebox_override("normal", MenuTheme.box(MenuTheme.FIELD, MenuTheme.ACCENT, 4, 6, 2))
		b.add_theme_color_override("font_color", MenuTheme.ACCENT)
		b.tooltip_text = "Esc: cancel · Delete: no key · click: cancel"
	else:
		b.text = Hotkeys.key_name(bind) if bind != 0 else "—"
		if not others.is_empty():
			b.add_theme_color_override("font_color", MenuTheme.WARN)
			b.add_theme_color_override("font_hover_color", MenuTheme.WARN)
			b.add_theme_stylebox_override("normal", MenuTheme.box(MenuTheme.FIELD, MenuTheme.WARN.darkened(0.3), 4, 6, 2))
	h.add_child(b)
	return p


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if not is_open or not (event is InputEventKey) or not event.pressed or Hotkeys.capturing():
		return
	if event.keycode == KEY_ESCAPE:
		if _search.has_focus() and _search.text != "":
			_search.text = ""
			query = ""
			_show()
		else:
			close()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_Z and event.ctrl_pressed and not _search.has_focus():
		undo()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not is_open:
		return
	if SDTMenu.instance != null and SDTMenu.instance.is_open:   # the menu opened (its tab): one panel at a time
		close()
		return
	if waiting != "" and not Hotkeys.capturing():   # Esc ended the wait
		waiting = ""
		_show()
	elif Hotkeys.version != _version:   # an extension switched on or off
		_show()
