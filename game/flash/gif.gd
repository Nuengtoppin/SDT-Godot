class_name FlashGif
extends RefCounted
## Minimal GIF decoder (first frame only) for images loaded through Loader, which Flash supported and Godot's Image
## does not. Handles global/local palettes, transparency (graphic control extension) and interlacing.


static func decode_first_frame(b: PackedByteArray) -> Image:
	if b.size() < 13 or b.slice(0, 3).get_string_from_ascii() != "GIF":
		return null
	var w := b[6] | (b[7] << 8)
	var h := b[8] | (b[9] << 8)
	var flags := b[10]
	var pos := 13
	var gpal := PackedByteArray()
	if flags & 0x80:
		var n := 3 * (1 << ((flags & 7) + 1))
		gpal = b.slice(pos, pos + n)
		pos += n
	var transparent := -1
	var out := PackedByteArray()
	out.resize(w * h * 4)
	out.fill(0)
	while pos < b.size():
		var block := b[pos]
		pos += 1
		if block == 0x21:
			var label := b[pos]
			pos += 1
			if label == 0xF9 and b[pos] >= 4:
				if b[pos + 1] & 1:
					transparent = b[pos + 4]
			while pos < b.size() and b[pos] != 0:
				pos += b[pos] + 1
			pos += 1
		elif block == 0x2C:
			var ix := b[pos] | (b[pos + 1] << 8)
			var iy := b[pos + 2] | (b[pos + 3] << 8)
			var iw := b[pos + 4] | (b[pos + 5] << 8)
			var ih := b[pos + 6] | (b[pos + 7] << 8)
			var iflags := b[pos + 8]
			pos += 9
			var pal := gpal
			if iflags & 0x80:
				var n := 3 * (1 << ((iflags & 7) + 1))
				pal = b.slice(pos, pos + n)
				pos += n
			var min_code := b[pos]
			pos += 1
			var data := PackedByteArray()
			while pos < b.size() and b[pos] != 0:
				var n := b[pos]
				data.append_array(b.slice(pos + 1, pos + 1 + n))
				pos += n + 1
			pos += 1
			var idx := _lzw(data, min_code, iw * ih)
			var rows := _row_order(ih, (iflags & 0x40) != 0)
			for r in ih:
				var yy: int = iy + rows[r]
				if yy >= h:
					continue
				for c in iw:
					var xx := ix + c
					if xx >= w:
						continue
					var k := r * iw + c
					if k >= idx.size():
						break
					var ci := idx[k]
					if ci == transparent or ci * 3 + 2 >= pal.size():
						continue
					var o := (yy * w + xx) * 4
					out[o] = pal[ci * 3]
					out[o + 1] = pal[ci * 3 + 1]
					out[o + 2] = pal[ci * 3 + 2]
					out[o + 3] = 255
			return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, out)
		else:
			break
	return null


static func _row_order(h: int, interlaced: bool) -> PackedInt32Array:
	var rows := PackedInt32Array()
	if not interlaced:
		for i in h:
			rows.append(i)
		return rows
	for pass_ in [[0, 8], [4, 8], [2, 4], [1, 2]]:
		var y: int = pass_[0]
		while y < h:
			rows.append(y)
			y += pass_[1]
	return rows


static func _lzw(data: PackedByteArray, min_code: int, max_out: int) -> PackedByteArray:
	var out := PackedByteArray()
	var clear := 1 << min_code
	var eoi := clear + 1
	var size := min_code + 1
	var dict_prefix := PackedInt32Array()
	var dict_suffix := PackedByteArray()
	var dict_first := PackedByteArray()
	dict_prefix.resize(4096)
	dict_suffix.resize(4096)
	dict_first.resize(4096)
	for i in clear:
		dict_prefix[i] = -1
		dict_suffix[i] = i
		dict_first[i] = i
	var next := eoi + 1
	var prev := -1
	var bitpos := 0
	var nbits := data.size() * 8
	var stack := PackedByteArray()
	while bitpos + size <= nbits and out.size() < max_out:
		var code := 0
		for i in size:
			var bp := bitpos + i
			if data[bp >> 3] & (1 << (bp & 7)):
				code |= 1 << i
		bitpos += size
		if code == clear:
			size = min_code + 1
			next = eoi + 1
			prev = -1
			continue
		if code == eoi:
			break
		var cur := code
		var first: int
		if code < next:
			first = dict_first[code]
		elif prev >= 0:
			first = dict_first[prev]
			cur = prev
		else:
			break
		stack.clear()
		var c := cur
		while c >= 0:
			stack.append(dict_suffix[c])
			c = dict_prefix[c]
		stack.reverse()
		out.append_array(stack)
		if code >= next:
			out.append(first)
		if prev >= 0 and next < 4096:
			dict_prefix[next] = prev
			dict_suffix[next] = first if code >= next else dict_first[code]
			dict_first[next] = dict_first[prev]
			next += 1
			if next == (1 << size) and size < 12:
				size += 1
		prev = code
	return out
