class_name FlashProxy
extends Node2D
## Helper node inserted in the Godot tree (never in the Flash tree) to implement masks.
##
## A clip proxy (timeline clipDepth mask) sits after its mask object and contains the masked siblings.
## A mask proxy (script 'mask' property) wraps a single object. Both clip their children to the mask's shapes,
## drawn here every tick with the mask's transform relative to the container.
##
## Static helpers also maintain the other wrappers an object can need: a FlashGroupProxy (offscreen group for
## 'layer' blend and blur / drop shadow / glow / shader filters) and a BackBufferCopy placed in front of objects
## using backdrop-reading blend modes (overlay, hardlight, screen ...).

const SCREEN_BLENDS := ["overlay", "hardlight", "screen", "lighten", "darken", "difference", "invert"]
const GROUP_FILTERS := ["DropShadow", "Glow", "Blur", "Shader", "Bevel"]

var _proxy: Node2D = null
var _container = null                   # FlashSprite whose space the mask is drawn in     # Flash container the masked content belongs to
var _mask_obj: FlashDisplayObject = null
var _wrapped: FlashDisplayObject = null  # for script masks


## Creates the node that clips a container's content to mask_obj (timeline clipDepth mask).
static func new_clip(container: FlashSprite, mask_obj: FlashDisplayObject) -> Node2D:
	var p := FlashProxy.new()
	p.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	p.name = "clip_%s" % mask_obj.flash_name if mask_obj.flash_name != "" else "clip"
	p._container = container
	p._mask_obj = mask_obj
	Flash.register_mask_proxy(p)
	return p


func _set_content(nodes: Array) -> void:
	FlashProxy.reconcile(self, nodes)


func _release_children() -> void:
	for c in get_children():
		remove_child(c)


func _exit_tree() -> void:
	pass


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		Flash.unregister_mask_proxy(self)


func _draw() -> void:
	if _mask_obj == null or not is_instance_valid(_mask_obj):
		return
	var base := Transform2D.IDENTITY
	var cont: FlashDisplayObject = _container if _container != null else (_wrapped._flash_parent if _wrapped else null)
	if cont != null:
		base = cont.flash_global_transform()
	var inv := base.affine_inverse()
	_draw_mask_object(_mask_obj, inv)


func _draw_mask_object(o: FlashDisplayObject, inv: Transform2D) -> void:
	if o is FlashShape:
		var s: FlashShape = o
		if s._texture == null:
			return
		draw_set_transform_matrix(inv * s.flash_global_transform())
		var sc: float = s._library.scale
		draw_texture_rect(s._texture, Rect2(s._entry["x"], s._entry["y"], s._texture.get_width() / sc,
			s._texture.get_height() / sc), false)
	elif o is FlashSprite:
		var sp: FlashSprite = o
		if sp._graphics != null and sp._graphics.has_content():
			draw_set_transform_matrix(inv * sp.flash_global_transform())
			sp._graphics._render(self)
		for c in sp._children:
			if c.visible:
				_draw_mask_object(c, inv)
	elif o is FlashBitmap:
		var b: FlashBitmap = o
		if b.bitmapData != null:
			draw_set_transform_matrix(inv * b.flash_global_transform())
			draw_texture(b.bitmapData.get_texture(), Vector2.ZERO)


# ---------------------------------------------------------------- tree reconciliation

## Makes parent's Godot children exactly 'seq' (in order). Nodes are moved from wherever they are.
static func reconcile(parent: Node, seq: Array) -> void:
	var expanded: Array = []
	for n in seq:
		var pre = n.get_meta("bbc", null) if n.has_meta("bbc") else null
		if pre != null:
			expanded.append(pre)
		expanded.append(n)
	for i in expanded.size():
		var n: Node = expanded[i]
		var cur := n.get_parent()
		if cur != parent:
			if cur != null:
				cur.remove_child(n)
			parent.add_child(n)
		if n.get_index() != i:
			parent.move_child(n, i)
	var extra := parent.get_child_count() - expanded.size()
	for _i in maxi(extra, 0):
		var last := parent.get_child(parent.get_child_count() - 1)
		parent.remove_child(last)


## Rebuilds the wrapper chain of obj after its mask / blend mode / filters changed.
static func update_for(obj: FlashDisplayObject) -> void:
	var need_group := obj._blend_mode == "layer"
	for f in obj._filters:
		if f is Dictionary and GROUP_FILTERS.has(f.get("type", "")):
			need_group = true
		elif f is FlashFilter and GROUP_FILTERS.has(f.type):
			need_group = true
	var need_mask := obj._mask != null
	var prev_outer := obj._tree_node()
	var old_bbc: Node = null
	if prev_outer.has_meta("bbc"):
		old_bbc = prev_outer.get_meta("bbc")
		prev_outer.remove_meta("bbc")
	# Tear down the existing chain (keeping nodes we can reuse).
	var old_group: FlashGroupProxy = null
	var old_mask: Node2D = null
	var p: Node2D = obj._proxy
	while p != null:
		if p is FlashGroupProxy:
			old_group = p
		elif p is FlashProxy:
			old_mask = p
		p = p.get(&"_proxy")
	var outer_parent: Node = obj._tree_node().get_parent()
	for n in [old_group, old_mask]:
		if n != null:
			for c in n.get_children():
				n.remove_child(c)
			if n.get_parent() != null:
				n.get_parent().remove_child(n)
	if obj.get_parent() != null:
		obj.get_parent().remove_child(obj)
	obj._proxy = null
	var inner: Node2D = obj
	if need_group:
		var g := old_group if old_group != null else FlashGroupProxy.new()
		g.configure(obj)
		g.add_child_content(inner)
		inner._proxy = g
		inner = g
		# Inside its viewport the object's transform is cancelled per tick; it must not be interpolated.
		obj.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		g.transform = obj.transform
		g.reset_physics_interpolation()
	elif old_group != null:
		old_group.queue_free()
		obj.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_INHERIT
	if need_mask:
		var m: FlashProxy = old_mask
		if m == null:
			m = FlashProxy.new()
			m.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
		m.name = "mask_" + obj.flash_name
		m._wrapped = obj
		m._mask_obj = obj._mask
		m._container = obj._flash_parent as FlashSprite
		Flash.register_mask_proxy(m)
		m.add_child(inner)
		inner._proxy = m
		inner = m
	elif old_mask != null:
		old_mask.queue_free()
	# Backdrop copy for blend modes that read what is behind the object.
	var outer := obj._tree_node()
	if SCREEN_BLENDS.has(obj._blend_mode):
		if old_bbc == null:
			var bbc := BackBufferCopy.new()
			bbc.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
			old_bbc = bbc
		outer.set_meta("bbc", old_bbc)
	elif old_bbc != null:
		if old_bbc.get_parent() != null:
			old_bbc.get_parent().remove_child(old_bbc)
		old_bbc.queue_free()
	obj._render_state_changed()
	obj._apply_color_transform()
	if obj._flash_parent != null:
		obj._flash_parent._mark_tree_dirty()
		obj._flash_parent._sync_tree()
	elif outer_parent != null:
		outer_parent.add_child(outer)
