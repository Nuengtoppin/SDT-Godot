extends SDTExtension
## Built-in reimplementation of the Loader's counters (BreathCounter, CumInMouthCounter, FinishesCounter,
## HeldBreathCounter, PleasureCounter, VigourCounter from its Default folder, and HerPleasureCounter V1): small
## readouts at the top of the screen, each a white number with a dark glow beside the counter's icon (the icon itself
## is only its glow, as in the Loader: a knockout shadow). On by default; each can be switched off in
## Settings > Counters. Positions and the breath inversion as in the Loader's own settings files (its "x", "y",
## "invert"). Written from their decompiled code; the icons are their shapes' outlines.
##
##   pleasure     his pleasure towards his finish (over 97: plus how long he has been held at the edge)
##   breath       the breath she has left (not inverted: how close she is to passing out)
##   held breath  how long she has been holding her breath
##   vigour       her vigour
##   cum in mouth how full her mouth is
##   finishes     his finishes this session
##   her pleasure DialogueActions' da.masturbation.herpleasure (shown only with DialogueActions on)

const HEART := "M8.25 -3.1 Q8.25 -2.1 7.85 -1.3 L7.05 -0.15 0.0 7.25 -7.05 -0.15 -7.85 -1.3 Q-8.25 -2.1 -8.25 -3.1 -8.25 -4.8 -7.05 -6.05 -5.8 -7.25 -4.1 -7.25 -2.4 -7.25 -1.15 -6.05 -0.15 -5.05 0.0 -3.8 0.2 -5.1 1.15 -6.05 2.4 -7.25 4.1 -7.25 5.85 -7.25 7.05 -6.05 8.25 -4.8 8.25 -3.1"
const BOLT := "M6.3 -5.65 L3.2 -1.9 7.65 0.0 3.2 1.9 6.3 5.65 -3.8 4.45 -5.05 4.15 Q-6.55 3.5 -7.3 1.95 -7.7 1.0 -7.6 0.0 -7.7 -1.0 -7.3 -1.95 -6.55 -3.5 -5.05 -4.15 L-3.8 -4.45 6.3 -5.65"
const PUFF := "M0.6 -1.2 Q0.25 -0.45 -0.15 -0.25 L-2.1 -0.25 -3.3 0.25 -3.25 0.3 -3.0 1.15 -2.9 2.35 -1.65 2.3 -0.9 3.0 -0.85 3.55 -0.9 4.25 -1.6 5.0 -2.85 5.0 -3.45 5.4 -3.25 6.0 Q-3.25 6.9 -4.05 6.9 -4.85 6.9 -5.0 6.45 L-5.0 5.9 -5.0 5.35 Q-4.9 5.05 -4.4 5.05 L-4.05 5.1 Q-3.5 4.1 -3.5 3.6 L-3.45 3.3 -4.65 3.1 Q-6.45 2.5 -6.75 1.9 L-6.75 1.25 -6.6 0.15 Q-6.15 -0.55 -4.4 -0.6 L-4.0 -0.35 Q-3.65 -1.4 -3.65 -1.95 L-3.4 -3.1 Q-2.9 -4.1 -1.6 -4.1 0.9 -4.1 0.9 -2.45 L0.6 -1.2"
const DROPS := "M11.35 -3.25 Q11.35 -1.55 10.2 -0.4 9.05 0.75 7.35 0.75 L6.45 0.7 6.35 0.65 5.3 0.15 Q-2.95 -3.05 -10.75 1.55 -1.15 -6.85 6.65 -7.15 L7.4 -7.25 Q9.0 -7.2 10.2 -6.0 11.35 -4.85 11.35 -3.25 M3.4 2.9 Q4.45 3.55 4.7 4.6 5.0 5.7 4.35 6.65 3.85 7.65 2.8 8.05 1.7 8.35 0.7 7.7 L0.1 7.3 -0.4 6.7 Q-4.2 1.9 -10.3 2.0 -1.8 0.3 2.95 2.75 L3.4 2.9 M-5.7 -5.0 L-6.05 -4.75 -6.6 -4.5 Q-10.3 -2.9 -11.3 1.1 -10.9 -4.7 -8.45 -7.35 L-8.3 -7.6 Q-7.75 -8.15 -6.95 -8.15 -6.15 -8.2 -5.7 -7.6 -5.1 -7.1 -5.1 -6.35 -5.15 -5.55 -5.7 -5.0"
# (the "#" outline only: its small inner square, a hole in Flash, would be filled by FlashGraphics)
const HASH := "M10.3 3.45 L11.4 3.45 11.15 4.5 10.1 4.5 9.75 5.95 10.95 5.95 10.7 7.0 9.55 7.0 9.1 9.05 7.9 9.05 8.35 7.0 7.0 7.0 6.55 9.05 5.4 9.05 5.8 7.0 4.7 7.0 4.95 5.95 6.05 5.95 6.35 4.5 5.15 4.5 5.35 3.45 6.55 3.45 7.0 1.35 8.2 1.35 7.75 3.45 9.1 3.45 9.55 1.35 10.75 1.35 10.3 3.45"

# id, label, Loader position, icon [x, y, scale], text [x, y], icon paths (the shapes' own coordinates)
const COUNTERS := [
	["pleasure", "Pleasure", Vector2(154, 10.75), [10.3, 0, 0.864], Vector2(27.35, -7.95), [HEART]],
	["vigour", "Vigour", Vector2(235, 10.5), [7.6, 0, 1.0], Vector2(26.7, -8.35), [BOLT]],
	["breath", "Breath", Vector2(338.15, 10.75), [-18.4, -1.4, 1.0], Vector2(-8.7, -8.35), [PUFF]],
	["held_breath", "Held breath", Vector2(338.15, 30.25), [-18.4, -1.4, 1.0], Vector2(-8.7, -8.35), [PUFF]],
	["cum_in_mouth", "Cum in mouth", Vector2(426.9, 9.95), [-27.8, 1.3, 1.0], Vector2(-8.7, -8.35), [DROPS]],
	["finishes", "Finishes", Vector2(426.9, 30.25), [-27.8, 1.3, 1.0], Vector2(-8.7, -8.35), [DROPS, HASH]],
	["her_pleasure", "Her pleasure", Vector2(154, 30.25), [10.3, 0, 0.864], Vector2(27.35, -7.95), [HEART]],
]

var hud: FlashSprite = null
var _stats: Dictionary = {}   # id -> [icon, text field]


func _init() -> void:
	id = "counters"
	title = "counters"
	description = "The Loader's counters: his pleasure, her breath, held breath, vigour, cum in mouth, finishes and her pleasure (Settings > Counters)."
	default_enabled = true


func _setup() -> void:
	for c in COUNTERS:
		setting(c[0], true, {"label": c[1], "desc": "Shows the %s counter." % c[1].to_lower()})
	for c in COUNTERS:
		setting(c[0] + "_x", c[2].x, {"label": c[1] + " x", "min": 0, "max": 700, "step": 0.05})
		setting(c[0] + "_y", c[2].y, {"label": c[1] + " y", "min": 0, "max": 600, "step": 0.05})
	setting("breath_invert", true, {"label": "Breath shows what she has left",
		"desc": "On: 100% is full breath (the Loader's setting). Off: how close she is to passing out."})


func _enable() -> void:
	on_late_tick(_tick)
	for c in COUNTERS:
		var extra := {"visible": func(): return Extensions.is_on("dialogueactions")} if c[0] == "her_pleasure" else {}
		menu_control("settings", "Counters", MenuSchema.setting_control(self, c[0], extra))


func _disable() -> void:
	if hud != null and hud._flash_parent != null:
		hud._flash_parent.removeChild(hud)
	hud = null
	_stats.clear()


func _setting_changed(key: String, _value) -> void:
	if hud == null:
		return
	for c in COUNTERS:
		if key == c[0] + "_x" or key == c[0] + "_y":
			_place(c)


func _tick() -> void:
	var any := false
	for c in COUNTERS:
		any = any or get_setting(c[0])
	if hud == null:
		if not any:
			return
		_build()
	hud.visible = any and g.gameRunning
	if not hud.visible:
		return
	var top: int = g.container.numChildren - 1
	if g.container.getChildIndex(hud) != top:
		g.container.addChild(hud)   # above what was added since
	for c in COUNTERS:
		var s: Array = _stats[c[0]]
		var on: bool = get_setting(c[0])
		var v = _value(c[0]) if on else null
		var vis: bool = on and v != null
		if s[0].visible != vis:
			s[0].visible = vis
			s[1].visible = vis
		if vis and s[1].text != v:
			s[1].text = v


## The counter's text as the Loader wrote it, or null to hide it.
func _value(cid: String):
	var him = g.him
	var her = g.her
	match cid:
		"pleasure":
			var p := float(int(him.pleasure / (him.ejacPleasure / 0.97) * 10000)) / 100.0
			if p >= 97:
				p += him.maxPleasureTimer / 20.0
			return _num(minf(100, p)) + "%"
		"breath":
			var inv := 100 if get_setting("breath_invert") else 0
			return _num(absf(inv - _round(her.passOutFactor / her.passOutMax * 100))) + "%"
		"held_breath":
			return _num(_round(100 - g.breathLevel / g.breathLevelMax * 100)) + "%"
		"vigour":
			return _num(minf(100, _round(her.vigour / 1050.0 * 100))) + "%"
		"cum_in_mouth":
			return _num(_round(float(her.cumInMouth) / her.maxCumInMouth * 100)) + "%"
		"finishes":
			return str(g.totalFinishes)
		"her_pleasure":
			var da = Extensions.get_extension("dialogueactions")
			if da == null or not Extensions.is_on("dialogueactions") or da.vars == null:
				return null
			var hp := snappedf(float(da.vars.mod_value("da.masturbation.herpleasure")), 0.01)
			return "0%" if hp == 0 else "%.2f%%" % hp
	return null


## AS3 Math.round: halves round up.
static func _round(v: float) -> float:
	return floorf(v + 0.5)


## AS3 Number to String: whole numbers without ".0".
static func _num(v: float) -> String:
	return str(int(v)) if v == floorf(v) and absf(v) < 1e15 else str(v)


## All icons in one layer and all numbers in another, each with its filter (the Loader filtered every icon and
## number on its own; the counters never overlap, so two render targets give the same picture as fourteen).
func _build() -> void:
	hud = FlashSprite.new()
	hud.flash_name = "counters"
	hud.mouseEnabled = false
	hud.mouseChildren = false
	g.container.addChild(hud)
	var icons := FlashSprite.new()
	icons.filters = [FlashFilter.dropShadow(0, 45, 0, 1.0, 7, 7, 0.46875, 3, false, true)]
	hud.addChild(icons)
	var texts := FlashSprite.new()
	texts.filters = [FlashFilter.dropShadow(0, 45, 0, 1.0, 3, 3, 1.1484375, 3)]
	hud.addChild(texts)
	var font := Flash.get_font_by_name("_sans")
	for c in COUNTERS:
		var icon := FlashSprite.new()
		icon.scaleX = c[3][2]
		icon.scaleY = c[3][2]
		for path in c[5]:
			_draw_path(icon.graphics, path)
		icons.addChild(icon)
		var tf := FlashTextField.new()
		tf._font = font
		tf.setup_from_library(null, {"x": -2.0, "y": -2.0, "w": 49.8, "h": 19.9, "readOnly": 1, "multiline": 1,
			"wordWrap": 1, "selectable": 0, "fontHeight": 12.0, "color": [255, 255, 255, 255], "leading": 2.0})
		tf.mouseEnabled = false
		texts.addChild(tf)
		_stats[c[0]] = [icon, tf]
		_place(c)


func _place(c: Array) -> void:
	var at := Vector2(get_setting(c[0] + "_x"), get_setting(c[0] + "_y"))
	var s: Array = _stats[c[0]]
	s[0].x = at.x + c[3][0]
	s[0].y = at.y + c[3][1]
	s[1].x = at.x + c[4].x
	s[1].y = at.y + c[4].y


## Fills an SVG-style path (M, L and Q with repeated coordinates, as FFDec exports shapes) in black.
static func _draw_path(gr: FlashGraphics, d: String) -> void:
	var tok := d.replace("M", " M ").replace("L", " L ").replace("Q", " Q ").split(" ", false)
	var cmd := ""
	var i := 0
	gr.beginFill(0)
	while i < tok.size():
		if tok[i] in ["M", "L", "Q"]:
			cmd = tok[i]
			i += 1
			continue
		if cmd == "Q":
			gr.curveTo(tok[i].to_float(), tok[i + 1].to_float(), tok[i + 2].to_float(), tok[i + 3].to_float())
			i += 4
		else:
			if cmd == "M":
				gr.moveTo(tok[i].to_float(), tok[i + 1].to_float())
				cmd = "L"
			else:
				gr.lineTo(tok[i].to_float(), tok[i + 1].to_float())
			i += 2
	gr.endFill()
