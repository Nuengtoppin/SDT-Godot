extends SDTExtension
## Built-in reimplementation of the Loader mod throatsoundcontrol (sby, V2): when her throat sounds play while you
## hold her (Behaviour > Reactions): always (the game's), only while she is awake, or never. A setting for all
## characters, like the Loader mod's own default (its character code field, off there by default, is not written;
## codes that have it keep it). Written from its source.

const MODES := ["Always", "Only while awake", "Never"]


func _init() -> void:
	id = "throatsoundcontrol"
	title = "throatsoundcontrol"
	description = "throatsoundcontrol (sby): her throat sounds while held: always, only while awake, or never (Behaviour > Reactions)."
	default_enabled = true


func _setup() -> void:
	setting("mode", MODES[0], {"label": "Throat sounds", "options": MODES,
		"desc": "Her throat sounds while you hold her: always (the game's), only while she is awake, or never."})


func _enable() -> void:
	hook_before(&"SoundControl.startHolding", func(c):
		if not _allowed():
			c.cancel())
	hook_after(&"Her.passOut", func(_c):
		if get_setting("mode") != MODES[0]:
			g.soundControl.stopHolding())
	menu_control("behaviour", "Reactions", MenuSchema.setting_control(self, "mode"))
	_check()


func _disable() -> void:
	# (its hooks are gone by now) the game's own: the sound plays whenever she is held
	if g.her != null and g.her.held and not g.soundControl.beingHeld:
		g.soundControl.startHolding()


func _setting_changed(_key: String, _value) -> void:
	_check()


func _allowed() -> bool:
	var m: String = get_setting("mode")
	return m == MODES[0] or (m == MODES[1] and not g.her.passedOut)


## The mod's checkthroat: starts or stops the sound at once for the new mode.
func _check() -> void:
	var her = g.her
	var sc = g.soundControl
	if her == null or sc == null:
		return
	if not _allowed():
		sc.stopHolding()
	elif her.held and not sc.beingHeld:
		sc.startHolding()
