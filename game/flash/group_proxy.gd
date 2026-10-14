class_name FlashGroupProxy
extends Node2D
## Offscreen group for one display object: Flash BlendMode.LAYER (needed for ERASE / ALPHA children) and
## Blur / DropShadow / Glow / Shader filters.
##
## The object is rendered into a SubViewport sized to its bounds, in the object's own local space at screen
## resolution; this node takes the object's transform and draws the result (applying filters). SubViewports
## nest reliably and masks (clip_children) work inside them, unlike CanvasGroup.

const DISPLAY_SHADER := preload("res://flash/shaders/group_display.gdshader")
const MAX_SIZE := 4096
## Blend modes applied when compositing the group (0 = normal); see group_display.gdshader.
const BLEND_IDS := {"overlay": 1, "hardlight": 2, "screen": 3, "lighten": 4, "darken": 5, "difference": 6,
	"invert": 7, "multiply": 8, "add": 9, "subtract": 10}

var _proxy: CanvasItem = null
var _obj: FlashDisplayObject = null
var _vp: SubViewport
var _rect := Rect2()          # obj-local area captured
var _px_scale := 1.0          # render-target pixels per obj-local unit
var _margin := 0.0            # obj-local margin for filters
var _mat := ShaderMaterial.new()


func _init() -> void:
	_vp = SubViewport.new()
	_vp.world_2d = World2D.new()   # own canvas: content must not also draw in the parent viewport
	_vp.transparent_bg = true
	_vp.disable_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_vp.size = Vector2i(2, 2)
	add_child(_vp)
	_mat.shader = DISPLAY_SHADER
	material = _mat


func configure(obj: FlashDisplayObject) -> void:
	_obj = obj
	name = "group_" + obj.flash_name
	_margin = 0.0
	_mat.shader = DISPLAY_SHADER
	_mat.set_shader_parameter("mode", 0)
	_mat.set_shader_parameter("blend_mode", BLEND_IDS.get(obj._blend_mode, 0))
	var shader_filter: FlashFilter = null
	for f in obj._filters:
		if f is FlashFilter and f.type == "Shader":
			shader_filter = f
	if shader_filter != null:
		# A shader filter owns the material; a following inner drop shadow is folded into it (the highlight
		# shader supports that), other filters are dropped.
		_apply_filter(shader_filter)
		for f in obj._filters:
			if f is FlashFilter and f.type == "DropShadow":
				_mat.set_shader_parameter("has_shadow", true)
				var a := deg_to_rad(f.angle)
				_mat.set_shader_parameter("shadow_offset_px", Vector2(cos(a), sin(a)) * f.distance)
				_mat.set_shader_parameter("shadow_blur_px", Vector2(f.blurX, f.blurY))
				var c := Color.hex((f.color << 8) | 0xFF)
				c.a = f.alpha
				_mat.set_shader_parameter("shadow_color", c)
				_mat.set_shader_parameter("shadow_strength", f.strength)
				_margin = maxf(_margin, maxf(f.blurX, f.blurY) + f.distance + 2.0)
	else:
		for f in obj._filters:
			if not (f is FlashFilter) or f.type == "ColorMatrix":
				continue
			_apply_filter(f)
	Flash.register_group(self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		Flash.unregister_group(self)


func content_parent() -> Node:
	return _vp


func add_child_content(n: Node) -> void:
	_vp.add_child(n)


func _apply_filter(f: FlashFilter) -> void:
	if f.type == "Shader":
		_mat.shader = f.shader
		for k in f.shaderParams:
			_mat.set_shader_parameter(k, f.shaderParams[k])
		_margin = maxf(_margin, 8.0)
		return
	_mat.set_shader_parameter("passes", float(maxi(f.quality, 1)))
	_mat.set_shader_parameter("blur_px", Vector2(f.blurX, f.blurY))
	if f.type == "Blur":
		_mat.set_shader_parameter("mode", 1)
	else:
		_mat.set_shader_parameter("mode", 2)
		var a := deg_to_rad(f.angle)
		_mat.set_shader_parameter("offset_px", Vector2(cos(a), sin(a)) * f.distance)
		var c := Color.hex((f.color << 8) | 0xFF)
		c.a = f.alpha
		_mat.set_shader_parameter("shadow_color", c)
		_mat.set_shader_parameter("strength", f.strength)
		_mat.set_shader_parameter("inner", f.inner)
		_mat.set_shader_parameter("knockout", f.knockout)
		_mat.set_shader_parameter("hide_object", f.hideObject)
	_margin = maxf(_margin, maxf(f.blurX, f.blurY) + f.distance + 2.0)
	_filter_px = Vector2(f.blurX, f.blurY)
	_filter_offset = f.distance


var _filter_px := Vector2.ZERO
var _filter_offset := 0.0


## Called by the runtime every tick: follows the object's transform and resizes the render target.
func update_layout() -> void:
	if _obj == null or not is_instance_valid(_obj) or not is_inside_tree():
		return
	transform = _obj.transform
	visible = _obj.visible
	var b := _obj._local_bounds()
	if b.size.x <= 0.0 or b.size.y <= 0.0:
		_rect = Rect2()
		queue_redraw()
		return
	# Filters are specified in screen pixels; convert the margin into obj-local units.
	var screen := get_viewport().get_final_transform() * get_global_transform_with_canvas()
	var s := maxf(screen.x.length(), screen.y.length())
	s = maxf(s, 0.01)
	var margin := _margin / s
	b = b.grow(margin)
	var want := Vector2(ceilf(b.size.x * s), ceilf(b.size.y * s))
	if want.x > MAX_SIZE or want.y > MAX_SIZE:
		s *= minf(MAX_SIZE / want.x, MAX_SIZE / want.y)
		want = Vector2(ceilf(b.size.x * s), ceilf(b.size.y * s))
	var cur := Vector2(_vp.size)
	# Resize with hysteresis: grow with slack, shrink only when much too large.
	if want.x > cur.x or want.y > cur.y or want.x < cur.x * 0.5 or want.y < cur.y * 0.5:
		_vp.size = Vector2i(mini(int(want.x * 1.15) + 2, MAX_SIZE), mini(int(want.y * 1.15) + 2, MAX_SIZE))
	_rect = Rect2(b.position, Vector2(_vp.size) / s)
	_px_scale = s
	# Shadow / blur parameters are in render-target pixels (= screen pixels).
	var stretch := Flash.screen_scale()
	if _mat.shader != DISPLAY_SHADER:
		_mat.set_shader_parameter("px_scale", stretch)
	if _mat.shader == DISPLAY_SHADER:
		_mat.set_shader_parameter("blur_px", _filter_px * stretch)
		var a: float = deg_to_rad(_obj._filters[0].angle) if not _obj._filters.is_empty() and _obj._filters[0] is FlashFilter else 0.0
		_mat.set_shader_parameter("offset_px", Vector2(cos(a), sin(a)) * _filter_offset * stretch)
	# Inside the viewport the object is drawn with its own transform; cancel it and map obj-local -> pixels.
	_vp.canvas_transform = Transform2D(0.0, Vector2(s, s), 0.0, -b.position * s) * _obj.transform.affine_inverse()
	queue_redraw()


func _draw() -> void:
	if _rect.size == Vector2.ZERO:
		return
	draw_texture_rect(_vp.get_texture(), _rect, false)
