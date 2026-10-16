class_name FlashAbc
extends RefCounted
## ActionScript 3 bytecode (ABC, from DoABC tags) for SWF mods: a parser and a small interpreter for the code mods
## actually run - timeline frame scripts (the "frameN" methods Flash CS compiles them into), such as
## `this.modType = ModTypes.BOTTOMS` or `registerMod(Skirt); modName = "..."`. The SDT mod kit's own classes
## (SDTMods.ModPackage, ModTypes, ...) are implemented natively by the game, not interpreted.

var strings: PackedStringArray = [""]
var ints: Array = [0]
var uints: Array = [0]
var doubles: Array = [NAN]
var namespaces: Array = [[0, ""]]      # [kind, name]
var ns_sets: Array = [[]]
var multinames: Array = [{}]           # {kind, name, ns}
var methods: Array = []                # {params, name}
var bodies: Dictionary = {}            # method index -> {code: PackedByteArray, locals: int}
var instances: Array = []              # {name, super, traits, iinit}
var classes: Array = []                # {cinit, traits}
var class_by_name: Dictionary = {}     # "pkg.Name" -> index

var _d: PackedByteArray
var _p := 0


static func parse(bytes: PackedByteArray) -> FlashAbc:
	var a := FlashAbc.new()
	a._d = bytes
	a._p = 4  # minor, major version
	if not a._parse():
		return null
	a._d = PackedByteArray()
	return a


# ---------------------------------------------------------------- reading

func _u8() -> int:
	if _p >= _d.size():
		return 0
	_p += 1
	return _d[_p - 1]


func _u30() -> int:
	var v := 0
	var shift := 0
	for i in 5:
		var b := _u8()
		v |= (b & 0x7f) << shift
		shift += 7
		if not b & 0x80:
			break
	return v


func _s32() -> int:
	var v := _u30()
	if v & 0x80000000:
		v -= 0x100000000
	return v


func _parse() -> bool:
	var n := _u30()
	for i in range(1, n):
		ints.append(_s32())
	n = _u30()
	for i in range(1, n):
		uints.append(_u30())
	n = _u30()
	for i in range(1, n):
		doubles.append(_d.decode_double(_p) if _p + 8 <= _d.size() else 0.0)
		_p += 8
	n = _u30()
	for i in range(1, n):
		var ln := _u30()
		strings.append(_d.slice(_p, _p + ln).get_string_from_utf8())
		_p += ln
	n = _u30()
	for i in range(1, n):
		var kind := _u8()
		namespaces.append([kind, strings[_u30()]])
	n = _u30()
	for i in range(1, n):
		var set: Array = []
		for k in _u30():
			set.append(_u30())
		ns_sets.append(set)
	n = _u30()
	for i in range(1, n):
		multinames.append(_read_multiname())
	n = _u30()
	for i in n:
		var pc := _u30()
		_u30()  # return type
		for k in pc:
			_u30()
		var name_i := _u30()
		var flags := _u8()
		if flags & 0x08:
			for k in _u30():
				_u30()
				_u8()
		if flags & 0x80:
			for k in pc:
				_u30()
		methods.append({"params": pc, "name": strings[name_i] if name_i < strings.size() else ""})
	n = _u30()
	for i in n:  # metadata
		_u30()
		var items := _u30()
		for k in items * 2:
			_u30()
	var class_count := _u30()
	for i in class_count:
		var inst := {"name": _qname(_u30()), "super": _qname(_u30())}
		var flags := _u8()
		if flags & 0x08:
			_u30()
		for k in _u30():
			_u30()
		inst["iinit"] = _u30()
		inst["traits"] = _read_traits()
		instances.append(inst)
		class_by_name[inst["name"]] = i
	for i in class_count:
		classes.append({"cinit": _u30(), "traits": _read_traits()})
	n = _u30()
	for i in n:  # scripts
		_u30()
		_read_traits()
	n = _u30()
	for i in n:
		var m := _u30()
		_u30()  # max stack
		var locals := _u30()
		_u30()  # init scope depth
		_u30()  # max scope depth
		var ln := _u30()
		bodies[m] = {"code": _d.slice(_p, _p + ln), "locals": locals}
		_p += ln
		for k in _u30():
			for x in 5:
				_u30()
		_read_traits()
	return _p <= _d.size()


func _read_multiname() -> Dictionary:
	var kind := _u8()
	match kind:
		0x07, 0x0D:
			var ns := _u30()
			var name_i := _u30()
			return {"kind": "qname", "ns": namespaces[ns][1] if ns < namespaces.size() else "", "name": strings[name_i]}
		0x0F, 0x10:
			return {"kind": "rtqname", "name": strings[_u30()]}
		0x11, 0x12:
			return {"kind": "rtqnamel"}
		0x09, 0x0E:
			var name_i := _u30()
			_u30()
			return {"kind": "multiname", "name": strings[name_i]}
		0x1B, 0x1C:
			_u30()
			return {"kind": "multinamel"}
		0x1D:
			var q := _u30()
			for k in _u30():
				_u30()
			return {"kind": "typename", "name": multinames[q].get("name", "") if q < multinames.size() else ""}
	return {"kind": "unknown"}


func _qname(i: int) -> String:
	if i <= 0 or i >= multinames.size():
		return ""
	var m: Dictionary = multinames[i]
	var ns: String = m.get("ns", "")
	return (ns + "." if ns != "" else "") + String(m.get("name", ""))


func _read_traits() -> Array:
	var out: Array = []
	for i in _u30():
		var t := {"name": String(multinames[_u30()].get("name", ""))}
		var kind := _u8()
		var tt := kind & 0x0f
		t["kind"] = tt
		match tt:
			0, 6:
				_u30()
				_u30()
				var vi := _u30()
				if vi:
					t["value"] = _const_value(vi, _u8())
			1, 2, 3:
				_u30()
				t["method"] = _u30()
			4, 5:
				_u30()
				t["index"] = _u30()
		if kind & 0x40:
			for k in _u30():
				_u30()
		out.append(t)
	return out


func _const_value(i: int, kind: int):
	match kind:
		0x01:
			return strings[i] if i < strings.size() else ""
		0x03:
			return ints[i] if i < ints.size() else 0
		0x04:
			return uints[i] if i < uints.size() else 0
		0x06:
			return doubles[i] if i < doubles.size() else 0.0
		0x0A:
			return false
		0x0B:
			return true
	return null


# ---------------------------------------------------------------- class info

## Frame scripts of a class and its superclasses defined in this ABC: {frame index: method index}.
func frame_scripts(cls: String) -> Dictionary:
	var out := {}
	var chain: Array = []
	var c := cls
	while class_by_name.has(c) and not chain.has(c):
		chain.push_front(c)
		c = instances[class_by_name[c]]["super"]
	for name_ in chain:
		for t in instances[class_by_name[name_]]["traits"]:
			if t["kind"] == 1 and String(t["name"]).begins_with("frame") and String(t["name"]).substr(5).is_valid_int():
				out[int(String(t["name"]).substr(5)) - 1] = t["method"]
	return out


## Declared instance variables with default values (slots / consts).
func slot_defaults(cls: String) -> Dictionary:
	var out := {}
	var c := cls
	var seen := {}
	while class_by_name.has(c) and not seen.has(c):
		seen[c] = true
		for t in instances[class_by_name[c]]["traits"]:
			if (t["kind"] == 0 or t["kind"] == 6) and t.has("value") and not out.has(t["name"]):
				out[t["name"]] = t["value"]
		c = instances[class_by_name[c]]["super"]
	return out


## Static constants of a class (e.g. a mod's own compiled SDTMods.ModTypes).
func static_consts(cls: String) -> Dictionary:
	var out := {}
	if class_by_name.has(cls):
		for t in classes[class_by_name[cls]]["traits"]:
			if (t["kind"] == 0 or t["kind"] == 6) and t.has("value"):
				out[t["name"]] = t["value"]
	return out


## Full name of a class defined here by full or short name ("" if none).
func find_class(n: String) -> String:
	if class_by_name.has(n):
		return n
	for c in class_by_name:
		if String(c).get_slice(".", String(c).get_slice_count(".") - 1) == n:
			return c
	return ""


## Instance method / getter trait of cls or its superclasses: [kind, method index] or [].
func find_method(cls: String, n: String) -> Array:
	var c := cls
	var seen := {}
	while class_by_name.has(c) and not seen.has(c):
		seen[c] = true
		for t in instances[class_by_name[c]]["traits"]:
			if t["name"] == n and (t["kind"] == 1 or t["kind"] == 2):
				return [t["kind"], t["method"]]
		c = instances[class_by_name[c]]["super"]
	return []


## True if cls is (or extends) base within this ABC.
func extends_class(cls: String, base: String) -> bool:
	var c := cls
	var seen := {}
	while c != "" and not seen.has(c):
		if c == base:
			return true
		seen[c] = true
		if not class_by_name.has(c):
			return false
		c = instances[class_by_name[c]]["super"]
	return false


# ---------------------------------------------------------------- interpreter

const _GLOBAL := &"__global__"
static var _warned: Dictionary = {}


static func _warn(msg: String) -> void:
	if not _warned.has(msg):
		_warned[msg] = true
		push_warning(msg)
var host: Object = null   # resolves globals / classes: host.abc_global(name) -> value, host.abc_construct(name, args)


## Runs method 'mi' with 'this' and returns its result. Unsupported instructions abort the method with a warning.
func run(mi: int, this_obj, args: Array = []):
	if _freed(this_obj):
		return null
	var body: Dictionary = bodies.get(mi, {})
	if body.is_empty():
		return null
	var code: PackedByteArray = body["code"]
	var locals: Array = []
	locals.resize(maxi(int(body["locals"]), args.size() + 1))
	locals[0] = this_obj
	for i in args.size():
		locals[i + 1] = args[i]
	var stack: Array = []
	var scopes: Array = []
	var pc := 0
	var steps := 0
	while pc < code.size():
		steps += 1
		if steps > 200000:
			_warn("ABC: step limit in %s" % methods[mi]["name"])
			return null
		var op := code[pc]
		pc += 1
		match op:
			0x1D:  # popscope
				scopes.pop_back()
			0x02, 0x09, 0x82, 0x08, 0xF0, 0xF1:  # nop, label, coerce_a, kill(u30), debugline, debugfile
				if op == 0x08 or op == 0xF0 or op == 0xF1:
					pc = _skip_u30(code, pc)
			0xEF:  # debug
				pc += 1
				pc = _skip_u30(code, pc)
				pc += 1
				pc = _skip_u30(code, pc)
			0x30, 0x1C:  # pushscope, pushwith
				scopes.append(stack.pop_back())
			0x57:  # newactivation (slots kept by index)
				stack.append({})
			0x6C, 0x6D:  # getslot, setslot
				var r := _read_u30(code, pc)
				pc = r[1]
				if op == 0x6D:
					var v = stack.pop_back()
					var o = stack.pop_back()
					if o is Dictionary:
						o[r[0]] = v
				else:
					var o = stack.pop_back()
					stack.append(o.get(r[0]) if o is Dictionary else null)
			0x40:  # newfunction (no captured outer scope)
				var r := _read_u30(code, pc)
				pc = r[1]
				var fm: int = r[0]
				stack.append(func(e = null): return run(fm, this_obj, [] if e == null else [e]))
			0x42:  # construct
				var r := _read_u30(code, pc)
				pc = r[1]
				var call_args := stack.slice(stack.size() - r[0]) if r[0] > 0 else []
				stack.resize(stack.size() - r[0])
				var cls_obj = stack.pop_back()
				if host != null and cls_obj is Dictionary and cls_obj.has("__class__"):
					stack.append(host.abc_construct(String(cls_obj["__class__"]), call_args))
				else:
					stack.append(null)
			0x20, 0x21:
				stack.append(null)
			0x24:
				var b := code[pc]
				pc += 1
				stack.append(b - 256 if b > 127 else b)
			0x25:
				var r := _read_u30(code, pc)
				pc = r[1]
				stack.append(r[0] - 0x10000 if r[0] & 0x8000 else r[0])
			0x26:
				stack.append(true)
			0x27:
				stack.append(false)
			0x28:
				stack.append(NAN)
			0x29:
				stack.pop_back()
			0x2A:
				stack.append(stack.back())
			0x2B:
				var a = stack.pop_back()
				var b = stack.pop_back()
				stack.append(a)
				stack.append(b)
			0x2C, 0x2D, 0x2E, 0x2F:
				var r := _read_u30(code, pc)
				pc = r[1]
				match op:
					0x2C: stack.append(strings[r[0]])
					0x2D: stack.append(ints[r[0]])
					0x2E: stack.append(uints[r[0]])
					0x2F: stack.append(doubles[r[0]])
			0xD0, 0xD1, 0xD2, 0xD3:
				stack.append(locals[op - 0xD0])
			0xD4, 0xD5, 0xD6, 0xD7:
				locals[op - 0xD4] = stack.pop_back()
			0x62, 0x63:
				var r := _read_u30(code, pc)
				pc = r[1]
				if r[0] >= locals.size():
					locals.resize(r[0] + 1)
				if op == 0x62:
					stack.append(locals[r[0]])
				else:
					locals[r[0]] = stack.pop_back()
			0x92, 0x94, 0xC2, 0xC3:  # inclocal, declocal (+ _i)
				var r := _read_u30(code, pc)
				pc = r[1]
				locals[r[0]] = _num(locals[r[0]]) + (1 if op == 0x92 or op == 0xC2 else -1)
			0x64, 0x65:  # getglobalscope, getscopeobject
				var idx := 0
				if op == 0x65:
					idx = code[pc]
					pc += 1
				stack.append(scopes[idx] if op == 0x65 and idx < scopes.size() else this_obj)
			0x5D, 0x5E, 0x5F, 0x60:  # findpropstrict, findproperty, finddef, getlex
				var r := _read_u30(code, pc)
				pc = r[1]
				var mn: Dictionary = multinames[r[0]]
				var owner = _find(this_obj, String(mn.get("name", "")))
				if op == 0x60:
					stack.append(_prop_get(owner, String(mn.get("name", ""))))
				else:
					stack.append(owner)
			0x66, 0x61, 0x68, 0x6A:  # getproperty, setproperty, initproperty, deleteproperty
				var r := _read_u30(code, pc)
				pc = r[1]
				var mn: Dictionary = multinames[r[0]]
				var value = null
				if op == 0x61 or op == 0x68:
					value = stack.pop_back()
				var key = _name_of(mn, stack)
				var obj = stack.pop_back()
				if op == 0x66:
					stack.append(_prop_get(obj, key))
				elif op == 0x6A:
					stack.append(true)
				else:
					_prop_set(obj, key, value)
			0x46, 0x4F, 0x4C, 0x4A:  # callproperty, callpropvoid, callproplex, constructprop
				var r := _read_u30(code, pc)
				var r2 := _read_u30(code, r[1])
				pc = r2[1]
				var argc: int = r2[0]
				var call_args := stack.slice(stack.size() - argc) if argc > 0 else []
				stack.resize(stack.size() - argc)
				var mn: Dictionary = multinames[r[0]]
				var key = _name_of(mn, stack)
				var obj = stack.pop_back()
				var res = _construct(obj, String(key), call_args) if op == 0x4A else _call(obj, String(key), call_args)
				if op != 0x4F:
					stack.append(res)
			0x41:  # call
				var r := _read_u30(code, pc)
				pc = r[1]
				var call_args := stack.slice(stack.size() - r[0]) if r[0] > 0 else []
				stack.resize(stack.size() - r[0])
				stack.pop_back()  # receiver
				var fn = stack.pop_back()
				stack.append(fn.callv(call_args) if fn is Callable and fn.is_valid() else null)
			0x49:  # constructsuper
				var r := _read_u30(code, pc)
				pc = r[1]
				stack.resize(stack.size() - r[0] - 1)
			0x55:  # newobject
				var r := _read_u30(code, pc)
				pc = r[1]
				var o := {}
				for i in r[0]:
					var v = stack.pop_back()
					var k = stack.pop_back()
					o[str(k)] = v
				stack.append(o)
			0x56:  # newarray
				var r := _read_u30(code, pc)
				pc = r[1]
				var a := stack.slice(stack.size() - r[0]) if r[0] > 0 else []
				stack.resize(stack.size() - r[0])
				stack.append(a)
			0x47:
				return null
			0x48:
				return stack.pop_back()
			0x70, 0x85:  # convert_s, coerce_s
				var v = stack.pop_back()
				stack.append(_str(v) if not (op == 0x85 and v == null) else null)
			0x73, 0x83, 0x74, 0x88:  # convert_i / coerce_i / convert_u / coerce_u
				stack.append(int(_num(stack.pop_back())))
			0x75, 0x84:
				stack.append(float(_num(stack.pop_back())))
			0x76, 0x81:
				stack.append(_truthy(stack.pop_back()))
			0x77, 0x89:
				pass
			0x80, 0x86:  # coerce, astype
				pc = _skip_u30(code, pc)
			0x87:  # astypelate
				stack.pop_back()
			0x90, 0xC4:
				stack.append(-_num(stack.pop_back()))
			0x91, 0xC0:
				stack.append(_num(stack.pop_back()) + 1)
			0x93, 0xC1:
				stack.append(_num(stack.pop_back()) - 1)
			0x96:
				stack.append(not _truthy(stack.pop_back()))
			0x95:
				var v = stack.pop_back()
				stack.append("string" if v is String else "number" if (v is int or v is float) else "boolean" if v is bool \
					else "undefined" if v == null else "object")
			0xA0, 0xA1, 0xA2, 0xA3, 0xA4, 0xC5, 0xC6, 0xC7, 0xA8, 0xA9, 0xAA, 0xA5, 0xA6, 0xA7:
				var b = stack.pop_back()
				var a = stack.pop_back()
				stack.append(_arith(op, a, b))
			0xAB, 0xAC, 0xAD, 0xAE, 0xAF, 0xB0:
				var b = stack.pop_back()
				var a = stack.pop_back()
				stack.append(_compare(op, a, b))
			0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1A, 0x0C, 0x0D, 0x0E, 0x0F:
				var off := _s24(code, pc)
				pc += 3
				var jump := false
				match op:
					0x10:
						jump = true
					0x11:
						jump = _truthy(stack.pop_back())
					0x12:
						jump = not _truthy(stack.pop_back())
					_:
						var b = stack.pop_back()
						var a = stack.pop_back()
						match op:
							0x13: jump = _compare(0xAB, a, b)
							0x14: jump = not _compare(0xAB, a, b)
							0x15: jump = _compare(0xAD, a, b)
							0x16: jump = _compare(0xAE, a, b)
							0x17: jump = _compare(0xAF, a, b)
							0x18: jump = _compare(0xB0, a, b)
							0x19: jump = _compare(0xAC, a, b)
							0x1A: jump = not _compare(0xAC, a, b)
							0x0C: jump = not _compare(0xAD, a, b)
							0x0D: jump = not _compare(0xAE, a, b)
							0x0E: jump = not _compare(0xAF, a, b)
							0x0F: jump = not _compare(0xB0, a, b)
				if jump:
					pc += off
			_:
				_warn("ABC: unsupported instruction 0x%02x in %s; script stopped" % [op, methods[mi]["name"]])
				return null
	return null


static func _read_u30(code: PackedByteArray, pc: int) -> Array:
	var v := 0
	var shift := 0
	for i in 5:
		if pc >= code.size():
			break
		var b := code[pc]
		pc += 1
		v |= (b & 0x7f) << shift
		shift += 7
		if not b & 0x80:
			break
	return [v, pc]


static func _skip_u30(code: PackedByteArray, pc: int) -> int:
	return _read_u30(code, pc)[1]


static func _s24(code: PackedByteArray, pc: int) -> int:
	var v := code[pc] | (code[pc + 1] << 8) | (code[pc + 2] << 16)
	return v - 0x1000000 if v & 0x800000 else v


func _name_of(mn: Dictionary, stack: Array):
	match mn.get("kind"):
		"multinamel", "rtqnamel":
			return stack.pop_back()
	return String(mn.get("name", ""))


static func _truthy(v) -> bool:
	if v == null:
		return false
	if v is bool:
		return v
	if v is int:
		return v != 0
	if v is float:
		return v != 0.0 and not is_nan(v)
	if v is String:
		return v != ""
	return true


static func _num(v) -> float:
	if v is int or v is float:
		return v
	if v is bool:
		return 1.0 if v else 0.0
	if v is String:
		return float(v) if v.is_valid_float() else NAN
	return 0.0 if v == null else NAN


static func _str(v) -> String:
	if v == null:
		return "null"
	if v is float and v == floorf(v) and absf(v) < 1e15:
		return str(int(v))
	return str(v)


static func _arith(op: int, a, b):
	match op:
		0xA0, 0xC5:
			if a is String or b is String:
				return _str(a) + _str(b)
			if a is Array and b is Array:
				return a + b
			return _num(a) + _num(b)
		0xA1, 0xC6:
			return _num(a) - _num(b)
		0xA2, 0xC7:
			return _num(a) * _num(b)
		0xA3:
			return _num(a) / _num(b) if _num(b) != 0 else (INF if _num(a) > 0 else -INF if _num(a) < 0 else NAN)
		0xA4:
			return fmod(_num(a), _num(b))
		0xA8:
			return int(_num(a)) & int(_num(b))
		0xA9:
			return int(_num(a)) | int(_num(b))
		0xAA:
			return int(_num(a)) ^ int(_num(b))
		0xA5:
			return int(_num(a)) << (int(_num(b)) & 31)
		0xA6, 0xA7:
			return int(_num(a)) >> (int(_num(b)) & 31)
	return null


static func _compare(op: int, a, b) -> bool:
	match op:
		0xAB:
			if (a is int or a is float) and (b is int or b is float):
				return a == b
			if typeof(a) == typeof(b):
				return a == b
			if a == null or b == null:
				return a == null and b == null
			return _num(a) == _num(b)
		0xAC:
			return typeof(a) == typeof(b) and a == b if not ((a is int or a is float) and (b is int or b is float)) else a == b
	if a is String and b is String:
		match op:
			0xAD: return a < b
			0xAE: return a <= b
			0xAF: return a > b
			0xB0: return a >= b
	var x := _num(a)
	var y := _num(b)
	match op:
		0xAD: return x < y
		0xAE: return x <= y
		0xAF: return x > y
		0xB0: return x >= y
	return false


# ---- property access on host objects

func _abc_method(obj: Object, n: String) -> Array:
	if obj.has_meta(&"abc_class"):
		var a: FlashAbc = obj.get_meta(&"abc")
		return a.find_method(String(obj.get_meta(&"abc_class")), n)
	return []


func _has(obj: Object, n: String) -> bool:
	if obj.has_method(n) or not _abc_method(obj, n).is_empty():
		return true
	if obj is FlashMovieClip and (obj._named.has(n) or obj._dyn.has(n)):
		return true
	for p in obj.get_property_list():
		if p["name"] == n:
			return true
	return false


## True for an object the runtime has freed (Flash.dispose_later): mod code still holding one sees null.
static func _freed(v) -> bool:
	return typeof(v) == TYPE_OBJECT and not is_instance_valid(v)


func _find(this_obj, n: String):
	if _freed(this_obj):
		return null
	if this_obj is Object and _has(this_obj, n):
		return this_obj
	if host != null and host.abc_has_global(n):
		return _GLOBAL
	return this_obj


func _prop_get(obj, key):
	if _freed(obj):
		return null
	if obj is StringName and obj == _GLOBAL:
		return host.abc_global(String(key)) if host != null else null
	if obj is Dictionary:
		match obj.get("__host_object__"):
			"Math":
				if str(key) == "PI":
					return PI
			"transform":
				match str(key):
					"colorTransform": return obj["obj"].colorTransform
					"matrix": return obj["obj"].matrix
			"loaderInfo":
				if str(key) == "applicationDomain":
					return {"__host_object__": "appdomain"}
		return obj.get(str(key))
	if obj is Array:
		if str(key) == "length":
			return obj.size()
		var i := int(_num(key))
		return obj[i] if i >= 0 and i < obj.size() else null
	if obj is String:
		return obj.length() if str(key) == "length" else null
	if obj is Object:
		var k := str(key)
		if obj is FlashDisplayObject:
			if k == "transform":
				return {"__host_object__": "transform", "obj": obj}
			if k == "loaderInfo":
				return {"__host_object__": "loaderInfo"}
		if obj.has_method(k) and not (obj is FlashMovieClip and obj._named.has(k)):
			return Callable(obj, k)
		var v = obj.get(k)
		if v == null:
			var m := _abc_method(obj, k)
			if not m.is_empty():
				var a: FlashAbc = obj.get_meta(&"abc")
				var mi: int = m[1]
				if m[0] == 2:
					return a.run(mi, obj)
				return func(e = null): return a.run(mi, obj, [] if e == null else [e])
		return v
	return null


func _prop_set(obj, key, value) -> void:
	if _freed(obj):
		return
	if obj is Dictionary and obj.get("__host_object__") == "transform":
		match str(key):
			"colorTransform": obj["obj"].colorTransform = value
			"matrix": obj["obj"].matrix = value
	elif obj is Dictionary:
		obj[str(key)] = value
	elif obj is Array:
		var i := int(_num(key))
		if i >= obj.size():
			obj.resize(i + 1)
		obj[i] = value
	elif obj is Object:
		obj.set(str(key), value)


func _call(obj, n: String, args: Array):
	if _freed(obj):
		return null
	if obj is StringName and obj == _GLOBAL:
		return host.abc_call_global(n, args) if host != null else null
	if obj is Dictionary and obj.has("__host_object__"):
		return host.abc_call_object(obj, n, args) if host != null else null
	if obj is Array:
		match n:
			"push":
				obj.append_array(args)
				return obj.size()
			"join":
				return (args[0] if not args.is_empty() else ",").join(PackedStringArray(obj.map(func(v): return _str(v))))
		return null
	if obj is String:
		match n:
			"toLowerCase": return obj.to_lower()
			"toUpperCase": return obj.to_upper()
			"split": return Array(obj.split(str(args[0]))) if not args.is_empty() else [obj]
		return null
	if obj is Object:
		if obj.has_method(n):
			var argc: int = obj.get_method_argument_count(n) if obj.has_method(n) else args.size()
			return obj.callv(n, args.slice(0, argc) if args.size() > argc else args)
		var m := _abc_method(obj, n)
		if not m.is_empty() and m[0] == 1:
			var a: FlashAbc = obj.get_meta(&"abc")
			return a.run(m[1], obj, args)
		var f = obj.get(n)
		if f is Callable and f.is_valid():
			return f.callv(args)
	_warn("ABC: no method %s on %s" % [n, obj.get_class() if obj is Object else type_string(typeof(obj))])
	return null


func _construct(obj, n: String, args: Array):
	if host != null:
		return host.abc_construct(n, args)
	return null
