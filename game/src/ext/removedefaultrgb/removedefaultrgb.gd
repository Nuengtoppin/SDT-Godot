extends SDTExtension
## Built-in reimplementation of the Loader mod removedefaultrgb (sby, V1): some of the game's items come with their
## own colour (the school shoes, high heels, several headwear pieces, the gem choker and tie, the shirt cuffs);
## changing to one of them replaces the colour you picked. With the option on, the collar, cuffs, footwear and
## headwear keep your colours. Off by default (the original game's behaviour). Written from its source (which
## empties the controls' defaultRGB tables; the port sets CharacterElementHelper.ignoreDefaultRGB instead, so the
## tables, and the colours mods register in them, come back when the option is switched off).

const CONTROLS := ["collarControl", "cuffsControl", "footwearControl", "headwearControl"]


func _init() -> void:
	id = "removedefaultrgb"
	title = "removedefaultrgb"
	description = "removedefaultrgb (sby): items with their own colour (school shoes, cat ears...) keep the colours you picked (Clothes > Outfit)."
	default_enabled = true


func _setup() -> void:
	setting("keep", false, {"label": "Keep colours when changing items",
		"desc": "Collars, cuffs, footwear and headwear keep your colours instead of an item's own (school shoes, cat ears...)."})


func _enable() -> void:
	menu_control("clothes", "Outfit", MenuSchema.setting_control(self, "keep"))
	_apply(get_setting("keep"))


func _disable() -> void:
	_apply(false)


func _setting_changed(_key: String, _value) -> void:
	_apply(get_setting("keep"))


func _apply(on: bool) -> void:
	var cc = g.characterControl
	if cc == null:
		return
	for n in CONTROLS:
		var h: CharacterElementHelper = cc.get(n)
		if h != null:
			h.ignoreDefaultRGB = on
