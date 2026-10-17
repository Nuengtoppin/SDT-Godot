class_name ExtList
extends FlashSprite
## Port extension: a scrolling list box for extensions (e.g. moremoods' mood list), styled like the Loader's:
## white box, one row per item, the selected row highlighted. on_pick(index) when a row is clicked; the mouse
## wheel scrolls.

const ROW_H := 20.0
const SEL_COL := 0x115F8A
const TEXT_COL := 0x115F8A

var on_pick: Callable
var items: Array = []
var selected := -1
var _w := 200.0
var _h := 368.0
var _scroll := 0.0
var _rows: FlashSprite
var _clip: FlashSprite


func _init(w := 200.0, h := 368.0) -> void:
	_w = w
	_h = h
	graphics.lineStyle(1, 0x000000, 1.0)
	graphics.beginFill(0xFFFFFF, 1.0)
	graphics.drawRect(0, 0, w, h)
	graphics.endFill()
	_rows = FlashSprite.new()
	addChild(_rows)
	_clip = FlashSprite.new()
	_clip.graphics.beginFill(0, 1)
	_clip.graphics.drawRect(0, 0, w, h)
	_clip.graphics.endFill()
	addChild(_clip)
	_rows.mask = _clip
	addEventListener(FlashEvent.MOUSE_WHEEL, func(e): _scroll_by(-e.delta * ROW_H))
	addEventListener(FlashEvent.CLICK, _clicked)


func set_items(list: Array) -> void:
	items = list.duplicate()
	_rebuild()


func select(i: int) -> void:
	selected = i
	_rebuild()


func scroll_to(i: int) -> void:
	_scroll = clampf(i * ROW_H - _h / 2 + ROW_H / 2, 0, maxf(0, items.size() * ROW_H - _h))
	_rows.y = -_scroll


func _scroll_by(d: float) -> void:
	_scroll = clampf(_scroll + d, 0, maxf(0, items.size() * ROW_H - _h))
	_rows.y = -_scroll


func _clicked(_e) -> void:
	var i := int(floor((mouseY + _scroll) / ROW_H))
	if i >= 0 and i < items.size():
		select(i)
		if on_pick.is_valid():
			on_pick.call(i)


func _rebuild() -> void:
	while _rows.numChildren > 0:
		_rows.removeChildAt(0)
	_rows.graphics.clear()
	if selected >= 0 and selected < items.size():
		_rows.graphics.beginFill(SEL_COL, 1.0)
		_rows.graphics.drawRect(1, selected * ROW_H, _w - 2, ROW_H)
		_rows.graphics.endFill()
	for i in items.size():
		var t := FlashTextField.new()
		t.mouseEnabled = false
		t.selectable = false
		t._box = Rect2(0, 0, _w - 8, ROW_H)
		t.setTextFormat({"size": 12.0, "color": 0xFFFFFF if i == selected else TEXT_COL})
		t.text = str(items[i])
		t.x = 6
		t.y = i * ROW_H + 1
		_rows.addChild(t)
