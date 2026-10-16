extends RefCounted
## Scripted checks (main.gd --driver, use with --save-dir): an overwriting mod clearing the layer with a
## character's rope hair, then hair / character changes after the killed elements' disposal delay (used to hit freed
## objects); text decoding; Flash .sol import guard. Prints "CHECK <name>: <result>".

const SOL_DIR := "Macromedia/Flash Player/#SharedObjects/<flash-id>/localhost/<loader-pack>/Loader5.45/SDT.swf"
var _t := 0
var _android := -1


func _check(n: String, v) -> void:
	print("CHECK %s: %s" % [n, v])


func step(frame: int) -> void:
	match frame:
		20:
			Flash.stage.getChildAt(0).playClicked()
			_decoding()
			_sol()
		40:
			for i in g.characterControl.characters.size():
				if g.characterControl.characters[i].get_script().get_global_name() == "Android18":
					_android = i
			g.characterControl.setChar(_android, false)
			_check("android ropes", g.characterControl.currentElements.size())
		100:
			_check("hair mods", g.modCatalog.hair_entries.map(func(e): return e["title"]))
			# what an overwriting HAIR_COSTUME / dynamic-hair mod does to the layer holding the character's ropes
			g.customElementLoader._clearTarget(g.hairOverLayer)
		101:
			_check("elements after mod (valid)", g.characterControl.currentElements.filter(func(e): return is_instance_valid(e)).size())
		400:
			_check("elements after delay (valid)", g.characterControl.currentElements.filter(func(e): return is_instance_valid(e)).size())
			g.characterControl.randomCurrentElements()
			g.inGameMenu._stepHair(-1)
			_check("hair after step back", [g.inGameMenu.hairModIndex, g.characterControl.currentHair])
		420:
			g.characterControl.setChar(0, false)
			_check("hairModIndex after char change", g.inGameMenu.hairModIndex)
		440:
			g.inGameMenu._stepBG(4)
			_check("bg mod index", g.inGameMenu.bgModIndex)
			g.characterControl.setBackground(2)
			_check("bg mod index after setBackground", [g.inGameMenu.bgModIndex, g.inGameMenu.bgPicker.itemLabel.text])
		700:
			print("CHECK done orphans=", Flash.orphan_stats(5))
			Flash.get_tree().quit()


func _decoding() -> void:
	var cases := {
		"utf8": "héllo ünïcode".to_utf8_buffer(),
		"utf8 bom": PackedByteArray([0xEF, 0xBB, 0xBF]) + "abc".to_utf8_buffer(),
		"utf16le": PackedByteArray([0xFF, 0xFE, 0x61, 0x00, 0xE9, 0x00]),
		"utf16be": PackedByteArray([0xFE, 0xFF, 0x00, 0x61, 0x00, 0xE9]),
		"cp1252": PackedByteArray([0x61, 0x84, 0x41, 0xE9, 0x62]),
		"overlong": PackedByteArray([0x61, 0xE0, 0x80, 0x80, 0x62]),
		"surrogate": PackedByteArray([0xED, 0xA0, 0x80]),
		"mixed": "ok ".to_utf8_buffer() + PackedByteArray([0x93]) + " ünï".to_utf8_buffer(),
	}
	for k in cases:
		var s: String = Flash.bytes_to_string(cases[k])
		_check("decode " + k, "%s %s" % [s.c_escape(), Array(s.to_utf32_buffer().to_int32_array())])


func _sol() -> void:
	var dir := OS.get_environment("APPDATA").path_join(SOL_DIR)
	for f in ["ChoIrrumatio.sol", "ChoIrrumatio_thumbs.sol"]:
		var p := dir.path_join(f)
		if not FileAccess.file_exists(p):
			_check("sol " + f, "missing")
			continue
		AMF3.lastError = ""
		var r = g.inGameMenu._storedCharsFromSol(FileAccess.get_file_as_bytes(p), p)
		_check("sol " + f, "%s err=%s" % [r.size() if r is Array else r, AMF3.lastError])
