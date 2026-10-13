class_name FlashSprite
extends FlashDisplayObject
## flash.display.Sprite / DisplayObjectContainer.
##
## _children is the authoritative Flash child list (index 0 = bottom). The Godot tree is derived from it by
## _sync_tree(), which wraps children in proxies for masks / blend groups. Syncing is deferred to the end of
## the tick, so all Flash-space queries go through _children and _flash_parent, never the Godot tree.

var _children: Array = []
var mouseChildren: bool = true
var buttonMode: bool = false
var useHandCursor: bool = true
## Rectangle used instead of children for hit testing, if set (Flash hitArea).
var hitArea: FlashDisplayObject = null
var _tree_dirty := false
var _graphics: FlashGraphics = null
var _clip_proxies: Dictionary = {}   # clip mask object -> FlashProxy
var _mask_holder: Node2D = null      # hidden node holding children used as masks (kept in tree, not drawn)


var graphics: FlashGraphics:
	get:
		if _graphics == null:
			_graphics = FlashGraphics.new(self)
		return _graphics


func _draw() -> void:
	if _graphics != null:
		_graphics._render(self)


# ---------------------------------------------------------------- child list API

var numChildren: int:
	get:
		return _children.size()


func addChild(child: FlashDisplayObject) -> FlashDisplayObject:
	return addChildAt(child, _children.size() if child._flash_parent != self else _children.size() - 1)


func addChildAt(child: FlashDisplayObject, index: int) -> FlashDisplayObject:
	if child._flash_parent != null:
		child._flash_parent._detach(child)
	index = clampi(index, 0, _children.size())
	_children.insert(index, child)
	child._flash_parent = self
	_mark_tree_dirty()
	_sync_tree()
	if _in_render_state_chain():
		child._render_state_changed()
	child._on_added()
	return child


func _render_state_changed() -> void:
	for c in _children:
		c._render_state_changed()
	if _graphics != null and _graphics.has_content():
		queue_redraw()


func removeChild(child: FlashDisplayObject) -> FlashDisplayObject:
	if child._flash_parent != self:
		push_error("remove_child_flash: not a child")
		return child
	_detach(child)
	child._on_removed()
	return child


func removeChildAt(index: int) -> FlashDisplayObject:
	return removeChild(_children[index])


func removeChildren() -> void:
	while not _children.is_empty():
		removeChildAt(_children.size() - 1)


func _detach(child: FlashDisplayObject) -> void:
	_children.erase(child)
	child._flash_parent = null
	if child._clip_depth > 0 and _clip_proxies.has(child):
		var p: Node2D = _clip_proxies[child]
		_clip_proxies.erase(child)
		p._release_children()
		p.queue_free()
	var n := child._tree_node()
	if n.get_parent() != null:
		n.get_parent().remove_child(n)
	_mark_tree_dirty()


func getChildAt(index: int) -> FlashDisplayObject:
	return _children[index] if index >= 0 and index < _children.size() else null


func getChildIndex(child: FlashDisplayObject) -> int:
	return _children.find(child)


func setChildIndex(child: FlashDisplayObject, index: int) -> void:
	var i := _children.find(child)
	if i < 0:
		return
	_children.remove_at(i)
	_children.insert(clampi(index, 0, _children.size()), child)
	_mark_tree_dirty()
	_sync_tree()


func swapChildren(a: FlashDisplayObject, b: FlashDisplayObject) -> void:
	var ia := _children.find(a)
	var ib := _children.find(b)
	if ia < 0 or ib < 0:
		return
	_children[ia] = b
	_children[ib] = a
	_mark_tree_dirty()
	_sync_tree()


func getChildByName(n: String) -> FlashDisplayObject:
	for c in _children:
		if c.flash_name == n:
			return c
	return null


func contains(o: FlashDisplayObject) -> bool:
	while o != null:
		if o == self:
			return true
		o = o._flash_parent
	return false


# ---------------------------------------------------------------- Godot tree sync

func _mark_tree_dirty() -> void:
	_tree_dirty = true


## Rebuilds the Godot child order (with mask / group proxies) from _children.
func _sync_tree() -> void:
	if not _tree_dirty:
		return
	_tree_dirty = false
	var seq: Array = []          # nodes directly under self, in order
	var masks: Array = []        # mask objects (go into the hidden holder)
	var clip_owner = null        # active clip mask object
	var clip_seq: Array = []
	var used_clips := {}
	for c in _children:
		if not c._masking.is_empty() and c._clip_depth == 0:
			masks.append(c._tree_node())
			continue
		if clip_owner != null and (c._depth < 0 or c._depth > clip_owner._clip_depth):
			_clip_proxies[clip_owner]._set_content(clip_seq)
			clip_owner = null
		if c._clip_depth > 0:
			var p: Node2D = _clip_proxies.get(c)
			if p == null:
				p = FlashProxy.new_clip(self, c)
				_clip_proxies[c] = p
			used_clips[c] = true
			masks.append(c._tree_node())
			seq.append(p)
			clip_owner = c
			clip_seq = []
			continue
		if clip_owner != null:
			clip_seq.append(c._tree_node())
		else:
			seq.append(c._tree_node())
	if clip_owner != null:
		_clip_proxies[clip_owner]._set_content(clip_seq)
	for k in _clip_proxies.keys():
		if not used_clips.has(k):
			var p: Node2D = _clip_proxies[k]
			_clip_proxies.erase(k)
			p._release_children()
			if p.get_parent() != null:
				p.get_parent().remove_child(p)
			p.queue_free()
	if not masks.is_empty() or _mask_holder != null:
		if _mask_holder == null:
			_mask_holder = Node2D.new()
			_mask_holder.name = "_masks"
			_mask_holder.visible = false
		FlashProxy.reconcile(_mask_holder, masks)
		seq.push_front(_mask_holder)
	FlashProxy.reconcile(self, seq)


# ---------------------------------------------------------------- bounds / hit testing

func _local_bounds() -> Rect2:
	var r := Rect2()
	var first := true
	if _graphics != null and _graphics.has_content():
		r = _graphics.bounds()
		first = false
	for c in _children:
		var cb: Rect2 = c._bounds_through(c.transform)
		if cb.size == Vector2.ZERO and cb.position == Vector2.ZERO:
			continue
		if first:
			r = cb
			first = false
		else:
			r = r.merge(cb)
	return r


func _bounds_through(t: Transform2D) -> Rect2:
	# Tighter than transforming the local bounds: transform each child's bounds individually.
	var r := Rect2()
	var first := true
	if _graphics != null and _graphics.has_content():
		r = _xform_rect(t, _graphics.bounds())
		first = false
	for c in _children:
		var cb: Rect2 = c._bounds_through(t * c.transform)
		if cb.size == Vector2.ZERO and cb.position == Vector2.ZERO:
			continue
		if first:
			r = cb
			first = false
		else:
			r = r.merge(cb)
	return r


func _hit_shape(p: Vector2) -> bool:
	if _graphics != null and _graphics.hit(p):
		return true
	for i in range(_children.size() - 1, -1, -1):
		var c: FlashDisplayObject = _children[i]
		if not c.visible and c._masking.is_empty():
			continue
		if c._clip_depth > 0 or not c._masking.is_empty():
			continue
		if c._hit_shape(c.transform.affine_inverse() * p):
			if _clip_allows(c, p):
				return true
	return false


## For children under a timeline clip mask, a hit only counts inside the mask.
func _clip_allows(c: FlashDisplayObject, p: Vector2) -> bool:
	if c._depth < 0:
		return true
	for m in _clip_proxies:
		if c._depth > m._depth and c._depth <= m._clip_depth:
			return m._hit_shape(m.transform.affine_inverse() * p)
	return true


## Finds the deepest interactive object under p (local space) for mouse dispatch.
func _mouse_target(p: Vector2) -> FlashDisplayObject:
	if not visible or _mask_hidden:
		return null
	if hitArea != null:
		var gp := flash_global_transform() * p
		return self if mouseEnabled and hitArea.hitTestPoint(gp.x, gp.y, true) else null
	for i in range(_children.size() - 1, -1, -1):
		var c: FlashDisplayObject = _children[i]
		if not c.visible or c._clip_depth > 0 or not c._masking.is_empty():
			continue
		var lp: Vector2 = c.transform.affine_inverse() * p
		if c._mask != null:
			var gp := flash_global_transform() * p
			if not c._mask.hitTestPoint(gp.x, gp.y, true):
				continue
		if not _clip_allows(c, p):
			continue
		if c is FlashSprite:
			var t: FlashDisplayObject = c._mouse_target(lp)
			if t != null:
				if not mouseChildren:
					return self if mouseEnabled else null
				return t
		elif c._hit_shape(lp):
			if c is FlashTextField and c.mouseEnabled:
				return c if mouseChildren else (self if mouseEnabled else null)
			return self if mouseEnabled else _first_enabled_ancestor()
	if _graphics != null and _graphics.hit(p):
		return self if mouseEnabled else _first_enabled_ancestor()
	return null


func _first_enabled_ancestor() -> FlashDisplayObject:
	var o := _flash_parent
	while o != null:
		if o.mouseEnabled:
			return o
		o = o._flash_parent
	return null
