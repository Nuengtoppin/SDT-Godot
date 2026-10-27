extends SDTExtension
## Built-in reimplementation of the Loader mod regulaterandom (sby, V5): choose what the shuffle button (and Shift+/,
## [RANDOMIZE_HER]) changes, and which clothes get random transparency. Defaults: the game's shuffle (all of it; random
## transparency for legwear, the second legwear and tops), not the mod's settings file (tops off). Also from the mod:
## her penis (costume and size), off like the game. Written from its source.
## Port change: the mod replaced the game's shuffle with its own copy; here the game's shuffle takes the parts from a
## before-hook (InGameMenu.SHUFFLE_PARTS / SHUFFLE_ALPHA), so other extensions' shuffle hooks keep working. The mod's
## moreclothing parts (body1-3, overtops) have no counterpart here.

## [part, label] in the mod's order.
const PARTS := [["mood", "Mood"], ["bodyScale", "Body size"], ["arms", "Arms"], ["hair", "Hair"], ["iris", "Iris"],
	["breasts", "Breasts"], ["skin", "Skin"], ["bg", "Background"], ["him", "Him"], ["lipstick", "Lipstick"],
	["eyeshadow", "Eye shadow"], ["nailpolish", "Nail polish"], ["collar", "Collar"], ["cuffs", "Cuffs"],
	["ankleCuffs", "Ankle cuffs"], ["gag", "Gag"], ["panties", "Panties"], ["bra", "Bra"], ["armwear", "Armwear"],
	["bottoms", "Bottoms"], ["tops", "Tops"], ["legwear", "Legwear"], ["legwearB", "Legwear 2"],
	["footwear", "Footwear"], ["eyewear", "Eyewear"], ["headwear", "Headwear"], ["tonguePiercing", "Tongue piercing"],
	["nipplePiercing", "Nipple piercings"], ["bellyPiercing", "Belly piercing"], ["earring", "Earrings"],
	["herPenis", "Her penis"]]
## Clothes whose colours can get random transparency.
const ALPHA := ["collar", "gag", "cuffs", "ankleCuffs", "eyewear", "panties", "armwear", "legwear", "legwearB", "bottoms",
	"footwear", "tops", "bra", "tonguePiercing", "nipplePiercing", "bellyPiercing", "earring", "headwear"]


func _init() -> void:
	id = "regulaterandom"
	title = "regulaterandom"
	description = "regulaterandom (sby): choose what shuffling her look changes."
	default_enabled = true


func _setup() -> void:
	for p in PARTS:
		setting(p[0], InGameMenu.SHUFFLE_PARTS.get(p[0], false), {"label": p[1], "group": "Shuffle changes",
			"desc": "Shuffling her look changes this."})
	for k in ALPHA:
		setting("alpha_" + k, InGameMenu.SHUFFLE_ALPHA.get(k, false), {"label": _label(k), "group": "Random transparency",
			"desc": "Shuffled colours of this can be partly see-through."})


func _enable() -> void:
	hook_before(&"InGameMenu.shuffle", _parts)


func _parts(c) -> void:
	for p in PARTS:
		c.args[0][p[0]] = get_setting(p[0])
	for k in ALPHA:
		c.args[1][k] = get_setting("alpha_" + k)


func _label(k: String) -> String:
	for p in PARTS:
		if p[0] == k:
			return p[1]
	return k
