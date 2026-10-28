extends SDTExtension
## Built-in reimplementation of the Loader mod morecumspurts (sby fork of V5.3): how much he cums and how it splits
## into spurts, how thick cum strands are drawn, and edging: teasing him near orgasm and letting him calm down boosts
## his next orgasm, his balls growing to show it (Him > Cum). Defaults: the game's. Written from its source.
##
## Port changes: the game's ejaculate takes its numbers from a before-hook (Him.EJACULATION) instead of the mod's
## copy of the method. The ball growth is shown on top of his ball size instead of changing it, so a character saved
## while he is edged keeps her own ball size, and moving the size slider no longer resets the edging. The finer
## numbers are the mod's shipped settings file.

# the mod's settings file
const RISING := 0.85         # pleasure (share of his orgasm point) that counts as near orgasm
const FALLING := 0.75        # ... and that he must calm down below before the next one counts
const EDGE_STEP := 0.2       # boost per edge
const BALL_STEP := 0.1       # ball growth per edge
const BALL_RATE := 0.02      # how fast his balls catch up, per tick

var edge := 1.0              # boost of his next orgasm
var ball_growth := 1.0       # target growth of his balls
var _shown_growth := 1.0     # growth shown now (eases to ball_growth)
var _near := false           # he is near orgasm (waiting to calm down)
var _was_cumming := false    # the edging is spent once he really cums (a veto may stop the orgasm)
var _applied := 1.0          # growth his balls are drawn with


func _init() -> void:
	id = "morecumspurts"
	title = "morecumspurts"
	description = "morecumspurts (sby): cum amount, spurt lengths and pauses, cum strand thickness, and edging (Him > Cum)."
	default_enabled = true


func _setup() -> void:
	var grp := "Cum"
	setting("amount", 1.0, {"label": "Cum amount", "min": 0.25, "max": 5.0, "step": 0.05, "group": grp,
		"desc": "How much he cums (1 = the game's). A lot makes many strands, which costs frame rate."})
	setting("min_spurt", 6, {"label": "Shortest spurt", "min": 4, "max": 40, "step": 1, "group": grp,
		"desc": "Shortest spurt, in ticks (the game's: 6). Short ones make a burst of small spurts."})
	setting("max_spurt", 21, {"label": "Longest spurt", "min": 6, "max": 60, "step": 1, "group": grp,
		"desc": "Longest spurt, in ticks, plus up to 5 at random (the game's: 21)."})
	setting("pause", 1.0, {"label": "Pauses between spurts", "min": 0.0, "max": 1.0, "step": 0.05, "group": grp,
		"desc": "Chance of a pause before each spurt after the first (the game's: always). His penis bobs in a pause, which scatters the cum."})
	setting("thickness", 1.0, {"label": "Cum strand thickness", "min": 0.5, "max": 5.0, "step": 0.1, "group": grp,
		"desc": "How thick cum strands are drawn at least (1 = the game's). Very thick ones look like clouds."})
	setting("edging", false, {"label": "Edging", "group": grp,
		"desc": "Each time he gets near orgasm and then calms down, his next orgasm is bigger (instead of the game's build-up)."})
	setting("max_edge", 3.0, {"label": "Most edging boost", "min": 1.0, "max": 5.0, "step": 0.1, "group": grp,
		"desc": "The most his orgasm can grow by edging (3 = three times). Each edge adds 0.2."})
	setting("ball_growth", true, {"label": "Balls grow with edging", "group": grp,
		"desc": "His balls grow a little with each edge and are back to their size after he cums."})
	setting("max_ball_growth", 1.5, {"label": "Most ball growth", "min": 1.0, "max": 2.0, "step": 0.05, "group": grp,
		"desc": "The most his balls grow by edging (1.5 = half again)."})


func _enable() -> void:
	edge = 1.0
	ball_growth = 1.0
	_shown_growth = 1.0
	_near = false
	_was_cumming = false
	_applied = 1.0
	_apply_thickness()
	hook_before(&"Him.ejaculate", _ejaculate)
	on_late_tick(_tick)
	var edging := func(): return get_setting("edging")
	var balls := func(): return get_setting("edging") and get_setting("ball_growth")
	for k in ["amount", "min_spurt", "max_spurt", "pause", "thickness", "edging"]:
		menu_control("him", "Cum", MenuSchema.setting_control(self, k))
	menu_control("him", "Cum", MenuSchema.setting_control(self, "max_edge", {"visible": edging}))
	menu_control("him", "Cum", MenuSchema.setting_control(self, "ball_growth", {"visible": edging}))
	menu_control("him", "Cum", MenuSchema.setting_control(self, "max_ball_growth", {"visible": balls}))
	menu_control("him", "Cum", MenuSchema.reset_control(self))


func _disable() -> void:
	if g.strandControl != null:
		g.strandControl.cumMinThickness = 1.0
	_shown_growth = 1.0
	_show_balls()


func _setting_changed(key: String, _value) -> void:
	if key == "thickness":
		_apply_thickness()
	elif key in ["edging", "ball_growth"] and not (get_setting("edging") and get_setting("ball_growth")):
		_shown_growth = 1.0
		_show_balls()


func _apply_thickness() -> void:
	if g.strandControl != null:
		g.strandControl.cumMinThickness = float(get_setting("thickness"))


## The game's ejaculate with this extension's numbers (only when an orgasm starts).
func _ejaculate(c) -> void:
	if g.him.ejaculating:
		return
	var p: Dictionary = c.args[0]
	p["amount"] = float(get_setting("amount"))
	p["min_spurt"] = int(get_setting("min_spurt"))
	p["max_spurt"] = maxi(int(get_setting("max_spurt")), int(get_setting("min_spurt")))
	p["pause"] = float(get_setting("pause"))
	if get_setting("edging"):
		p["build_up"] = false
		p["amount"] *= edge


## Edging: near orgasm, then calmed down = one edge.
func _tick() -> void:
	var him: Him = g.him
	if him == null or not get_setting("edging"):
		return
	if him.ejaculating and not _was_cumming:
		edge = 1.0
		ball_growth = 1.0
	_was_cumming = him.ejaculating
	var level := him.pleasure / him.ejacPleasure
	if not _near:
		_near = level >= RISING
	elif level < FALLING:
		_near = false
		edge = minf(edge + EDGE_STEP, float(get_setting("max_edge")))
		ball_growth = minf(ball_growth + BALL_STEP, float(get_setting("max_ball_growth")))
	if get_setting("ball_growth"):
		_shown_growth += (ball_growth - _shown_growth) * BALL_RATE
		if absf(_shown_growth - ball_growth) < 0.001:
			_shown_growth = ball_growth
		if _shown_growth != _applied:
			_show_balls()


## His balls at his ball size times the shown growth (of the size slider's position, as the mod grew it).
func _show_balls() -> void:
	var him: Him = g.him
	if him == null or him.balls == null:
		return
	_applied = _shown_growth
	var s := Him.MIN_BALL_SIZE + (Him.MAX_BALL_SIZE - Him.MIN_BALL_SIZE) * him.ballSizeSlider * _shown_growth
	him.balls.scaleX = s
	him.balls.scaleY = s
