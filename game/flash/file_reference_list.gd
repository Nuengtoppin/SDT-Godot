class_name FlashFileReferenceList
extends FlashEventDispatcher
## flash.net.FileReferenceList: pick several files; fileList holds one FlashFileReference per file (call load() on
## each to read it). Events: select, cancel.

var fileList: Array = []
## Folder the file dialog opens in (see FlashFileReference.start_dir); then the last folder used.
var start_dir: String = ""
var _last_dir: String = ""


func browse(filters: Array = []) -> bool:
	var godot_filters := PackedStringArray()
	for f in filters:
		var desc: String = f.get("description", "") if f is Dictionary else str(f)
		var ext: String = f.get("extension", "*.*") if f is Dictionary else "*.*"
		godot_filters.append(ext.replace(";", ",") + ";" + desc)
	var start := _last_dir if _last_dir != "" else (start_dir if start_dir != "" else Flash.mods_dir())
	if DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		DisplayServer.file_dialog_show("Open files", start, "", false, DisplayServer.FILE_DIALOG_MODE_OPEN_FILES,
			godot_filters, func(ok: bool, paths: PackedStringArray, _f: int): _picked(ok, paths))
	else:
		var d := FileDialog.new()
		d.access = FileDialog.ACCESS_FILESYSTEM
		d.use_native_dialog = false
		d.file_mode = FileDialog.FILE_MODE_OPEN_FILES
		d.filters = godot_filters
		d.current_dir = start
		Flash.add_child(d)
		d.files_selected.connect(func(p: PackedStringArray): _picked(true, p); d.queue_free())
		d.canceled.connect(func(): _picked(false, PackedStringArray()); d.queue_free())
		d.popup_centered_ratio(0.7)
	return true


func _picked(ok: bool, paths: PackedStringArray) -> void:
	if not ok or paths.is_empty():
		dispatchEvent(FlashEvent.new(FlashEvent.CANCEL))
		return
	fileList = []
	for p in paths:
		var fr := FlashFileReference.new()
		fr._path = p
		fr.name = p.get_file()
		fileList.append(fr)
	_last_dir = paths[0].get_base_dir()
	dispatchEvent(FlashEvent.new(FlashEvent.SELECT))
