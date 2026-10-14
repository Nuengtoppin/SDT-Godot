class_name SDTSlider
extends FlashMovieClip
## Port of obj.Slider (renamed: Godot has a built-in Slider class): a draggable handle with an optional numeric
## label field.

var handle: FlashMovieClip
var hitbox: FlashMovieClip
var bar: FlashMovieClip
var alphaType := false
var amountLabel: FlashTextField
var haveLabel := false
var labelRangeStart: float = 0.0
var labelRange: float = 255.0
var handleRangeStart: float = 0.0
var handleRangeEnd: float = 128.0
var handleRange: float = 128.0
var draggingHandle := false


func _init() -> void:
	super()
	handleRange = handleRangeEnd - handleRangeStart
	handle.mouseEnabled = false
	handle.x = handleRangeStart
	bar.scaleX = handleRange * 0.01
	addEventListener(FlashEvent.ENTER_FRAME, tick)
	addEventListener(FlashEvent.MOUSE_DOWN, handleDragged)


func setLabelRange(start: float, range_: float) -> void:
	labelRangeStart = start
	labelRange = range_


func setRangeEnd(e: float) -> void:
	handleRangeEnd = e
	handleRange = handleRangeEnd - handleRangeStart
	bar.scaleX = handleRange * 0.01
	hitbox.scaleX = handleRange * 0.01


func giveLabel(tf: FlashTextField) -> void:
	amountLabel = tf
	amountLabel.restrict = "0-9\\-"
	haveLabel = true


func setPos(v: float, noLabel: bool = false) -> void:
	v *= handleRange
	handle.x = v + handleRangeStart
	if not noLabel:
		setAmountLabel()


func setFromLabel() -> void:
	if haveLabel:
		var v := AS3.Number(amountLabel.text)
		if is_nan(v):
			return
		v = minf(labelRange + labelRangeStart, maxf(labelRangeStart, Maths.round(v)))
		handle.x = (v - labelRangeStart) / labelRange * handleRange + handleRangeStart


func currentValue(scale: float = 255) -> float:
	var v := Maths.round((handle.x - handleRangeStart) / handleRange * scale)
	return 0.0 if is_nan(v) else v


func handleDragged(_e = null) -> void:
	draggingHandle = true
	stage.addEventListener(FlashEvent.MOUSE_UP, mouseReleased)


func mouseReleased(_e = null) -> void:
	if draggingHandle:
		handle.x = minf(handleRangeEnd, maxf(handleRangeStart, mouseX))
		if haveLabel:
			setAmountLabel()
		dispatchEvent(FlashEvent.new("sliderChanged"))
		dispatchEvent(FlashEvent.new("handleReleased"))
		draggingHandle = false
	stage.removeEventListener(FlashEvent.MOUSE_UP, mouseReleased)


func tick() -> void:
	if draggingHandle:
		handle.x = minf(handleRangeEnd, maxf(handleRangeStart, mouseX))
		dispatchEvent(FlashEvent.new("sliderChanged"))
		if haveLabel:
			setAmountLabel()


func setAmountLabel() -> void:
	var v := int(currentValue() / 255.0 * labelRange + labelRangeStart)
	if haveLabel:
		amountLabel.text = str(v)
