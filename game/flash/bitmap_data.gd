class_name FlashBitmapData
extends RefCounted
## flash.display.BitmapData backed by an Image (CPU) with a lazily-updated texture (GPU).
## Colours use Flash's 0xAARRGGBB / 0xRRGGBB integers.

var image: Image
var transparent := true
var _texture: ImageTexture = null
var _tex_dirty := true


func _init(w: int = 1, h: int = 1, p_transparent: bool = true, fill_color: int = 0xFFFFFFFF) -> void:
	transparent = p_transparent
	image = Image.create_empty(maxi(w, 1), maxi(h, 1), false, Image.FORMAT_RGBA8)
	image.fill(argb_to_color(fill_color if p_transparent else (fill_color | 0xFF000000)))


static func from_image(img: Image) -> FlashBitmapData:
	var b := FlashBitmapData.new(1, 1)
	b.image = img
	if b.image.get_format() != Image.FORMAT_RGBA8:
		b.image.convert(Image.FORMAT_RGBA8)
	b._tex_dirty = true
	return b


static func from_library(lib: FlashLibrary, id: int) -> FlashBitmapData:
	var c: Dictionary = lib.get_char(id)
	if not c.has("file"):
		return FlashBitmapData.new(1, 1)
	var p := lib.file_path(c["file"])
	var img: Image
	if p.begins_with("res://"):
		var tex: Texture2D = load(p)
		img = tex.get_image() if tex != null else null
	else:
		img = Image.load_from_file(p)
	if img == null:
		return FlashBitmapData.new(1, 1)
	if img.is_compressed():
		img.decompress()
	return from_image(img)


static func argb_to_color(c: int) -> Color:
	return Color8((c >> 16) & 0xFF, (c >> 8) & 0xFF, c & 0xFF, (c >> 24) & 0xFF)


static func color_to_argb(c: Color) -> int:
	return (c.a8 << 24) | (c.r8 << 16) | (c.g8 << 8) | c.b8


var width: int:
	get:
		return image.get_width()

var height: int:
	get:
		return image.get_height()

var rect: Rect2i:
	get:
		return Rect2i(0, 0, image.get_width(), image.get_height())


func get_texture() -> Texture2D:
	if _texture == null:
		_texture = ImageTexture.create_from_image(image)
		_tex_dirty = false
	elif _tex_dirty:
		if _texture.get_size() == Vector2(image.get_size()):
			_texture.update(image)
		else:
			_texture = ImageTexture.create_from_image(image)
		_tex_dirty = false
	return _texture


func mark_dirty() -> void:
	_tex_dirty = true


func getPixel(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= width or y >= height:
		return 0
	return color_to_argb(image.get_pixel(x, y)) & 0xFFFFFF


func getPixel32(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= width or y >= height:
		return 0
	return color_to_argb(image.get_pixel(x, y))


func setPixel(x: int, y: int, c: int) -> void:
	if x >= 0 and y >= 0 and x < width and y < height:
		image.set_pixel(x, y, argb_to_color(c | 0xFF000000))
		_tex_dirty = true


func setPixel32(x: int, y: int, c: int) -> void:
	if x >= 0 and y >= 0 and x < width and y < height:
		image.set_pixel(x, y, argb_to_color(c))
		_tex_dirty = true


func fillRect(r: Rect2i, c: int) -> void:
	image.fill_rect(r, argb_to_color(c if transparent else (c | 0xFF000000)))
	_tex_dirty = true


func copyPixels(source: FlashBitmapData, source_rect: Rect2i, dest: Vector2i) -> void:
	image.blit_rect(source.image, source_rect, dest)
	_tex_dirty = true


func clone() -> FlashBitmapData:
	var b := FlashBitmapData.from_image(image.duplicate())
	b.transparent = transparent
	return b


func dispose() -> void:
	image = Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)
	_texture = null


## BitmapData.merge: per channel new = (src * mult + dst * (256 - mult)) / 256 (multipliers 0..256).
func merge(source: FlashBitmapData, source_rect: Rect2i, dest: Vector2i, rm: int, gm: int, bm: int, am: int) -> void:
	var src := source.image.get_data()
	var dst := image.get_data()
	var sw := source.width
	var dw := width
	var mults := [rm, gm, bm, am]
	for yy in source_rect.size.y:
		var sy := source_rect.position.y + yy
		var dy := dest.y + yy
		if sy < 0 or sy >= source.height or dy < 0 or dy >= height:
			continue
		for xx in source_rect.size.x:
			var sx := source_rect.position.x + xx
			var dx := dest.x + xx
			if sx < 0 or sx >= sw or dx < 0 or dx >= dw:
				continue
			var si := (sy * sw + sx) * 4
			var di := (dy * dw + dx) * 4
			for ch in 4:
				var m: int = mults[ch]
				dst[di + ch] = (src[si + ch] * m + dst[di + ch] * (256 - m)) >> 8
	image.set_data(width, height, false, Image.FORMAT_RGBA8, dst)
	_tex_dirty = true


## BitmapData.draw for shape-based display objects: software-renders obj's shapes through matrix m
## (bilinear sampling, normal alpha compositing), applying the colour transform ct.
func draw(obj: FlashDisplayObject, m: Transform2D = Transform2D.IDENTITY, ct: FlashColorTransform = null,
		clip: Rect2i = Rect2i()) -> void:
	var dst := image.get_data()
	_draw_rec(obj, m, ct if ct != null else FlashColorTransform.new(), dst, clip if clip.size != Vector2i.ZERO else rect)
	image.set_data(width, height, false, Image.FORMAT_RGBA8, dst)
	_tex_dirty = true


func _draw_rec(o: FlashDisplayObject, m: Transform2D, ct: FlashColorTransform, dst: PackedByteArray, clip: Rect2i) -> void:
	if o is FlashShape:
		var s: FlashShape = o
		if s._entry.is_empty() or not s._entry.has("img"):
			return
		var img: Image = s._library.get_image(s._entry["img"])
		if img == null:
			return
		var sc: float = s._library.scale
		var e: Dictionary = s._entry
		# shape-local -> image pixel: (p - entry.xy) * scale ; dest pixel -> shape-local: inverse of m
		var inv := m.affine_inverse()
		var r := FlashDisplayObject._xform_rect(m, Rect2(e["x"], e["y"], img.get_width() / sc, img.get_height() / sc))
		var x0 := maxi(clip.position.x, int(floor(r.position.x)))
		var y0 := maxi(clip.position.y, int(floor(r.position.y)))
		var x1 := mini(clip.end.x, int(ceil(r.end.x)))
		var y1 := mini(clip.end.y, int(ceil(r.end.y)))
		var iw := img.get_width()
		var ih := img.get_height()
		var dw := width
		for py in range(y0, y1):
			for px in range(x0, x1):
				var lp := inv * Vector2(px + 0.5, py + 0.5)
				var ix: float = (lp.x - e["x"]) * sc - 0.5
				var iy: float = (lp.y - e["y"]) * sc - 0.5
				if ix < -1 or iy < -1 or ix > iw or iy > ih:
					continue
				var c := _bilinear(img, ix, iy, iw, ih)
				if c.a <= 0.0:
					continue
				c = Color(c.r * ct.redMultiplier + ct.redOffset / 255.0, c.g * ct.greenMultiplier + ct.greenOffset / 255.0,
					c.b * ct.blueMultiplier + ct.blueOffset / 255.0, c.a * ct.alphaMultiplier + ct.alphaOffset / 255.0)
				c = c.clamp()
				var di := (py * dw + px) * 4
				var da := dst[di + 3] / 255.0
				var oa := c.a + da * (1.0 - c.a)
				if oa <= 0.0:
					continue
				for ch in 3:
					var sv: float = c[ch]
					var dv := dst[di + ch] / 255.0
					dst[di + ch] = clampi(int((sv * c.a + dv * da * (1.0 - c.a)) / oa * 255.0 + 0.5), 0, 255)
				dst[di + 3] = clampi(int(oa * 255.0 + 0.5), 0, 255)
	elif o is FlashSprite:
		for ch in (o as FlashSprite)._children:
			if ch.visible:
				var cct: FlashColorTransform = ch.colorTransform
				cct.concat(ct)
				_draw_rec(ch, m * ch.transform, cct, dst, clip)


static func _bilinear(img: Image, x: float, y: float, w: int, h: int) -> Color:
	var x0 := int(floor(x))
	var y0 := int(floor(y))
	var fx := x - x0
	var fy := y - y0
	var c00 := _px(img, x0, y0, w, h)
	var c10 := _px(img, x0 + 1, y0, w, h)
	var c01 := _px(img, x0, y0 + 1, w, h)
	var c11 := _px(img, x0 + 1, y0 + 1, w, h)
	# interpolate premultiplied to avoid dark fringes
	var p := (c00 * (1 - fx) * (1 - fy)) + (c10 * fx * (1 - fy)) + (c01 * (1 - fx) * fy) + (c11 * fx * fy)
	if p.a <= 0.0:
		return Color(0, 0, 0, 0)
	return Color(p.r / p.a, p.g / p.a, p.b / p.a, p.a)


static func _px(img: Image, x: int, y: int, w: int, h: int) -> Color:
	if x < 0 or y < 0 or x >= w or y >= h:
		return Color(0, 0, 0, 0)
	var c := img.get_pixel(x, y)
	return Color(c.r * c.a, c.g * c.a, c.b * c.a, c.a)


## Copies a region of another bitmap with an offset (BitmapData.draw(otherBitmapData, translate) case).
func draw_bitmap(source: FlashBitmapData, offset: Vector2i, clip: Rect2i) -> void:
	var src_rect := Rect2i(clip.position - offset, clip.size)
	image.blend_rect(source.image, src_rect, clip.position)
	_tex_dirty = true


## Pixels of 'r' as 0xAARRGGBB big-endian bytes (Flash ByteArray layout).
func getPixels(r: Rect2i) -> PackedByteArray:
	var sub := image.get_region(r)
	var src := sub.get_data()
	var out := PackedByteArray()
	out.resize(src.size())
	for i in range(0, src.size(), 4):
		out[i] = src[i + 3]
		out[i + 1] = src[i]
		out[i + 2] = src[i + 1]
		out[i + 3] = src[i + 2]
	return out


func setPixels(r: Rect2i, bytes: PackedByteArray) -> void:
	var data := PackedByteArray()
	data.resize(r.size.x * r.size.y * 4)
	for i in range(0, mini(data.size(), bytes.size()), 4):
		data[i] = bytes[i + 1]
		data[i + 1] = bytes[i + 2]
		data[i + 2] = bytes[i + 3]
		data[i + 3] = bytes[i]
	var sub := Image.create_from_data(r.size.x, r.size.y, false, Image.FORMAT_RGBA8, data)
	image.blit_rect(sub, Rect2i(Vector2i.ZERO, r.size), r.position)
	mark_dirty()
