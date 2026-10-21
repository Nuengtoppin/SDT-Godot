class_name PortSettings
extends RefCounted
## Port addition (not in the original game): settings of the port itself (for now the new menu's), kept in
## port.cfg next to the save files (FlashSharedObject.save_dir, so --save-dir test runs use their own copy).

const FILE := "port.cfg"

static var _cfg: ConfigFile = null


static func get_value(section: String, key: String, default = null):
	_load()
	return _cfg.get_value(section, key) if _cfg.has_section_key(section, key) else default


static func set_value(section: String, key: String, value) -> void:
	_load()
	if _cfg.has_section_key(section, key) and _cfg.get_value(section, key) == value:
		return
	_cfg.set_value(section, key, value)
	var err := _cfg.save(FlashSharedObject.save_dir.path_join(FILE))
	if err != OK:
		push_error("port settings: cannot save %s (%s)" % [FILE, error_string(err)])


## Frame rate limit (Settings > Graphics > FPS limit): "Off" (as fast as it goes), "Monitor" (the screen's refresh rate) or a
## number. A limit keeps the GPU from drawing frames the screen cannot show.
const FPS_LIMITS := ["Off", "Monitor", "60", "120", "144", "240"]


static func fps_limit() -> String:
	var v := str(get_value("graphics", "fps_limit", "Off"))
	return v if v in FPS_LIMITS else "Off"


static func set_fps_limit(v: String) -> void:
	set_value("graphics", "fps_limit", v)
	apply_fps_limit()


static func apply_fps_limit() -> void:
	var v := fps_limit()
	var fps := 0
	if v == "Monitor":
		var hz := DisplayServer.screen_get_refresh_rate(DisplayServer.window_get_current_screen())
		fps = int(roundf(hz)) if hz > 0.0 else 60
	elif v != "Off":
		fps = int(v)
	Engine.max_fps = fps


## MSAA (Settings > Graphics): edge smoothing of strands, drawn shapes and the edges of rotated images, on the screen
## and in every render target (FlashProxy.msaa_level).
const MSAA_LEVELS := {"Off": Viewport.MSAA_DISABLED, "2x": Viewport.MSAA_2X, "4x": Viewport.MSAA_4X, "8x": Viewport.MSAA_8X}


static func msaa() -> String:
	var v := str(get_value("graphics", "msaa", "4x"))
	return v if MSAA_LEVELS.has(v) else "4x"


static func set_msaa(v: String) -> void:
	set_value("graphics", "msaa", v)
	apply_msaa()


static func apply_msaa() -> void:
	var m: Viewport.MSAA = MSAA_LEVELS[msaa()]
	FlashProxy.msaa_level = m
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		tree.root.msaa_2d = m
	# the render targets switch at once
	for p in Flash._mask_proxies.keys() + Flash._groups.keys():
		if is_instance_valid(p) and p.has_method("refresh_msaa"):
			p.refresh_msaa()


static func _load() -> void:
	if _cfg != null:
		return
	_cfg = ConfigFile.new()
	var path := FlashSharedObject.save_dir.path_join(FILE)
	if FileAccess.file_exists(path):
		_cfg.load(path)
