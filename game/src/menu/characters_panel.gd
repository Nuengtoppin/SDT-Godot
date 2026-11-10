class_name CharactersPanel
extends CanvasLayer
## Port addition: the character manager of the new menu (Her › Character › Manage characters…), a panel on the menu's
## side like the hotkey editor. Every character with its picture, the game's own and the stored ones, in the player's
## order: click one to switch to her, drag one to move it. Her current look is saved as a new character from the top
## row; a stored one can be renamed, given her current look, or deleted. Everything goes through MenuCharacters and
## so through the classic menu's character list, and is saved at once. The game's keys do nothing while it is open.
## A switch hides the game's own characters, all but the first, here, in Her › Character and from C / X.

const MAX_WIDTH := 520.0   # stage units
const THUMB := Vector2(49, 42)

static var instance: CharactersPanel = null

var is_open := false
var query := ""
var renaming = null        # the stored character being renamed
var confirming = null      # the stored character whose Delete was clicked once
var _shown := []           # the list's state when it was built: selected index, number of characters
var _root: Control
var _dock: PanelContainer
var _search: LineEdit
var _name: LineEdit
var _save: Button
var _hide: CheckButton
var _hint: Label
var _missing: VBoxContainer
var _rows: VBoxContainer
var _missing_shown := -1


static func open_editor() -> void:
	if instance == null:
		instance = CharactersPanel.new()
		instance.name = "CharactersPanel"
		Flash.add_child(instance)
	instance.open()


func _ready() -> void:
	layer = 55


func _exit_tree() -> void:
	if instance == self:
		instance = null


func open() -> void:
	if is_open:
		return
	if _root == null:
		_build()
	is_open = true
	_root.visible = true
	renaming = null
	confirming = null
	g.controlLocked = true
	g.inTextField = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_say("")
	_hide.set_pressed_no_signal(MenuCharacters.hiding())
	_layout()
	_show()


func close() -> void:
	if not is_open:
		return
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

func save_new() -> void:
	var n := MenuCharacters.clean_name(_name.text)
	if n == "":
		_say("Give her a name first.", true)
		return
	_unseen(func():
		if MenuCharacters.save_new(n):
			_name.text = ""
			_say("Saved as %s." % n)
		else:
			_say("Some of her mods have no file: enter their paths below, then save again.", true)
		_show())


func update(c: CustomCharacter) -> void:
	confirming = null
	_unseen(func():
		if MenuCharacters.update(c):
			_say("%s now has her current look." % c.charName)
		else:
			_say("Some of her mods have no file: enter their paths below, then update again.", true)
		_show())


## Runs fn with the panel off the screen for a frame: a character's picture is read from the window.
func _unseen(fn: Callable) -> void:
	if DisplayServer.get_name() != "headless":
		_root.visible = false
		await RenderingServer.frame_post_draw
		_root.visible = is_open
	fn.call()


func delete(c: CustomCharacter) -> void:
	if confirming != c:
		confirming = c
		renaming = null
		_say("Click Delete again to delete %s. This can't be undone." % c.charName, true)
		_show()
		return
	confirming = null
	MenuCharacters.delete(c)
	_say("Deleted %s." % c.charName)
	_show()


func rename(c: CustomCharacter, text: String) -> void:
	renaming = null
	var n := MenuCharacters.clean_name(text)
	if n != "" and n != c.charName:
		MenuCharacters.rename(c, n)
		_say("Renamed to %s." % n)
	_show()


func set_hiding(on: bool) -> void:
	MenuCharacters.set_hiding(on)
	_show()


func _start_rename(c: CustomCharacter) -> void:
	renaming = c
	confirming = null
	_show()


func _say(text: String, warn := false) -> void:
	if _hint == null:
		return
	_hint.text = text if text != "" else "Click a character to switch to her, drag one to move it."
	_hint.add_theme_color_override("font_color", MenuTheme.WARN if warn else MenuTheme.MUTED)


# ---------------------------------------------------------------- building

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
	title.text = "Characters"
	title.add_theme_font_size_override("font_size", MenuTheme.TITLE)
	head.add_child(title)
	_search = LineEdit.new()
	_search.placeholder_text = "Search by name"
	_search.clear_button_enabled = true
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_changed.connect(func(t):
		query = t.strip_edges()
		_show())
	head.add_child(_search)
	var x := _button("×", "Close (Esc)", close)
	x.custom_minimum_size = Vector2(18, 18)
	head.add_child(x)
	v.add_child(_hline())

	var form := HBoxContainer.new()
	form.add_theme_constant_override("separation", 5)
	v.add_child(_margin(form, 8, 5, 8, 5))
	_name = LineEdit.new()
	_name.placeholder_text = "Name for her current look"
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name.text_submitted.connect(func(_t): save_new())
	form.add_child(_name)
	_save = _button("Save as new", "Stores her current look, mods and dialogue as a new character.", save_new)
	form.add_child(_save)
	_missing = VBoxContainer.new()
	_missing.add_theme_constant_override("separation", 3)
	v.add_child(_margin(_missing, 8, 0, 8, 0))
	v.add_child(_hline())
	var line := HBoxContainer.new()
	var label := Label.new()
	label.text = "Hide the game's characters"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(label)
	_hide = CheckButton.new()
	_hide.tooltip_text = "Leaves them out of this list, of Her › Character and of the next / previous character keys. The first one stays."
	_hide.focus_mode = Control.FOCUS_NONE
	_hide.toggled.connect(set_hiding)
	line.add_child(_hide)
	v.add_child(_margin(line, 8, 2, 8, 2))
	v.add_child(_hline())
	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", MenuTheme.SMALL + 1)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_margin(_hint, 8, 4, 8, 4))
	v.add_child(_hline())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 2)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_margin(_rows, 6, 6, 8, 8, true))
	v.add_child(scroll)
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


func _layout() -> void:
	if _root == null:
		return
	var vw: float = _root.get_viewport_rect().size.x
	var w := clampf(vw - 160.0, 380.0, MAX_WIDTH)
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


# ---------------------------------------------------------------- the list

## The indices of the characters the search shows.
func shown_characters() -> Array:
	var out: Array = []
	var names := MenuCharacters.names()
	for i in names.size():
		if not MenuCharacters.hidden(i) and (query == "" or str(names[i]).containsn(query)):
			out.append(i)
	return out


func _state() -> Array:
	return [MenuCharacters.index(), MenuCharacters.count()]


func _show() -> void:
	if _root == null or not is_open:
		return
	_shown = _state()
	for c in _rows.get_children():
		_rows.remove_child(c)
		c.queue_free()
	var names := MenuCharacters.names()
	var at := MenuCharacters.index()
	for i in shown_characters():
		_rows.add_child(_row(i, str(names[i]), i == at))
	_show_missing()


func _row(i: int, n: String, selected: bool) -> Control:
	var c: CustomCharacter = MenuCharacters.stored(i)
	var row := PanelContainer.new()
	row.set_meta("index", i)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_theme_stylebox_override("panel", MenuTheme.box(MenuTheme.CARD if selected else Color(0, 0, 0, 0),
		MenuTheme.ACCENT if selected else Color(0, 0, 0, 0), 3, 3, 2))
	row.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.double_click == false \
				and not e.pressed and renaming == null:
			_pick(i))
	row.set_drag_forwarding(func(_p): return _drag(i, n, row),
		func(_p, d): return d is Dictionary and d.has("character") and query == "",
		func(_p, d): _drop(d["character"], i))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(h)
	var pic := TextureRect.new()
	pic.texture = MenuCharacters.picture(i)
	pic.custom_minimum_size = THUMB
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(pic)
	if c != null and c == renaming:
		var edit := LineEdit.new()
		edit.text = c.charName
		edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		edit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		edit.text_submitted.connect(func(t): rename(c, t))
		h.add_child(edit)
		h.add_child(_small("Save", "Keeps the new name.", func(): rename(c, edit.text)))
		h.add_child(_small("Cancel", "Keeps the old name.", func(): rename(c, c.charName)))
		edit.grab_focus.call_deferred()
		edit.select_all.call_deferred()
		return row
	var l := Label.new()
	l.text = n
	l.clip_text = true
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(l)
	if MenuCharacters.has_clothes(i):
		h.add_child(_small("Clothes", "Puts on her clothes only; the body stays.", func(): MenuCharacters.load_costume(i)))
	if c != null:
		h.add_child(_small("Rename", "A new name; her look stays as it is.", func(): _start_rename(c)))
		h.add_child(_small("Update", "Replaces this character's look, mods and dialogue with the current ones.",
			func(): update(c)))
		var del := _small("Delete?" if c == confirming else "Delete", "Deletes this character.", func(): delete(c))
		if c == confirming:
			del.add_theme_color_override("font_color", MenuTheme.WARN)
		h.add_child(del)
	return row


func _small(text: String, tip: String, fn: Callable) -> Button:
	var b := _button(text, tip, fn)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", MenuTheme.SMALL)
	return b


func _pick(i: int) -> void:
	confirming = null
	MenuCharacters.select(i)
	_say("")
	_show()


func _drag(i: int, n: String, row: Control) -> Variant:
	if query != "":
		return null
	var l := Label.new()
	l.text = n
	row.set_drag_preview(l)
	return {"character": i}


func _drop(from: int, to: int) -> void:
	MenuCharacters.move(from, to)
	_show()


# ---------------------------------------------------------------- mods without a file

func _show_missing() -> void:
	var list := MenuCharacters.missing_paths()
	_missing_shown = list.size()
	for c in _missing.get_children():
		_missing.remove_child(c)
		c.queue_free()
	for e in list:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 5)
		var l := Label.new()
		l.text = str(e.elementLabel.text)
		l.custom_minimum_size.x = 120
		l.clip_text = true
		h.add_child(l)
		var edit := LineEdit.new()
		edit.text = str(e.enteredPath)
		edit.placeholder_text = "The mod's file"
		edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		edit.text_submitted.connect(func(t): MenuCharacters.try_path(e, t))
		h.add_child(edit)
		h.add_child(_small("Check", "Looks for the file at this path.", func(): MenuCharacters.try_path(e, edit.text)))
		_missing.add_child(h)


func _unhandled_input(event: InputEvent) -> void:
	if not is_open or not (event is InputEventKey) or not event.pressed:
		return
	if event.keycode == KEY_ESCAPE:
		if renaming != null:
			renaming = null
			_show()
		elif _search.has_focus() and _search.text != "":
			_search.text = ""
			query = ""
			_show()
		else:
			close()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not is_open:
		return
	if SDTMenu.instance != null and SDTMenu.instance.is_open:   # the menu opened (its tab): one panel at a time
		close()
		return
	if _state() != _shown:   # a character finished loading
		_show()
	elif _missing_shown > 0 and MenuCharacters.missing_paths().size() != _missing_shown:   # a path was found
		_show_missing()
