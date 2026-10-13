class_name HimBody
extends RefCounted
## Port of obj.him.bodies.HimBody (base of the body types; also stands in for the IHimBody interface).

static var _bodyMenuContainer: FlashSprite = null

var _him: Him
var lastPos: float = 0.0
var movementSpeed: float = 0.0
var lastHandPos: float = 0.0
var lastYPos: float = 0.0
var _bodyMenu = null


func _init(him: Him) -> void:
	_him = him
	initElements()
	initMenu()


static func setBodyMenuContainer(c: FlashSprite) -> void:
	_bodyMenuContainer = c


func move(p: float, hand: float, yp: float) -> void:
	movementSpeed = p - lastPos
	lastPos = p
	lastHandPos = hand
	lastYPos = yp


func redoLastMove() -> void:
	move(lastPos, lastHandPos, lastYPos)


func debugMove(p: Vector2) -> void:
	_him.x = p.x
	_him.y = p.y


func loadDataPairs(_pairs: Array) -> void:
	pass


func getDataString() -> String:
	return ""


func animationChanged() -> void:
	pass


func toggleBodySettings() -> void:
	pass


func shuffle() -> void:
	pass


func initElements() -> void:
	pass


func initMenu() -> void:
	pass


func setup() -> void:
	setupElements()
	setupAnimation()
	if _bodyMenu:
		_bodyMenuContainer.addChild(_bodyMenu)
		_bodyMenu.addEventListener(FlashEvent.ENTER_FRAME, fadeInMenu)
		_bodyMenu.alpha = 0
	setupMenu()
	updateSharedMenuItems()


func fadeInMenu() -> void:
	if _bodyMenu:
		_bodyMenu.alpha = minf(1.0, _bodyMenu.alpha + 0.1)
		if _bodyMenu.alpha == 1:
			_bodyMenu.removeEventListener(FlashEvent.ENTER_FRAME, fadeInMenu)


func breakdown() -> void:
	if _bodyMenu:
		_bodyMenuContainer.removeChild(_bodyMenu)
		_bodyMenu.removeEventListener(FlashEvent.ENTER_FRAME, fadeInMenu)
	breakdownBody()


func breakdownBody() -> void:
	pass


func updateSharedMenuItems() -> void:
	g.inGameMenu.updateHisBodyList()


func setupElements() -> void:
	pass


func setupAnimation() -> void:
	pass


func setupMenu() -> void:
	pass


var xDelta: float:
	get:
		return _getXDelta()


func _getXDelta() -> float:
	return 0.0
