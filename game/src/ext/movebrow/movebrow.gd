extends SDTExtension
## Built-in reimplementation of the Loader mod movebrow (sby, V1): her (right) eyebrow can show over her hair, at 80%
## (Her > Face, "Eyebrow over hair"): it moves to a layer in the game's front layer that follows her every tick.
## Saved in the character code as "moveBrow:BrowOver" like the mod (a full code without it is the game's layering).
## Written from its source.

var on := false
var _layer: FlashSprite = null
var _parent: FlashSprite = null
var _index := 0


func _init() -> void:
	id = "movebrow"
	title = "movebrow"
	description = "movebrow (sby): her eyebrow can show over her hair (Her > Face)."
	default_enabled = true


func _enable() -> void:
	on_late_tick(_tick)
	charcode_field("moveBrow", func(): return "BrowOver" if on else null,
		func(v, _l):
			if v == "Normal" or v == "BrowOver":
				set_on(v == "BrowOver"),
		func(_l): set_on(false))
	menu_control("her", "Face", MenuSchema.toggle("Eyebrow over hair", "Her eyebrow shows through her hair.",
		func(): return on, func(v: bool): set_on(v); g.saveData.saveCharData(), {"after": "Eyebrows"}))


func _disable() -> void:
	set_on(false)
	if _layer != null and _layer._flash_parent != null:
		_layer._flash_parent.removeChild(_layer)
	_layer = null


func set_on(v: bool) -> void:
	on = v
	var her = g.her
	if her == null:
		return
	var brow = her.rightEyebrow
	if _layer == null:
		_layer = FlashSprite.new()
		_layer.flash_name = "moveBrow"
		_layer.alpha = 0.8
		_layer.mouseEnabled = false
		_layer.mouseChildren = false
		g.frontLayer.addChild(_layer)
		_parent = brow._flash_parent
		_index = _parent.getChildIndex(brow)
	if on:
		if brow._flash_parent != _layer:
			_layer.transform = her.transform
			_layer.addChild(brow)
	elif brow._flash_parent != _parent:
		_parent.addChildAt(brow, _index)


func _tick() -> void:
	if on and _layer != null and g.her != null:
		_layer.transform = g.her.transform
