class_name ScrollingArea
extends FlashMovieClip
## Port of obj.ui.ScrollingArea: masks a content container to a window and adds a scroll bar (and mouse wheel).

var bgLeft: FlashMovieClip
var bgRight: FlashMovieClip
var bgSpan: FlashMovieClip
var windowContent: FlashSprite
var contentMask: FlashSprite
var scroller: ScrollingAreaScroller


func _init(w: float = 100, h: float = 100, content: FlashSprite = null, yPad: float = 0) -> void:
	if content == null:
		return
	windowContent = content
	if windowContent.parent:
		windowContent.parent.removeChild(windowContent)
	windowContent.x = 0
	windowContent.y = 0
	addChild(windowContent)
	contentMask = FlashSprite.new()
	contentMask.graphics.beginFill(0, 1)
	contentMask.graphics.drawRect(1, 1, w - 1, h - 1)
	contentMask.graphics.endFill()
	addChild(contentMask)
	windowContent.mask = contentMask
	bgLeft.bgSpan.height = h - 40
	bgLeft.bgBottom.y = h - 20
	bgSpan.width = w - 40
	bgSpan.height = h
	bgRight.x = w - 20
	bgRight.height = h
	scroller = ScrollingAreaScroller.new()
	scroller.x = w
	addChild(scroller)
	scroller.prepare(windowContent, h, yPad)
	addEventListener(FlashEvent.ROLL_OVER, rolledOver)
	addEventListener(FlashEvent.ROLL_OUT, rolledOut)


func scrollTo(v: float) -> void:
	scroller.scrollTo(v)


func jumpTo(o: FlashDisplayObject) -> void:
	scroller.jumpTo(o)


func updateContent() -> void:
	scroller.updateContent()


func mouseWheelScroll(d: float) -> void:
	scroller.mouseWheelScroll(d)


func rolledOver(_e = null) -> void:
	g.overScrollArea = self


func rolledOut(_e = null) -> void:
	if g.overScrollArea == self:
		g.overScrollArea = null
