class_name Freckles
extends FlashMovieClip
## Port of obj.her.Freckles: scatters Freckle symbols over the face.

var targetOrigin := Vector2(-13, 0)
var targetSize := Vector2(160, 100)
var freckles: Array = []


func setFreckleAmount(amount: float) -> void:
	amount = floor(amount * 1.2)
	while amount < freckles.size():
		var i := int(floor(randf() * freckles.size()))
		removeChild(freckles[i])
		freckles[i].queue_free()
		freckles.remove_at(i)
	while amount > freckles.size():
		var f := Flash.create("Freckle")
		f.x = targetOrigin.x - targetSize.x * 0.5 + randomDist() * targetSize.x
		f.y = targetOrigin.y - targetSize.y * 0.5 + randomDist() * targetSize.y
		f.alpha = randf() * 0.4 + 0.6
		var s := randf() * 0.5 + 0.5
		f.scaleX = s
		f.scaleY = s
		addChild(f)
		freckles.append(f)


func randomDist() -> float:
	return (randf() + randf() + randf()) / 3.0
