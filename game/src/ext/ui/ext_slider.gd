class_name ExtSlider
extends FlashSprite
## Port extension: a small slider for extensions' menu controls, styled like the Loader's mod sliders (white bar,
## blue marker). value is 0..1; on_change(value) is called while dragging and on release.

const MARKER_COL := 0x115F8A
const MARKER_HOVER_COL := 0x44DCFF
const MARKER_W := 8.0

var on_change: Callable
var value := 0.0
var enabled := true:
	set(v):
		enabled = v
		mouseEnabled = v
		alpha = 1.0 if v else 0.8
var _w := 80.0
var _h := 12.0
var _hover := false
var _dragging := false


func _init(w := 80.0, h := 12.0) -> void:
	_w = w
	_h = h
	buttonMode = true
	addEventListener(FlashEvent.MOUSE_OVER, func(_e): _hover = true; _redraw())
	addEventListener(FlashEvent.MOUSE_OUT, func(_e): _hover = false; _redraw())
	addEventListener(FlashEvent.MOUSE_DOWN, func(_e):
		if enabled:
			_dragging = true
			Flash.stage.addEventListener(FlashEvent.MOUSE_UP, _up))
	addEventListener(FlashEvent.ENTER_FRAME, _tick)
	_redraw()


func set_value(v: float) -> void:
	value = clampf(v, 0.0, 1.0)
	_redraw()


func _tick() -> void:
	if _dragging:
		_drag_to_mouse()


func _up(_e) -> void:
	Flash.stage.removeEventListener(FlashEvent.MOUSE_UP, _up)
	if _dragging:
		_drag_to_mouse()
		_dragging = false
		_redraw()


func _drag_to_mouse() -> void:
	var v := clampf(mouseX / _w, 0.0, 1.0)
	if v != value:
		value = v
		_redraw()
		if on_change.is_valid():
			on_change.call(value)


func _redraw() -> void:
	graphics.clear()
	graphics.lineStyle(1, 0x000000, 1.0)
	graphics.beginFill(0xFFFFFF, 1.0)
	graphics.drawRect(0, 0, _w, _h)
	graphics.endFill()
	graphics.lineStyle()
	var x := clampf(value * _w - MARKER_W / 2, 0, _w - MARKER_W)
	graphics.beginFill(MARKER_HOVER_COL if _hover or _dragging else MARKER_COL, 1.0)
	graphics.drawRect(x, 0, MARKER_W, _h)
	graphics.endFill()
