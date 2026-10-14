class_name SecretOptionDrawer
extends FlashMovieClip
## Port of obj.SecretOptionDrawer: hidden drawer that slides out after hovering at the menu edge.

var cbBukkakeMode
var arrow: FlashMovieClip
var slideIn: float = 253.0
var slideOut: float = 421.0
var slidingIn := false
var slidingOut := false
var slideSmooth: float = 2.0
var drawerOpen := false
var drawerOver := false
var drawerArrowShowing := false
var overTimer: int = 0
var offTimer: int = 0
var openDelay: int = 30
var closeDelay: int = 30


func _init() -> void:
	super()
	addEventListener(FlashEvent.ENTER_FRAME, tick)
	addEventListener(FlashEvent.ROLL_OVER, rolledOver)
	addEventListener(FlashEvent.ROLL_OUT, rolledOut)


func tick() -> void:
	if slidingIn:
		x += (slideIn - x) / slideSmooth
		if absf(x - slideIn) < 0.1:
			x = slideIn
			slidingIn = false
	elif slidingOut:
		x += (slideOut - x) / slideSmooth
		if absf(x - slideOut) < 0.1:
			x = slideOut
			slidingOut = false
			drawerOpen = false
	if not drawerOpen and drawerOver:
		overTimer += 1
		if overTimer >= openDelay:
			openDrawer()
	if drawerOpen and not drawerOver:
		offTimer += 1
		if offTimer >= closeDelay:
			closeDrawer()


func rolledOver(_e = null) -> void:
	drawerOver = true
	offTimer = 0
	if drawerOpen:
		openDrawer()
	else:
		arrow.gotoAndPlay("FadeIn")
		drawerArrowShowing = true


func rolledOut(_e = null) -> void:
	drawerOver = false
	overTimer = 0
	if drawerArrowShowing:
		arrow.gotoAndPlay("FadeOut")
		drawerArrowShowing = false


func openDrawer() -> void:
	slidingIn = true
	slidingOut = false
	drawerOpen = true
	if drawerArrowShowing:
		arrow.gotoAndPlay("FadeOut")
		drawerArrowShowing = false


func closeDrawer() -> void:
	if drawerOpen:
		slidingOut = true
		slidingIn = false
