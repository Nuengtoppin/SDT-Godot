class_name HerPenisRGBFill
extends FlashMovieClip
## Port of obj.her.HerPenisRGBFill: every instance follows the selected penis type.

static var _instances: Array = []


func _init() -> void:
	if not _instances.has(self):
		_instances.append(self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_instances.erase(self)


static func setPenisType(t: String) -> void:
	for i in _instances:
		if is_instance_valid(i):
			i.gotoAndStop(t)
