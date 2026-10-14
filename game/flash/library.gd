class_name FlashLibrary
extends RefCounted
## A converted SWF (see tools/swfconv): symbol table, timelines, and lazily-loaded artwork.
##
## The base game is one library; every converted mod is another. Character ids are local to a library.

var path: String                 # folder containing library.json
var scale: float = 2.0           # bake scale of the shape images
var chars: Dictionary = {}       # str(id) -> entry
var classes: Dictionary = {}     # fully qualified AS3 class name -> id
var root: Dictionary = {}        # main timeline
var document_class: String = ""
var width: float = 700.0
var height: float = 600.0
var fps: float = 30.0

var _textures: Dictionary = {}

## Morph shapes have one image per ratio (~15k in the base game, several GB of VRAM in total), so their textures
## are streamed: loaded on worker threads on first use and kept in an LRU cache of at most morph_cache_bytes.
static var morph_cache_bytes: int = 1024 * 1048576
static var _streaming: Array[FlashLibrary] = []   # libraries with loads in flight
var _lru: Dictionary = {}        # img -> bytes, least recently used first (insertion order)
var _lru_bytes := 0
var _pending: Dictionary = {}    # img -> Array of FlashShape waiting for it
## The headless dummy renderer cannot create textures off the main thread.
static var _threaded: bool = DisplayServer.get_name() != "headless"
var _hit_masks: PackedByteArray = PackedByteArray()
var _hit_masks_loaded := false


static func load_from(dir: String) -> FlashLibrary:
	var f := FileAccess.open(dir.path_join("library.json"), FileAccess.READ)
	if f == null:
		push_error("FlashLibrary: cannot open %s" % dir)
		return null
	var data = JSON.parse_string(f.get_as_text())
	if data == null:
		push_error("FlashLibrary: bad json in %s" % dir)
		return null
	var lib := FlashLibrary.new()
	lib.path = dir
	lib.scale = float(data.get("scale", 2))
	lib.chars = data["chars"]
	lib.classes = data.get("classes", {})
	lib.root = data.get("root", {})
	lib.document_class = data.get("documentClass", "")
	lib.width = data.get("width", 700.0)
	lib.height = data.get("height", 600.0)
	lib.fps = data.get("fps", 30.0)
	return lib


func get_char(id: int) -> Dictionary:
	return chars.get(str(id), {})


func class_id(cls: String) -> int:
	return int(classes.get(cls, -1))


func get_texture(img: String) -> Texture2D:
	var t: Texture2D = _textures.get(img)
	if t != null:
		_touch(img)
		return t
	var p := path.path_join("shapes/%s.png" % img)
	if p.begins_with("res://"):
		Flash.prof_count("#texture loads (blocking)")
		t = load(p)   # waits for an in-flight background load of the same file
	else:
		# Mods converted at runtime / outside the project are plain PNG files.
		var image := Image.load_from_file(p)
		if image != null:
			image.generate_mipmaps()
			t = ImageTexture.create_from_image(image)
	_cache(img, t)
	return t


## Non-blocking get for morph frames: returns the texture if it is cached, otherwise starts loading it on a worker
## thread and returns null; 'waiter' (if any) gets _texture_ready(img, texture) once it has loaded.
func request_texture(img: String, waiter: Object = null) -> Texture2D:
	var t: Texture2D = _textures.get(img)
	if t != null:
		_touch(img)
		return t
	var p := path.path_join("shapes/%s.png" % img)
	if not p.begins_with("res://") or not _threaded:
		return get_texture(img)
	if not _pending.has(img):
		if ResourceLoader.load_threaded_request(p, "Texture2D") != OK:
			return get_texture(img)
		Flash.prof_count("#texture loads (background)")
		_pending[img] = []
		if _streaming.is_empty() or not _streaming.has(self):
			_streaming.append(self)
	if waiter != null and not _pending[img].has(waiter):
		_pending[img].append(waiter)
	return null


func is_texture_cached(img: String) -> bool:
	return _textures.get(img) != null


## Called once per tick by the runtime: hands finished background loads to their waiting shapes.
static func poll_streaming() -> void:
	var i := 0
	while i < _streaming.size():
		var lib := _streaming[i]
		for img in lib._pending.keys():
			lib._poll_one(img)
		if lib._pending.is_empty():
			_streaming.remove_at(i)
		else:
			i += 1


func _poll_one(img: String) -> bool:
	var p := path.path_join("shapes/%s.png" % img)
	var st := ResourceLoader.load_threaded_get_status(p)
	if st == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return false
	var t: Texture2D = ResourceLoader.load_threaded_get(p) if st == ResourceLoader.THREAD_LOAD_LOADED else null
	var waiters: Array = _pending[img]
	_pending.erase(img)
	if t == null:
		t = load(p)
	_cache(img, t)
	for w in waiters:
		if is_instance_valid(w):
			w._texture_ready(img, t)
	return true


func _cache(img: String, t: Texture2D) -> void:
	_textures[img] = t
	if t == null or not img.begins_with("m"):
		return
	if _lru.has(img):
		_touch(img)
		return
	var bytes := t.get_width() * t.get_height() * 16 / 3   # RGBA8 + mipmaps
	_lru[img] = bytes
	_lru_bytes += bytes
	while _lru_bytes > morph_cache_bytes and _lru.size() > 1:
		var oldest: String
		for k in _lru:
			oldest = k
			break
		_lru_bytes -= _lru[oldest]
		_lru.erase(oldest)
		# shapes still showing it keep their own reference
		_textures.erase(oldest)


func _touch(img: String) -> void:
	var b = _lru.get(img)
	if b != null:
		_lru.erase(img)
		_lru[img] = b


var _images: Dictionary = {}


## CPU copy of a shape image (for software rendering into BitmapData).
func get_image(img: String) -> Image:
	var im: Image = _images.get(img)
	if im == null:
		var p := path.path_join("shapes/%s.png" % img)
		if p.begins_with("res://"):
			var tex: Texture2D = load(p)
			im = tex.get_image() if tex != null else null
		else:
			im = Image.load_from_file(p)
		if im != null:
			if im.is_compressed():
				im.decompress()
			if im.has_mipmaps():
				im.clear_mipmaps()
			im.convert(Image.FORMAT_RGBA8)
		_images[img] = im
	return im


func file_path(rel: String) -> String:
	return path.path_join(rel)


## Tests p (shape-local, pixels) against the 1-bit 1x coverage mask produced by the converter.
func hit_mask_test(entry: Dictionary, p: Vector2) -> bool:
	if not _hit_masks_loaded:
		_hit_masks_loaded = true
		var f := FileAccess.open(path.path_join("hitmasks.bin"), FileAccess.READ)
		if f != null:
			_hit_masks = f.get_buffer(f.get_length())
	var hm: Array = entry["hm"]
	var x := int(floor(p.x - entry["x"]))
	var y := int(floor(p.y - entry["y"]))
	var w: int = hm[1]
	var h: int = hm[2]
	if x < 0 or y < 0 or x >= w or y >= h:
		return false
	var bit := y * w + x
	var byte_i: int = int(hm[0]) + (bit >> 3)
	if byte_i >= _hit_masks.size():
		return false
	return (_hit_masks[byte_i] >> (bit & 7)) & 1 == 1
