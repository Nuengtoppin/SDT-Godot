extends CanvasLayer
## Frames-per-second overlay (not part of the original game). F3 toggles it.

var _label := Label.new()
var _timer := 0.0


func _ready() -> void:
	layer = 100
	_label.position = Vector2(6, 4)
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_label.add_theme_constant_override("outline_size", 4)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	_update()


func _process(delta: float) -> void:
	_timer += delta
	if _timer >= 0.25:
		_timer = 0.0
		_update()


func _update() -> void:
	_label.text = "%d fps" % Engine.get_frames_per_second()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		visible = not visible
