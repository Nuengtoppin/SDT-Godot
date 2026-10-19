extends SDTExtension
## Built-in reimplementation of the Loader mod dialogspeed (sby, v1): how fast her lines are typed out. The default
## is the setting of sby's Loader pack (the game's own speed is 55; lower is faster).

const GAME_SPEED := 55


func _init() -> void:
	id = "dialogspeed"
	title = "dialogspeed"
	description = "How fast dialogue lines are typed out."
	default_enabled = true


func _setup() -> void:
	setting("dialogspeed", 40, {"label": "Text speed", "min": 10, "max": 100,
		"desc": "Time per letter; lower is faster. The game's own speed is 55. Lines with a voice clip keep its pace."})


func _enable() -> void:
	_apply(get_setting("dialogspeed"))
	menu_control("dialogue", "Dialogue", MenuSchema.setting_control(self, "dialogspeed"))


func _disable() -> void:
	_apply(GAME_SPEED)


func _setting_changed(_key: String, value) -> void:
	_apply(value)


func _apply(speed: int) -> void:
	var dc = g.dialogueControl
	if dc == null:
		return
	if dc.typingSpeed == dc.DEFAULT_TYPING_SPEED:   # a line typing at the default speed changes too
		dc.typingSpeed = speed
	dc.DEFAULT_TYPING_SPEED = speed
