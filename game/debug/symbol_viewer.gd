extends Node2D
## Debug tool: renders a library symbol and saves a screenshot, for comparison with FFDec reference renders.
##
## Usage: godot --path game res://debug/symbol_viewer.tscn -- --id 123 [--frame 1|label] [--zoom 1] [--out file.png]
##        (or --class Her instead of --id). Without --out it stays open for inspection.

var _out := ""
var _frames_left := 4


func _ready() -> void:
	var args := _parse_args()
	Flash.paused = args.get("play", "0") == "0"
	Flash.attach_stage(self)
	var obj: FlashDisplayObject = null
	var t0 := Time.get_ticks_usec()
	if args.has("class"):
		obj = Flash.create(args["class"])
	else:
		obj = Flash.create_char(Flash.base_library, int(args.get("id", "1")))
	print("create: %.1f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
	if obj == null:
		push_error("symbol_viewer: could not create symbol")
		get_tree().quit(1)
		return
	if args.has("frame") and obj is FlashMovieClip:
		var f: String = args["frame"]
		(obj as FlashMovieClip).gotoAndStop(int(f) if f.is_valid_int() else f)
	elif obj is FlashMovieClip:
		(obj as FlashMovieClip).stop()
	if args.has("blend"):
		obj.blendMode = args["blend"]
	var zoom := float(args.get("zoom", "1"))
	t0 = Time.get_ticks_usec()
	Flash.stage.addChild(obj)
	print("attach: %.1f ms, nodes: %d" % [(Time.get_ticks_usec() - t0) / 1000.0, _count(obj)])
	var b := obj.getBounds(Flash.stage)
	obj.scale = Vector2(zoom, zoom)
	obj.position = -b.position * zoom + Vector2(4, 4)
	print("bounds: ", b)
	if args.has("dump"):
		_dump(obj, 0, int(args["dump"]))
	_out = args.get("out", "")
	if _out != "":
		get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		get_window().size = Vector2i(ceili(b.size.x * zoom) + 8, ceili(b.size.y * zoom) + 8)
		RenderingServer.set_default_clear_color(Color(0.5, 0.5, 0.5))


func _parse_args() -> Dictionary:
	var out := {}
	var a := OS.get_cmdline_user_args()
	var i := 0
	while i < a.size():
		if a[i].begins_with("--") and i + 1 < a.size():
			out[a[i].substr(2)] = a[i + 1]
			i += 2
		else:
			i += 1
	return out


func _process(_d: float) -> void:
	if _out == "":
		return
	_frames_left -= 1
	if _frames_left == 0:
		var img := get_viewport().get_texture().get_image()
		img.save_png(_out)
		print("saved ", _out)
		get_tree().quit()


func _dump(o: FlashDisplayObject, indent: int, max_depth: int) -> void:
	var info := "%s%s #%d d=%d" % ["  ".repeat(indent), o.flash_name if o.flash_name != "" else "-", o._char_id, o._depth]
	if o._clip_depth:
		info += " CLIP->%d" % o._clip_depth
	if o._blend_mode != "normal":
		info += " blend=" + o._blend_mode
	if not o._filters.is_empty():
		info += " filters=%d" % o._filters.size()
	if o._mask_hidden:
		info += " MASKHIDDEN vl=%d" % o.visibility_layer
	if not o.visible:
		info += " invisible"
	if o is FlashMovieClip:
		info += " f%d/%d" % [o.currentFrame, o.totalFrames]
	if o is FlashShape:
		info += " shape"
	var b := o.getBounds(Flash.stage)
	info += " [%d,%d %dx%d]" % [b.position.x, b.position.y, b.size.x, b.size.y]
	print(info)
	if indent < max_depth and o is FlashSprite:
		for c in o._children:
			_dump(c, indent + 1, max_depth)


func _count(n: Node) -> int:
	var c := 1
	for ch in n.get_children():
		c += _count(ch)
	return c
