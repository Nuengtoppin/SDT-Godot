class_name Presentation
extends Node2D
## Port addition (widescreen): shows the 700x600 Flash stage centred in a window of any shape, at full height.
## The stage keeps its own coordinates; Flash.presentation_rect tells the game what part of them the window shows
## (x < 0 and x > 700 in the side areas). The background draws as wide as it is: the game's own are 700 wide, a
## wide custom image or a SWF background may reach into the side areas. Behind it, filling the window: a blurred,
## darkened copy of the background (Settings > Window > Blurred sides). Her, him and the strands may reach into the
## side areas too (the game's screen masks are widened to the window).
## Based on the widescreen shell contributed by @Nuengtoppin (issue #1).

const STAGE_SIZE := Vector2(700, 600)
const AMBIENT_PX := 320.0   # long side of the blurred background's render target

const AMBIENT_SHADER := """
shader_type canvas_item;
render_mode unshaded;
uniform sampler2D source : filter_linear, repeat_disable;
uniform vec2 source_texel = vec2(0.003125, 0.005556);
void fragment() {
	vec2 d = source_texel * 2.5;
	vec3 c = texture(source, UV).rgb * 0.20;
	c += (texture(source, UV + vec2(d.x, 0.0)).rgb + texture(source, UV - vec2(d.x, 0.0)).rgb
		+ texture(source, UV + vec2(0.0, d.y)).rgb + texture(source, UV - vec2(0.0, d.y)).rgb) * 0.10;
	c += (texture(source, UV + d).rgb + texture(source, UV - d).rgb
		+ texture(source, UV + vec2(d.x, -d.y)).rgb + texture(source, UV + vec2(-d.x, d.y)).rgb) * 0.05;
	c += (texture(source, UV + vec2(2.0 * d.x, 0.0)).rgb + texture(source, UV - vec2(2.0 * d.x, 0.0)).rgb
		+ texture(source, UV + vec2(0.0, 2.0 * d.y)).rgb + texture(source, UV - vec2(0.0, 2.0 * d.y)).rgb) * 0.05;
	COLOR = vec4(c * 0.82, 1.0);
}
"""

## The Flash stage goes in here.
var host: Node2D
var _ambient_vp: SubViewport
var _ambient_painter: AmbientPainter
var _ambient_fill: ColorRect
var _ambient_mat: ShaderMaterial
var _size := Vector2.ZERO


## Paints the current background, scaled to cover the window, into a small render target (read only: no second
## Background or timeline). Built-in backgrounds are shapes, custom image backgrounds bitmaps.
class AmbientPainter extends Node2D:
	var canvas_size := Vector2(320, 180)

	func _draw() -> void:
		if not is_instance_valid(g.bg) or not g.bg.visible:
			return
		var bounds: Rect2 = g.bg.getBounds(g.bg)
		if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
			return
		var k: float = maxf(canvas_size.x / bounds.size.x, canvas_size.y / bounds.size.y)
		# follows the camera's zoom a little (SceneLayer.currentZoom is at least 0.4)
		var zoom: float = maxf(0.4, g.sceneLayer.currentZoom) if is_instance_valid(g.sceneLayer) else g.defaultZoom + 0.4
		k *= zoom / 0.4
		var center: Vector2 = bounds.get_center()
		var half: Vector2 = canvas_size / (2.0 * k)
		center.y = clampf(300.0 - g.bg.y, bounds.position.y + half.y, bounds.end.y - half.y)
		var fit := Transform2D(Vector2(k, 0), Vector2(0, k), canvas_size * 0.5 - center * k)
		var ct: FlashColorTransform = g.bg.colorTransform
		var tint := Color(ct.redMultiplier, ct.greenMultiplier, ct.blueMultiplier, ct.alphaMultiplier)
		for c in g.bg._children:
			_paint(c, fit * c.transform, tint)
		draw_set_transform_matrix(Transform2D.IDENTITY)

	func _paint(o: FlashDisplayObject, xf: Transform2D, inherited: Color) -> void:
		if not is_instance_valid(o) or not o.visible:
			return
		var ct: FlashColorTransform = o.colorTransform
		var tint := inherited * Color(ct.redMultiplier, ct.greenMultiplier, ct.blueMultiplier, ct.alphaMultiplier)
		if tint.a <= 0.0:
			return
		draw_set_transform_matrix(xf)
		if o is FlashShape:
			var s := o as FlashShape
			if s._texture != null and not s._draw_entry.is_empty():
				var e: Dictionary = s._draw_entry
				draw_texture_rect(s._texture, Rect2(Vector2(e["x"], e["y"]), Vector2(s._texture.get_size()) / s._library.scale),
					false, tint)
		elif o is FlashBitmap:
			var b := o as FlashBitmap
			if b.bitmapData != null:
				draw_texture(b.bitmapData.get_texture(), Vector2.ZERO, tint)
		elif o is FlashSprite:
			for c in (o as FlashSprite)._children:
				_paint(c, xf * c.transform, tint)


func _ready() -> void:
	name = "Presentation"
	_ambient_vp = SubViewport.new()
	_ambient_vp.disable_3d = true
	_ambient_vp.world_2d = World2D.new()
	_ambient_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_ambient_vp)
	_ambient_painter = AmbientPainter.new()
	_ambient_vp.add_child(_ambient_painter)
	_ambient_fill = ColorRect.new()
	_ambient_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ambient_fill.color = Color.BLACK
	var sh := Shader.new()
	sh.code = AMBIENT_SHADER
	_ambient_mat = ShaderMaterial.new()
	_ambient_mat.shader = sh
	_ambient_mat.set_shader_parameter("source", _ambient_vp.get_texture())
	add_child(_ambient_fill)
	host = Node2D.new()
	host.name = "GameFrame"
	add_child(host)
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	var extent: Vector2 = get_viewport().get_visible_rect().size
	_size = extent
	# full height; only a window narrower than the game's own shape fits by width
	var k: float = minf(extent.y / STAGE_SIZE.y, extent.x / STAGE_SIZE.x)
	host.scale = Vector2(k, k)
	host.position = ((extent - STAGE_SIZE * k) * 0.5).round()
	Flash.presentation_rect = Rect2(-host.position / k, extent / k)
	_ambient_fill.position = Vector2.ZERO
	_ambient_fill.size = extent
	var down: float = AMBIENT_PX / maxf(1.0, maxf(extent.x, extent.y))
	_ambient_vp.size = Vector2i(maxi(2, roundi(extent.x * down)), maxi(2, roundi(extent.y * down)))
	_ambient_painter.canvas_size = Vector2(_ambient_vp.size)
	_ambient_mat.set_shader_parameter("source_texel", Vector2.ONE / Vector2(_ambient_vp.size))


## The game field in the viewport's coordinates.
func game_rect() -> Rect2:
	return Rect2(host.position, STAGE_SIZE * host.scale)


func _process(_delta: float) -> void:
	if _size != get_viewport().get_visible_rect().size:
		_layout()
	var sides := Flash.presentation_rect.size.x > STAGE_SIZE.x + 1.0 or Flash.presentation_rect.size.y > STAGE_SIZE.y + 1.0
	var blur := sides and PortSettings.blurred_sides()
	_ambient_fill.material = _ambient_mat if blur else null
	_ambient_fill.visible = sides
	_ambient_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if blur else SubViewport.UPDATE_DISABLED
	if blur:
		_ambient_painter.queue_redraw()
	_fit_masks()
	_fit_title()


## The title screen's gradient (and the loading one before it) covers the whole window, not just the game field;
## its text and buttons stay in the field. The loading gradient goes back to 700x600 once the title exists: it
## stays under the game for good (with no background it shows behind her, as in the game).
func _fit_title() -> void:
	if Flash.stage == null or Flash.stage._children.is_empty() or not (Flash.stage._children[0] is DT):
		return
	var dt: DT = Flash.stage._children[0]
	if is_instance_valid(dt.menuBG):
		if is_instance_valid(dt.preloaderBG):
			_cover(dt.preloaderBG, Rect2(Vector2.ZERO, STAGE_SIZE))
		if dt.menuBG.visible:
			_cover(dt.menuBG, Flash.presentation_rect)
	elif is_instance_valid(dt.preloaderBG):
		_cover(dt.preloaderBG, Flash.presentation_rect)


## Scales and places o (in its parent) so that its bounds fill rect (stage coordinates).
func _cover(o: FlashDisplayObject, rect: Rect2) -> void:
	var parent := o._flash_parent
	if parent == null:
		return
	var src: Rect2 = o.getBounds(o)
	if src.size.x <= 0.0 or src.size.y <= 0.0:
		return
	var fit: Vector2 = rect.size / src.size
	var in_stage := Transform2D(Vector2(fit.x, 0), Vector2(0, fit.y), rect.position - src.position * fit)
	var want: Transform2D = parent.flash_global_transform().affine_inverse() * Flash.stage.flash_global_transform() * in_stage
	if not o.transform.is_equal_approx(want):
		o.transform = want


## The game's screen masks (ScreenMask, 700x600) are widened to the window, so her, him and the strands are not
## cut off at the field's edge.
func _fit_masks() -> void:
	if not is_instance_valid(g.container):
		return
	for layer in [g.sceneLayer, g.backLayer, g.frontLayer, g.strandBackLayer, g.strandFrontLayer, g.cumLayer]:
		if is_instance_valid(layer) and is_instance_valid(layer.mask):
			_fit_mask(layer.mask)


func _fit_mask(clip: FlashDisplayObject) -> void:
	if clip._library != Flash.base_library or clip._char_id != Flash.base_library.class_id("ScreenMask"):
		return
	var rect: Rect2 = Flash.presentation_rect
	if clip.has_meta("fit_rect") and clip.get_meta("fit_rect") == rect:
		return
	var src: Rect2 = clip.getBounds(clip)
	if src.size.x <= 0.0 or src.size.y <= 0.0:
		return
	var fit: Vector2 = rect.size / src.size
	clip.transform = Transform2D(Vector2(fit.x, 0), Vector2(0, fit.y), rect.position - src.position * fit)
	clip.set_meta("fit_rect", rect)
