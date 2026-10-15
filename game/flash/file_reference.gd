class_name FlashFileReference
extends FlashEventDispatcher
## flash.net.FileReference: browse() + load() to read a user-picked file, save() to write one. Uses the native OS
## file dialog where available, otherwise a Godot FileDialog. Events: select, cancel, complete.

var name: String = ""
var data: PackedByteArray = PackedByteArray()
var _path: String = ""
var _save_bytes: PackedByteArray
var _dialog: FileDialog = null

## Folder the file dialog opens in (not part of the Flash API; the game sets one per purpose, see
## Flash.MOD_FOLDERS). Each reference then remembers the folder it was last used in.
var start_dir: String = ""
var _last_dir: String = ""


## filters: Array of {description, extension} like FileFilter ("*.txt;*.swf").
func browse(filters: Array = []) -> bool:
	_open(false, "", _filters_to_godot(filters))
	return true


func save(content, default_name: String = "") -> void:
	if content is PackedByteArray:
		_save_bytes = content
	elif content is String:
		_save_bytes = content.to_utf8_buffer()
	elif content is Image:
		_save_bytes = content.save_png_to_buffer()
	else:
		_save_bytes = str(content).to_utf8_buffer()
	_open(true, default_name, PackedStringArray())


func load() -> void:
	if _path == "":
		return
	var f := FileAccess.open(_path, FileAccess.READ)
	if f == null:
		dispatchEvent(FlashEvent.new("ioError"))
		return
	data = f.get_buffer(f.get_length())
	f.close()
	# Flash dispatched COMPLETE asynchronously.
	(func(): dispatchEvent(FlashEvent.new(FlashEvent.COMPLETE))).call_deferred()


func _filters_to_godot(filters: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for f in filters:
		var desc: String = f.get("description", "") if f is Dictionary else str(f)
		var ext: String = f.get("extension", "*.*") if f is Dictionary else "*.*"
		out.append(ext.replace(";", ",") + ";" + desc)
	return out


func _open(saving: bool, default_name: String, filters: PackedStringArray) -> void:
	var start := _last_dir if _last_dir != "" else (start_dir if start_dir != "" else Flash.mods_dir())
	var mode := DisplayServer.FILE_DIALOG_MODE_SAVE_FILE if saving else DisplayServer.FILE_DIALOG_MODE_OPEN_FILE
	if DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		DisplayServer.file_dialog_show("Save file" if saving else "Open file", start, default_name, false, mode,
			filters, func(ok: bool, paths: PackedStringArray, _filter: int): _picked(saving, ok, paths))
		return
	if _dialog == null:
		_dialog = FileDialog.new()
		_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_dialog.use_native_dialog = false
		Flash.add_child(_dialog)
	_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE if saving else FileDialog.FILE_MODE_OPEN_FILE
	_dialog.filters = filters
	_dialog.current_dir = start
	_dialog.current_file = default_name
	for c in _dialog.file_selected.get_connections():
		_dialog.file_selected.disconnect(c["callable"])
	for c in _dialog.canceled.get_connections():
		_dialog.canceled.disconnect(c["callable"])
	_dialog.file_selected.connect(func(p: String): _picked(saving, true, PackedStringArray([p])))
	_dialog.canceled.connect(func(): _picked(saving, false, PackedStringArray()))
	_dialog.popup_centered_ratio(0.7)


func _picked(saving: bool, ok: bool, paths: PackedStringArray) -> void:
	if not ok or paths.is_empty():
		dispatchEvent(FlashEvent.new(FlashEvent.CANCEL))
		return
	_path = paths[0]
	name = _path.get_file()
	_last_dir = _path.get_base_dir()
	if saving:
		dispatchEvent(FlashEvent.new(FlashEvent.SELECT))
		var f := FileAccess.open(_path, FileAccess.WRITE)
		if f == null:
			dispatchEvent(FlashEvent.new("ioError"))
			return
		f.store_buffer(_save_bytes)
		f.close()
		dispatchEvent(FlashEvent.new(FlashEvent.COMPLETE))
	else:
		dispatchEvent(FlashEvent.new(FlashEvent.SELECT))
