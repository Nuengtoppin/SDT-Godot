class_name LockedStrand
extends FlashMovieClip
## Port of obj.LockedStrand: a frozen strand bitmap that slowly fades.

var strandBitmap: FlashBitmap
var container = null
var step: int = 0


func _init(data: FlashBitmapData = null, p_container = null) -> void:
	if data == null:
		return
	strandBitmap = FlashBitmap.new(data)
	addChild(strandBitmap)
	container = p_container
	addEventListener(FlashEvent.ENTER_FRAME, tick)


func tick() -> void:
	if step >= 10:
		step = 0
		if alpha > 0:
			alpha -= 0.00025
		else:
			kill()
	else:
		step += 1


func kill() -> void:
	g.strandControl.delistLockedStrand(self)
	removeEventListener(FlashEvent.ENTER_FRAME, tick)
	parent.removeChild(self)
	queue_free()
