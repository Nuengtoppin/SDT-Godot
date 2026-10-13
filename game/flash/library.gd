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
	if t == null:
		var p := path.path_join("shapes/%s.png" % img)
		if p.begins_with("res://"):
			t = load(p)
		else:
			# Mods converted at runtime / outside the project are plain PNG files.
			var image := Image.load_from_file(p)
			if image != null:
				image.generate_mipmaps()
				t = ImageTexture.create_from_image(image)
		_textures[img] = t
	return t


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
