extends Node
## Debug: opens a SWF with SWFFile and exercises every character (prints before each step, to locate crashes).
## Run: godot --headless --path game res://debug/swf_probe.tscn -- --swf=<path>

func _ready() -> void:
	var path := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--swf="):
			path = a.substr(6)
	var f: Object = ClassDB.instantiate(&"SWFFile")
	print("open ", f.open(FileAccess.get_file_as_bytes(path)))
	var chars: Dictionary = f.get_characters()
	print("chars ", chars.size())
	for cid in chars:
		var t: String = chars[cid]["type"]
		printraw("%s %s ... " % [cid, t])
		match t:
			"shape", "morph", "text":
				var r: Dictionary = f.render(int(cid), 0 if t == "morph" else -1, 2.0)
				print("ok %s" % ("empty" if r.is_empty() else str(r["image"].get_size())))
			"sprite":
				print("ok frames %d" % (f.get_timeline(int(cid))[0] as Array).size())
			"bitmap":
				var img = f.get_bitmap(int(cid))
				print("ok %s" % (img.get_size() if img else "null"))
			_:
				print("skip")
	print("abc blocks ", f.get_abc_blocks().size())
	get_tree().quit()
