extends CanvasLayer
## Port addition (not in the original game): a small notice in a bottom corner of the scene while ModCatalog looks
## at the mods folders ("Loading mods 37 / 142"), with the name of a mod being converted for the first time (the slow
## part). It sits on the side away from the menu, shows only if the scan takes longer than SHOW_AFTER (a collection
## that is all cached and small never shows it), and fades out and frees itself when the scan is done.

const SHOW_AFTER := 0.5   # seconds
const FADE := 0.4         # seconds
const MARGIN := 6.0

var catalog   # ModCatalog
var _age := 0.0
var _pill := PanelContainer.new()
var _count := Label.new()
var _detail := Label.new()


func _ready() -> void:
	layer = 60   # above the menu (50), under the FPS counter (100)
	_pill.theme = MenuTheme.get_theme()
	_pill.add_theme_stylebox_override("panel", MenuTheme.box(Color(MenuTheme.PANEL, 0.85), MenuTheme.LINE, 8, 8, 4))
	_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pill.modulate.a = 0.0
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pill.add_child(v)
	_count.add_theme_font_size_override("font_size", MenuTheme.FONT_SIZE)
	_count.add_theme_color_override("font_color", MenuTheme.TEXT)
	v.add_child(_count)
	_detail.add_theme_font_size_override("font_size", MenuTheme.SMALL)
	_detail.add_theme_color_override("font_color", MenuTheme.MUTED)
	_detail.visible = false
	v.add_child(_detail)
	add_child(_pill)


func _process(delta: float) -> void:
	_age += delta
	var p: Dictionary = catalog.progress()
	if p["finished"]:
		_pill.modulate.a -= delta / FADE
		if _pill.modulate.a <= 0.0:
			queue_free()
		_place()
		return
	if _age < SHOW_AFTER:
		return
	_pill.modulate.a = minf(1.0, _pill.modulate.a + delta / FADE)
	_count.text = "Loading mods  %d / %d" % [p["done"], p["total"]]
	var converting: Array = p["converting"]
	_detail.visible = not converting.is_empty()
	if _detail.visible:
		_detail.text = "Converting %s%s" % [converting[0],
			(" (+%d)" % (converting.size() - 1)) if converting.size() > 1 else ""]
	_place()


## Bottom corner on the side away from the menu.
func _place() -> void:
	_pill.reset_size()
	var view := _pill.get_viewport_rect().size
	var x := view.x - _pill.size.x - MARGIN if SDTMenu.on_left() else MARGIN
	_pill.position = Vector2(x, view.y - _pill.size.y - MARGIN)
