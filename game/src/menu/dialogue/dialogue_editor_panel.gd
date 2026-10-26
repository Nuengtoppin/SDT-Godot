class_name DialogueEditorPanel
extends CanvasLayer
## Port addition: the dialogue editor of the new menu (Menu > Dialogue > Edit…; the classic menu keeps the game's
## own DialogueEditor). A wide panel on the menu's side: line types on the left, the lines of one type (or every
## line matching the search) in the middle, the selected lines' text and settings on the right, the dialogue log at
## the bottom. Typing "[" or "*" in a line offers the actions and wildcards (the game's, and the ones DialogueActions
## and its add-ons registered). Play hides the panel and plays the line in the game until the next click.
##
## It edits a copy of the current dialogue and hands it to the game the way the game's editor does
## (Dialogue.loadFromDialogueEditor), only when something changed: before playing, saving and on close.

const MAX_WIDTH := 820.0       # stage units (the window shows ~1200 x 600 of them at 1600 x 800)
const TYPES_W := 185.0          # the widest the line type column gets (longer names are cut short)
const INSPECTOR_W := 250.0
const MAX_ROWS := 200          # lines shown at once (a search over a big dialogue shows the first ones)
const MAX_UNDO := 50
const REFRESH_SECONDS := 0.5   # how often "can't play now" is re-checked
const STYLES := [DialogueLine.SPEAKING_STYLE, DialogueLine.THOUGHT_STYLE, DialogueLine.HIM_STYLE]
const WILDCARD_TYPES := ["cough", "interrupt"]
const CALLED_GROUP := "Called by other lines"   # line types the dialogue makes up: said only when a line leads there
const AC_WIDTH := 300.0        # the suggestions under the text field
const AC_ROWS := 8

static var instance: DialogueEditorPanel = null

## One line being edited: what the game's DialogueEditorLine holds, with every setting kept.
class Entry:
	extends RefCounted
	var trigger := ""
	var phrase := ""
	var settings := {}
	var finish := false

	static func from_line(t: String, src: DialogueLine, fin: bool) -> Entry:
		var e := Entry.new()
		e.trigger = t
		e.phrase = src.phrase
		e.finish = fin
		e.settings = src.settings.duplicate(true)
		e._put("style", src._style if src._style != DialogueLine.SPEAKING_STYLE else "")
		e._put("mood", src.mood)
		e._put("held", src.held)
		e._put("next", src.nextLine)
		return e

	func copy() -> Entry:
		var e := Entry.new()
		e.trigger = trigger
		e.phrase = phrase
		e.settings = settings.duplicate(true)
		e.finish = finish
		return e

	func opt(k: String) -> String:
		return str(settings[k]) if settings.get(k) != null else ""

	func _put(k: String, v) -> void:
		if v == null or (v is String and v == "") or (v is Dictionary and v.is_empty()):
			settings.erase(k)
		else:
			settings[k] = v

	func wildcard() -> bool:
		return finish or DialogueEditorPanel.WILDCARD_TYPES.has(trigger)

	## What Dialogue.loadFromDialogueEditor reads.
	func getDialogueLine() -> DialogueLine:
		return DialogueLine.new(phrase, settings.duplicate(true))

var is_open := false
var playing := false
var _before: Dictionary = {}   # the scene when Play was pressed (_scene_state): a played line's actions last only while it plays
var entries: Array = []        # [Entry]
var library_name := ""
var current_type := "general"
var query := ""
var style_filter := ""         # "" = all
var custom_types: Array = []   # line types added in this session (no lines yet)
var dirty := false

var _sel: Array = []           # selected entries
var _anchor: Entry = null      # where a shift-click range starts
var _shown: Array = []         # entries in the middle column, in order
var _undo: Array = []
var _typing_snapshot := false  # the text field's changes since it got focus are one undo step
var _refresh_t := 0.0
var _insert_tab := "actions"
var _actions_cache: Array = []
var _ext_actions := {}         # trigger name -> true (the highlighter's orange)
var _file: FlashFileReference
var _browsing := false
var _saving := false
var _quiet := false            # updating the inspector's controls from the selection (no write-back)

var _root: Control
var _dock: PanelContainer
var _name: LineEdit
var _search: LineEdit
var _pause: Button
var _types: VBoxContainer
var _tscroll: ScrollContainer
var _types_w := TYPES_W
var _new_type: LineEdit
var _list_title: Label
var _list_desc: Label
var _style_seg: Array = []
var _rows: VBoxContainer
var _list_scroll: ScrollContainer
var _insp: VBoxContainer
var _insp_title: Label
var _type_pick: OptionButton
var _text: CodeEdit
var _picker_tabs: Array = []
var _picker_find: LineEdit
var _picker_list: VBoxContainer
var _picker_help: Label
var _line_props: VBoxContainer
var _style_btns: Array = []
var _mood_flow: HFlowContainer
var _held_btns: Array = []
var _next_pick: OptionButton
var _check_edit: LineEdit
var _set_edit: LineEdit
var _play: Button
var _dup: Button
var _del: Button
var _log: Label
var _ac: PanelContainer        # the [ / * suggestions under the text field
var _ac_list: ItemList
var _ac_items: Array = []
var _ac_from := 0              # column of the "[" or "*" being completed
var _overlay: PanelContainer
var _overlay_text: TextEdit


# ---------------------------------------------------------------- open / close

static func open_editor() -> void:
	if instance == null:
		instance = DialogueEditorPanel.new()
		instance.name = "DialogueEditorPanel"
		Flash.add_child(instance)
	instance.open()


func _ready() -> void:
	layer = 55


func open() -> void:
	if is_open:
		return
	if _root == null:
		_build()
	is_open = true
	_root.visible = true
	_layout()
	_load_from_game()
	_undo.clear()
	dirty = false
	_pause.button_pressed = bool(PortSettings.get_value("dialogue_editor", "pause", true))
	_pause.text = "Game paused" if _pause.button_pressed else "Game running"
	g.gamePaused = _pause.button_pressed
	g.controlLocked = true
	g.inTextField = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh_catalogue()
	if not _type_exists(current_type):
		current_type = "general"
	_select([])
	_show_types()
	_show_lines()


func close() -> void:
	if not is_open:
		return
	if playing:
		_stop_playing()
	_output()
	is_open = false
	_root.visible = false
	Presentation.reserve(0)
	_overlay.visible = false
	g.gamePaused = false
	g.controlLocked = false
	g.inTextField = false
	if not g.showMouse and g.gameRunning:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


## Flash input skips the mouse over the panel, and everywhere while a played line runs (the click that ends it
## must not reach the scene).
func blocks_mouse() -> bool:
	if not is_open:
		return false
	if playing:
		return true
	return _dock.get_global_rect().has_point(_root.get_global_mouse_position())


# ---------------------------------------------------------------- the dialogue

func _load_from_game() -> void:
	entries.clear()
	var dlg: Dictionary = g.dialogueControl.getCurrentDialogue()
	for t in dlg:
		if dlg[t] == null:
			continue
		for src in dlg[t]:
			entries.append(Entry.from_line(str(t), src, false))
	var fin: Dictionary = g.dialogueControl.getCurrentFinishes()
	for k in fin:
		for src in fin[k]:
			entries.append(Entry.from_line("finish" + str(k), src, true))
	library_name = g.dialogueControl.getCurrentLibraryName()
	_name.text = library_name
	custom_types.clear()


## Hands the edited dialogue to the game (as the game's editor does on close), if anything changed.
func _output() -> void:
	if not dirty:
		return
	dirty = false
	g.dialogueControl.resetCustomDialogue(false)
	g.inGameMenu.setDialogueLibraryName(library_name)
	g.dialogueControl.setDialogueLibraryName(library_name)
	g.dialogueControl.loadFromDialogueEditor(entries)


func _changed() -> void:
	dirty = true


func _snapshot() -> void:
	_undo.append({"entries": entries.map(func(e): return e.copy()), "name": library_name,
		"types": custom_types.duplicate()})
	if _undo.size() > MAX_UNDO:
		_undo.pop_front()


func undo() -> void:
	if _undo.is_empty():
		return
	var s: Dictionary = _undo.pop_back()
	entries = s["entries"]
	library_name = s["name"]
	custom_types = s["types"]
	_name.text = library_name
	_changed()
	_select([])
	_show_types()
	_show_lines()


func _count(t: String) -> int:
	var n := 0
	for e in entries:
		if e.trigger == t:
			n += 1
	return n


func _type_exists(t: String) -> bool:
	return _all_types().has(t)


## Line types in list order, as [group title, [type, ...], extension group?].
func _type_groups() -> Array:
	var present := {}
	for e in entries:
		present[e.trigger] = true
	var game: Array = DialogueLibrary.allDialogueTypes.filter(func(t): return not WILDCARD_TYPES.has(t))
	var wild: Array = WILDCARD_TYPES.duplicate()
	for i in range(1, 11):
		wild.append("finish%d" % i)
	var da: Array = []
	if Extensions.is_on("dialogueactions"):
		da = DialogueCatalogue.DA_LINE_TYPES.keys()
	var known := {}
	for t in game + wild + da:
		known[t] = true
	var extra: Array = []
	for t in present.keys() + custom_types:
		if known.has(t) or extra.has(t):
			continue
		if t.begins_with("finish"):
			wild.append(t)
		elif t.begins_with("button") and Extensions.is_on("dialogueactions"):
			da.append(t)
		else:
			extra.append(t)
		known[t] = true
	extra.sort()
	var out := [["Game", game, false], ["Wildcards", wild, false]]
	if not da.is_empty():
		out.append(["DialogueActions", da, true])
	if not extra.is_empty():
		out.append([CALLED_GROUP, extra, false])
	return out


func _all_types() -> Array:
	var out: Array = []
	for grp in _type_groups():
		out += grp[1]
	return out


## The line types the game does not know (CALLED_GROUP): no description of their own, only what leads there.
func _is_called_type(t: String) -> bool:
	for grp in _type_groups():
		if grp[1].has(t):
			return grp[0] == CALLED_GROUP
	return false


## The line types whose lines lead to t: its name as a line's Next line, or "[t]" in a line's text.
func _callers(t: String) -> Array:
	var out: Array = []
	var tag := "[" + t + "]"
	for e in entries:
		if (e.opt("next") == t or e.phrase.contains(tag)) and not out.has(e.trigger):
			out.append(e.trigger)
	return out


func _describe(t: String) -> String:
	if not _is_called_type(t):
		return DialogueCatalogue.describe_type(t)
	var c := _callers(t)
	if c.is_empty():
		return "nothing leads here: never said (set it as a line's Next line, or write [%s] in a line)" % t
	var shown := ", ".join(PackedStringArray(c.slice(0, 3))) + (" …" if c.size() > 3 else "")
	return "said after a line of " + shown


func _is_wild_type(t: String) -> bool:
	return WILDCARD_TYPES.has(t) or t.begins_with("finish")


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
	title.text = "Dialogue"
	title.add_theme_font_size_override("font_size", MenuTheme.TITLE)
	head.add_child(title)
	_name = LineEdit.new()
	_name.custom_minimum_size.x = 110
	_name.tooltip_text = "The dialogue's name (saved files are named after it)."
	_name.text_changed.connect(func(t):
		_snapshot()
		library_name = t
		_changed())
	head.add_child(_name)
	_search = LineEdit.new()
	_search.placeholder_text = "Search lines, line types and actions"
	_search.clear_button_enabled = true
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_changed.connect(func(t):
		query = t.strip_edges()
		_show_types()
		_show_lines())
	head.add_child(_search)
	_pause = _button("Game paused", "Click to pause or run the game while the editor is open (a played line runs either way).")
	_pause.toggle_mode = true
	_pause.toggled.connect(func(on: bool):
		_pause.text = "Game paused" if on else "Game running"
		PortSettings.set_value("dialogue_editor", "pause", on)
		if is_open and not playing:
			g.gamePaused = on)
	head.add_child(_pause)
	head.add_child(_button("Undo", "Undoes the last change (Ctrl+Z outside the text field).", undo))
	head.add_child(_button("Load…", "Loads a dialogue file.", _load_clicked))
	head.add_child(_button("Save…", "Saves the dialogue to a file.", _save_clicked))
	head.add_child(_button("Help", "How dialogue lines work.", _show_help))
	var x := _button("×", "Close the editor (Esc)", close)
	x.custom_minimum_size = Vector2(18, 18)
	head.add_child(x)
	v.add_child(_hline())

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 0)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)

	_tscroll = ScrollContainer.new()
	_tscroll.custom_minimum_size.x = TYPES_W
	_tscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_types = VBoxContainer.new()
	_types.add_theme_constant_override("separation", 1)
	_types.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tscroll.add_child(_margin(_types, 4, 4, 4, 6, true))   # (fills the column: a scroll container sizes its child to its minimum otherwise)
	body.add_child(_tscroll)
	body.add_child(_vline())

	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 5)
	body.add_child(_margin(mid, 8, 7, 8, 6, true))
	var mh := HBoxContainer.new()
	mh.add_theme_constant_override("separation", 6)
	mid.add_child(mh)
	_list_title = Label.new()
	_list_title.add_theme_font_size_override("font_size", MenuTheme.FONT_SIZE + 1)
	mh.add_child(_list_title)
	_list_desc = Label.new()
	_list_desc.add_theme_color_override("font_color", MenuTheme.MUTED)
	_list_desc.add_theme_font_size_override("font_size", MenuTheme.SMALL)
	_list_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_desc.clip_text = true
	_list_desc.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	mh.add_child(_list_desc)
	var seg := HBoxContainer.new()
	seg.add_theme_constant_override("separation", 0)
	mh.add_child(seg)
	var sg := ButtonGroup.new()
	for s in ["", DialogueLine.SPEAKING_STYLE, DialogueLine.THOUGHT_STYLE, DialogueLine.HIM_STYLE]:
		var b := _button("All" if s == "" else s, "Show only lines of this style." if s != "" else "Show all lines.")
		b.toggle_mode = true
		b.button_group = sg
		b.button_pressed = s == ""
		b.pressed.connect(func():
			style_filter = s
			_show_lines())
		seg.add_child(b)
		_style_seg.append(b)
	var add := _button("+ Add line", "Adds a line to this line type (with the selected line's style and mood).", _add_line)
	add.add_theme_stylebox_override("normal", MenuTheme.box(MenuTheme.ACCENT, MenuTheme.ACCENT, 4, 6, 2))
	add.add_theme_color_override("font_color", MenuTheme.INK)
	mh.add_child(add)
	_list_scroll = ScrollContainer.new()
	_list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 3)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_scroll.add_child(_rows)
	mid.add_child(_list_scroll)
	body.add_child(_vline())

	var iscroll := ScrollContainer.new()
	iscroll.custom_minimum_size.x = INSPECTOR_W
	iscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(iscroll)
	_insp = VBoxContainer.new()
	_insp.add_theme_constant_override("separation", 6)
	_insp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	iscroll.add_child(_margin(_insp, 8, 7, 8, 8, true))
	_build_inspector()

	v.add_child(_hline())
	var logrow := HBoxContainer.new()
	logrow.add_theme_constant_override("separation", 8)
	v.add_child(_margin(logrow, 8, 3, 8, 3))
	var ll := Label.new()
	ll.text = "Log"
	logrow.add_child(ll)
	_log = Label.new()
	_log.add_theme_color_override("font_color", MenuTheme.MUTED)
	_log.add_theme_font_size_override("font_size", MenuTheme.SMALL)
	_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log.clip_text = true
	_log.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	logrow.add_child(_log)
	logrow.add_child(_button("Full log", "The dialogue log: lines loaded, played and skipped.", _show_log))

	_overlay = PanelContainer.new()
	_overlay.add_theme_stylebox_override("panel", MenuTheme.box(MenuTheme.CARD, MenuTheme.LINE, 6, 8, 8))
	_overlay.visible = false
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_dock.add_child(_overlay)   # (a second child of the dock: it covers the panel while shown)
	var ov := VBoxContainer.new()
	_overlay.add_child(ov)
	var oh := HBoxContainer.new()
	ov.add_child(oh)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	oh.add_child(sp)
	oh.add_child(_button("Close", "", func(): _overlay.visible = false))
	_overlay_text = TextEdit.new()
	_overlay_text.editable = false
	_overlay_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_overlay_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_overlay_text.add_theme_color_override("font_readonly_color", MenuTheme.TEXT)
	_overlay_text.add_theme_stylebox_override("read_only", MenuTheme.box(MenuTheme.FIELD, MenuTheme.LINE, 4, 6, 4))
	ov.add_child(_overlay_text)

	_ac = PanelContainer.new()   # on the root: the text field would clip it
	_ac.add_theme_stylebox_override("panel", MenuTheme.box(MenuTheme.CARD, MenuTheme.ACCENT.darkened(0.3), 4, 3, 3))
	_ac.visible = false
	_ac.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_ac)
	_ac_list = ItemList.new()
	_ac_list.focus_mode = Control.FOCUS_NONE
	_ac_list.custom_minimum_size = Vector2(AC_WIDTH, 0)
	_ac_list.add_theme_stylebox_override("panel", MenuTheme.box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0, 0))
	_ac_list.add_theme_stylebox_override("selected", MenuTheme.box(MenuTheme.ACCENT.darkened(0.45), Color(0, 0, 0, 0), 3, 2, 1))
	_ac_list.add_theme_stylebox_override("selected_focus", MenuTheme.box(MenuTheme.ACCENT.darkened(0.45), Color(0, 0, 0, 0), 3, 2, 1))
	_ac_list.add_theme_stylebox_override("hovered", MenuTheme.box(MenuTheme.FIELD, Color(0, 0, 0, 0), 3, 2, 1))
	_ac_list.add_theme_font_size_override("font_size", MenuTheme.FONT_SIZE)
	_ac_list.add_theme_color_override("guide_color", Color(0, 0, 0, 0))
	_ac_list.item_clicked.connect(func(i, _p, _b): _ac_accept(i))
	_ac.add_child(_ac_list)

	_file = FlashFileReference.new()
	_file.start_dir = Flash.mods_dir("Dialogue")
	_file.addEventListener(FlashEvent.SELECT, func(_e = null):
		if _browsing:
			_file.load())
	_file.addEventListener(FlashEvent.COMPLETE, _file_complete)
	_file.addEventListener(FlashEvent.CANCEL, func(_e = null):
		_browsing = false
		_saving = false)
	get_viewport().size_changed.connect(_layout)


func _build_inspector() -> void:
	_insp_title = Label.new()
	_insp.add_child(_insp_title)
	_type_pick = OptionButton.new()
	_type_pick.fit_to_longest_item = false
	_type_pick.tooltip_text = "The line type: when she says the line. Changing it moves the selected lines."
	_type_pick.item_selected.connect(func(i):
		if _quiet:
			return
		var t := _type_pick.get_item_text(i)
		_set_on_selection(func(e):
			e.trigger = t
			e.finish = t.begins_with("finish"))
		current_type = _type_pick.get_item_text(i)
		_show_types()
		_show_lines())
	_insp.add_child(_type_pick)

	_text = CodeEdit.new()
	_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_text.scroll_fit_content_height = true
	_text.custom_minimum_size.y = 40
	_text.gutters_draw_line_numbers = false
	_text.auto_brace_completion_enabled = false
	_text.placeholder_text = "The line. Type [ for an action, * for a wildcard."
	var hl := DialogueHighlighter.new()
	hl.is_ext = func(inner: String) -> bool: return _ext_actions.has(inner.get_slice("_", 0)) \
		or _ext_actions.has(inner) or _ext_actions.has(_da_name(inner))
	_text.syntax_highlighter = hl
	_text.add_theme_stylebox_override("normal", MenuTheme.box(MenuTheme.FIELD, MenuTheme.LINE, 4, 5, 4))
	_text.add_theme_stylebox_override("focus", MenuTheme.box(MenuTheme.FIELD, MenuTheme.ACCENT, 4, 5, 4))
	_text.add_theme_color_override("background_color", MenuTheme.FIELD)
	_text.add_theme_color_override("font_color", MenuTheme.TEXT)
	_text.add_theme_color_override("caret_color", MenuTheme.TEXT)
	_text.focus_entered.connect(func(): _typing_snapshot = false)
	_text.focus_exited.connect(func(): _ac.visible = false)
	_text.text_changed.connect(_text_changed)
	_text.caret_changed.connect(_complete)
	_text.gui_input.connect(_text_key)
	_insp.add_child(_text)

	var pick := PanelContainer.new()
	pick.add_theme_stylebox_override("panel", MenuTheme.box(MenuTheme.CARD, Color(0, 0, 0, 0), 5, 6, 5))
	_insp.add_child(pick)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 3)
	pick.add_child(pv)
	var ph := HBoxContainer.new()
	ph.add_theme_constant_override("separation", 0)
	pv.add_child(ph)
	var pg := ButtonGroup.new()
	for tab in [["actions", "Actions"], ["wildcards", "Wildcards"], ["variables", "Variables"]]:
		var b := _button(tab[1], "")
		b.toggle_mode = true
		b.button_group = pg
		b.button_pressed = tab[0] == _insert_tab
		b.pressed.connect(func():
			_insert_tab = tab[0]
			_show_picker())
		ph.add_child(b)
		_picker_tabs.append(b)
	_picker_find = LineEdit.new()
	_picker_find.placeholder_text = "Find"
	_picker_find.clear_button_enabled = true
	_picker_find.text_changed.connect(func(_t): _show_picker())
	pv.add_child(_picker_find)
	var pscroll := ScrollContainer.new()
	pscroll.custom_minimum_size.y = 120
	pscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_picker_list = VBoxContainer.new()
	_picker_list.add_theme_constant_override("separation", 0)
	_picker_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pscroll.add_child(_picker_list)
	pv.add_child(pscroll)
	_picker_help = Label.new()
	_picker_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_picker_help.add_theme_color_override("font_color", MenuTheme.MUTED)
	_picker_help.add_theme_font_size_override("font_size", MenuTheme.SMALL)
	_picker_help.text = "Click to insert at the cursor."
	pv.add_child(_picker_help)

	_line_props = VBoxContainer.new()
	_line_props.add_theme_constant_override("separation", 6)
	_insp.add_child(_line_props)
	_style_btns = _seg_row("Style", STYLES, func(i):
		_set_on_selection(func(e): e._put("style", "" if i == 0 else STYLES[i])))
	var mr := _prop_row("Mood")
	var ml: Label = mr.get_child(0)
	ml.size_flags_vertical = Control.SIZE_SHRINK_BEGIN   # at the top of the (tall) list of moods, in line with its first row
	ml.custom_minimum_size.y = 18
	ml.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_mood_flow = HFlowContainer.new()
	_mood_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mood_flow.add_theme_constant_override("h_separation", 3)
	_mood_flow.add_theme_constant_override("v_separation", 3)
	mr.add_child(_mood_flow)
	_held_btns = _seg_row("Held", ["Any", "Held", "Not held"], func(i):
		_set_on_selection(func(e): e._put("held", ["", "true", "false"][i])))
	var nr := _prop_row("Next line")
	_next_pick = OptionButton.new()
	_next_pick.fit_to_longest_item = false
	_next_pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_next_pick.tooltip_text = "A line type said right after this line."
	_next_pick.item_selected.connect(func(i):
		if _quiet:
			return
		_set_on_selection(func(e): e._put("next", "" if i == 0 else _next_pick.get_item_text(i))))
	nr.add_child(_next_pick)
	var cr := _prop_row("Needs")
	_check_edit = _vars_edit("DialogueActions: the line plays only if these variables match, e.g. teased=1, count=>=3")
	_check_edit.text_submitted.connect(func(_t): _vars_submitted(_check_edit, "check"))
	_check_edit.focus_exited.connect(func(): _vars_submitted(_check_edit, "check"))
	cr.add_child(_check_edit)
	var sr := _prop_row("Sets")
	_set_edit = _vars_edit("DialogueActions: variables the line sets when it plays, e.g. teased=1")
	_set_edit.text_submitted.connect(func(_t): _vars_submitted(_set_edit, "set"))
	_set_edit.focus_exited.connect(func(): _vars_submitted(_set_edit, "set"))
	sr.add_child(_set_edit)

	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 4)
	_insp.add_child(foot)
	_play = _button("Play this line", "Hides the editor and plays the line in the game. Click anywhere to come back.", _play_clicked)
	_play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_play.add_theme_stylebox_override("normal", MenuTheme.box(MenuTheme.ACCENT, MenuTheme.ACCENT, 4, 6, 2))
	_play.add_theme_color_override("font_color", MenuTheme.INK)
	foot.add_child(_play)
	_dup = _button("Duplicate", "Copies the selected lines.", _duplicate)
	foot.add_child(_dup)
	_del = _button("Delete", "Deletes the selected lines.", _delete)
	foot.add_child(_del)


# ---------------------------------------------------------------- small widgets

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


func _prop_row(label: String) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 6)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size.x = 48
	l.add_theme_color_override("font_color", MenuTheme.MUTED)
	r.add_child(l)
	_line_props.add_child(r)
	return r


func _seg_row(label: String, items: Array, on_pick: Callable) -> Array:
	var r := _prop_row(label)
	var seg := HBoxContainer.new()
	seg.add_theme_constant_override("separation", 0)
	r.add_child(seg)
	var out: Array = []
	for i in items.size():
		var b := _button(items[i], "")
		b.toggle_mode = true
		b.pressed.connect(func():
			if not _quiet:
				on_pick.call(i))
		seg.add_child(b)
		out.append(b)
	return out


func _vars_edit(tip: String) -> LineEdit:
	var e := LineEdit.new()
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	e.tooltip_text = tip
	e.placeholder_text = "none"
	return e


func _badge(text: String, ext := false, warn := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", MenuTheme.SMALL)
	var c := MenuTheme.PLUGIN if ext else (Color("e6a0a0") if warn else MenuTheme.MUTED)
	l.add_theme_color_override("font_color", c)
	l.add_theme_stylebox_override("normal", MenuTheme.box(Color(0, 0, 0, 0), c.darkened(0.45), 7, 5, 0))
	return l


# ---------------------------------------------------------------- layout

## The stage width around its centre that shows the whole speech bubble (with a little room).
func _bubble_width() -> float:
	var c := Presentation.STAGE_SIZE.x / 2.0
	var b: Rect2 = g.dialogueControl.getBounds(Flash.stage) if is_instance_valid(g.dialogueControl) else Rect2()
	if b.size.x <= 0.0:
		return Presentation.STAGE_SIZE.x
	return 2.0 * maxf(c - b.position.x, b.end.x - c) + 24.0


func _layout() -> void:
	if _root == null:
		return
	var vw: float = _root.get_viewport_rect().size.x
	var w := clampf(vw - 120.0, 560.0, MAX_WIDTH - (TYPES_W - _types_w))   # a narrow type column: more of the game
	var left := SDTMenu.on_left()
	_dock.anchor_top = 0
	_dock.anchor_bottom = 1
	_dock.offset_top = 0
	_dock.offset_bottom = 0
	_dock.anchor_left = 0 if left else 1
	_dock.anchor_right = 0 if left else 1
	if is_open:
		Presentation.reserve(0.0 if playing else (w if not left else -w), _bubble_width())   # the game beside it
	var away := w + 4 if playing else 0.0   # a played line: the panel moves off the screen
	_dock.offset_left = (0.0 - away) if left else (-w + away)
	_dock.offset_right = (w - away) if left else away


# ---------------------------------------------------------------- line types

func _show_types() -> void:
	for c in _types.get_children():
		c.queue_free()
	var group := ButtonGroup.new()
	for grp in _type_groups():
		var h := Label.new()
		h.text = grp[0].to_upper()
		h.add_theme_font_size_override("font_size", MenuTheme.HEADING)
		h.add_theme_color_override("font_color", MenuTheme.PLUGIN if grp[2] else MenuTheme.MUTED)
		_types.add_child(_margin(h, 4, 6, 0, 1))
		for t in grp[1]:
			var n := _count(t)
			var b := Button.new()
			b.text = t
			b.toggle_mode = true
			b.button_group = group
			b.button_pressed = query == "" and t == current_type
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.focus_mode = Control.FOCUS_NONE
			b.tooltip_text = _describe(t)
			if _is_called_type(t) and _callers(t).is_empty() and n > 0:
				b.add_theme_color_override("font_color", Color("e6a0a0"))   # never said
			b.clip_text = true
			b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			for st in ["normal", "hover", "pressed", "hover_pressed"]:
				var bg: Color = MenuTheme.CARD if st == "hover" else (MenuTheme.ACCENT if st.contains("pressed") else Color(0, 0, 0, 0))
				var box := MenuTheme.box(bg, Color(0, 0, 0, 0), 4, 5, 1)
				box.content_margin_right = 20   # room for the count
				b.add_theme_stylebox_override(st, box)
			if n == 0:
				b.add_theme_color_override("font_color", MenuTheme.MUTED.darkened(0.25))
			var cnt := Label.new()
			cnt.text = str(n)
			cnt.add_theme_font_size_override("font_size", MenuTheme.SMALL)
			cnt.add_theme_color_override("font_color", MenuTheme.MUTED)
			cnt.set_anchors_preset(Control.PRESET_FULL_RECT)
			cnt.offset_right = -5
			cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			cnt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			cnt.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(cnt)
			var paint := func(on: bool): cnt.add_theme_color_override("font_color", MenuTheme.INK if on else MenuTheme.MUTED)
			paint.call(b.button_pressed)
			b.toggled.connect(paint)
			b.pressed.connect(func():
				current_type = t
				if query != "":
					_search.text = ""
					query = ""
				_select([])
				_show_lines())
			_types.add_child(b)
	_new_type = LineEdit.new()
	_new_type.placeholder_text = "+ Custom line type…"
	_new_type.tooltip_text = "Type a name and press Enter (a line type for DialogueActions or a mod, or a Next line target)."
	_new_type.text_submitted.connect(func(t: String):
		t = t.strip_edges().replace(" ", "_")
		if t == "" or _type_exists(t):
			return
		_snapshot()
		custom_types.append(t)
		current_type = t
		_show_types()
		_show_lines())
	_types.add_child(_margin(_new_type, 0, 6, 0, 0))
	_fit_types()


## The line type column as wide as its longest name (and the dock narrower by what that saves), at most TYPES_W.
func _fit_types() -> void:
	var f := MenuTheme.font()
	var widest := 0.0
	for grp in _type_groups():
		widest = maxf(widest, f.get_string_size(grp[0].to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, MenuTheme.HEADING).x + 4)
		for n in grp[1]:
			widest = maxf(widest, f.get_string_size(n, HORIZONTAL_ALIGNMENT_LEFT, -1, MenuTheme.FONT_SIZE).x + 25)   # + the count
	var sb := _tscroll.get_v_scroll_bar().get_combined_minimum_size().x
	var w := clampf(ceilf(widest + 10 + sb), 110.0, TYPES_W)   # (+ the margins and the scroll bar)
	if w != _types_w:
		_types_w = w
		_tscroll.custom_minimum_size.x = w
		_layout()


# ---------------------------------------------------------------- lines

func _matches(e: Entry, q: String) -> bool:
	return e.phrase.to_lower().contains(q) or e.trigger.to_lower().contains(q)


func _show_lines() -> void:
	for c in _rows.get_children():
		c.queue_free()
	var q := query.to_lower()
	_shown = []
	for e in entries:
		if q != "":
			if not _matches(e, q):
				continue
		elif e.trigger != current_type:
			continue
		if style_filter != "" and not e.wildcard():
			var st: String = e.opt("style")
			if (st if st != "" else DialogueLine.SPEAKING_STYLE) != style_filter:
				continue
		_shown.append(e)
	if q != "":
		_list_title.text = "Search"
		_list_desc.text = "%d matching lines" % _shown.size()
	else:
		_list_title.text = current_type
		var d := _describe(current_type)
		_list_desc.text = "%d lines%s" % [_count(current_type), (" · " + d) if d != "" else ""]
	for i in mini(_shown.size(), MAX_ROWS):
		_rows.add_child(_row(_shown[i], q != ""))
	if _shown.size() > MAX_ROWS:
		var more := Label.new()
		more.text = "%d more lines: narrow the search" % (_shown.size() - MAX_ROWS)
		more.add_theme_color_override("font_color", MenuTheme.MUTED)
		_rows.add_child(more)
	if _shown.is_empty():
		var none := Label.new()
		none.text = "No lines yet: + Add line." if q == "" else "No lines match."
		none.add_theme_color_override("font_color", MenuTheme.MUTED)
		_rows.add_child(none)
	_show_inspector()
	_refresh_reasons()


func _row(e: Entry, with_type: bool) -> PanelContainer:
	var p := PanelContainer.new()
	p.set_meta("entry", e)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	var t := RichTextLabel.new()
	t.bbcode_enabled = true
	t.fit_content = true
	t.scroll_active = false
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(t)
	var badges := HBoxContainer.new()
	badges.add_theme_constant_override("separation", 3)
	badges.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(badges)
	p.set_meta("text", t)
	p.set_meta("badges", badges)
	_fill_row(p, with_type)
	p.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_row_clicked(e, ev.ctrl_pressed, ev.shift_pressed)
			if ev.double_click and _sel.size() == 1:
				_text.grab_focus())
	p.mouse_entered.connect(func(): if not _sel.has(e): p.add_theme_stylebox_override("panel", _row_box(false, true)))
	p.mouse_exited.connect(func(): p.add_theme_stylebox_override("panel", _row_box(_sel.has(e), false)))
	return p


func _row_box(selected: bool, hover: bool) -> StyleBoxFlat:
	return MenuTheme.box(MenuTheme.CARD.lightened(0.04) if hover else MenuTheme.CARD,
		MenuTheme.ACCENT if selected else MenuTheme.CARD, 5, 7, 5)


func _fill_row(p: PanelContainer, with_type: bool) -> void:
	var e: Entry = p.get_meta("entry")
	p.add_theme_stylebox_override("panel", _row_box(_sel.has(e), false))
	var t: RichTextLabel = p.get_meta("text")
	t.text = _bbcode(e.phrase) if e.phrase != "" else "[color=#%s](empty)[/color]" % MenuTheme.MUTED.to_html(false)
	var badges: HBoxContainer = p.get_meta("badges")
	for c in badges.get_children():
		c.queue_free()
	if with_type:
		badges.add_child(_badge(e.trigger))
	if not e.wildcard():
		var st: String = e.opt("style")
		badges.add_child(_badge(st if st != "" else DialogueLine.SPEAKING_STYLE))
		if e.opt("mood") != "":
			badges.add_child(_badge(e.opt("mood"), not Moods.VANILLA.has(e.opt("mood"))))
		if e.opt("held") != "":
			badges.add_child(_badge("held" if e.opt("held") == "true" else "not held"))
		if e.opt("next") != "":
			badges.add_child(_badge("next: " + e.opt("next")))
		if e.settings.get("check") is Dictionary and not e.settings["check"].is_empty():
			badges.add_child(_badge("needs " + _vars_text(e.settings["check"]), true))
		if e.settings.get("set") is Dictionary and not e.settings["set"].is_empty():
			badges.add_child(_badge("sets " + ", ".join(PackedStringArray(e.settings["set"].keys())), true))
	var why := _badge("", false, true)
	why.visible = false
	badges.add_child(why)
	p.set_meta("why", why)


## The line as rich text: actions as chips (orange when an extension adds them), wildcards in the accent colour.
func _bbcode(s: String) -> String:
	var out := ""
	var i := 0
	while i < s.length():
		var c := s[i]
		if c == "[":
			var e := s.find("]", i)
			if e == -1:
				out += "[lb]"
				i += 1
				continue
			var inner := s.substr(i + 1, e - i - 1)
			var ext := _ext_actions.has(_da_name(inner))
			out += "[bgcolor=#%s][color=#%s] %s [/color][/bgcolor]" % ["3a2a10" if ext else "173246",
				"f0c27a" if ext else "9fd3f3", inner.replace("[", "[lb]")]
			i = e + 1
		elif c == "*":
			var e := s.find("*", i + 1)
			if e == -1:
				out += "*"
				i += 1
				continue
			out += "[color=#%s]%s[/color]" % [MenuTheme.ACCENT.to_html(false), s.substr(i, e - i + 1).replace("[", "[lb]")]
			i = e + 1
		else:
			out += c
			i += 1
	return out


## The trigger an action's text names (DialogueActions' rule: [LOOK_DOWN_1000] is LOOK_DOWN with one argument).
func _da_name(inner: String) -> String:
	var da = DialogueCatalogue._da()
	if da == null:
		return inner
	return da.recognises(inner)


func _row_clicked(e: Entry, ctrl: bool, shift: bool) -> void:
	if ctrl:
		var s := _sel.duplicate()
		if s.has(e):
			s.erase(e)
		else:
			s.append(e)
		_select(s)
		_anchor = e
	elif shift and _anchor != null and _shown.has(_anchor):
		var a := _shown.find(_anchor)
		var b := _shown.find(e)
		_select(_shown.slice(mini(a, b), maxi(a, b) + 1))
	else:
		_anchor = e
		_select([e])


func _select(s: Array) -> void:
	_sel = s
	_typing_snapshot = false
	for p in _rows.get_children():
		if p.has_meta("entry"):
			p.add_theme_stylebox_override("panel", _row_box(_sel.has(p.get_meta("entry")), false))
	_show_inspector()


func _row_of(e: Entry) -> PanelContainer:
	for p in _rows.get_children():
		if p.has_meta("entry") and p.get_meta("entry") == e:
			return p
	return null


func _add_line() -> void:
	_snapshot()
	var e := Entry.new()
	e.trigger = current_type if query == "" else (_sel[0].trigger if not _sel.is_empty() else "general")
	e.finish = e.trigger.begins_with("finish")
	if not _sel.is_empty() and not e.wildcard():
		for k in ["style", "mood"]:
			e._put(k, _sel[0].opt(k))
	var at := entries.find(_sel.back()) + 1 if not _sel.is_empty() else entries.size()
	entries.insert(at, e)
	_changed()
	current_type = e.trigger
	_select([e])
	_show_types()
	_show_lines()
	_text.grab_focus()


func _duplicate() -> void:
	if _sel.is_empty():
		return
	_snapshot()
	var copies: Array = []
	for e in _sel:
		var c: Entry = e.copy()
		entries.insert(entries.find(e) + 1, c)
		copies.append(c)
	_changed()
	_select(copies)
	_show_types()
	_show_lines()


func _delete() -> void:
	if _sel.is_empty():
		return
	_snapshot()
	for e in _sel:
		entries.erase(e)
	_changed()
	_select([])
	_show_types()
	_show_lines()


## Applies fn(entry) to every selected line (one undo step) and redraws their rows.
func _set_on_selection(fn: Callable) -> void:
	if _sel.is_empty():
		return
	_snapshot()
	for e in _sel:
		fn.call(e)
	_changed()
	for e in _sel:
		var p := _row_of(e)
		if p != null:
			_fill_row(p, query != "")
	_show_inspector()
	_refresh_reasons()


# ---------------------------------------------------------------- inspector

func _same(k: String) -> String:
	var v: String = _sel[0].opt(k)
	for e in _sel:
		if e.opt(k) != v:
			return "…"
	return v


func _show_inspector() -> void:
	_quiet = true
	var n := _sel.size()
	var any := n > 0
	var one := n == 1
	var wild := any and _sel.all(func(e): return e.wildcard())
	if n == 0:
		_insp_title.text = "No line selected"
	elif one:
		var i: int = _shown.find(_sel[0])
		_insp_title.text = "Line %d of %d" % [i + 1, _shown.size()] if i >= 0 else "1 line"
	else:
		_insp_title.text = "%d lines selected" % n
	_type_pick.clear()
	for t in _all_types():
		_type_pick.add_item(t)
	var tt := ""
	if any:
		tt = _sel[0].trigger
		for e in _sel:
			if e.trigger != tt:
				tt = ""
	var ti := _all_types().find(tt)
	_type_pick.select(ti)
	_type_pick.disabled = not any
	_text.editable = one
	if one:
		if _text.text != _sel[0].phrase:
			_text.text = _sel[0].phrase
	else:
		_text.text = ""
		_text.placeholder_text = "Select one line to edit its text." if n > 1 else "The line. Type [ for an action, * for a wildcard."
	_line_props.visible = any and not wild
	if any and not wild:
		var st := _same("style")
		for i in STYLES.size():
			_style_btns[i].button_pressed = (st == "" and i == 0) or st == STYLES[i]
		var hd := _same("held")
		for i in 3:
			_held_btns[i].button_pressed = hd == ["", "true", "false"][i]
		_fill_moods(_same("mood"))
		_next_pick.clear()
		_next_pick.add_item("none")
		for t in _all_types():
			_next_pick.add_item(t)
		var nx := _same("next")
		_next_pick.select(0 if nx == "" else maxi(0, _all_types().find(nx) + 1))
		_check_edit.text = _vars_field("check")
		_set_edit.text = _vars_field("set")
	_play.disabled = not one or wild
	_dup.disabled = not any
	_del.disabled = not any
	_quiet = false
	for b in _picker_list.get_children():
		if b is Button:
			b.disabled = not one


func _fill_moods(cur: String) -> void:
	for c in _mood_flow.get_children():
		c.queue_free()
	for m in [""] + Moods.all():
		var ext: bool = m != "" and not Moods.VANILLA.has(m)
		var b := _button("Any" if m == "" else m, "Plays only in this mood." if m != "" else "Plays in any mood.")
		b.toggle_mode = true
		b.button_pressed = m == cur
		if ext:
			b.add_theme_color_override("font_color", MenuTheme.PLUGIN)
		b.pressed.connect(func():
			_set_on_selection(func(e): e._put("mood", m)))
		_mood_flow.add_child(b)


func _vars_text(d: Dictionary) -> String:
	var parts := PackedStringArray()
	for k in d:
		parts.append("%s=%s" % [k, AS3.toString(d[k])])
	return ", ".join(parts)


func _vars_field(k: String) -> String:
	var first = _sel[0].settings.get(k, {})
	for e in _sel:
		if str(e.settings.get(k, {})) != str(first):
			return "…"
	return _vars_text(first) if first is Dictionary else ""


## "a=1, b=>=3" as a dictionary: numbers as numbers, true / false as booleans, the rest as text.
static func parse_vars(s: String) -> Dictionary:
	var out := {}
	for part in s.split(","):
		var kv := part.strip_edges()
		var at := kv.find("=")
		if kv == "" or at <= 0:
			continue
		var k := kv.substr(0, at).strip_edges()
		var v := kv.substr(at + 1).strip_edges()
		if v.is_valid_int():
			out[k] = v.to_int()
		elif v.is_valid_float():
			out[k] = v.to_float()
		elif v == "true" or v == "false":
			out[k] = v == "true"
		else:
			out[k] = v
	return out


func _vars_submitted(edit: LineEdit, k: String) -> void:
	if _quiet or _sel.is_empty() or edit.text == "…" or edit.text == _vars_field(k):
		return
	var d := parse_vars(edit.text)
	_set_on_selection(func(e): e._put(k, d.duplicate()))


func _text_changed() -> void:
	if _quiet or _sel.size() != 1:
		return
	var t := _text.text
	if t.contains("\n"):   # one line per entry: Enter does not break it
		var c := _text.get_caret_column()
		t = t.replace("\n", "")
		_text.text = t
		_text.set_caret_column(c)
	if t == _sel[0].phrase:   # (the inspector showing a line sets the text too)
		return
	if not _typing_snapshot:
		_snapshot()
		_typing_snapshot = true
	_sel[0].phrase = t
	_changed()
	var p := _row_of(_sel[0])
	if p != null:
		_fill_row(p, query != "")


# ---------------------------------------------------------------- insert picker and autocomplete

func _refresh_catalogue() -> void:
	_actions_cache = DialogueCatalogue.actions()
	_ext_actions.clear()
	for a in _actions_cache:
		if a["owner"] != "":
			_ext_actions[a["name"].get_slice("_<", 0)] = true
	_show_picker()


func _picker_items() -> Array:
	match _insert_tab:
		"wildcards":
			return DialogueCatalogue.wildcards()
		"variables":
			return DialogueCatalogue.variables()
	return _actions_cache


func _show_picker() -> void:
	for c in _picker_list.get_children():
		c.queue_free()
	var q := _picker_find.text.strip_edges().to_lower()
	var group := ""
	var shown := 0
	for a in _picker_items():
		if q != "" and not a["name"].to_lower().contains(q) and not a["desc"].to_lower().contains(q):
			continue
		if a["group"] != group:
			group = a["group"]
			var h := Label.new()
			h.text = group.to_upper()
			h.add_theme_font_size_override("font_size", MenuTheme.HEADING)
			h.add_theme_color_override("font_color", MenuTheme.PLUGIN if a["owner"] != "" else MenuTheme.MUTED)
			_picker_list.add_child(h)
		var b := _button(a["name"], "")
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.custom_minimum_size.x = 1
		b.add_theme_stylebox_override("normal", MenuTheme.box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 3, 4, 1))
		b.add_theme_color_override("font_color", MenuTheme.PLUGIN if a["owner"] != "" else Color("9fd3f3"))
		b.disabled = _sel.size() != 1
		var help: String = a["name"] + (": " + a["desc"] if a["desc"] != "" else "") \
			+ (" (" + DialogueCatalogue._owner_title(a["owner"]) + ")" if a["owner"] != "" else "")
		b.mouse_entered.connect(func(): _picker_help.text = help)
		b.pressed.connect(func(): _insert(a["insert"]))
		_picker_list.add_child(b)
		shown += 1
	if shown == 0:
		var none := Label.new()
		none.text = "Nothing here." if q == "" else "Nothing matches."
		none.add_theme_color_override("font_color", MenuTheme.MUTED)
		_picker_list.add_child(none)


func _insert(s: String) -> void:
	if _sel.size() != 1:
		return
	_text.grab_focus()
	_text.insert_text_at_caret(s)


## Typing "[" offers the actions, "*" the wildcards and variables: a list under the text field that narrows as
## you type (Up / Down, Enter or Tab to insert, Esc to close).
func _complete() -> void:
	_ac_items = []
	if _sel.size() == 1 and _text.has_focus():
		var line := _text.get_line(_text.get_caret_line())
		var i := _text.get_caret_column() - 1
		while i >= 0 and (line[i] == "_" or line[i].to_upper() != line[i].to_lower() or line[i].is_valid_int()):
			i -= 1
		if i >= 0 and (line[i] == "[" or line[i] == "*"):
			_ac_from = i
			var typed := line.substr(i + 1, _text.get_caret_column() - i - 1).to_upper()
			var pool: Array = _actions_cache if line[i] == "[" else DialogueCatalogue.wildcards() + DialogueCatalogue.variables()
			var later: Array = []   # names that contain the typed text, after the ones that start with it
			for a in pool:
				var n: String = a["name"].to_upper()
				if typed == "" or n.begins_with(typed):
					_ac_items.append(a)
				elif n.contains(typed):
					later.append(a)
			_ac_items += later
	_ac.visible = not _ac_items.is_empty()
	if not _ac.visible:
		return
	_ac_list.clear()
	for a in _ac_items:
		var label: String = a["name"] + ("   " + a["desc"] if a["desc"] != "" else "") \
			+ ("   (" + DialogueCatalogue._owner_title(a["owner"]) + ")" if a["owner"] != "" else "")
		var i := _ac_list.add_item(label)
		_ac_list.set_item_custom_fg_color(i, MenuTheme.PLUGIN if a["owner"] != "" else Color("9fd3f3"))
	_ac_list.select(0)
	_ac_list.custom_minimum_size.y = minf(AC_ROWS, _ac_list.item_count) * (MenuTheme.FONT_SIZE + 8) + 2
	_ac.reset_size()
	var caret := _text.get_caret_draw_pos()
	var at := _text.get_global_rect().position + Vector2(clampf(caret.x - 20.0, 0.0, maxf(0.0, _text.size.x - 40.0)), caret.y + 6.0)
	var room: float = _root.get_viewport_rect().size.x - AC_WIDTH - 10.0
	_ac.global_position = Vector2(minf(at.x, room), at.y)


func _text_key(ev: InputEvent) -> void:
	if not _ac.visible or not (ev is InputEventKey) or not ev.pressed:
		return
	var cur: int = _ac_list.get_selected_items()[0] if _ac_list.is_anything_selected() else 0
	match ev.keycode:
		KEY_DOWN:
			_ac_list.select(mini(cur + 1, _ac_list.item_count - 1))
			_ac_list.ensure_current_is_visible()
		KEY_UP:
			_ac_list.select(maxi(cur - 1, 0))
			_ac_list.ensure_current_is_visible()
		KEY_ENTER, KEY_KP_ENTER, KEY_TAB:
			_ac_accept(cur)
		KEY_ESCAPE:
			_ac.visible = false
		_:
			return
	_text.accept_event()


## Replaces what was typed after "[" / "*" with the chosen action or wildcard.
func _ac_accept(i: int) -> void:
	if i < 0 or i >= _ac_items.size():
		return
	var ln := _text.get_caret_line()
	_text.select(ln, _ac_from, ln, _text.get_caret_column())
	_text.insert_text_at_caret(_ac_items[i]["insert"])
	_ac.visible = false
	_text.grab_focus()


# ---------------------------------------------------------------- play

func _play_clicked() -> void:
	if _sel.size() != 1 or _sel[0].wildcard():
		return
	_output()
	playing = true
	_before = _scene_state()
	_layout()
	g.gamePaused = false
	g.currentPos.x = 0
	g.currentPos.y = 0
	g.dialogueControl.startSpeakingPhrase(_sel[0].getDialogueLine())


func _stop_playing() -> void:
	playing = false
	g.dialogueControl.instantStop()
	_restore_scene(_before)
	g.gamePaused = _pause.button_pressed
	_layout()


## What a played line's actions and "set" can change for good: her mood, arms and eyes, his hold, the animation
## style, tears, and the dialogue's variables (local, global and mod ones).
func _scene_state() -> Dictionary:
	var s := {}
	if g.her != null:
		var tr = g.her.tears
		s["mood"] = Moods.current()
		s["arms"] = [g.her.currentLeftArmPosition, g.her.currentRightArmPosition]
		s["eyes_closed"] = g.her.eyelidMotion["isClosed"]
		s["tears"] = [tr.tearsData.clone(), tr.mascaraData.clone(), tr.lowerEyelidData.clone(), tr.tearList.duplicate(),
			tr.tearSpotList.duplicate(), tr.lowerEyelidClear]
	if g.him != null:
		s["hold"] = g.him.currentArmPosition
	if g.animationControl != null:
		s["animation"] = g.animationControl.currentAnimation
	s["store"] = g.dialogueControl.advancedController._dialogueDataStore.duplicate(true)
	var da = DialogueCatalogue._da()
	if da != null:
		s["globals"] = da.vars.globals.duplicate(true)
		var mods := {}
		for n in da.vars._write:
			if da.vars._read.has(n):
				mods[n] = da.vars.mod_value(n)
		s["mod_vars"] = mods
	return s


func _restore_scene(s: Dictionary) -> void:
	if s.is_empty():
		return
	if g.her != null and s.has("mood"):
		if Moods.current() != s["mood"]:   # e.g. [ANGRY_MOOD] in the line
			g.her.setMood(s["mood"])
		if g.her.currentLeftArmPosition != s["arms"][0]:
			g.her.setLeftArmPosition(s["arms"][0])
		if g.her.currentRightArmPosition != s["arms"][1]:
			g.her.setRightArmPosition(s["arms"][1])
		if g.her.eyelidMotion["isClosed"] != s["eyes_closed"]:
			if s["eyes_closed"]:
				g.her.closeEye()
			else:
				g.her.openEye()
		var tr = g.her.tears
		var was: Array = s["tears"]
		for spot in tr.tearSpotList:
			if not was[4].has(spot):
				tr.tearSpotsLayer.removeChild(spot)
				spot.queue_free()
		tr.tearSpotList = was[4].filter(func(spot): return is_instance_valid(spot) and spot._flash_parent == tr.tearSpotsLayer)
		tr.tearList = was[3]
		for pair in [[tr.tearsData, was[0]], [tr.mascaraData, was[1]], [tr.lowerEyelidData, was[2]]]:
			pair[0].fillRect(pair[0].rect, 0)
			pair[0].copyPixels(pair[1], pair[1].rect, Vector2i())
		tr.lowerEyelidClear = was[5]
		tr._refresh()
	if g.him != null and s.has("hold") and g.him.currentArmPosition != s["hold"]:   # [HOLD] / [RELEASE]
		g.him.setArmPosition(s["hold"])
	if s.has("animation") and g.animationControl.currentAnimation != s["animation"]:   # [NORMAL_STYLE] / [FACE_FUCK_STYLE]
		g.animationControl.setAnimation(s["animation"])
		g.saveData.saveCharOptionsData()
		g.inGameMenu.setStyleCheckboxes()
	var st: Dictionary = g.dialogueControl.advancedController._dialogueDataStore
	st.clear()
	st.merge(s["store"])
	var da = DialogueCatalogue._da()
	if da != null and s.has("globals"):
		da.vars.globals.clear()
		da.vars.globals.merge(s["globals"])
		for n in s["mod_vars"]:
			if da.vars._write.has(n) and da.vars.mod_value(n) != s["mod_vars"][n]:
				da.vars._write[n].call(s["mod_vars"][n])


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if playing:
		if (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed):
			_stop_playing()
			get_viewport().set_input_as_handled()
		return


func _unhandled_input(event: InputEvent) -> void:
	if not is_open or playing or not (event is InputEventKey) or not event.pressed:
		return
	if event.keycode == KEY_ESCAPE:
		if _overlay.visible:
			_overlay.visible = false
		else:
			close()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_Z and event.ctrl_pressed:
		undo()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not is_open:
		return
	_refresh_t += delta
	if _refresh_t >= REFRESH_SECONDS:
		_refresh_t = 0.0
		_refresh_reasons()
		_show_log_line()


## "can't play now" on each shown line whose own conditions (mood, held, DialogueActions checks) do not hold.
func _refresh_reasons() -> void:
	for p in _rows.get_children():
		if not p.has_meta("why"):
			continue
		var why: Label = p.get_meta("why")
		var r := why_not(p.get_meta("entry"))
		why.visible = r != ""
		if why.text != r:
			why.text = r


static func why_not(e: Entry) -> String:
	if e.wildcard() or g.her == null:
		return ""
	var m := e.opt("mood")
	if m != "" and g.her.mood != m and Moods.current() != m:
		return "not now: mood"
	var h := e.opt("held")
	if h != "" and g.him != null:
		var arms: String = Him.armPositions[g.him.currentArmPosition]
		if (h == "true" and arms != "Holding") or (h == "false" and arms != "Free"):
			return "not now: held"
	if e.settings.get("check") is Dictionary and not e.settings["check"].is_empty() and DialogueLine.advancedController != null:
		# the game's own check, with its log lines taken back out (this runs twice a second)
		var ed = g.dialogueEditor
		var n: int = ed._logLines.size()
		var c: int = ed.logCount
		var ok: bool = DialogueLine.advancedController.canPlay(e.getDialogueLine())
		ed._logLines.resize(n)
		ed.logCount = c
		if not ok:
			return "not now: variables"
	return ""


func _show_log_line() -> void:
	var lines: PackedStringArray = g.dialogueEditor._logLines
	var t := ""
	for i in range(maxi(0, lines.size() - 2), lines.size()):
		t += ("   " if t != "" else "") + lines[i].replace("\n", " ")
	if _log.text != t:
		_log.text = t


func _show_log() -> void:
	_overlay_text.text = g.dialogueEditor.logCache
	_overlay.visible = true
	_log_to_end.call_deferred()   # once it is laid out: wrapped lines are only counted then


## The full log opens at its last line.
func _log_to_end() -> void:
	var last := _overlay_text.get_line_count() - 1
	_overlay_text.set_caret_line(last)
	_overlay_text.set_caret_column(_overlay_text.get_line(last).length())
	_overlay_text.scroll_vertical = _overlay_text.get_scroll_pos_for_line(last, _overlay_text.get_line_wrap_count(last))


func _show_help() -> void:
	_overlay_text.text = HELP
	_overlay.visible = true
	_overlay_text.scroll_vertical = 0


const HELP := """Dialogue lines

Each line belongs to a line type, which says when she may say it (hover a type for a description). Out of the lines of a type that can play right now, one is picked at random.

Text
  [ACTION]      does something while she speaks: [BLINK], [SWALLOW], [LOOK_UP] ... Type [ for the list.
  *WILDCARD*    is replaced: *YOU* his name, *ME* her name, *FINISHES* how often he came ... Type * for the list.
  Orange actions come from extensions (DialogueActions and its add-ons, MoreTriggers, moremoods ...): they work while those are on.

Settings
  Style      Speak (aloud), Thought (in her head; works while her mouth is full) or Him (he speaks).
  Mood       the line plays only in this mood.
  Held       the line plays only while he holds her head, or only while he does not.
  Next line  a line type said right after this line.
  Needs / Sets   DialogueActions variables: the line plays only if they match; it sets them when it plays.

Wildcard types
  cough, interrupt and finish1 ... finish10 hold words that other lines use, not lines of their own.

Keys
  Esc closes the editor, Ctrl+Z undoes (outside the text field). Ctrl / Shift + click selects several lines: style, mood and the rest then change on all of them.

Files
  Save… writes a .txt file the game (and the Loader) can load. Load… reads one: Mods/Dialogue is the usual place.
"""


# ---------------------------------------------------------------- files

func _load_clicked() -> void:
	_browsing = true
	_saving = false
	_file.browse()


func _save_clicked() -> void:
	_output()
	_saving = true
	_browsing = false
	_file.save(g.dialogueControl.exportDialogue(), library_name + ".txt")


func _file_complete(_e = null) -> void:
	if _browsing:
		_browsing = false
		var text := Flash.bytes_to_string(_file.data)
		if text == "" and _file.data.size() > 0:
			g.showError("Error loading dialogue file. Check encoding is UTF-8")
			return
		g.dialogueControl.loadCustomDialogue(text)
		_load_from_game()
		_undo.clear()
		dirty = false
		_refresh_catalogue()
		if not _type_exists(current_type):
			current_type = "general"
		_select([])
		_show_types()
		_show_lines()
	elif _saving:
		_saving = false
