extends RefCounted
## DialogueActions variable triggers: SETVAR, APPENDVAR, globals, object variables, saved variables, SPLITSTRING
## and the older VA_ forms. Arguments arrive as the parts between "_" (so variable names cannot contain "_",
## as in DialogueActions).


static func register(da) -> void:
	var v = da.vars
	da.register_trigger("SETVAR", 2, func(a): set_var(da, a[0], a[1]))
	da.register_trigger("SETVARBYNAME", 2, func(a): _set_typed(v, a[0], v.value_text(a[1])))
	da.register_trigger("SETVARBYNAEM", 2, func(a): _set_typed(v, a[0], v.value_text(a[1])))
	da.register_trigger("APPENDVAR", 2, func(a): v.set_value(a[0], v.value_text(a[0]) + str(a[1])))
	da.register_trigger("APPENDVARBYNAME", 2, func(a): v.set_value(a[0], v.value_text(a[0]) + v.value_text(a[1])))
	da.register_trigger("APPENDVARBYNAEM", 2, func(a): v.set_value(a[0], v.value_text(a[0]) + v.value_text(a[1])))
	da.register_trigger("SETGLOBAL", 2, func(a): v.set_global(a[0], _typed(a[1])))
	da.register_trigger("SETGLOBALBYNAME", 2, func(a): v.set_global(a[0], _typed(v.value_text(a[1]))))
	da.register_trigger("SETGLOBALBYNAEM", 2, func(a): v.set_global(a[0], _typed(v.value_text(a[1]))))
	da.register_trigger("REGISTERGLOBALS", -1, func(a): _each_local(v, a, func(n): v.copy_to_global(n); v.link(n, true)))
	da.register_trigger("UNREGISTERGLOBALS", -1, func(a): _each_global(v, a, func(n): v.link(n, false)))
	da.register_trigger("DELETEGLOBALS", -1, func(a): _each_global(v, a, func(n): v.globals.erase(n)))
	da.register_trigger("DELETELOCALS", -1, func(a): _each_local(v, a, func(n): v.store().erase(n)))
	da.register_trigger("SETGLOBALS", -1, func(a): _each_local(v, a, func(n): v.copy_to_global(n)))
	da.register_trigger("GETGLOBALS", -1, func(a): _each_global(v, a, func(n): v.copy_from_global(n)))
	da.register_trigger("LOADGLOBALS", -1, func(a): _each_global(v, a, func(n): v.copy_from_global(n); v.link(n, true)))
	da.register_trigger("COPYOBJECT", 3, func(a): copy_object(v, int(AS3.Number(a[0])), a[1], a[2], ""))
	da.register_trigger("COPYOBJECT", 5, func(a): copy_object(v, int(AS3.Number(a[0])), a[1], a[2], a[4]))
	da.register_trigger("DEFINEOBJECT", -1, func(a): define_object(v, a))
	da.register_trigger("SPLITSTRING", 2, func(a): split_string(v, str(a[0]), a[1]))
	da.register_trigger("SPLITSTRINGBYNAME", 2, func(a): split_string(v, v.value_text(a[0]), a[1]))
	da.register_trigger("SPLITSTRINGBYNAEM", 2, func(a): split_string(v, v.value_text(a[0]), a[1]))
	da.register_trigger("SAVESETVARS", -1, func(a): save_set(da, a))
	da.register_trigger("SAVEGETVARS", -1, func(a): save_get(da, a))
	da.register_trigger("SAVEREMOVEVARS", -1, func(a): save_remove(da, a))
	da.register_trigger("SAVEDELETE", 1, func(a): DirAccess.remove_absolute(_save_path(da, a[0])))
	# older forms (DialogueActions v2 / VariableArithmetic)
	da.register_trigger("VA_SET_VARIABLE", 2, func(a): set_var(da, a[0], a[1]))
	da.register_trigger("VA_SET_VARIABLEBYNAME", 2, func(a): _set_typed(v, a[0], v.value_text(a[1])))
	da.register_trigger("VA_SET_GLOBALVARIABLE", 2, func(a): v.set_global(a[0], _typed(a[1])))
	da.register_trigger("VA_SET_GLOBALVARIABLEBYNAME", 2, func(a): v.set_global(a[0], _typed(v.value_text(a[1]))))
	da.register_trigger("VA_LOAD_GLOBALVARIABLE", 1, func(a): v.copy_from_global(a[0]))
	da.register_trigger("VA_SAVE_SAVEGAME", 1, func(a): _save_all_globals(da, a[0]))
	da.register_trigger("VA_LOAD_SAVEGAME", 1, func(a): _load_all_globals(da, a[0]))
	da.register_trigger("VA_CLEAR_SAVEGAME", 1, func(a): DirAccess.remove_absolute(_save_path(da, a[0])))
	v.register_read("da.random", func(): return randf())


## [SETVAR_x_value]: a number is stored as a number, text as text; "+=n" / "-=n" add / subtract.
static func set_var(da, name: String, value: String) -> void:
	var v = da.vars
	if value.begins_with("+=") or value.begins_with("-="):
		var n := AS3.Number(value.substr(2))
		if is_nan(n):
			v.dlog("no number in [SETVAR_%s_%s]" % [name, value])
			return
		if value.begins_with("-="):
			n = -n
		v.set_value(name, AS3.toString(n) if n < 0 else "+" + AS3.toString(n))
	else:
		_set_typed(v, name, value)


static func _set_typed(v, name: String, value: String) -> void:
	v.set_value(name, _typed(value))


static func _typed(s):
	var n := AS3.Number(s)
	return s if is_nan(n) else n


static func _each_local(v, names: Array, fn: Callable) -> void:
	for a in names:
		for n in v.expand_local(str(a)):
			fn.call(n)


static func _each_global(v, names: Array, fn: Callable) -> void:
	for a in names:
		for n in v.expand_global(str(a)):
			fn.call(n)


## [COPYOBJECT_layers_target._source.(_USING_struct.)]: copies every variable under source. to target., up to
## `layers` dots deeper (0 = all); with a struct only the names the struct object has.
static func copy_object(v, layers: int, target: String, source: String, struct: String) -> void:
	var dots := source.count(".")
	var allowed := {}
	if struct != "":
		for n in v.local_names(struct):
			allowed[n.substr(struct.length())] = true
	for n in v.local_names(source):
		if layers != 0 and dots + layers < n.count("."):
			continue
		var rest: String = n.substr(source.length())
		if struct != "" and not allowed.has(rest):
			continue
		_set_typed(v, target + rest, v.value_text(n))


## [DEFINEOBJECT_obj._a_b_c]: creates obj.a, obj.b, obj.c with value 0.
static func define_object(v, args: Array) -> void:
	if args.is_empty():
		return
	var obj := str(args[0])
	if not obj.ends_with("."):
		obj += "."
	for i in range(1, args.size()):
		v.set_value(obj + str(args[i]), 0)


## [SPLITSTRING_text_obj]: obj.length and obj.charAt.0, obj.charAt.1, ...
static func split_string(v, text: String, target: String) -> void:
	if not target.ends_with("."):
		target += "."
	v.set_value(target + "length", text.length())
	for i in text.length():
		v.set_value(target + "charAt." + str(i), text[i])


# ---------------------------------------------------------------- saved variables (save namespace)

static func _save_path(da, name: String) -> String:
	var d: String = da.data_dir().path_join("saves")
	DirAccess.make_dir_recursive_absolute(d)
	return d.path_join(name.validate_filename() + ".json")


static func _read_save(da, name: String) -> Dictionary:
	var p := _save_path(da, name)
	if not FileAccess.file_exists(p):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(p))
	return d if d is Dictionary else {}


static func _write_save(da, name: String, data: Dictionary) -> void:
	var f := FileAccess.open(_save_path(da, name), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data, "\t"))


## [SAVESETVARS_name_var1_obj._...]
static func save_set(da, args: Array) -> void:
	if args.is_empty():
		return
	var v = da.vars
	var data := _read_save(da, args[0])
	for i in range(1, args.size()):
		for n in v.expand_local(str(args[i])):
			data[n] = _typed(v.value_text(n))
	_write_save(da, args[0], data)


## [SAVEGETVARS_name_var1_obj._...]
static func save_get(da, args: Array) -> void:
	if args.is_empty():
		return
	var v = da.vars
	var data := _read_save(da, args[0])
	for i in range(1, args.size()):
		var a := str(args[i])
		for n in data:
			if n == a or (a.ends_with(".") and n.begins_with(a) and n.length() > a.length()):
				v.set_value(n, data[n])


static func save_remove(da, args: Array) -> void:
	if args.is_empty():
		return
	var data := _read_save(da, args[0])
	for i in range(1, args.size()):
		var a := str(args[i])
		for n in data.keys():
			if n == a or (a.ends_with(".") and n.begins_with(a)):
				data.erase(n)
	_write_save(da, args[0], data)


static func _save_all_globals(da, name: String) -> void:
	var data := {}
	for n in da.vars.globals:
		data[n] = da.vars.globals[n]["value"]
	_write_save(da, name, data)


static func _load_all_globals(da, name: String) -> void:
	var data := _read_save(da, name)
	for n in data:
		da.vars.set_global(n, data[n])
