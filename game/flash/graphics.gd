class_name FlashGraphics
extends RefCounted
## flash.display.Graphics: records drawing commands and renders them on the owner sprite.
##
## Each fill becomes its own RenderingServer canvas item (drawn under the sprite's children) with a pooled
## gradient material, so solid / linear / radial / focal fills render exactly and can be redrawn every tick.

const FILL_SHADER := preload("res://flash/shaders/graphics_fill.gdshader")

var _owner: FlashSprite
var _fills: Array = []      # [{style: Dictionary, paths: Array[PackedVector2Array]}]
var _lines: Array = []      # [{width, color, alpha, points: PackedVector2Array}]
var _cur_fill = null
var _cur_line = null
var _pen := Vector2.ZERO
var _items: Array = []      # RID per fill
var _materials: Array = []  # ShaderMaterial per fill
var _dirty := false
var _bounds := Rect2()


func _init(owner: FlashSprite) -> void:
	_owner = owner


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for rid in _items:
			RenderingServer.free_rid(rid)


## flash.geom.Matrix.createGradientBox: maps the -819.2..819.2 gradient square onto a w x h box at (tx, ty).
static func createGradientBox(w: float, h: float, rot: float = 0.0, tx: float = 0.0, ty: float = 0.0) -> Transform2D:
	# Flash's formula: a = cos*w, b = sin*h, c = -sin*w, d = cos*h (all / 1638.4).
	var c := cos(rot)
	var s := sin(rot)
	return Transform2D(Vector2(c * w / 1638.4, s * h / 1638.4), Vector2(-s * w / 1638.4, c * h / 1638.4),
		Vector2(tx + w / 2.0, ty + h / 2.0))


func clear() -> void:
	_fills.clear()
	_lines.clear()
	_cur_fill = null
	_cur_line = null
	_pen = Vector2.ZERO
	_mark()


func beginFill(color: int, alpha: float = 1.0) -> void:
	_end_current_fill()
	var c := Color.hex((color << 8) | 0xFF)
	c.a = alpha
	_cur_fill = {"style": {"mode": 0, "color": c}, "paths": [PackedVector2Array([_pen])]}


## type: "linear" or "radial". colors: RGB ints; alphas: 0..1; ratios: 0..255; m: Transform2D gradient box.
func beginGradientFill(type: String, colors: Array, alphas: Array, ratios: Array, m: Transform2D = Transform2D.IDENTITY,
		_spread: String = "pad", _interp: String = "rgb", focal_point_ratio: float = 0.0) -> void:
	_end_current_fill()
	var cols: Array = []
	for i in colors.size():
		var c := Color.hex((int(colors[i]) << 8) | 0xFF)
		c.a = alphas[i] if i < alphas.size() else 1.0
		cols.append(c)
	var rs: Array = []
	for r in ratios:
		rs.append(float(r) / 255.0)
	_cur_fill = {"style": {"mode": 1 if type == "linear" else 2, "colors": cols, "ratios": rs, "matrix": m,
		"focal": focal_point_ratio}, "paths": [PackedVector2Array([_pen])]}


func endFill() -> void:
	_end_current_fill()
	_mark()


func lineStyle(thickness = null, color: int = 0, alpha: float = 1.0) -> void:
	if thickness == null or (thickness is float and is_nan(thickness)):
		_cur_line = null
		return
	var c := Color.hex((color << 8) | 0xFF)
	c.a = alpha
	_cur_line = {"width": maxf(float(thickness), 1.0), "color": c, "points": PackedVector2Array([_pen])}
	_lines.append(_cur_line)


func moveTo(x: float, y: float) -> void:
	_pen = Vector2(x, y)
	if _cur_fill != null:
		_cur_fill["paths"].append(PackedVector2Array([_pen]))
	if _cur_line != null:
		_cur_line = {"width": _cur_line["width"], "color": _cur_line["color"], "points": PackedVector2Array([_pen])}
		_lines.append(_cur_line)


func lineTo(x: float, y: float) -> void:
	_pen = Vector2(x, y)
	_add_point(_pen)


func curveTo(cx: float, cy: float, ax: float, ay: float) -> void:
	var p0 := _pen
	var c := Vector2(cx, cy)
	var p1 := Vector2(ax, ay)
	var n := clampi(int((p0.distance_to(c) + c.distance_to(p1)) / 3.0), 2, 24)
	for i in range(1, n + 1):
		var t := float(i) / n
		var u := 1.0 - t
		_add_point(p0 * (u * u) + c * (2.0 * u * t) + p1 * (t * t))
	_pen = p1


func drawRect(x: float, y: float, w: float, h: float) -> void:
	moveTo(x, y)
	lineTo(x + w, y)
	lineTo(x + w, y + h)
	lineTo(x, y + h)
	lineTo(x, y)


func drawCircle(x: float, y: float, r: float) -> void:
	moveTo(x + r, y)
	for i in range(1, 33):
		var a := TAU * i / 32.0
		lineTo(x + cos(a) * r, y + sin(a) * r)


func copyFrom(other: FlashGraphics) -> void:
	_fills = other._fills.duplicate(true)
	_lines = other._lines.duplicate(true)
	_cur_fill = null
	_cur_line = null
	_pen = other._pen
	_mark()


func _add_point(p: Vector2) -> void:
	if _cur_fill != null:
		var paths: Array = _cur_fill["paths"]
		paths[paths.size() - 1].append(p)
	if _cur_line != null:
		_cur_line["points"].append(p)
	_mark()


func _end_current_fill() -> void:
	if _cur_fill != null:
		_fills.append(_cur_fill)
		_cur_fill = null


func _mark() -> void:
	_owner._bounds_changed()
	_owner._hb_invalidate()
	if not _dirty:
		_dirty = true
		_owner.queue_redraw()


func has_content() -> bool:
	return not _fills.is_empty() or not _lines.is_empty() or _cur_fill != null


func bounds() -> Rect2:
	_compute_bounds()
	return _bounds


func _compute_bounds() -> void:
	var first := true
	var r := Rect2()
	for f in _all_fills():
		for path in f["paths"]:
			for p in path:
				if first:
					r = Rect2(p, Vector2.ZERO)
					first = false
				else:
					r = r.expand(p)
	for l in _lines:
		for p in l["points"]:
			if first:
				r = Rect2(p, Vector2.ZERO)
				first = false
			else:
				r = r.expand(p)
	_bounds = r


func _all_fills() -> Array:
	if _cur_fill != null:
		return _fills + [_cur_fill]
	return _fills


func hit(p: Vector2) -> bool:
	for f in _all_fills():
		var inside := false
		for path in f["paths"]:
			if path.size() >= 3 and Geometry2D.is_point_in_polygon(p, path):
				inside = not inside
		if inside:
			return true
	return false


## Called from the owner's _draw (or by a mask proxy drawing onto 'canvas').
func _render(canvas: CanvasItem) -> void:
	_dirty = false
	if canvas != _owner:
		# Mask rendering: shape only, colour irrelevant.
		for f in _all_fills():
			for path in f["paths"]:
				var tri := Geometry2D.triangulate_polygon(path)
				if tri.size() >= 3:
					canvas.draw_colored_polygon(path, Color.WHITE)
		return
	var fills := _all_fills()
	var parent_rid := _owner.get_canvas_item()
	while _items.size() < fills.size():
		var rid := RenderingServer.canvas_item_create()
		RenderingServer.canvas_item_set_parent(rid, parent_rid)
		RenderingServer.canvas_item_set_draw_behind_parent(rid, false)
		_items.append(rid)
		var m := ShaderMaterial.new()
		m.shader = FILL_SHADER
		_materials.append(m)
		RenderingServer.canvas_item_set_material(rid, m.get_rid())
	for i in _items.size():
		var rid: RID = _items[i]
		RenderingServer.canvas_item_clear(rid)
		# Keep fills underneath the sprite's children, in fill order.
		RenderingServer.canvas_item_set_draw_index(rid, -1000 + i)
		if i >= fills.size():
			continue
		var f: Dictionary = fills[i]
		_configure_material(_materials[i], f["style"])
		for path in f["paths"]:
			if path.size() < 3:
				continue
			var idx := Geometry2D.triangulate_polygon(path)
			if idx.is_empty():
				continue
			RenderingServer.canvas_item_add_triangle_array(rid, idx, path, PackedColorArray([Color.WHITE]))
	for l in _lines:
		if l["points"].size() >= 2:
			canvas.draw_polyline(l["points"], l["color"], l["width"], true)


func _configure_material(m: ShaderMaterial, style: Dictionary) -> void:
	var off := _owner.effective_color_offset() / 255.0
	m.set_shader_parameter("offset", Vector4(off.r, off.g, off.b, off.a))
	m.set_shader_parameter("fill_mode", style["mode"])
	if style["mode"] == 0:
		m.set_shader_parameter("solid", style["color"])
		return
	var mt: Transform2D = style["matrix"].affine_inverse()
	m.set_shader_parameter("inv_matrix", Basis(Vector3(mt.x.x, mt.x.y, 0), Vector3(mt.y.x, mt.y.y, 0),
		Vector3(mt.origin.x, mt.origin.y, 1)))
	m.set_shader_parameter("focal", style.get("focal", 0.0))
	var cols: Array = style["colors"]
	var rs: Array = style["ratios"]
	var n := mini(cols.size(), 8)
	var pc := PackedVector4Array()
	var pr := PackedFloat32Array()
	for i in 8:
		var c: Color = cols[mini(i, n - 1)]
		pc.append(Vector4(c.r, c.g, c.b, c.a))
		pr.append(rs[mini(i, n - 1)])
	m.set_shader_parameter("stop_count", n)
	m.set_shader_parameter("stop_colors", pc)
	m.set_shader_parameter("stop_ratios", pr)
