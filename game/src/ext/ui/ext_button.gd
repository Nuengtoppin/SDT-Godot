class_name ExtButton
extends FlashSprite
## Port extension (not in the original game): the small square button extensions put into the game menus, styled
## like the Loader's mod buttons (white box, blue glyph, blue highlight on hover, outline while pressed). The idle
## background colour shows a state, e.g. green for "on", as the Loader mods did.

const HOVER_COL := 0x115F8A
const GLYPH_COL := 0x115F8A
const GLYPH_HOVER_COL := 0x44DCFF
const GLYPH_CLICK_COL := 0xFFFFFF
const FADE_TICKS := 15

## Called with no arguments when the button is clicked (pressed and released over it).
var on_click: Callable
var _w := 16.0
var _h := 16.0
var _idle := 0xFFFFFF
var _hover := false
var _pressed := false
var _fade := 0
var _label: FlashTextField


func _init(w := 16.0, h := 16.0, text := "", text_size := 10.0) -> void:
	_w = w
	_h = h
	buttonMode = true
	mouseChildren = false
	_label = FlashTextField.new()
	_label.mouseEnabled = false
	_label.selectable = false
	_label._box = Rect2(0, 0, w, h)
	_label.setTextFormat({"size": text_size, "align": "center", "color": GLYPH_COL})
	_label.text = text
	_label.y = (h - text_size) / 2 - 4
	addChild(_label)
	addEventListener(FlashEvent.MOUSE_OVER, func(_e): _hover = true)
	addEventListener(FlashEvent.MOUSE_OUT, func(_e): _hover = false)
	addEventListener(FlashEvent.MOUSE_DOWN, _down)
	addEventListener(FlashEvent.ENTER_FRAME, _tick)
	_redraw()


## Sets the idle background colour (0xRRGGBB), e.g. 0x00FF00 for "on".
func set_color(rgb: int) -> void:
	if rgb != _idle:
		_idle = rgb
		_redraw()


## The button's label.
var text: String:
	get:
		return _label.text


func set_text(t: String) -> void:
	_label.text = t


func _down(_e) -> void:
	_pressed = true
	_fade = FADE_TICKS
	Flash.stage.addEventListener(FlashEvent.MOUSE_UP, _up)
	_redraw()


func _up(_e) -> void:
	Flash.stage.removeEventListener(FlashEvent.MOUSE_UP, _up)
	if _pressed:
		_pressed = false
		_redraw()
		if _hover and on_click.is_valid():
			on_click.call()


func _tick() -> void:
	var f := mini(FADE_TICKS, _fade + 1) if _hover else maxi(0, _fade - 1)
	var col := GLYPH_CLICK_COL if _pressed else (GLYPH_HOVER_COL if _hover else GLYPH_COL)
	if f != _fade or _label.textColor != col:
		_fade = f
		_label.textColor = col
		_redraw()


func _redraw() -> void:
	graphics.clear()
	graphics.beginFill(_idle, 1.0)
	graphics.drawRect(0, 0, _w, _h)
	graphics.endFill()
	if _fade > 0:
		graphics.beginFill(HOVER_COL, float(_fade) / FADE_TICKS)
		graphics.drawRect(0, 0, _w, _h)
		graphics.endFill()
	if _pressed:
		graphics.lineStyle(1, 0x000000, 1.0)
		graphics.beginFill(HOVER_COL, 1.0)
		graphics.drawRect(0, 0, _w, _h)
		graphics.endFill()
		graphics.lineStyle()
