extends Node
## Loads SWF mods through FlashLoader (like the game's mod menu) and prints what the game would see.
## Run: godot --headless --path game res://debug/mod_load_test.tscn -- --mod=<path.swf> [--mod=...] [--list=<file>]

var _queue: Array = []
var _ok := 0
var _fail := 0
var _t0 := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mod="):
			_queue.append(a.substr(6))
		elif a.begins_with("--list="):
			for line in FileAccess.get_file_as_string(a.substr(7)).split("\n"):
				if line.strip_edges() != "":
					_queue.append(line.strip_edges())
	_t0 = Time.get_ticks_msec()
	_next()


func _next() -> void:
	if _queue.is_empty():
		print("done: %d ok, %d failed, %d ms" % [_ok, _fail, Time.get_ticks_msec() - _t0])
		get_tree().quit()
		return
	var path: String = _queue.pop_front()
	print("LOADING ", path)
	var l := FlashLoader.new()
	l.contentLoaderInfo.addEventListener(FlashEvent.INIT, func(e): _inited(path, e.target.content))
	l.contentLoaderInfo.addEventListener(FlashEvent.IO_ERROR, func(e): _failed(path, e.text))
	l.load(path)


func _failed(path: String, msg: String) -> void:
	print("FAIL %s: %s" % [path.get_file(), msg])
	_fail += 1
	_next.call_deferred()


func _inited(path: String, c) -> void:
	var mv = c.get("MOD_VERSION") if c != null else null
	if mv == null:
		print("NOT A MOD %s (%s)" % [path.get_file(), c])
		_fail += 1
		_next.call_deferred()
		return
	_ok += 1
	print("MOD %s: '%s' by '%s' type=%s charData=%s dialogue=%s" % [path.get_file(), c.get("modName"), c.get("modCreator"),
		c.get("modType"), str(c.get("charData")).left(40), c.get("dialogueName")])
	var mods = c.get("mods")
	for m in (mods if mods != null else []):
		if m == null:
			print("   <null mod>")
		elif m is DialogueMod:
			print("   dialogue %s: %s%s" % [m.lineType, m.dialogueLine.left(50), " (audio)" if m.audio else ""])
		elif m is FlashDisplayObject:
			var names := PackedStringArray()
			for i in m.numChildren:
				names.append(m.getChildAt(i).flash_name)
			print("   %s %s target=%s overwrite=%s children=%s" % [m.flash_name, m.get("modType"), m.get("targetElement"),
				m.get("overwrite"), names])
		else:
			print("   ? %s" % m)
	_next.call_deferred()
