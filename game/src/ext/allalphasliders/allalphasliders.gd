extends SDTExtension
## Built-in reimplementation of the Loader mod allalphasliders (sby and stuntcock, V10):
##   - every colour picker shows its alpha (hers and his);
##   - a second colour for the top, bra, panties, armwear, eyewear, gag, earrings and the tongue / nipple / belly
##     piercings, for clothing mods with rgbFill2 parts (the game's own items have none, so the new menu shows it
##     only while a mod is worn there);
##   - her nipples: Auto (shown without a bra, as in the game), Shown or Hidden, saved in the character code as
##     "nippleButton:Auto|OvOn|OvOff" like the Loader mod (a full code without it is Auto).
## Written from its source. (Its top colour rework and shuffle option were switched off in V10; the port fixes the
## one bug they were about: a second top colour no longer changes the top's see-through alpha, CharacterControl.)

const SECOND := ["topControl", "braControl", "pantiesControl", "armwearControl", "eyewearControl", "gagControl",
	"earringControl", "tonguePiercingControl", "nipplePiercingControl", "bellyPiercingControl"]
const NIPPLES := ["Auto", "Shown", "Hidden"]
const NIPPLE_CODES := {"Auto": "Auto", "Shown": "OvOn", "Hidden": "OvOff"}

var nipples := "Auto"
var _added: Array = []   # helpers whose second colour this extension switched on


func _init() -> void:
	id = "allalphasliders"
	title = "allalphasliders"
	description = "allalphasliders (sby, stuntcock): alpha on every colour picker, second colours for clothing mods, and a nipple option (Clothes > Upper body)."
	default_enabled = true


func _enable() -> void:
	CharacterElementHelper.all_alpha = true
	var cc = g.characterControl
	for n in SECOND:
		var h: CharacterElementHelper = cc.get(n)
		if h != null and not h.haveRGBFill2:
			h.haveRGBFill2 = true
			h.rgbFill2ForMods = true
			_added.append(h)
	hook_after(&"Her.breastCostumeChanged", func(_c): _apply_nipples())
	cc.breastSizeChangeListeners.append(_apply_nipples)
	charcode_field("nippleButton", func(): return NIPPLE_CODES[nipples], func(v, _l): _load_code(v),
		func(_l): set_nipples("Auto"))
	menu_control("clothes", "Upper body", MenuSchema.pick("Nipples",
		"Auto: shown without a bra (as in the game). Shown / Hidden: always.", func(): return NIPPLES,
		func(): return NIPPLES.find(nipples), func(i: int): set_nipples(NIPPLES[i]); g.saveData.saveCharData(),
		{"wide": true}))
	_apply_nipples()


func _disable() -> void:
	CharacterElementHelper.all_alpha = false
	for h in _added:
		h.haveRGBFill2 = false
		h.rgbFill2ForMods = false
	_added.clear()
	var cc = g.characterControl
	if cc != null:
		cc.breastSizeChangeListeners.erase(_apply_nipples)
	nipples = "Auto"
	if g.her != null:
		g.her.breastCostumeChanged()   # the game's own nipple visibility


func set_nipples(v: String) -> void:
	nipples = v if v in NIPPLES else "Auto"
	if nipples == "Auto" and g.her != null:
		g.her.breastCostumeChanged()
	_apply_nipples()


func _apply_nipples() -> void:
	var her = g.her
	if her == null or nipples == "Auto":
		return
	var on := nipples == "Shown"
	her.torsoBack.leftBreast.nipple.visible = on
	her.torso.midLayer.rightBreast.nipple.visible = on


func _load_code(v: String) -> void:
	for k in NIPPLE_CODES:
		if NIPPLE_CODES[k] == v:
			set_nipples(k)
			return
