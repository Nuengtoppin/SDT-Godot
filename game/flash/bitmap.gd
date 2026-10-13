class_name FlashBitmap
extends FlashDisplayObject
## flash.display.Bitmap: draws a FlashBitmapData at the origin.

var bitmapData: FlashBitmapData:
	set(value):
		bitmapData = value
		queue_redraw()

var smoothing := true:
	set(value):
		smoothing = value
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if value else CanvasItem.TEXTURE_FILTER_NEAREST


func _init(data: FlashBitmapData = null, _pixel_snapping: String = "auto", p_smoothing: bool = true) -> void:
	bitmapData = data
	smoothing = p_smoothing


## Call after modifying bitmapData's pixels.
func refresh() -> void:
	queue_redraw()


func _draw() -> void:
	if bitmapData != null:
		draw_texture(bitmapData.get_texture(), Vector2.ZERO)


func _local_bounds() -> Rect2:
	if bitmapData == null:
		return Rect2()
	return Rect2(0, 0, bitmapData.width, bitmapData.height)


func _hit_shape(p: Vector2) -> bool:
	return _local_bounds().has_point(p)
