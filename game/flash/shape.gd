class_name FlashShape
extends FlashDisplayObject
## A static vector shape (DefineShape / static text) or a morph shape at a given ratio.
##
## This is the only class that knows how artwork is drawn. The current backend draws pre-rasterised
## textures produced by tools/swfconv; a vector-mesh backend would replace _draw / _hit_shape here only.

var _entry: Dictionary = {}      # library image entry: img, x, y, w, h, hm
var _morph: Dictionary = {}      # morph character entry (ratios -> image entry), if a morph shape
var _ratio: int = 0
var _texture: Texture2D = null


func setup(library, char_id: int, ratio: int = 0) -> void:
	_library = library
	_char_id = char_id
	var c: Dictionary = library.get_char(char_id)
	if c.get("t") == "morph":
		_morph = c
		set_ratio(ratio)
	else:
		_set_entry(c)


func set_ratio(ratio: int) -> void:
	if _morph.is_empty() or (ratio == _ratio and not _entry.is_empty()):
		return
	_ratio = ratio
	var e = _morph["ratios"].get(str(ratio))
	if e == null:
		e = _nearest_ratio(ratio)
	_set_entry(e if e != null else {})


func _nearest_ratio(ratio: int):
	var best = null
	var best_d := 1 << 30
	for k in _morph["ratios"]:
		var d: int = absi(int(k) - ratio)
		if d < best_d and _morph["ratios"][k] != null:
			best_d = d
			best = _morph["ratios"][k]
	return best


func _set_entry(e: Dictionary) -> void:
	_entry = e
	_texture = _library.get_texture(e["img"]) if e.has("img") else null
	queue_redraw()


func _draw() -> void:
	if _texture == null:
		return
	var s: float = _library.scale
	draw_texture_rect(_texture, Rect2(_entry["x"], _entry["y"], _texture.get_width() / s, _texture.get_height() / s), false)


func _local_bounds() -> Rect2:
	if _entry.is_empty():
		return Rect2()
	return Rect2(_entry["x"], _entry["y"], _entry["w"], _entry["h"])


func _hit_shape(p: Vector2) -> bool:
	if _entry.is_empty() or not _entry.has("hm"):
		return false
	return _library.hit_mask_test(_entry, p)


func _render_state_changed() -> void:
	material = Flash.shape_material(self)
