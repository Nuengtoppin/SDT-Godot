extends SDTExtension
## Built-in reimplementation of the Loader mod moveeyewear (sby, V1): her eyewear can go under her hair's middle
## layer (Clothes > Head and neck, "Eyewear under hair"). Saved in the character code as
## "moveEyewear:EyewearUnder" like the mod (a full code without it is the game's layering). Written from its source.

var on := false


func _init() -> void:
	id = "moveeyewear"
	title = "moveeyewear"
	description = "moveeyewear (sby): her eyewear can go under her hair (Clothes > Head and neck)."
	default_enabled = true


func _enable() -> void:
	charcode_field("moveEyewear", func(): return "EyewearUnder" if on else null,
		func(v, _l):
			if v == "Normal" or v == "EyewearUnder":
				set_on(v == "EyewearUnder"),
		func(_l): set_on(false))
	menu_control("clothes", "Head and neck", MenuSchema.toggle("Eyewear under hair", "Her eyewear under her hair.",
		func(): return on, func(v: bool): set_on(v); g.saveData.saveCharData(),
		{"after": "Eyewear colours", "visible": func(): return g.characterControl.eyewearControl.inUse()}))


func _disable() -> void:
	set_on(false)


func set_on(v: bool) -> void:
	on = v
	var her = g.her
	if her == null:
		return
	var at: int = her.getChildIndex(her.eyewear)
	if on:
		if at != her.getChildIndex(her.hairMidContainer) - 1:
			her.removeChild(her.eyewear)
			her.addChildAt(her.eyewear, maxi(0, her.getChildIndex(her.hairMidContainer)))
	elif at != her.getChildIndex(her.hairBetweenLayer) - 1:
		her.removeChild(her.eyewear)
		her.addChildAt(her.eyewear, maxi(0, her.getChildIndex(her.hairBetweenLayer)))
