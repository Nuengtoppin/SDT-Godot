class_name ScrollingAreaScroller
extends FlashMovieClip
## Port of obj.ui.ScrollingAreaScroller: the draggable bar that scrolls a ScrollingArea's content.

var bg: FlashMovieClip
var bar: FlashMovieClip
var scrollPos: float = 0.0
var lastBarY: float = 0.0
var scrollSpeed: float = 0.0
var draggingBar := false
var dragOffset: float = 0.0
var scrollerContent: FlashSprite
var contentStartY: float = 0.0
var scrollerHeight: float = 0.0
var yPad: float = 0.0


func prepare(content: FlashSprite, h: float, pad: float = 0) -> void:
	scrollerContent = content
	scrollerContent.cacheAsBitmap = true
	contentStartY = content.y
	scrollerHeight = h
	yPad = pad
	bg.height = scrollerHeight
	bar.height = scrollerHeight * minf(1, _ratio())
	addEventListener(FlashEvent.ENTER_FRAME, tick)
	bar.addEventListener(FlashEvent.MOUSE_DOWN, barPressed)


## scrollerHeight / content height; empty content divides by zero (Infinity in Flash).
func _ratio() -> float:
	var ch: float = scrollerContent.height
	return scrollerHeight / ch if ch > 0 else INF


## Flash yields NaN / Infinity on x/0 and ignores NaN assignments to y; 0 keeps things in place here.
func _safeDiv(a: float, b: float) -> float:
	if b == 0:
		return 0.0
	return a / b


func scrollTo(v: float) -> void:
	v = maxf(0, minf(1, v))
	bar.y = v * (scrollerHeight - bar.height)
	updateScrollPos()


func jumpTo(o: FlashDisplayObject) -> void:
	if scrollerContent.contains(o):
		if o.y - scrollerContent.y < 0 or o.y - scrollerContent.y > scrollerHeight:
			scrollTo(_safeDiv(o.y, scrollerContent.height))


func updateContent() -> void:
	bar.height = scrollerHeight * minf(1, _ratio())
	bar.y = _safeDiv((scrollerHeight - bar.height) * (contentStartY - scrollerContent.y),
		scrollerContent.height + yPad - scrollerHeight)
	bar.y = maxf(0, minf(scrollerHeight - bar.height, bar.y))
	updateScrollPos()


func mouseWheelScroll(d: float) -> void:
	bar.y = maxf(0, minf(scrollerHeight - bar.height, bar.y - d))
	updateScrollPos()


func updateScrollPos() -> void:
	scrollPos = _safeDiv(bar.y, scrollerHeight - bar.height)
	scrollerContent.y = contentStartY - scrollPos * (scrollerContent.height + yPad - scrollerHeight)


func tick() -> void:
	if draggingBar:
		bar.y = maxf(0, minf(scrollerHeight - bar.height, mouseY - dragOffset))
		scrollSpeed = bar.y - lastBarY
		lastBarY = bar.y
		updateScrollPos()
	elif scrollSpeed != 0:
		bar.y = maxf(0, minf(scrollerHeight - bar.height, bar.y + scrollSpeed))
		scrollSpeed *= 0.5
		if absf(scrollSpeed) < 0.25:
			scrollSpeed = 0
		updateScrollPos()


func barPressed(_e = null) -> void:
	dragOffset = mouseY - bar.y
	stage.addEventListener(FlashEvent.MOUSE_UP, barReleased)
	draggingBar = true


func barReleased(_e = null) -> void:
	stage.removeEventListener(FlashEvent.MOUSE_UP, barReleased)
	draggingBar = false
