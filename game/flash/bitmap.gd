class_name FlashBitmap
extends FlashDisplayObject
## flash.display.Bitmap: draws a FlashBitmapData at the origin.

var bitmap_data: FlashBitmapData:
	set(value):
		bitmap_data = value
		queue_redraw()

var smoothing := true:
	set(value):
		smoothing = value
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if value else CanvasItem.TEXTURE_FILTER_NEAREST


func _init(data: FlashBitmapData = null, _pixel_snapping: String = "auto", p_smoothing: bool = true) -> void:
	bitmap_data = data
	smoothing = p_smoothing


## Call after modifying bitmap_data's pixels.
func refresh() -> void:
	queue_redraw()


func _draw() -> void:
	if bitmap_data != null:
		draw_texture(bitmap_data.get_texture(), Vector2.ZERO)


func _local_bounds() -> Rect2:
	if bitmap_data == null:
		return Rect2()
	return Rect2(0, 0, bitmap_data.width, bitmap_data.height)


func _hit_shape(p: Vector2) -> bool:
	return _local_bounds().has_point(p)
