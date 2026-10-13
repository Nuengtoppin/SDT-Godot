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
