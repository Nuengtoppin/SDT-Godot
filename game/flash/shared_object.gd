class_name FlashSharedObject
extends RefCounted
## flash.net.SharedObject (local only): a persistent `data` Dictionary saved to user://<name>.sav with Godot's
## binary Variant serialization. Like Flash, pending changes are also written when the game closes.

static var _open: Dictionary = {}

var name: String
var data: Dictionary = {}


static func getLocal(n: String) -> FlashSharedObject:
	if _open.has(n):
		return _open[n]
	var so := FlashSharedObject.new()
	so.name = n
	so._load()
	_open[n] = so
	return so


static func flush_all() -> void:
	for so in _open.values():
		so.flush()


func _path() -> String:
	return "user://%s.sav" % name


func _load() -> void:
	if not FileAccess.file_exists(_path()):
		return
	var f := FileAccess.open(_path(), FileAccess.READ)
	if f == null:
		return
	var v = f.get_var()
	if v is Dictionary:
		data = v


## Approximate serialized size in bytes (0 when empty, like Flash).
var size: int:
	get: return 0 if data.is_empty() else var_to_bytes(data).size()


func flush(_min_disk_space: int = 0) -> String:
	var f := FileAccess.open(_path(), FileAccess.WRITE)
	if f == null:
		push_error("SharedObject %s: cannot write %s" % [name, _path()])
		return "pending"
	f.store_var(data)
	return "flushed"


func clear() -> void:
	data = {}
	if FileAccess.file_exists(_path()):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_path()))
