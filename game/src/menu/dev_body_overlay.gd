class_name DevBodyOverlay
extends CanvasLayer
## derrdev: debug layers drawn over body parts (developer panel, Body tab). The same four layers for every part:
##   base       the part's source shape, undeformed (cyan)
##   rendered   what is drawn this tick (pink; a second outline such as a highlight in blue)
##   points     the control points (cyan; the second set in blue)
##   axis       axes and bones: the game's in yellow, ours (our body layer) in orange
##   zones      regions along the part (the throat's rings), each in its own colour, and markers on it
## A part is a provider Callable returning {"node": FlashDisplayObject, "base": Array, "rendered": Array,
## "rendered2": Array, "points": Array, "points2": Array, "axes": [[from, to], ...],
## "axes_ours": [[from, to], ...], "zones": [[from, to, Color, width multiplier], ...], "marks": [[point, Color], ...]},
## points in the node's own space;
## a part leaves out what it does not have.
## Drawn in screen space over the game (under the menus), outside the Flash display list: no hit testing, no change
## to what the game draws. Made the first time a layer is switched on; read only.

const LAYERS := ["base", "rendered", "points", "axis", "zones"]
const COLORS := {"base": Color(0.15, 1.0, 0.9), "rendered": Color(1.0, 0.3, 0.75), "rendered2": Color(0.5, 0.65, 1.0),
	"axis": Color(1.0, 0.85, 0.1), "ours": Color(1.0, 0.5, 0.1)}

static var instance: DevBodyOverlay = null
static var _on: Dictionary = {}          # "part:layer" -> true
static var line_width := 1.0
static var point_radius := 1.5

var _canvas: Node2D


## Body parts with debug layers, all with the same layers.
static func parts() -> Dictionary:
	return {"neck": func(): return DevBodyOverlay.neck(), "throat": func(): return DevBodyOverlay.throat(),
		"legs": func(): return DevBodyOverlay.legs(), "arms": func(): return DevBodyOverlay.arms(),
		"breasts": func(): return DevBodyOverlay.breasts()}


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
		if not LAYERS.any(func(l): return is_on(part, l)):
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
			for k in [["axes", "axis"], ["axes_ours", "ours"]]:
				for a in d.get(k[0], []):
					_canvas.draw_line(xf * a[0], xf * a[1], COLORS[k[1]], line_width, true)
					_canvas.draw_circle(xf * a[0], point_radius * 2.0, COLORS[k[1]])
					_canvas.draw_circle(xf * a[1], point_radius * 2.0, COLORS[k[1]])
		if is_on(part, "zones"):
			for z in d.get("zones", []):
				_canvas.draw_line(xf * z[0], xf * z[1], z[2], line_width * z[3], true)
			for m in d.get("marks", []):
				_canvas.draw_circle(xf * m[0], point_radius * 2.5, m[1])


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


## A display object's origin (or `p` in its own space) in her space.
static func _at(o: FlashDisplayObject, p := Vector2.ZERO) -> Vector2:
	return g.her.globalToLocal(o.localToGlobal(p))


## An IK chain (IKController): its three joints as two bones, and where it aims.
static func _chain(ik: IKController) -> Array:
	var j: Array = [_at(ik.s1), _at(ik.s2), _at(ik.s3)]
	var t: Vector2 = j[2]
	if ik.targetPointCoordinateSpace != null:
		t = _at(ik.targetPointCoordinateSpace, ik.targetPoint)
	return [[j[0], j[1]], [j[1], j[2]], t]


## Her legs: the right leg is an IK chain (torso -> thigh -> calf) aimed at the knee target of the pose; the left leg
## is no chain, it copies the right thigh's rotation (x0.95, its own start point), shown as its thigh -> calf.
static func legs() -> Dictionary:
	if g.her == null or g.her.torsoIK == null:
		return {}
	var h = g.her
	var c := _chain(h.torsoIK)
	var left = h.leftLegContainer.leg
	return {"node": h, "axes": [c[0], c[1], [_at(left), _at(left.calf)]], "points": [c[2]]}


## Her arms: two IK chains (upper arm -> forearm -> hand) and where each hand aims.
static func arms() -> Dictionary:
	if g.her == null or g.her.leftArmIK == null:
		return {}
	var l := _chain(g.her.leftArmIK)
	var r := _chain(g.her.rightArmIK)
	return {"node": g.her, "axes": [l[0], l[1], r[0], r[1]], "points": [l[2], r[2]]}


## Her breasts: each one's pivot and a line down it that leans with its sway (both springs get the same push in the
## game, BreastController.update).
static func breasts() -> Dictionary:
	if g.her == null or g.her.leftBreastController == null:
		return {}
	var out := {"node": g.her, "axes": [], "points": []}
	for b in [g.her.leftBreastController._breast, g.her.rightBreastController._breast]:
		out["axes"].append([_at(b), _at(b, Vector2(0, 60))])
		out["points"].append(_at(b))
	return out


## Her throat's rings (ThroatRings): a line across the neck at each ring's top and bottom edge, green while the ring
## is not stretched to red when fully stretched (grey once it would have snapped), thicker while he presses on it;
## a white dot at his tip and a blue one at the swallow wave, on the drawn front of the neck.
static func throat() -> Dictionary:
	if g.her == null or g.her.head == null:
		return {}
	var n: Neck = g.her.head.neck
	var front: Array = n.renderedPoints if n.renderedPoints.size() == n.neckPoints.size() else n.neckPoints
	var zones: Array = []
	for r in ThroatRings.rings():
		if not r["on"]:
			continue
		var c := Color(0.6, 0.6, 0.6) if r["snapped"] else Color.from_hsv(0.33 * (1.0 - r["stretch"]), 0.85, 1.0)
		var w: float = 1.0 + 2.0 * minf(1.0, r["pressure"])
		for depth in [r["top"], r["bottom"]]:
			var a := front_at(n, front, depth)
			zones.append([a, Vector2(_back_x(n, a.y), a.y), c, w])
	var marks: Array = []
	if ThroatRings.tip > 0.0:
		marks.append([front_at(n, front, ThroatRings.tip), Color.WHITE])
	if n.swallowing:
		marks.append([front_at(n, front, n.swallowProgress), COLORS["rendered2"]])
	return {"node": n, "zones": zones, "marks": marks}


## The point at `depth` along the front of the neck (`pts`: the neck's outline points, base or as drawn).
static func front_at(n: Neck, pts: Array, depth: float) -> Vector2:
	var f := clampf(depth, 0.0, 1.0) * n.frontEndPoint
	var i := mini(int(f), n.frontEndPoint - 2)
	return (pts[i] as Vector2).lerp(pts[i + 1], f - i)


## Where the back of the neck crosses height `y` (the outline after the front runs back up from her chest).
static func _back_x(n: Neck, y: float) -> float:
	var pts: Array = n.neckPoints
	for i in range(n.frontEndPoint, pts.size() - 1):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		if (y - a.y) * (y - b.y) <= 0.0 and a.y != b.y:
			return lerpf(a.x, b.x, (y - a.y) / (b.y - a.y))
	return -60.0
