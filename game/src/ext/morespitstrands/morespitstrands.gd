extends SDTExtension
## Built-in reimplementation of the Loader mod morespitstrands (sby, V3): extra spit strands when her lips leave him
## and while she slides back along him (Effects > Fluids and marks). Both off by default (the game's spit). The numbers
## are the mod's shipped settings file; the maximum strands per pull-off / pull-back can be set. Written from its source.

# the mod's settings file
const PULLED_OFF_CHANCE := 0.6     # chance of each of the pull-off's strands
const PULL_BACK_MOVE_MIN := 8.0      # her movement per tick before pulling back makes strands
const PULL_BACK_TRAVEL_MIN := 65.0   # how far back she must have pulled
const PULL_BACK_CHANCE := 0.25       # chance per tick of a strand while pulling back
const PULL_DOWN_RESTORE := 40.0    # going deeper this far allows one more pull-back strand

var _was_in := false     # her mouth was full: the pull-off's strands are due when it empties
var _back_strands := 0     # strands made in this pull-back
var _last_down := 0.0    # her down travel when the pull-back count last went down
var made := 0            # strands made (checks)


func _init() -> void:
	id = "morespitstrands"
	title = "morespitstrands"
	description = "morespitstrands (sby): extra spit strands when she pulls off him and while she pulls back along him (Effects > Fluids and marks)."
	default_enabled = true


func _setup() -> void:
	setting("pulled_off", false, {"label": "Spit strands when she pulls off",
		"desc": "Extra spit strands when her lips leave him."})
	setting("pulled_off_max", 1, {"label": "Max strands", "min": 0, "max": 5, "step": 1,
		"desc": "At most this many extra strands each time she pulls off (each made by chance)."})
	setting("pulling_up", false, {"label": "Spit strands when she pulls back",
		"desc": "Extra spit strands while she slides back along him quickly, her lips still on him."})
	setting("pulling_up_max", 3, {"label": "Max strands", "min": 0, "max": 8, "step": 1,
		"desc": "At most this many extra strands each time she pulls back; going deeper again allows more."})


func _enable() -> void:
	_was_in = false
	_back_strands = 0
	on_late_tick(_tick)
	var off_on := func(): return get_setting("pulled_off")
	var up_on := func(): return get_setting("pulling_up")
	menu_control("effects", "Fluids and marks", MenuSchema.setting_control(self, "pulled_off", {"after": "Spit"}))
	menu_control("effects", "Fluids and marks", MenuSchema.setting_control(self, "pulled_off_max",
		{"after": "Spit strands when she pulls off", "visible": off_on}))
	menu_control("effects", "Fluids and marks", MenuSchema.setting_control(self, "pulling_up",
		{"after": "Spit strands when she pulls off"}))
	menu_control("effects", "Fluids and marks", MenuSchema.setting_control(self, "pulling_up_max",
		{"after": "Spit strands when she pulls back", "visible": up_on}))


func _tick() -> void:
	var her: Her = g.her
	if her == null:
		return
	if get_setting("pulled_off"):
		if not her.mouthFull:
			if _was_in:
				_was_in = false
				for i in int(get_setting("pulled_off_max")):
					if randf() < PULLED_OFF_CHANCE:
						_strand()
		else:
			_was_in = true
	if get_setting("pulling_up"):
		if not her.mouthFull:
			_back_strands = 0
			return
		if her.movement < -PULL_BACK_MOVE_MIN:
			_last_down = her.downTravel
		if _back_strands < int(get_setting("pulling_up_max")) and her.absMovement > PULL_BACK_MOVE_MIN \
				and her.upTravel > PULL_BACK_TRAVEL_MIN and randf() < PULL_BACK_CHANCE:
			_strand()
			_back_strands += 1
		if her.downTravel - _last_down > PULL_DOWN_RESTORE:
			_last_down = her.downTravel
			_back_strands = maxi(0, _back_strands - 1)


## A random strand, the oldest one making room at the limit (as the mod did).
func _strand() -> void:
	if not g.spit:
		return
	if g.strandControl.maxPop():
		g.strandControl.killOldestSpit()
	g.her.generateRandomStrand("random", true)
	made += 1
