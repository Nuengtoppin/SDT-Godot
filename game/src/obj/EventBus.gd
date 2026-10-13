class_name EventBus
extends RefCounted
## Port of obj.EventBus: global named callbacks.

static var events: Dictionary = {}


static func addListener(event: String, fn: Callable) -> void:
	if not events.has(event):
		events[event] = []
	events[event].append(fn)


static func removeListener(event: String, fn: Callable) -> void:
	if events.has(event):
		events[event].erase(fn)


static func dispatch(event: String) -> void:
	if events.has(event):
		for fn in events[event].duplicate():
			if fn.is_valid():
				fn.call()
