class_name FlashEventDispatcher
extends RefCounted
## flash.events.EventDispatcher for non-display objects.

var _listeners: Dictionary = {}


func add_event_listener(type: String, listener: Callable, _use_capture: bool = false, priority: int = 0) -> void:
	var list: Array = _listeners.get(type, [])
	for l in list:
		if l[0] == listener:
			return
	list.append([listener, priority])
	list.sort_custom(func(a, b): return a[1] > b[1])
	_listeners[type] = list


func remove_event_listener(type: String, listener: Callable, _use_capture: bool = false) -> void:
	var list: Array = _listeners.get(type, [])
	for i in range(list.size() - 1, -1, -1):
		if list[i][0] == listener:
			list.remove_at(i)


func has_event_listener(type: String) -> bool:
	return not _listeners.get(type, []).is_empty()


func dispatch_event(event: FlashEvent) -> bool:
	event.target = self
	event.current_target = self
	for l in _listeners.get(event.type, []).duplicate():
		var cb: Callable = l[0]
		if not cb.is_valid():
			continue
		if cb.get_argument_count() == 0:
			cb.call()
		else:
			cb.call(event)
		if event._stop_immediate:
			break
	return not event.default_prevented
