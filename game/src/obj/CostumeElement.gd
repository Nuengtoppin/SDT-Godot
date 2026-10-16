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


## Flash.dispose_later policy: a killed element the game still lists (the character's hair elements after an
## overwriting hair mod killed them, a mod package's element) stays alive, as in Flash.
func _can_dispose() -> bool:
	if g.characterControl.currentElements.has(self):
		return false
	for m in g.customElementLoader.instancedModElements:
		if m._mod == self:
			return false
	for pkg in g.customElementLoader.loadedModPackages:
		for m in pkg.modElements:
			if m._mod == self:
				return false
	return true


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
