class_name VolumeSlider
extends FlashMovieClip
## Port of obj.VolumeSlider: volume bar revealed by a mask as the handle is dragged.

var barMask: FlashMovieClip
var handleRangeStart: float = 0.0
var handleRangeEnd: float = 128.0
var handleRange: float = 128.0
var draggingHandle := false
var handlePos: float = 0.0


func _init() -> void:
	super()
	handleRange = handleRangeEnd - handleRangeStart
	addEventListener(FlashEvent.ENTER_FRAME, tick)
	addEventListener(FlashEvent.MOUSE_DOWN, handleDragged)


func setPos(v: float) -> void:
	v *= handleRange
	barMask.width = v
	handlePos = v


func currentValue() -> float:
	return (handlePos - handleRangeStart) / handleRange


func handleDragged(_e = null) -> void:
	draggingHandle = true
	stage.addEventListener(FlashEvent.MOUSE_UP, mouseReleased)


func mouseReleased(_e = null) -> void:
	if draggingHandle:
		handlePos = minf(handleRangeEnd, maxf(handleRangeStart, mouseX))
		barMask.width = handlePos
		dispatchEvent(FlashEvent.new("handleReleased"))
		draggingHandle = false
	stage.removeEventListener(FlashEvent.MOUSE_UP, mouseReleased)


func tick() -> void:
	if draggingHandle:
		handlePos = minf(handleRangeEnd, maxf(handleRangeStart, mouseX))
		barMask.width = handlePos
		dispatchEvent(FlashEvent.new("handleReleased"))
