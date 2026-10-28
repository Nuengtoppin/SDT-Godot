extends SDTExtension
## Built-in reimplementation of the Loader mod cumRGB (sby, V3): the cum colour, and how strong the strands' highlights
## are. Saved in the character code as "cumRGB:r,g,b,trans,highlights" like the Loader mod; a full code without it
## (and a character reset) brings back the defaults, which are the original game's.
## Written from its source.
##
## The colour's alpha is the highlights' transparency (the strand shader's "trans", 0..2.2; the game's 1.1 is alpha
## 0.5), "Cum highlights" their strength (the shader's "totMult", -2.2..2.2; the game's 0.5).

const MAX_TRANS := 2.2
const MAX_HIGHLIGHTS := 2.2
const DEFAULT_RGB := {"r": 255, "g": 252, "b": 247}
const DEFAULT_TRANS := 1.1
const DEFAULT_HIGHLIGHTS := 0.5

var rgb := {"r": 255, "g": 252, "b": 247, "a": DEFAULT_TRANS / MAX_TRANS}
var highlights := DEFAULT_HIGHLIGHTS


func _init() -> void:
	id = "cumrgb"
	title = "cumRGB"
	description = "cumRGB (sby): the cum colour and the strength of the strands' highlights (Effects > Fluids and marks)."
	default_enabled = true


func _enable() -> void:
	charcode_field("cumRGB", _code, func(v, _l): _load_code(v), func(_l): reset())
	menu_control("effects", "Fluids and marks", MenuSchema.colour("Cum colour",
		"The colour of cum. Its alpha is how transparent the highlights are.", func(): return rgb,
		func(c, _f): set_colour(c), "rgbFill", true))
	menu_control("effects", "Fluids and marks", {"type": "slider", "label": "Cum highlights",
		"tip": "How strong the shine on cum strands is (the game's is 0.5).", "min": -MAX_HIGHLIGHTS,
		"max": MAX_HIGHLIGHTS, "step": 0.01, "get": func(): return highlights,
		"set": func(v: float): set_highlights(v), "release": func(): g.saveData.saveCharData(),
		"reset": func(): set_highlights(0.5); g.saveData.saveCharData(),
		"format": func(v): return str(snappedf(v, 0.01))})
	_apply()


func _disable() -> void:
	reset()


func set_colour(c: Dictionary) -> void:
	rgb = {"r": int(c["r"]), "g": int(c["g"]), "b": int(c["b"]), "a": float(c.get("a", rgb["a"]))}
	_apply()


func set_highlights(v: float) -> void:
	highlights = clampf(v, -MAX_HIGHLIGHTS, MAX_HIGHLIGHTS)
	_apply()


## The original game's colour and highlights.
func reset() -> void:
	rgb = {"r": DEFAULT_RGB["r"], "g": DEFAULT_RGB["g"], "b": DEFAULT_RGB["b"], "a": DEFAULT_TRANS / MAX_TRANS}
	highlights = DEFAULT_HIGHLIGHTS
	_apply()


func _apply() -> void:
	g.cumRGB = (int(rgb["r"]) << 16) | (int(rgb["g"]) << 8) | int(rgb["b"])
	if g.cumHighlight != null:
		g.cumHighlight.shaderParams["trans"] = float(rgb["a"]) * MAX_TRANS
		g.cumHighlight.shaderParams["totMult"] = highlights
		if g.inGameMenu != null and g.cumLayer != null:
			g.inGameMenu.updateStrandShaders()   # re-applies the filter with the new values


func _code() -> String:
	return "%d,%d,%d,%.5f,%.5f" % [int(rgb["r"]), int(rgb["g"]), int(rgb["b"]), float(rgb["a"]) * MAX_TRANS, highlights]


func _load_code(v: String) -> void:
	var p := v.split(",")
	if p.size() < 4:
		return
	rgb = {"r": int(float(p[0])), "g": int(float(p[1])), "b": int(float(p[2])), "a": clampf(float(p[3]) / MAX_TRANS, 0.0, 1.0)}
	if p.size() > 4:
		highlights = clampf(float(p[4]), -MAX_HIGHLIGHTS, MAX_HIGHLIGHTS)
	_apply()
