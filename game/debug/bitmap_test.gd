extends Node
## Checks FlashBitmapData's bounds-tracking fast paths against the plain per-pixel BitmapData.merge formula.
## Run: godot --headless --path game res://debug/bitmap_test.tscn

var failures := 0


func _ready() -> void:
	seed(1234)
	for trial in 40:
		_merge_trial(trial)
	print("bitmap_test: %s (%d failures)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(1 if failures else 0)


## Reference: per channel new = (src * mult + dst * (256 - mult)) >> 8 over the clipped rectangle.
func _reference_merge(dst: PackedByteArray, dw: int, dh: int, src: PackedByteArray, sw: int, sh: int,
		sr: Rect2i, dest: Vector2i, mults: Array) -> void:
	for yy in sr.size.y:
		for xx in sr.size.x:
			var sx := sr.position.x + xx
			var sy := sr.position.y + yy
			var dx := dest.x + xx
			var dy := dest.y + yy
			if sx < 0 or sy < 0 or sx >= sw or sy >= sh or dx < 0 or dy < 0 or dx >= dw or dy >= dh:
				continue
			var si := (sy * sw + sx) * 4
			var di := (dy * dw + dx) * 4
			for ch in 4:
				dst[di + ch] = (src[si + ch] * mults[ch] + dst[di + ch] * (256 - mults[ch])) >> 8


func _random_paint(b: FlashBitmapData) -> void:
	# a few opaque-ish / translucent rectangles and pixels, through the public API so bounds are tracked
	for i in randi_range(0, 4):
		var r := Rect2i(randi_range(-5, b.width), randi_range(-5, b.height), randi_range(1, 30), randi_range(1, 30))
		b.fillRect(r, (randi_range(1, 255) << 24) | randi_range(0, 0xFFFFFF))
	for i in randi_range(0, 10):
		b.setPixel32(randi_range(0, b.width - 1), randi_range(0, b.height - 1), (randi_range(1, 255) << 24) | randi())


func _merge_trial(trial: int) -> void:
	var w := randi_range(10, 80)
	var h := randi_range(10, 80)
	var src := FlashBitmapData.new(w, h, true, 0)
	_random_paint(src)
	var dst := FlashBitmapData.new(w, h, true, 0)
	if trial % 2 == 0:
		_random_paint(dst)
	# fade idiom used by Tears: clear, then merge a clone back with alpha 255
	var fade := trial % 3 == 0
	var mults := [256, 256, 256, 255] if fade else [randi_range(0, 256), randi_range(0, 256), randi_range(0, 256), randi_range(0, 256)]
	var sr := Rect2i(randi_range(-3, 5), randi_range(-3, 5), randi_range(1, w + 5), randi_range(1, h + 5))
	var dest := Vector2i(randi_range(-3, 5), randi_range(-3, 5))
	if fade:
		sr = Rect2i(0, 0, w, h)
		dest = Vector2i.ZERO
		src = dst.clone() if trial % 2 == 0 else src
		dst.fillRect(Rect2i(0, 0, w, h), 0)
	var expect := dst.image.get_data()
	_reference_merge(expect, w, h, src.image.get_data(), src.width, src.height, sr, dest, mults)
	dst.merge(src, sr, dest, mults[0], mults[1], mults[2], mults[3])
	var got := dst.image.get_data()
	# pixels that end up fully transparent may differ in RGB (the fast path zeroes them); compare premultiplied
	for i in range(0, got.size(), 4):
		var ea := expect[i + 3]
		var ga := got[i + 3]
		var same := ea == ga and (ea == 0 or (expect[i] == got[i] and expect[i + 1] == got[i + 1] and expect[i + 2] == got[i + 2]))
		if not same:
			failures += 1
			print("trial %d pixel %d: expected %s got %s" % [trial, i / 4, expect.slice(i, i + 4), got.slice(i, i + 4)])
			return
	# bounds must cover every non-transparent pixel
	var b := dst._bounds
	for y in h:
		for x in w:
			if got[(y * w + x) * 4 + 3] != 0 and not b.has_point(Vector2i(x, y)):
				failures += 1
				print("trial %d: pixel %d,%d outside bounds %s" % [trial, x, y, b])
				return
