extends Node
## Compares SWFFile.render (native rasteriser) with the converter's images of the base game.
## Run: godot --headless --path game res://debug/swf_raster_test.tscn -- [--swf=path] [--n=200] [--out=dir]

func _ready() -> void:
	var swf_path := "extracted/SDT.swf"
	var n := 200
	var out_dir := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--swf="):
			swf_path = a.substr(6)
		elif a.begins_with("--n="):
			n = int(a.substr(4))
		elif a.begins_with("--out="):
			out_dir = a.substr(6)
	var f: Object = ClassDB.instantiate(&"SWFFile")
	var t0 := Time.get_ticks_msec()
	var err: int = f.open(FileAccess.get_file_as_bytes(swf_path))
	print("open: %s in %d ms" % [error_string(err), Time.get_ticks_msec() - t0])
	var lib = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sdt/library.json"))
	var chars: Dictionary = f.get_characters()
	var jobs: Array = []   # [id, ratio, image name]
	for k in lib["chars"]:
		var e: Dictionary = lib["chars"][k]
		if e.get("t") == "shape" and String(e.get("img", "")).begins_with("s"):
			jobs.append([int(k), -1, e["img"]])
		elif e.get("t") == "morph":
			for r in e["ratios"]:
				if e["ratios"][r] != null:
					jobs.append([int(k), int(r), e["ratios"][r]["img"]])
					break
	seed(1)
	jobs.shuffle()
	jobs = jobs.slice(0, n)
	var worst: Array = []
	var total_ms := 0
	var size_mismatch := 0
	var sum_err := 0.0
	var count := 0
	for j in jobs:
		var ts := Time.get_ticks_msec()
		var res: Dictionary = f.render(j[0], j[1], 2.0)
		total_ms += Time.get_ticks_msec() - ts
		var ref_img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/sdt/shapes/%s.png" % j[2]))
		if res.is_empty() or ref_img == null:
			print("  skip %s (render empty=%s)" % [j[2], res.is_empty()])
			continue
		ref_img.convert(Image.FORMAT_RGBA8)
		var img: Image = res["image"]
		if img.get_size() != ref_img.get_size():
			size_mismatch += 1
			print("  size %s: ours %s ref %s" % [j[2], img.get_size(), ref_img.get_size()])
			continue
		var a := img.get_data()
		var b := ref_img.get_data()
		var e_sum := 0.0
		var px := 0
		for i in range(0, a.size(), 4):
			var aa := a[i + 3]
			var ba := b[i + 3]
			if aa == 0 and ba == 0:
				continue
			px += 1
			# compare premultiplied colours
			var d := absf(aa - ba)
			for ch in 3:
				d += absf(a[i + ch] * aa / 255.0 - b[i + ch] * ba / 255.0)
			e_sum += d / 4.0
		var err_px := e_sum / maxf(1.0, px)
		sum_err += err_px
		count += 1
		worst.append([err_px, j[2], img, ref_img])
	worst.sort_custom(func(x, y): return x[0] > y[0])
	print("rendered %d in %d ms; size mismatches %d; mean error per covered px %.2f (0..255)" % [count, total_ms,
		size_mismatch, sum_err / maxf(1, count)])
	for w in worst.slice(0, 10):
		print("  worst %s err %.2f" % [w[1], w[0]])
	if out_dir != "":
		DirAccess.make_dir_recursive_absolute(out_dir)
		for w in worst.slice(0, 6):
			var ours: Image = w[2]
			var ref: Image = w[3]
			var cmp := Image.create_empty(ours.get_width() * 2, ours.get_height(), false, Image.FORMAT_RGBA8)
			cmp.fill(Color(0.45, 0.42, 0.33))
			cmp.blend_rect(ours, Rect2i(Vector2i.ZERO, ours.get_size()), Vector2i.ZERO)
			cmp.blend_rect(ref, Rect2i(Vector2i.ZERO, ref.get_size()), Vector2i(ours.get_width(), 0))
			cmp.save_png(out_dir.path_join("%s_cmp.png" % w[1]))
	get_tree().quit()
