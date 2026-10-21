extends SDTExtension
## Built-in reimplementation of the Loader mod charcodefilesaving (sby, V2): her character code saved to / loaded from
## a text file ("Code.txt"), and the whole character list exported to / imported from a text backup
## ("SDTTextBackup.txt", the mod's format: names, codes, thumbnails as hex, dialogues), in Mods > Character code /
## Character list and as the mod's buttons in the classic Modding tab. Written from its source. Port fixes: an
## imported dialogue keeps its line breaks (the mod joined its lines), and Windows line endings are read (the mod's
## replace() calls threw their result away).

const HEADER := "charcodefilesavingV2 export"
const DIALOG_START := "StartOfDialogThisIsVeryUniqueSBY"
const DIALOG_END := "EndOfDialogThisIsVeryUniqueSBY"

var _file := FlashFileReference.new()
var _on_loaded := Callable()


func _init() -> void:
	id = "charcodefilesaving"
	title = "charcodefilesaving"
	description = "charcodefilesaving (sby): character codes and the character list saved to and loaded from text files (Mods)."
	default_enabled = true
	_file.start_dir = Flash.mods_dir("Characters")
	_file.addEventListener(FlashEvent.SELECT, func(_e): _file.load())
	_file.addEventListener(FlashEvent.COMPLETE, func(_e):
		if _on_loaded.is_valid():
			var f := _on_loaded
			_on_loaded = Callable()
			f.call(_file.data.get_string_from_utf8()))


func _enable() -> void:
	menu_control("mods", "Character code", MenuSchema.actions("", "", [
		["Save to file…", save_code, "Saves her current code to a text file."],
		["Load from file…", load_code, "Loads a code from a text file."]]))
	menu_control("mods", "Character list", MenuSchema.actions("", "", [
		["Save as text…", save_text, "All stored characters (codes, thumbnails, dialogues) in one text file."],
		["Load text…", load_text, "Adds the characters of such a text file (or replaces the list, see above)."]]))
	# the mod's buttons in the classic Modding tab
	menu_button("moddingMenu", -150, -18, "Save Code", save_code, 62, 16)
	menu_button("moddingMenu", -84, -18, "Load Code", load_code, 62, 16)
	menu_button("moddingMenu", 28, 40, "Save Text", save_text, 62, 16)
	menu_button("moddingMenu", 94, 40, "Load Text", load_text, 62, 16)


func save_code() -> void:
	_file.save(g.inGameMenu.getSaveDataString(), "Code.txt")


func load_code() -> void:
	_on_loaded = func(text: String): g.inGameMenu.loadData(_lines(text))
	_file.browse()


func load_text() -> void:
	_on_loaded = func(text: String): import_text(text)
	_file.browse()


func save_text() -> void:
	_file.save(export_text(), "SDTTextBackup.txt")


static func _lines(text: String) -> String:
	return text.replace("\r\n", "\n").replace("\r", "\n")


## The character list in the mod's text format, in menu order.
func export_text() -> String:
	var chars: Array = g.storedChars.duplicate()
	chars.sort_custom(func(a, b): return a.menuPosition < b.menuPosition)
	var out := HEADER + "\n"
	for c in chars:
		out += "StartOfCharacter\n"
		out += str(c.ver) + "\n" + c.charName + "\n" + c.charData + "\n"
		var px: PackedByteArray = c.charShot.getPixels(Rect2i(0, 0, 70, 60)) if c.charShot != null else PackedByteArray()
		out += px.hex_encode() + "\n"
		out += ("true" if c.haveCharShot else "false") + "\n"
		out += str(c.ID) + "\n"
		out += DIALOG_START + "\n" + c.dialogue + "\n" + DIALOG_END + "\n"
		out += str(c.menuPosition) + "\n\n"
	return out


## Reads the mod's text format and hands the characters to the game like its Load Backup does.
func import_text(text: String) -> void:
	var lines := _lines(text).split("\n")
	var list: Array = []
	var i := 0
	while i < lines.size():
		if lines[i] != "StartOfCharacter" or i + 6 >= lines.size():
			i += 1
			continue
		var entry := {"charName": lines[i + 2], "charData": lines[i + 3]}
		var px := lines[i + 4].hex_decode()
		if lines[i + 5] == "true" and px.size() == 70 * 60 * 4:
			entry["shotBytes"] = px.compress(FileAccess.COMPRESSION_DEFLATE)
		var j := i + 6
		var dialog: Array = []
		var adding := false
		while j < lines.size():
			if lines[j] == DIALOG_END:
				j += 1
				break
			if lines[j] == DIALOG_START:
				adding = true
			elif lines[j] == "StartOfCharacter":
				j -= 1
				break
			elif adding:
				dialog.append(lines[j])
			j += 1
		if adding:
			entry["dialogue"] = "\n".join(PackedStringArray(dialog))
		list.append(entry)
		i = j
	if not list.is_empty():
		g.inGameMenu.instanceStoredCharFile(list)
