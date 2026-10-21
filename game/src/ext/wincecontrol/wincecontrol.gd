extends SDTExtension
## Built-in reimplementation of the Loader mod wincecontrol (sby, V3): when she winces (Behaviour > Reactions):
## always (the game's), only while she is awake, or never. Swallowing still makes her wince while awake (the mod's
## allowwinceforswallow), and moods that do not wince (moremoods: Broken, Horny, Android, Numb, Asleep) skip it.
## A setting for all characters, like the Loader mod's own default (its character code field, off there by default,
## is not written; codes that have it keep it). Written from its source.

const MODES := ["Always", "Only while awake", "Never"]


func _init() -> void:
	id = "wincecontrol"
	title = "wincecontrol"
	description = "wincecontrol (sby): when she winces: always, only while awake, or never (Behaviour > Reactions)."
	default_enabled = true


func _setup() -> void:
	setting("mode", MODES[0], {"label": "Wincing", "options": MODES,
		"desc": "When she winces (and her mascara runs): always (the game's), only while she is awake, or never."})


func _enable() -> void:
	hook_before(&"Her.wince", func(c):
		if not _allowed():
			c.cancel())
	menu_control("behaviour", "Reactions", MenuSchema.setting_control(self, "mode", {"wide": true}))


func _allowed() -> bool:
	var her = g.her
	var m: String = get_setting("mode")
	var ok: bool = m == MODES[0] or (m == MODES[1] and not her.passedOut) or (not her.passedOut and her.swallowing)
	var mm = Extensions.get_extension("moremoods")
	if ok and mm != null and mm.enabled and mm.face != null and mm.face.skip_wince:
		ok = false
	return ok
