class_name FlashDisplayObject
extends Node2D
## Base of every node that takes part in the Flash-style display list.
##
## Mirrors flash.display.DisplayObject: Flash name, alpha / color transform, blend mode, filters, masks,
## events and coordinate conversion. Transform properties use Godot's Node2D directly
## (position, rotation_degrees, scale, skew); Flash's per-axis scale maps to scale.x / scale.y.
##
## The "Flash tree" can differ from the Godot tree: masks, filters and blend groups insert proxy nodes
## (see FlashProxy) between a container and its child. Always navigate with flash_parent() /
## FlashSprite.get_child_at() etc., never with get_parent()/get_child() directly.

## Instance name as used by ActionScript (getChildByName, timeline property binding).
var flash_name: String = ""
## Timeline bookkeeping (set by FlashMovieClip when the timeline owns this child).
var _depth: int = -1
var _birth: int = -1
var _place_index: int = -1
var _char_id: int = -1
var _library = null
## Flash parent container (independent of proxies in the Godot tree).
var _flash_parent: FlashDisplayObject = null

var mouse_enabled: bool = true

var _color_transform: FlashColorTransform = FlashColorTransform.new()
var _blend_mode: String = "normal"
var _filters: Array = []
var _mask: FlashDisplayObject = null
## Set when this object is used as another object's mask (it is then not rendered itself).
var _masking: Array = []
## Clip-depth (timeline) mask: masks siblings with depth in (_depth, _clip_depth].
var _clip_depth: int = 0
var _proxy: Node2D = null

var _listeners: Dictionary = {}


# ---------------------------------------------------------------- tree helpers

func flash_parent() -> FlashSprite:
	return _flash_parent as FlashSprite


## Topmost node actually inserted in the Godot tree for this object (itself or its outermost proxy).
func _tree_node() -> Node2D:
	var n: Node2D = self
	var p: Node2D = _proxy
	while p != null:
		n = p
		p = p.get(&"_proxy")
	return n


func _on_added() -> void:
	if not _listeners.is_empty() or _flash_parent != null:
		dispatch_event(FlashEvent.new(FlashEvent.ADDED, true))


func _on_removed() -> void:
	dispatch_event(FlashEvent.new(FlashEvent.REMOVED, true))


func get_stage() -> FlashSprite:
	return Flash.stage if is_inside_tree() else null


func get_root() -> FlashDisplayObject:
	var o: FlashDisplayObject = self
	while o._flash_parent != null:
		o = o._flash_parent
	return o


# ---------------------------------------------------------------- appearance

var alpha: float:
	get:
		return _color_transform.alpha_multiplier
	set(value):
		_color_transform.alpha_multiplier = value
		_apply_color_transform()


var color_transform: FlashColorTransform:
	get:
		return _color_transform.clone()
	set(value):
		_color_transform = value.clone()
		_apply_color_transform()


func _apply_color_transform() -> void:
	var ct := _color_transform
	var c := Color(ct.red_multiplier, ct.green_multiplier, ct.blue_multiplier, ct.alpha_multiplier)
	if _proxy is FlashGroupProxy:
		# Offscreen group: multipliers apply to the composited image (Flash layer semantics).
		_proxy.modulate = c
		modulate = Color.WHITE
	else:
		modulate = c
	if ct.has_offsets() or _had_offsets:
		_had_offsets = ct.has_offsets()
		_render_state_changed()

var _had_offsets := false


## Called when inherited render state (color offsets, blend mode, color-matrix filters) may have changed for
## this object or an ancestor. Shapes rebuild their material; containers forward to their children.
func _render_state_changed() -> void:
	pass


## True if this object carries render state that its descendants inherit.
func _has_own_render_state() -> bool:
	if _color_transform.has_offsets():
		return true
	if _blend_mode != "normal" and _blend_mode != "layer":
		return true
	for f in _filters:
		if f is FlashFilter and f.type == "ColorMatrix":
			return true
	return false


## True if this object or any ancestor carries inherited render state.
func _in_render_state_chain() -> bool:
	var o: FlashDisplayObject = self
	while o != null:
		if o._has_own_render_state():
			return true
		o = o._flash_parent
	return false


## Sum of additive offsets (0..255 units) that apply to content drawn by this node, accounting for the
## multipliers of ancestors: Flash applies child transform first, then each parent in turn.
func effective_color_offset() -> Color:
	var off := Color(0, 0, 0, 0)
	var o: FlashDisplayObject = self
	while o != null:
		var ct := o._color_transform
		off = Color(off.r * ct.red_multiplier + ct.red_offset, off.g * ct.green_multiplier + ct.green_offset,
			off.b * ct.blue_multiplier + ct.blue_offset, off.a * ct.alpha_multiplier + ct.alpha_offset)
		o = o._flash_parent
	return off


var blend_mode: String:
	get:
		return _blend_mode
	set(value):
		_blend_mode = value
		FlashProxy.update_for(self)


var filters: Array:
	get:
		return _filters.duplicate()
	set(value):
		_filters = value.duplicate() if value != null else []
		FlashProxy.update_for(self)


var mask: FlashDisplayObject:
	get:
		return _mask
	set(value):
		if _mask != null:
			_mask._masking.erase(self)
			_mask._update_mask_visibility()
		_mask = value
		if _mask != null:
			_mask._masking.append(self)
			_mask._update_mask_visibility()
		FlashProxy.update_for(self)


func _update_mask_visibility() -> void:
	# Masks are never rendered directly; the proxy of the masked object draws them as a clip region.
	# The container keeps mask objects under a hidden holder node (see FlashSprite._sync_tree).
	var was := _mask_hidden
	_mask_hidden = not (_masking.is_empty() and _clip_depth == 0)
	if was != _mask_hidden and _flash_parent != null:
		_flash_parent._mark_tree_dirty()
		_flash_parent._sync_tree()


var _mask_hidden := false


func _all_descendants() -> Array:
	var out: Array = []
	var stack: Array = [self]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			if c is CanvasItem:
				out.append(c)
				stack.append(c)
	return out


# ---------------------------------------------------------------- transform helpers

## Flash 'transform.matrix' as Transform2D.
var matrix: Transform2D:
	get:
		return transform
	set(value):
		transform = value


func set_flash_matrix(m: Array) -> void:
	transform = Transform2D(Vector2(m[0], m[1]), Vector2(m[2], m[3]), Vector2(m[4], m[5]))


## Global (stage) transform in Flash coordinates (the stage root sits at the canvas origin).
func flash_global_transform() -> Transform2D:
	var t := transform
	var o := _flash_parent
	while o != null:
		t = o.transform * t
		o = o._flash_parent
	return t


func local_to_global(p: Vector2) -> Vector2:
	return flash_global_transform() * p


func global_to_local(p: Vector2) -> Vector2:
	return flash_global_transform().affine_inverse() * p


var mouse_x: float:
	get:
		return global_to_local(Flash.mouse_position()).x

var mouse_y: float:
	get:
		return global_to_local(Flash.mouse_position()).y


# ---------------------------------------------------------------- bounds

## Bounds of this object's own drawn content in its local space (overridden by shapes / containers).
func _local_bounds() -> Rect2:
	return Rect2()


## Flash getBounds(target): axis-aligned bounds in target's coordinate space.
func get_bounds(target: FlashDisplayObject = null) -> Rect2:
	var t := flash_global_transform()
	if target != null:
		t = target.flash_global_transform().affine_inverse() * t
	return _bounds_through(t)


func _bounds_through(t: Transform2D) -> Rect2:
	var b := _local_bounds()
	if b.size == Vector2.ZERO and b.position == Vector2.ZERO:
		return Rect2()
	return _xform_rect(t, b)


static func _xform_rect(t: Transform2D, r: Rect2) -> Rect2:
	var p0 := t * r.position
	var out := Rect2(p0, Vector2.ZERO)
	out = out.expand(t * Vector2(r.end.x, r.position.y))
	out = out.expand(t * Vector2(r.position.x, r.end.y))
	out = out.expand(t * r.end)
	return out


var width: float:
	get:
		return _get_width()
	set(value):
		_set_width(value)

var height: float:
	get:
		return _get_height()
	set(value):
		_set_height(value)


func _get_width() -> float:
	return get_bounds(_flash_parent).size.x if _flash_parent else _bounds_through(transform).size.x


func _get_height() -> float:
	return get_bounds(_flash_parent).size.y if _flash_parent else _bounds_through(transform).size.y


func _set_width(value: float) -> void:
	var w := _local_bounds().size.x
	if w > 0.0:
		scale.x = value / w


func _set_height(value: float) -> void:
	var h := _local_bounds().size.y
	if h > 0.0:
		scale.y = value / h


# ---------------------------------------------------------------- hit testing

## Flash hitTestPoint: (x, y) in stage coordinates. shape_flag tests actual drawn pixels instead of bounds.
func hit_test_point(x: float, y: float, shape_flag: bool = false) -> bool:
	if not shape_flag:
		return get_bounds(null).has_point(Vector2(x, y))
	return _hit_shape(flash_global_transform().affine_inverse() * Vector2(x, y))


## p is in this object's local space.
func _hit_shape(_p: Vector2) -> bool:
	return false


# ---------------------------------------------------------------- events

func add_event_listener(type: String, listener: Callable, use_capture: bool = false, priority: int = 0) -> void:
	if type == FlashEvent.ENTER_FRAME:
		Flash.add_enter_frame(self, listener)
		return
	var list: Array = _listeners.get(type, [])
	for l in list:
		if l[0] == listener and l[1] == use_capture:
			return
	list.append([listener, use_capture, priority])
	list.sort_custom(func(a, b): return a[2] > b[2])
	_listeners[type] = list


func remove_event_listener(type: String, listener: Callable, use_capture: bool = false) -> void:
	if type == FlashEvent.ENTER_FRAME:
		Flash.remove_enter_frame(self, listener)
		return
	var list: Array = _listeners.get(type, [])
	for i in range(list.size() - 1, -1, -1):
		if list[i][0] == listener and list[i][1] == use_capture:
			list.remove_at(i)


func has_event_listener(type: String) -> bool:
	if type == FlashEvent.ENTER_FRAME:
		return Flash.has_enter_frame(self)
	return not _listeners.get(type, []).is_empty()


## Dispatches with Flash semantics: capture phase (root→parent), target, then bubble (parent→root).
func dispatch_event(event: FlashEvent) -> bool:
	event.target = self
	var chain: Array = []
	var p := _flash_parent
	while p != null:
		chain.append(p)
		p = p._flash_parent
	for i in range(chain.size() - 1, -1, -1):
		if event._stop:
			return true
		event.event_phase = FlashEvent.CAPTURING_PHASE
		chain[i]._invoke_listeners(event, true)
	if not event._stop:
		event.event_phase = FlashEvent.AT_TARGET
		_invoke_listeners(event, false)
	if event.bubbles:
		for o in chain:
			if event._stop:
				break
			event.event_phase = FlashEvent.BUBBLING_PHASE
			o._invoke_listeners(event, false)
	return not event.default_prevented


func _invoke_listeners(event: FlashEvent, capture: bool) -> void:
	var list: Array = _listeners.get(event.type, [])
	if list.is_empty():
		return
	event.current_target = self
	for l in list.duplicate():
		if l[1] != capture:
			continue
		var cb: Callable = l[0]
		if not cb.is_valid():
			continue
		if cb.get_argument_count() == 0:
			cb.call()
		else:
			cb.call(event)
		if event._stop_immediate:
			return
