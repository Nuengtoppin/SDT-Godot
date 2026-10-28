extends SDTExtension
## Built-in reimplementation of the Loader mod lipstickRingSmear (V2): a ring of lipstick builds up on him where her
## lips rest, her lips and hand push the lipstick on him along and thin it, it fades over time, and her own lipstick
## wears off as it smears onto him (Effects > Fluids and marks). All off by default (the game's smearing). Like the mod,
## it works whether or not the game's "Lipstick smearing" is on. The numbers are the mod's shipped settings file.
## Written from its source.
##
## Changes from the mod: its colour transforms set the colour of the lipstick on him from a pixel value used as a
## multiplier (white once that pixel had lipstick); here they only scale alpha. Her lipstick goes back to full
## (the game's value) rather than to its colour's alpha, which the game already applies. No toggle key (the settings
## switch it).

# the mod's settings file
const RING_EVERY := 1              # smearRate: ticks between rings
const RING_MAX_SPEED := 5.0        # maximumSpeed: rings only while she moves this slowly
const RING_MAX_POS := 1.03         # maxPositionGeneration
const RING_OFFSET := 0.01          # mouthOffset
const RING_WEAR := 1.0             # ringSmearAlphaRate: how much each ring smear wears her lipstick
const MOUTH_MOVE := 10.0           # mouthSmearBlendMovement
const MOUTH_ALPHA := 64            # mouthSmearBlendAlpha: lipstick this strong is pushed along
const MOUTH_FACTOR := 8.0          # mouthSmearBlendFactor: smears per alpha
const MOUTH_RANGE := 3.0           # mouthSmearBlendRangeFactor
const MOUTH_PUSH_FADE := 0.95      # mouthSmearBlendAlphaMultiplier
const MOUTH_FADE := 0.98           # mouthSmearAlphaMultiplier
const FADE_EVERY := 10             # fadeRate
const FADE := 0.999999             # fadeAlphaMultiplier (one alpha step in 8.8 fixed point)
const HAND_MOVE := 10.0            # handjobSmearBlendMovement
const HAND_ALPHA := 64
const HAND_FACTOR := 8.0
const HAND_RANGE := 4.0
const HAND_PUSH_FADE := 0.9
const HAND_FADE := 0.97
const WEAR_BUFFER := 5000.0        # bufferAmount: smearing this much costs her lipstick nothing
const WEAR_AMOUNT := 20000.0       # alphaAmount: then this much more wears it off

var _ring_counter := 0
var _fade_counter := 0
var _prev_dist := 0.0
var _prev_hand := 0.0
var _pushing := false     # the mod's "smearing": its own push smears neither wear her lipstick nor are skipped
var _ring := false
var _buffer := WEAR_BUFFER
var _wear_left := WEAR_AMOUNT


func _init() -> void:
	id = "lipstickringsmear"
	title = "lipstickRingSmear"
	description = "lipstickRingSmear (V2): a lipstick ring on him, lipstick pushed along and fading, her lipstick wearing off (Effects > Fluids and marks)."
	default_enabled = true


func _setup() -> void:
	setting("ring", false, {"label": "Lipstick ring on him",
		"desc": "A ring of her lipstick builds up on him where her lips rest while she holds still."})
	setting("ring_amount", 5, {"label": "Ring strength", "min": 1, "max": 20, "step": 1,
		"desc": "How quickly the ring builds up."})
	setting("mouth_push", false, {"label": "Her lips push lipstick along",
		"desc": "Going deeper pushes the lipstick on him further along; it thins where her lips slide."})
	setting("hand_push", false, {"label": "Her hand pushes lipstick along",
		"desc": "In handjobs her hand pushes the lipstick on him along and wipes some of it off."})
	setting("fade", false, {"label": "Lipstick on him fades",
		"desc": "The lipstick on him slowly fades away."})
	setting("wear_off", false, {"label": "Her lipstick wears off",
		"desc": "Her lipstick fades as it smears onto him until it is gone; setting her lipstick or loading a character brings it back."})


func _enable() -> void:
	_ring_counter = 0
	_fade_counter = 0
	_prev_dist = 0.0
	_prev_hand = 0.0
	_restore()
	on_late_tick(_tick)
	hook_before(&"Him.smearLipstick", _before_smear)
	hook_after(&"CharacterControl.setLipstick", func(_c): _restore())
	var group := "Fluids and marks"
	menu_control("effects", group, MenuSchema.setting_control(self, "ring", {"after": "Lipstick smearing"}))
	menu_control("effects", group, MenuSchema.setting_control(self, "ring_amount",
		{"after": "Lipstick ring on him", "visible": func(): return get_setting("ring")}))
	menu_control("effects", group, MenuSchema.setting_control(self, "mouth_push", {"after": "Lipstick ring on him"}))
	menu_control("effects", group, MenuSchema.setting_control(self, "hand_push", {"after": "Her lips push lipstick along"}))
	menu_control("effects", group, MenuSchema.setting_control(self, "fade", {"after": "Her hand pushes lipstick along"}))
	menu_control("effects", group, MenuSchema.setting_control(self, "wear_off", {"after": "Lipstick on him fades"}))


func _disable() -> void:
	_restore()


func _setting_changed(key: String, _value) -> void:
	if key == "wear_off":
		_restore()


## Her lipstick at full again, its wear budget refilled.
func _restore() -> void:
	_buffer = WEAR_BUFFER
	_wear_left = WEAR_AMOUNT
	_set_lip_alpha(1.0)


func _set_lip_alpha(a: float) -> void:
	var her: Her = g.her
	if her == null:
		return
	her.topLipstickContainer.topLipstick.alpha = a
	her.bottomLipstick.alpha = a


func _before_smear(c: Hooks.Call) -> void:
	if not get_setting("wear_off"):
		if _ring:
			c.args[1] = 0.0
		return
	if not _pushing and g.characterControl.lipstickRGB.a != 0:
		_buffer -= c.args[1]
		if _buffer < 0:
			_wear_left -= c.args[1]
			_set_lip_alpha(maxf(0.0, _wear_left / WEAR_AMOUNT))
	if _ring:
		c.args[1] = 0.0
	if not _pushing and g.her.bottomLipstick.alpha <= 0:
		c.cancel()


func _tick() -> void:
	var her: Her = g.her
	var him: Him = g.him
	if her == null or him == null:
		return
	var data := him.lipstickData
	var changed := false
	if get_setting("mouth_push") and her.mouthFull and her.absMovement > MOUTH_MOVE:
		var cur := her.penisInMouthDist
		var prev_x := _prev_dist / him.currentPenisLengthScale
		var cur_x := cur / him.currentPenisLengthScale
		# the mod's rectangle: from the smaller x, as wide as the larger one
		var r := Rect2i(int(minf(prev_x, cur_x)), 0, int(maxf(prev_x, cur_x)), 100)
		var a := _alpha_at(data, prev_x)
		if a >= MOUTH_ALPHA and cur > _prev_dist:
			_pushing = true
			for i in ceili(a / MOUTH_FACTOR):
				him.smearLipstick(her.pos, her.absMovement / MOUTH_RANGE)
			data.multiplyAlpha(r, MOUTH_PUSH_FADE)
			_pushing = false
		data.multiplyAlpha(r, MOUTH_FADE)
		changed = true
		_prev_dist = cur
	if get_setting("fade"):
		if _fade_counter == 0:
			data.multiplyAlpha(Rect2i(0, 0, 1000, 100), FADE)
			changed = true
			_fade_counter = FADE_EVERY
		else:
			_fade_counter -= 1
	if get_setting("hand_push") and g.handJobMode and not her.passedOut:
		var cur: float = g.currentHandJobPos.x
		var length := him.currentPenisLength
		var prev_x := _prev_hand * length
		var cur_x := cur * length
		var diff := absf(cur_x - prev_x)
		if diff > HAND_MOVE:
			var forward := cur_x > prev_x
			var r := Rect2i(int(prev_x - 0.2 * length), 0, int(absf(g.targetHandJobPos.x * length - prev_x) + 0.2 * length), 100) \
				if forward else Rect2i(int(cur_x - 0.2 * length), 0, int(diff + 0.2 * length), 100)
			var a := _alpha_at(data, prev_x)
			if a >= HAND_ALPHA:
				_pushing = true
				var at := (cur_x if forward else prev_x) / length + 0.2
				for i in ceili(a / HAND_FACTOR):
					him.smearLipstick(at, diff / HAND_RANGE)
				data.multiplyAlpha(r, HAND_PUSH_FADE)
				_pushing = false
			data.multiplyAlpha(r, HAND_FADE)
			changed = true
		_prev_hand = cur
	if get_setting("ring") and her.mouthFull:
		if _ring_counter >= RING_EVERY and her.absMovement <= RING_MAX_SPEED:
			_ring_counter = 0
			var at := minf(her.pos + RING_OFFSET, RING_MAX_POS)
			_ring = true
			for i in int(get_setting("ring_amount")):
				him.smearLipstick(at, RING_WEAR)
			_ring = false
		else:
			_ring_counter += 1
	if changed:
		him.lipstickLayer.refresh()


## The strongest lipstick alpha (0-255) on him at x, from three rows like the mod.
func _alpha_at(data: FlashBitmapData, x: float) -> int:
	var ix := int(x)
	return maxi(data.getPixel32(ix, 25) >> 24 & 255, maxi(data.getPixel32(ix, 50) >> 24 & 255,
		data.getPixel32(ix, 75) >> 24 & 255))
