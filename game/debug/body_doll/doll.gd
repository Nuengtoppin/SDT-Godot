extends Node2D
## The body doll: Dima's pieces on bones (scene made by tools/body_proto/doll.py, kept out of git).
## In the editor: select a Bone2D under Skeleton2D and rotate it.
## Running it (F6): drag a bone's handle (the ring on the bone) to turn it around its joint; R resets the pose.
## A neck (or anything) put under NeckSlot follows the ribcage and draws between the clavicle and the ribcage.

const PICK := 24.0        # px: how close to a handle a press must be
const DEAD := 12.0        # px: no turning this close to the joint (the angle jumps there)
const MAX_STEP := 40.0    # degrees per mouse move at most
const HANDLE_AT := 0.6    # the handle sits this far along the bone

var _bones: Array[Bone2D] = []
var _rest := {}
var _drag: Bone2D
var _last := Vector2.ZERO
var _overlay: Node2D


func _ready() -> void:
	for b in find_children("*", "Bone2D", true, false):
		_bones.append(b)
		_rest[b] = b.rotation
	_overlay = Node2D.new()
	_overlay.z_index = 100
	add_child(_overlay)
	_overlay.draw.connect(_draw_overlay)
	var hint := Label.new()
	hint.text = "Drag a ring to turn its bone. R - reset."
	hint.position = Vector2(12, 8)
	var layer := CanvasLayer.new()
	layer.add_child(hint)
	add_child(layer)
	_fit()
	get_viewport().size_changed.connect(_fit)


func _process(_delta: float) -> void:
	_overlay.queue_redraw()   # bones may turn from anywhere (the editor's remote tree, an animation, a script)


func _fit() -> void:
	# the body in template space spans about (-520, -520)..(300, 400); leave room for a turned leg
	var vs := get_viewport_rect().size
	var s := minf(vs.x / 1150.0, vs.y / 1200.0)
	scale = Vector2(s, s)
	position = vs * 0.5 - Vector2(-110, -40) * s


func _origin(b: Bone2D) -> Vector2:
	return b.global_position


func _tip(b: Bone2D, t := 1.0) -> Vector2:
	return b.global_transform * (Vector2.RIGHT.rotated(b.get_bone_angle()) * b.get_length() * t)


func _unhandled_input(e: InputEvent) -> void:
	var key := e as InputEventKey
	var button := e as InputEventMouseButton
	var motion := e as InputEventMouseMotion
	if key and key.pressed and key.keycode == KEY_R:
		for b in _bones:
			b.rotation = _rest[b]
		_overlay.queue_redraw()
	elif button and button.button_index == MOUSE_BUTTON_LEFT:
		_drag = null
		if button.pressed:
			var best := PICK
			for b in _bones:
				var d := button.position.distance_to(_tip(b, HANDLE_AT))
				if d < best:
					best = d
					_drag = b
			_last = button.position
		_overlay.queue_redraw()
	elif motion and _drag:
		var o := _origin(_drag)
		if motion.position.distance_to(o) > DEAD and _last.distance_to(o) > DEAD:
			var step := wrapf((motion.position - o).angle() - (_last - o).angle(), -PI, PI)
			_drag.rotation += clampf(step, -deg_to_rad(MAX_STEP), deg_to_rad(MAX_STEP))
		_last = motion.position
		_overlay.queue_redraw()


func _draw_overlay() -> void:
	var inv := _overlay.get_global_transform().affine_inverse()
	for b in _bones:
		var o := inv * _origin(b)
		var tip := inv * _tip(b)
		var h := inv * _tip(b, HANDLE_AT)
		var col := Color(1.0, 0.5, 0.0, 0.9) if b != _drag else Color(1.0, 0.2, 0.2, 1.0)
		_overlay.draw_line(o, tip, col, 2.0 / scale.x)
		_overlay.draw_circle(o, 5.0 / scale.x, col)
		_overlay.draw_arc(h, 9.0 / scale.x, 0.0, TAU, 24, col, 2.0 / scale.x)
