class_name CostumeElement
extends FlashMovieClip
## Port of obj.CostumeElement: a costume / hair piece that can be shift-clicked to hide, linked to other pieces,
## or pinned to a moving anchor.

var showing := true
var toggleable := true
var linkedTo: Array = []
var linked := false
var dynamicAnchored := false
var anchorContainer = null
var anchorPoint := Vector2()
var currentAnchor := Vector2()


func _init() -> void:
	super()
	mouseChildren = false
	addEventListener(FlashEvent.CLICK, clicked)


func makeUnToggleable() -> void:
	toggleable = false
	removeEventListener(FlashEvent.CLICK, clicked)


func dynamicAnchor(ax: float, ay: float, container) -> void:
	anchorContainer = container
	dynamicAnchored = true
	anchorPoint = Vector2(ax, ay)
	addEventListener(FlashEvent.ENTER_FRAME, tick)


func tick() -> void:
	if dynamicAnchored:
		currentAnchor = g.sceneLayer.globalToLocal(anchorContainer.localToGlobal(anchorPoint))
		x = currentAnchor.x
		y = currentAnchor.y
		rotation_degrees = anchorContainer.rotation_degrees


func showingString() -> String:
	return "1" if showing else "0"


func tryToHide() -> void:
	if toggleable:
		hideMe()
		if linked:
			for c in linkedTo:
				c.hideMe()


func hideMe() -> void:
	alpha = 0
	showing = false


func showMe() -> void:
	alpha = 1
	showing = true


func linkTo(other: CostumeElement, shareClicks: bool = false) -> void:
	linkedTo.append(other)
	linked = true
	if shareClicks:
		other.addEventListener(FlashEvent.CLICK, clicked)


func clicked(_e = null) -> void:
	if toggleable and g.shiftDown:
		if showing:
			hideMe()
			if linked:
				for c in linkedTo:
					c.hideMe()
		else:
			showMe()
			if linked:
				for c in linkedTo:
					c.showMe()
		dispatchEvent(FlashEvent.new("toggled"))


func kill() -> void:
	if toggleable:
		makeUnToggleable()
	if dynamicAnchored:
		removeEventListener(FlashEvent.ENTER_FRAME, tick)
	for c in linkedTo:
		c.removeEventListener(FlashEvent.CLICK, clicked)
	if parent:
		parent.removeChild(self)
	Flash.dispose_later(self)
