class_name DevBodyOverlay
extends CanvasLayer
## derrdev: debug layers drawn over body parts (developer panel, Body tab). The same four layers for every part:
##   base       the part's source shape, undeformed (cyan)
##   rendered   what is drawn this tick (pink; a second outline such as a highlight in blue)
##   points     the control points (cyan; the second set in blue)
##   axis       axes and bones (yellow)
## A part is a provider Callable returning {"node": FlashDisplayObject, "base": Array, "rendered": Array,
## "rendered2": Array, "points": Array, "points2": Array, "axes": [[from, to], ...]}, points in the node's own space.
## Drawn in screen space over the game (under the menus), outside the Flash display list: no hit testing, no change
## to what the game draws. Made the first time a layer is switched on; read only.

const LAYERS := ["base", "rendered", "points", "axis"]
const COLORS := {"base": Color(0.15, 1.0, 0.9), "rendered": Color(1.0, 0.3, 0.75), "rendered2": Color(0.5, 0.65, 1.0),
	"axis": Color(1.0, 0.85, 0.1)}

static var instance: DevBodyOverlay = null
static var _on: Dictionary = {}          # "part:layer" -> true
static var line_width := 1.0
static var point_radius := 1.5

var _canvas: Node2D


## Body parts with debug layers. Legs and breasts come next, with the same layers.
static func parts() -> Dictionary:
	return {"neck": func(): return DevBodyOverlay.neck()}


static func is_on(part: String, layer: String) -> bool:
	return _on.has(part + ":" + layer)


static func set_on(part: String, layer: String, on: bool) -> void:
	if on:
		_on[part + ":" + layer] = true
		_ensure()
	else:
		_on.erase(part + ":" + layer)


static func any_on() -> bool:
	return not _on.is_empty()


static func clear() -> void:
	_on.clear()


static func _ensure() -> void:
	if instance == null:
		instance = DevBodyOverlay.new()
		instance.name = "DevBodyOverlay"
		Flash.add_child(instance)


func _ready() -> void:
	layer = 45   # over the game, under the menus (50) and the FPS counter
	_canvas = Node2D.new()
	_canvas.draw.connect(_draw_parts)
	add_child(_canvas)


func _process(_delta: float) -> void:
	_canvas.visible = any_on() and g.gameRunning and SDTMenu.dev != null and SDTMenu.dev._enabled()
	if _canvas.visible:
		_canvas.queue_redraw()


func _draw_parts() -> void:
	var stage: Transform2D = Flash.stage.get_global_transform_with_canvas()
	for part in parts():
		if not (is_on(part, "base") or is_on(part, "rendered") or is_on(part, "points") or is_on(part, "axis")):
			continue
		var d: Dictionary = parts()[part].call()
		if d.is_empty():
			continue
		var xf: Transform2D = stage * (d["node"] as FlashDisplayObject).flash_global_transform()
		if is_on(part, "base"):
			_poly(xf, d.get("base", []), COLORS["base"])
		if is_on(part, "rendered"):
			_poly(xf, d.get("rendered", []), COLORS["rendered"])
			_poly(xf, d.get("rendered2", []), COLORS["rendered2"])
		if is_on(part, "points"):
			for p in d.get("points", []):
				_canvas.draw_circle(xf * p, point_radius, COLORS["base"])
			for p in d.get("points2", []):
				_canvas.draw_circle(xf * p, point_radius, COLORS["rendered2"])
		if is_on(part, "axis"):
			for a in d.get("axes", []):
				_canvas.draw_line(xf * a[0], xf * a[1], COLORS["axis"], line_width, true)
				_canvas.draw_circle(xf * a[0], point_radius * 2.0, COLORS["axis"])
				_canvas.draw_circle(xf * a[1], point_radius * 2.0, COLORS["axis"])


## A closed outline through `pts` (node space).
func _poly(xf: Transform2D, pts: Array, color: Color) -> void:
	if pts.size() < 2:
		return
	var out := PackedVector2Array()
	for p in pts:
		out.append(xf * p)
	out.append(out[0])
	_canvas.draw_polyline(out, color, line_width, true)


# ---------------------------------------------------------------- parts

## Her neck (obj.her.Neck): base = the respaced source outline, rendered = this tick's outline (throat bulge,
## swallow wave) and the highlight, points = both point sets, axis = neck origin to her torso.
static func neck() -> Dictionary:
	if g.her == null or g.her.head == null:
		return {}
	var n: Neck = g.her.head.neck
	var torso: Vector2 = n.globalToLocal(g.her.torso.localToGlobal(Vector2.ZERO))
	return {"node": n, "base": n.neckPoints, "rendered": n.renderedPoints if not n.renderedPoints.is_empty() else n.neckPoints,
		"rendered2": n.highlightPoints, "points": n.neckPoints, "points2": n.highlightPoints, "axes": [[Vector2.ZERO, torso]]}
