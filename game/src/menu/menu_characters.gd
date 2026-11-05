class_name MenuCharacters
extends RefCounted
## Port addition (not in the original game): the character list of the new menu (SDTMenu), read from the classic
## character menu (CharacterMenu: the game's characters, then stored ones, in the player's order) and selected
## through it, so C / X, stored characters and the classic menu keep working the same way.


const FIRST_CHARACTER := 0   # the game's first character stays when the others are hidden


static func _menu() -> CharacterMenu:
	return g.inGameMenu.characterMenu


static func names() -> Array:
	var m := _menu()
	var out: Array = []
	for t in m.thumbs:
		out.append(m.charNames[t.baseCharID] if t.isBaseChar else t.customChar.charName)
	return out


## The selected character's position in names(), -1 for a custom (edited or loaded from a code) character.
static func index() -> int:
	var m := _menu()
	return m.thumbs.find(m.selected) if m.selected != null else -1


static func select(i: int) -> void:
	var m := _menu()
	if i < 0 or i >= m.thumbs.size():
		return
	m.resetSearch()
	m.triggerSelect(i)


## Puts on character i's clothes only (the classic Select... costume button).
static func load_costume(i: int) -> void:
	var m := _menu()
	if i < 0 or i >= m.thumbs.size():
		return
	g.inGameMenu.onlyLoadCostume = true
	m.triggerSelect(i)
	g.inGameMenu.onlyLoadCostume = false


## Whether the game's own characters are hidden (Characters panel). The new menu only: the classic list shows them all.
static func hiding() -> bool:
	return SDTMenu.active() and bool(PortSettings.get_value("characters", "hide_defaults", false))


static func set_hiding(on: bool) -> void:
	PortSettings.set_value("characters", "hide_defaults", on)


## Whether character i is left out of the lists and of C / X.
static func hidden(i: int) -> bool:
	var t = _menu().thumbs[i]
	return hiding() and t.isBaseChar and t.baseCharID != FIRST_CHARACTER


## The positions in names() of the characters not hidden.
static func shown() -> Array:
	return range(count()).filter(func(i): return not hidden(i))


static func shown_names() -> Array:
	var all := names()
	return shown().map(func(i): return all[i])


## The selected character's position in shown_names(), -1 for a custom or hidden one.
static func shown_index() -> int:
	return shown().find(index())


static func select_shown(i: int) -> void:
	var list := shown()
	if i >= 0 and i < list.size():
		select(list[i])


static func count() -> int:
	return _menu().thumbs.size()


## Whether character i has clothes to put on alone (the classic list has no costume button on the others).
static func has_clothes(i: int) -> bool:
	var t = _menu().thumbs[i]
	return not t.isBaseChar or g.characterControl.characters[t.baseCharID].defaultCostume != ""


## Character i's stored character, null for one of the game's own.
static func stored(i: int) -> CustomCharacter:
	var t = _menu().thumbs[i]
	return null if t.isBaseChar else t.customChar


## Character i's picture: a stored one's shot, the art of the classic list's thumbnail for the game's own.
static func picture(i: int) -> Texture2D:
	var t = _menu().thumbs[i]
	if not t.isBaseChar:
		return t.customChar.charShot.get_texture() if t.customChar.haveCharShot else null
	var shape = t.thumb.get_child(0) if t.thumb.get_child_count() > 0 else null
	if shape is FlashShape and shape._entry.has("img"):
		return shape._library.get_texture(shape._entry["img"])
	return null


## The classic name field's characters only (a-z A-Z 0-9 and spaces).
static func clean_name(s: String) -> String:
	return RegEx.create_from_string("[^a-zA-Z0-9 ]").sub(s, "", true).strip_edges()


## Stores her current look as a new character and selects it. False: a mod has no file (missing_paths()).
static func save_new(n: String) -> bool:
	var cs = g.inGameMenu.charStoring
	cs.setEditing(false)
	_prepare(cs)
	if not cs.allPathsFound:
		return false
	cs.charNameTF.text = n
	cs.storeCharClicked()
	return true


## Gives a stored character her current look, mods, dialogue and picture. False: a mod has no file.
static func update(c: CustomCharacter) -> bool:
	var cs = g.inGameMenu.charStoring
	if not c.haveCharShot:
		c.giveCharShot(g.generateCharacterShot())
	cs.setEditing(true, c)
	_prepare(cs)
	var ok: bool = cs.allPathsFound
	if ok:
		cs.storeCharClicked()
	cs.setEditing(false)
	return ok


static func _prepare(cs) -> void:
	cs.setupChar(g.inGameMenu.getSaveDataString(false))
	cs.populateMods()


## The save panel's rows of the mods she wears whose file is not known (after save_new / update failed).
static func missing_paths() -> Array:
	return g.inGameMenu.charStoring.filePaths.filter(func(e): return not e.pathOkay)


static func try_path(entry, path: String) -> void:
	entry.enteredPath = path
	entry.checkDefaultFolders = false
	entry.recheck()


static func rename(c: CustomCharacter, n: String) -> void:
	var m := _menu()
	c.charName = n
	for t in m.thumbs:
		if not t.isBaseChar and t.customChar == c:
			t.setCustomChar(c)
			t.itemLabel.text = n
			if t == m.selected:
				m.menuButton.labelContainer.buttonLabel.text = n
			break
	g.saveData.saveCustomChar(c.ID)


static func delete(c: CustomCharacter) -> void:
	var m := _menu()
	m.deleteChar(c)
	m.saveOrder()   # the saved order is ignored at the next start when its length is wrong


## Moves character `from` to position `to`, as dragging it in the classic list does.
static func move(from: int, to: int) -> void:
	var m := _menu()
	if from == to or from < 0 or to < 0 or from >= m.thumbs.size() or to >= m.thumbs.size():
		return
	m.resetSearch()
	var t = m.thumbs[from]
	m.thumbs.remove_at(from)
	m.thumbs.insert(to, t)
	for i in m.thumbs.size():
		m.thumbs[i].x = i * m.SPACING
	m.setThumbTargets()
	m.saveOrder()
	if m.selected != null:
		m.lastSelectedID = m.thumbs.find(m.selected)


## A list of characters to take the clothes from.
static func choose_costume() -> void:
	if SDTMenu.instance == null:
		return
	var pop := PopupPanel.new()
	var v := VBoxContainer.new()
	var l := Label.new()
	l.text = "Wear the clothes of:"
	v.add_child(l)
	var list := ItemList.new()
	list.custom_minimum_size = Vector2(170, 260)
	list.add_theme_stylebox_override("panel", MenuTheme.box(MenuTheme.FIELD, MenuTheme.LINE, 4, 3, 3))
	list.add_theme_stylebox_override("hovered", MenuTheme.box(MenuTheme.CARD, Color(0, 0, 0, 0), 3, 3, 1))
	list.add_theme_stylebox_override("selected", MenuTheme.box(MenuTheme.ACCENT, Color(0, 0, 0, 0), 3, 3, 1))
	list.add_theme_stylebox_override("selected_focus", MenuTheme.box(MenuTheme.ACCENT, Color(0, 0, 0, 0), 3, 3, 1))
	list.add_theme_color_override("font_selected_color", MenuTheme.INK)
	for n in names():
		list.add_item(n)
	list.item_clicked.connect(func(i: int, _p, _b):
		load_costume(i)
		pop.hide())
	v.add_child(list)
	pop.add_child(v)
	pop.popup_hide.connect(func(): SDTMenu.open_popups -= 1; pop.queue_free())
	SDTMenu.instance.add_popup(pop)
	SDTMenu.open_popups += 1
	var vp := SDTMenu.instance.get_viewport().get_visible_rect().size
	var x := 8.0 if not SDTMenu.on_left() else SDTMenu.WIDTH + 8.0
	if not SDTMenu.on_left():
		x = vp.x - SDTMenu.WIDTH - 190
	pop.popup(Rect2i(Vector2i(int(x), 40), Vector2i(0, 0)))
