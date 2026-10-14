extends Node
## Flash runtime (autoload "Flash").
##
## Owns the stage (root of the Flash display list), the loaded symbol libraries, the mapping from AS3 classes
## to ported GDScript classes, and the fixed 30 Hz tick that drives ENTER_FRAME listeners and timelines.
## Game logic runs inside that tick (_physics_process); Godot's physics interpolation smooths rendering
## between ticks.

const BASE_LIBRARY := "res://assets/sdt"

const SHAPE_SHADERS := {
	"normal": preload("res://flash/shaders/shape_mix.gdshader"),
	"add": preload("res://flash/shaders/shape_add.gdshader"),
	"subtract": preload("res://flash/shaders/shape_sub.gdshader"),
	"multiply": preload("res://flash/shaders/shape_mul.gdshader"),
	"erase": preload("res://flash/shaders/shape_erase.gdshader"),
	"alpha": preload("res://flash/shaders/shape_alpha.gdshader"),
	"screen_read": preload("res://flash/shaders/shape_screen.gdshader"),
}
const SCREEN_BLEND_MODES := {"overlay": 0, "hardlight": 1, "screen": 2, "lighten": 3, "darken": 4,
	"difference": 5, "invert": 6}

## Debug flags from the command line (after --).
var debug_flags: PackedStringArray = OS.get_cmdline_user_args()

## Debug: render layer-blend / filtered objects directly instead of through offscreen groups.
var debug_no_groups := "--nogroups" in OS.get_cmdline_user_args()
## Debug: ignore masks.
var debug_no_masks := "--nomasks" in OS.get_cmdline_user_args()

## Root of the Flash display list (700x600 stage space).
var stage: FlashStage
var libraries: Array = []
var base_library: FlashLibrary
## Frames per second of the logic tick (Flash frame rate).
var frame_rate: float = 30.0
var tick_count: int = 0
## When true, timelines and ENTER_FRAME listeners are not ticked (debug tools / pause screens).
var paused := false

var _pending_symbol = null
var _gd_classes: Dictionary = {}       # short class name -> script path
var _lib_class_by_id: Dictionary = {}  # library -> {id -> short class name}
var _script_cache: Dictionary = {}
var _bindable_cache: Dictionary = {}   # Script -> {name: true}
var _runtime_props: Dictionary = {}

var _enter_frame: Array = []           # [object, Callable]
var _playing: Dictionary = {}          # FlashMovieClip -> true (insertion ordered)
var _mask_proxies: Dictionary = {}
var _groups: Dictionary = {}
var _material_pool: Dictionary = {}

var _mouse_over: FlashDisplayObject = null
var _mouse_down_target: FlashDisplayObject = null
var _focus: FlashDisplayObject = null

var _audio_pool: Array = []
var _active_channels: Dictionary = {}   # keeps playing FlashSoundChannels alive


func _ready() -> void:
	process_physics_priority = -100
	Engine.physics_ticks_per_second = int(frame_rate)
	_index_gd_classes()
	base_library = load_library(BASE_LIBRARY)
	stage = FlashStage.new()
	stage.name = "Stage"
	stage.flash_name = "root1"


func _exit_tree() -> void:
	if stage != null and stage.get_parent() == null:
		stage.free()


## Adds the stage to the scene tree under 'parent' (done by the main scene).
func attach_stage(parent: Node) -> void:
	if stage.get_parent() != null:
		stage.get_parent().remove_child(stage)
	parent.add_child(stage)


func load_library(dir: String) -> FlashLibrary:
	var lib := FlashLibrary.load_from(dir)
	if lib == null:
		return null
	libraries.append(lib)
	var by_id := {}
	for cls in lib.classes:
		by_id[int(lib.classes[cls])] = cls.get_slice(".", cls.get_slice_count(".") - 1)
	_lib_class_by_id[lib] = by_id
	return lib


# ---------------------------------------------------------------- classes & instantiation

func _index_gd_classes() -> void:
	for c in ProjectSettings.get_global_class_list():
		_gd_classes[String(c["class"])] = c["path"]
	# Properties declared by the runtime base classes must never be bound to timeline children.
	var probe := FlashMovieClip.new()
	for p in probe.get_property_list():
		_runtime_props[p["name"]] = true
	probe.free()


func take_pending_symbol():
	var p = _pending_symbol
	_pending_symbol = null
	return p


## AS3 class names that clash with Godot built-in classes are ported under these GDScript names.
const CLASS_ALIASES := {"Slider": "SDTSlider", "MenuButton": "SDTMenuButton"}


## GDScript class name used for an AS3 short class name.
static func gd_class_name(as3_short: String) -> String:
	return CLASS_ALIASES.get(as3_short, as3_short)


## Finds the library symbol for a class: [library, id], or [] if none. Exact (fully qualified or top-level) names
## win over short-name matches, since e.g. both "MenuCheckbox" and "obj.MenuCheckbox" exist.
func find_class_symbol(name_: String) -> Array:
	for lib in libraries:
		if lib.classes.has(name_):
			return [lib, int(lib.classes[name_])]
	var short := name_.get_slice(".", name_.get_slice_count(".") - 1)
	for alias in CLASS_ALIASES:
		if CLASS_ALIASES[alias] == short:
			short = alias
	for lib in libraries:
		var by_id: Dictionary = _lib_class_by_id[lib]
		for id in by_id:
			if by_id[id] == short:
				return [lib, id]
	return []


func _gd_script_for(short_name: String) -> Script:
	if _script_cache.has(short_name):
		return _script_cache[short_name]
	var s: Script = null
	var gd_name := gd_class_name(short_name)
	if _gd_classes.has(gd_name):
		s = load(_gd_classes[gd_name])
	_script_cache[short_name] = s
	return s


## Instantiates character 'id' of 'lib' (what a timeline PlaceObject does). When placed by a timeline, the
## parent and placement are applied before the class constructor body runs, as in Flash.
func create_char(lib: FlashLibrary, id: int, parent = null, place: Dictionary = {}, pidx: int = -1,
		depth: int = -1, birth: int = -1) -> FlashDisplayObject:
	var c: Dictionary = lib.get_char(id)
	match c.get("t", ""):
		"shape", "morph":
			var s := FlashShape.new()
			s.setup(lib, id)
			return s
		"sprite":
			var short = _lib_class_by_id[lib].get(id)
			_pending_symbol = [lib, id, parent, place, pidx, depth, birth]
			if short != null:
				var script := _gd_script_for(short)
				if script != null:
					var o = script.new()
					_pending_symbol = null
					return o
			var mc := FlashMovieClip.new()
			_pending_symbol = null
			return mc
		"edittext":
			var tf := FlashTextField.new()
			tf.setup_from_library(lib, c)
			tf._char_id = id
			return tf
		"button":
			return _create_button(lib, id, c)
		"bitmap":
			var b := FlashBitmap.new(FlashBitmapData.from_library(lib, id))
			b._char_id = id
			return b
		"empty":
			var e := FlashShape.new()
			e._char_id = id
			return e
	return null


func _create_button(lib: FlashLibrary, id: int, c: Dictionary) -> FlashDisplayObject:
	var sp := FlashSprite.new()
	sp._char_id = id
	sp.buttonMode = true
	for r in c["records"]:
		if not r["states"].has("up"):
			continue
		var child := create_char(lib, int(r["c"]))
		if child == null:
			continue
		child.set_flash_matrix(r["m"])
		child.colorTransform = FlashColorTransform.from_array(r["ct"])
		sp.addChild(child)
	return sp


## Creates an instance of a library class by AS3 name (short or fully qualified), e.g. Flash.create("MenuButton").
func create(as3_class: String) -> FlashDisplayObject:
	var found := find_class_symbol(as3_class)
	if found.is_empty():
		push_error("Flash.create: no library symbol for class %s" % as3_class)
		return null
	return create_char(found[0], found[1])


## True if 'n' is a script-declared property of obj (not a runtime/engine property), so a timeline child of
## that name can be bound to it.
func is_bindable_property(obj: Object, n: String) -> bool:
	var script: Script = obj.get_script()
	if script == null:
		return false
	var props: Dictionary = _bindable_cache.get(script, {})
	if not _bindable_cache.has(script):
		for p in script.get_script_property_list():
			if not _runtime_props.has(p["name"]):
				props[p["name"]] = true
		_bindable_cache[script] = props
	return props.has(n)


# ---------------------------------------------------------------- fonts

var _fonts: Dictionary = {}


func get_font(lib: FlashLibrary, id: int) -> Font:
	var key := "%s/%d" % [lib.path, id]
	if _fonts.has(key):
		return _fonts[key]
	var f: Font = null
	var c: Dictionary = lib.get_char(id)
	if c.has("file"):
		var p := lib.file_path(c["file"])
		if p.begins_with("res://") and ResourceLoader.exists(p):
			f = load(p)
		elif FileAccess.file_exists(p):
			var ff := FontFile.new()
			if ff.load_dynamic_font(p) == OK:
				f = ff
	if f == null:
		f = get_font_by_name(c.get("name", ""))
	_fonts[key] = f
	return f


## Device / named fonts (e.g. dialogue font choices). Falls back to the system font.
func get_font_by_name(font_name: String) -> Font:
	for lib in libraries:
		for id in lib.chars:
			var c: Dictionary = lib.chars[id]
			if c.get("t") == "font" and c.get("name") == font_name and c.has("file"):
				return get_font(lib, int(id))
	var sf := SystemFont.new()
	if font_name != "" and not font_name.begins_with("_"):
		sf.font_names = PackedStringArray([font_name])
	return sf


# ---------------------------------------------------------------- tick

func add_enter_frame(obj: Object, cb: Callable) -> void:
	for e in _enter_frame:
		if e[0] == obj and e[1] == cb:
			return
	_enter_frame.append([obj, cb])


func remove_enter_frame(obj: Object, cb: Callable) -> void:
	for i in range(_enter_frame.size() - 1, -1, -1):
		if _enter_frame[i][0] == obj and _enter_frame[i][1] == cb:
			_enter_frame.remove_at(i)


func has_enter_frame(obj: Object) -> bool:
	for e in _enter_frame:
		if e[0] == obj:
			return true
	return false


func register_playing(mc: FlashMovieClip) -> void:
	_playing[mc] = true


func unregister_playing(mc: FlashMovieClip) -> void:
	_playing.erase(mc)


func register_mask_proxy(p: Node) -> void:
	_mask_proxies[p] = true


func unregister_mask_proxy(p: Node) -> void:
	_mask_proxies.erase(p)


func register_group(g: FlashGroupProxy) -> void:
	_groups[g] = true
	g.update_layout.call_deferred()


func unregister_group(g: FlashGroupProxy) -> void:
	_groups.erase(g)


func _physics_process(_delta: float) -> void:
	if paused:
		return
	tick_count += 1
	# 1. Timelines advance.
	for mc in _playing.keys():
		if is_instance_valid(mc):
			mc._advance()
		else:
			_playing.erase(mc)
	# 2. ENTER_FRAME listeners (game logic).
	for e in _enter_frame.duplicate():
		if not is_instance_valid(e[0]):
			continue
		var cb: Callable = e[1]
		if cb.is_valid():
			if cb.get_argument_count() == 0:
				cb.call()
			else:
				cb.call(FlashEvent.new(FlashEvent.ENTER_FRAME))
	# 3. Masks follow the (possibly moved) objects.
	for p in _mask_proxies.keys():
		if is_instance_valid(p):
			p.refresh()
		else:
			_mask_proxies.erase(p)
	for g in _groups.keys():
		if is_instance_valid(g):
			g.update_layout()
		else:
			_groups.erase(g)
	_update_mouse_over()
	_free_orphans()


var _release_candidates: Array = []


## Frees `o` at the end of the tick if it is still off the display list by then.
func release_if_orphaned(o: FlashDisplayObject) -> void:
	_release_candidates.append(o)


func _free_orphans() -> void:
	if _release_candidates.is_empty():
		return
	var list := _release_candidates
	_release_candidates = []
	for o in list:
		if is_instance_valid(o) and o._flash_parent == null and not o.is_inside_tree():
			if o == _focus:
				_focus = null
			o.queue_free()


# ---------------------------------------------------------------- materials

## Shared material for a shape given its inherited colour offsets, blend mode and colour-matrix filters.
func shape_material(s: FlashShape) -> Material:
	var off := s.effective_color_offset()
	var blend := "normal"
	var cm: Projection = Projection.IDENTITY
	var cm_off := Vector4.ZERO
	var has_cm := false
	var o: FlashDisplayObject = s
	while o != null:
		if blend == "normal" and o._blend_mode != "normal" and o._blend_mode != "layer":
			blend = o._blend_mode
		for f in o._filters:
			if f is FlashFilter and f.type == "ColorMatrix" and f.matrix.size() >= 20:
				var m: Array = f.matrix
				var b := Projection(Vector4(m[0], m[5], m[10], m[15]), Vector4(m[1], m[6], m[11], m[16]),
					Vector4(m[2], m[7], m[12], m[17]), Vector4(m[3], m[8], m[13], m[18]))
				cm_off = b * cm_off + Vector4(m[4], m[9], m[14], m[19]) / 255.0
				cm = b * cm
				has_cm = true
		o = o._flash_parent
	if off == Color(0, 0, 0, 0) and blend == "normal" and not has_cm:
		return null
	var key := "%s|%s|%s|%s" % [blend, off, cm if has_cm else "", cm_off if has_cm else ""]
	var mat: ShaderMaterial = _material_pool.get(key)
	if mat != null:
		return mat
	mat = ShaderMaterial.new()
	if SCREEN_BLEND_MODES.has(blend) and not ("--noscreenblend" in OS.get_cmdline_user_args()):
		mat.shader = SHAPE_SHADERS["screen_read"]
		mat.set_shader_parameter("mode", SCREEN_BLEND_MODES[blend])
	else:
		mat.shader = SHAPE_SHADERS.get(blend, SHAPE_SHADERS["normal"])
	mat.set_shader_parameter("offset", Vector4(off.r, off.g, off.b, off.a) / 255.0)
	if has_cm:
		mat.set_shader_parameter("use_matrix", true)
		mat.set_shader_parameter("cm", cm)
		mat.set_shader_parameter("cm_offset", cm_off)
	_material_pool[key] = mat
	return mat


# ---------------------------------------------------------------- input

## Mouse position in stage coordinates.
func mouse_position() -> Vector2:
	if stage != null and stage.is_inside_tree():
		return stage.get_global_mouse_position()
	return Vector2.ZERO


## Window pixels per stage pixel (used to size screen-space effects such as blur).
func screen_scale() -> float:
	var vp := get_viewport()
	if vp == null:
		return 1.0
	var t := vp.get_final_transform()
	return t.get_scale().x


func _mouse_target_at(p: Vector2) -> FlashDisplayObject:
	var t := stage._mouse_target(p)
	return t if t != null else stage


## _input (not _unhandled_input) so clicks and keys on text fields (Godot Controls) still reach the Flash
## display list, as in Flash where the TextField is an ordinary event target.
func _input(event: InputEvent) -> void:
	if stage == null:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		var target := _mouse_target_at(mouse_position())
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_mouse_down_target = target
				_set_focus(target)
				_dispatch_mouse(target, FlashEvent.MOUSE_DOWN)
			else:
				_dispatch_mouse(target, FlashEvent.MOUSE_UP)
				if _mouse_down_target == target:
					_dispatch_mouse(target, FlashEvent.CLICK)
				_mouse_down_target = null
		elif mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			var e := FlashEvent.mouse(FlashEvent.MOUSE_WHEEL)
			e.delta = 3 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -3
			_fill_local(e, target)
			target.dispatchEvent(e)
	elif event is InputEventMouseMotion:
		var target := _mouse_target_at(mouse_position())
		_dispatch_mouse(target, FlashEvent.MOUSE_MOVE)
		_update_mouse_over()
	elif event is InputEventKey:
		var k := event as InputEventKey
		if k.echo and not k.pressed:
			return
		var e := FlashEvent.new(FlashEvent.KEY_DOWN if k.pressed else FlashEvent.KEY_UP, true)
		e.keyCode = FlashKeys.to_flash(k.physical_keycode if k.keycode == KEY_NONE else k.keycode)
		e.charCode = k.unicode
		e.shiftKey = k.shift_pressed
		e.ctrlKey = k.ctrl_pressed
		e.altKey = k.alt_pressed
		var t: FlashDisplayObject = _focus if _focus != null and is_instance_valid(_focus) and _focus.is_inside_tree() else stage
		t.dispatchEvent(e)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_EXIT and stage != null:
		stage.dispatchEvent(FlashEvent.new(FlashEvent.MOUSE_LEAVE))
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		FlashSharedObject.flush_all()


func _set_focus(o: FlashDisplayObject) -> void:
	if o == _focus:
		return
	var old := _focus
	_focus = o
	if old != null and is_instance_valid(old):
		old.dispatchEvent(FlashEvent.new(FlashEvent.FOCUS_OUT, true))
	if o != null:
		o.dispatchEvent(FlashEvent.new(FlashEvent.FOCUS_IN, true))


func set_focus(o: FlashDisplayObject) -> void:
	_set_focus(o)


func get_focus() -> FlashDisplayObject:
	return _focus


func _fill_local(e: FlashEvent, target: FlashDisplayObject) -> void:
	var lp := target.globalToLocal(Vector2(e.stageX, e.stageY))
	e.localX = lp.x
	e.localY = lp.y


func _dispatch_mouse(target: FlashDisplayObject, type: String) -> void:
	var e := FlashEvent.mouse(type)
	_fill_local(e, target)
	target.dispatchEvent(e)


func _update_mouse_over() -> void:
	if stage == null or not stage.is_inside_tree():
		return
	var target := _mouse_target_at(mouse_position())
	if target == _mouse_over:
		return
	var old := _mouse_over
	_mouse_over = target
	if old != null and is_instance_valid(old):
		var e := FlashEvent.mouse(FlashEvent.MOUSE_OUT)
		e.relatedObject = target
		_fill_local(e, old)
		old.dispatchEvent(e)
	if target != null:
		var e := FlashEvent.mouse(FlashEvent.MOUSE_OVER)
		e.relatedObject = old
		_fill_local(e, target)
		target.dispatchEvent(e)
	# ROLL_OUT / ROLL_OVER: non-bubbling, sent to every ancestor left / entered.
	var old_chain := _ancestors(old)
	var new_chain := _ancestors(target)
	for o in old_chain:
		if not new_chain.has(o):
			var e := FlashEvent.mouse(FlashEvent.ROLL_OUT, false)
			_fill_local(e, o)
			o.dispatchEvent(e)
	for i in range(new_chain.size() - 1, -1, -1):
		var o: FlashDisplayObject = new_chain[i]
		if not old_chain.has(o):
			var e := FlashEvent.mouse(FlashEvent.ROLL_OVER, false)
			_fill_local(e, o)
			o.dispatchEvent(e)
	var hand := false
	var o2 := target
	while o2 != null:
		if o2 is FlashSprite and o2.buttonMode and o2.useHandCursor:
			hand = true
			break
		o2 = o2._flash_parent
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if hand else Input.CURSOR_ARROW)


func _ancestors(o: FlashDisplayObject) -> Array:
	var out: Array = []
	while o != null and is_instance_valid(o):
		out.append(o)
		o = o._flash_parent
	return out


# ---------------------------------------------------------------- sound

## Plays a timeline (StartSound) sound.
func play_library_sound(lib: FlashLibrary, id: int) -> void:
	var s := FlashSound.from_library(lib, id)
	if s != null:
		s.play()


func _get_audio_player() -> AudioStreamPlayer:
	for p in _audio_pool:
		if not p.playing and not p.has_meta("busy"):
			return p
	var np := AudioStreamPlayer.new()
	# Each pooled player gets its own bus with a panner, for SoundTransform.pan.
	var bus := AudioServer.bus_count
	AudioServer.add_bus(bus)
	var bus_name := "FlashSfx%d" % _audio_pool.size()
	AudioServer.set_bus_name(bus, bus_name)
	AudioServer.set_bus_send(bus, "Master")
	AudioServer.add_bus_effect(bus, AudioEffectPanner.new())
	np.bus = bus_name
	add_child(np)
	_audio_pool.append(np)
	return np


## Stereo pan (-1..1) for a pooled player.
func set_player_pan(p: AudioStreamPlayer, pan: float) -> void:
	var bus := AudioServer.get_bus_index(p.bus)
	if bus > 0:
		var fx := AudioServer.get_bus_effect(bus, 0) as AudioEffectPanner
		if fx:
			fx.pan = clampf(pan, -1.0, 1.0)


## Global volume / mute (flash.media.SoundMixer.soundTransform).
func set_master_volume(v: float) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(v, 0.0001)))
	AudioServer.set_bus_mute(0, v <= 0.0)


# ---------------------------------------------------------------- external content

## Folder that relative content paths (mods, custom hair / backgrounds) resolve against, like a SWF's own
## location in Flash: the executable's folder when exported, the project's parent folder in the editor.
func content_root() -> String:
	if OS.has_feature("editor"):
		return ProjectSettings.globalize_path("res://").get_base_dir().get_base_dir()
	return OS.get_executable_path().get_base_dir()


func resolve_content_path(url: String) -> String:
	if url == "":
		return ""
	var p := url.replace("\\", "/")
	if p.begins_with("file:///"):
		p = p.substr(8)
	elif p.begins_with("file://"):
		p = p.substr(7)
	p = p.uri_decode()
	if p.is_absolute_path() or p.begins_with("res://") or p.begins_with("user://"):
		return p
	return content_root().path_join(p)


## Captures the last rendered frame of the stage area as an Image of size (stage_size * scale). Flash drew the
## display list into a BitmapData; here the displayed frame is read back, which shows the same content (the game
## only captures what is on screen) and keeps the window's resolution for high-quality screenshots.
func capture_screen(stage_size: Vector2, scale: float = 1.0) -> Image:
	var vp := get_viewport()
	if vp == null:
		return null
	var img := vp.get_texture().get_image()
	if img == null or img.is_empty():
		return null
	var t := vp.get_final_transform()
	var origin := t.origin
	var s := t.get_scale()
	var rect := Rect2i(Vector2i(origin.round()), Vector2i((stage_size * s).round()))
	rect = rect.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	if rect.size.x <= 0 or rect.size.y <= 0:
		return null
	var out := img.get_region(rect)
	var want := Vector2i(maxi(1, int(round(stage_size.x * scale))), maxi(1, int(round(stage_size.y * scale))))
	if out.get_size() != want:
		out.resize(want.x, want.y, Image.INTERPOLATE_LANCZOS if want.x < out.get_width() else Image.INTERPOLATE_CUBIC)
	out.convert(Image.FORMAT_RGBA8)
	return out
