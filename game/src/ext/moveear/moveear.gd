extends SDTExtension
## Built-in reimplementation of the Loader mod moveear (sby, V4): her ear (and earrings) can go under her hair's
## middle layer instead of above the layer between her hair (Her > Face, "Ear under hair"). Saved in the character
## code as "moveEar:EarUnder" like the mod (a full code without it is the game's layering). Written from its source.

var on := false


func _init() -> void:
	id = "moveear"
	title = "moveear"
	description = "moveear (sby): her ear can go under her hair (Her > Face)."
	default_enabled = true


func _enable() -> void:
	charcode_field("moveEar", func(): return "EarUnder" if on else null,
		func(v, _l):
			if v == "Normal" or v == "EarUnder":
				set_on(v == "EarUnder"),
		func(_l): set_on(false))
	menu_control("her", "Face", MenuSchema.toggle("Ear under hair", "Her ear (and earrings) under her hair.",
		func(): return on, func(v: bool): set_on(v); g.saveData.saveCharData(), {"after": "Ears"}))


func _disable() -> void:
	set_on(false)


func set_on(v: bool) -> void:
	on = v
	var her = g.her
	if her == null:
		return
	var between: int = her.getChildIndex(her.hairBetweenLayer)
	var mid: int = her.getChildIndex(her.hairMidContainer)
	if on:
		if her.getChildIndex(her.ear) != mid - 2:
			her.addChildAt(her.earrings, maxi(0, mid))
			her.addChildAt(her.ear, her.getChildIndex(her.earrings))
	elif her.getChildIndex(her.ear) != between + 1:
		her.addChildAt(her.ear, maxi(0, between))
		her.addChildAt(her.earrings, her.getChildIndex(her.ear))
