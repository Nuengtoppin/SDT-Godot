class_name AMF3
extends RefCounted
## Minimal AMF3 (Flash ByteArray.writeObject / readObject) codec, enough for the stored-characters backup file
## (CustomChars.sdt): null/undefined, booleans, int, double, String, Array (dense + associative), anonymous Object,
## ByteArray, Date (as ms), with string / object / trait reference tables. Typed (sealed) objects decode into
## Dictionaries. On a decode error, decode() returns null and `lastError` is set.

static var lastError := ""

var _b: PackedByteArray
var _p: int = 0
var _err := ""
var _strings: Array = []
var _objects: Array = []
var _traits: Array = []
var _out := PackedByteArray()
var _string_refs: Dictionary = {}


static func decode(bytes: PackedByteArray):
	var d := AMF3.new()
	d._b = bytes
	var v = d._read_value()
	lastError = d._err
	return null if d._err else v


## Flash local shared object file (.sol, AMF3 encoding): {name: value} of its data, or null (AMF0 files and
## errors: lastError is set). Header: 00 BF, u32 length, "TCSO", 6 bytes, u16 name length + name, u32 AMF version;
## then name (AMF3 string), value, one padding byte - with string / object references shared across entries.
static func decode_sol(bytes: PackedByteArray):
	if bytes.size() < 22 or bytes[0] != 0x00 or bytes[1] != 0xBF or bytes.slice(6, 10).get_string_from_ascii() != "TCSO":
		lastError = "Not a Flash shared object"
		return null
	var name_len := (bytes[16] << 8) | bytes[17]
	var p := 18 + name_len
	if p + 4 > bytes.size():
		lastError = "Truncated shared object"
		return null
	var version := (bytes[p] << 24) | (bytes[p + 1] << 16) | (bytes[p + 2] << 8) | bytes[p + 3]
	if version != 3:
		lastError = "Shared object uses AMF%d (only AMF3 is supported)" % version
		return null
	var d := AMF3.new()
	d._b = bytes
	d._p = p + 4
	var out := {}
	while d._p < bytes.size() and d._err == "":
		var key := d._read_string()
		var v = d._read_value()
		d._u8()
		if d._err == "":
			out[key] = v
	lastError = d._err
	return null if d._err else out


static func encode(v) -> PackedByteArray:
	var e := AMF3.new()
	e._write_value(v)
	return e._out


# ---------------------------------------------------------------- decoding

func _u8() -> int:
	if _p >= _b.size():
		_err = "Unexpected end of data"
		return 0
	_p += 1
	return _b[_p - 1]


func _u29() -> int:
	var v := 0
	for i in 4:
		var c := _u8()
		if i < 3:
			v = (v << 7) | (c & 0x7F)
			if c & 0x80 == 0:
				return v
		else:
			v = (v << 8) | c
	return v


func _read_utf8(n: int) -> String:
	if _p + n > _b.size():
		_err = "Unexpected end of data"
		return ""
	var s := _b.slice(_p, _p + n).get_string_from_utf8()
	_p += n
	return s


func _read_string() -> String:
	var h := _u29()
	if h & 1 == 0:
		var i := h >> 1
		return _strings[i] if i < _strings.size() else ""
	var n := h >> 1
	if n == 0:
		return ""
	var s := _read_utf8(n)
	_strings.append(s)
	return s


func _read_value():
	if _err:
		return null
	var marker := _u8()
	match marker:
		0x00, 0x01:
			return null
		0x02:
			return false
		0x03:
			return true
		0x04:
			var v := _u29()
			if v & 0x10000000:
				v -= 0x20000000
			return v
		0x05:
			if _p + 8 > _b.size():
				_err = "Unexpected end of data"
				return null
			var bytes := _b.slice(_p, _p + 8)
			bytes.reverse()
			_p += 8
			return bytes.decode_double(0)
		0x06:
			return _read_string()
		0x08:
			var h := _u29()
			if h & 1 == 0:
				return _objects[h >> 1]
			if _p + 8 > _b.size():
				_err = "Unexpected end of data"
				return null
			var bytes := _b.slice(_p, _p + 8)
			bytes.reverse()
			_p += 8
			var d := bytes.decode_double(0)
			_objects.append(d)
			return d
		0x09:
			return _read_array()
		0x0A:
			return _read_object()
		0x0C:
			var h := _u29()
			if h & 1 == 0:
				return _objects[h >> 1]
			var n := h >> 1
			var ba := _b.slice(_p, _p + n)
			_p += n
			_objects.append(ba)
			return ba
		0x07, 0x0B:
			var h := _u29()
			if h & 1 == 0:
				return _objects[h >> 1]
			var s := _read_utf8(h >> 1)
			_objects.append(s)
			return s
	_err = "Unsupported AMF3 marker 0x%02x" % marker
	return null


func _read_array():
	var h := _u29()
	if h & 1 == 0:
		return _objects[h >> 1]
	var n := h >> 1
	var assoc := {}
	var arr: Array = []
	var slot := _objects.size()
	_objects.append(arr)
	while _err == "":
		var key := _read_string()
		if key == "":
			break
		assoc[key] = _read_value()
	for i in n:
		arr.append(_read_value())
	if not assoc.is_empty():
		# Mixed arrays (rare here): keep the named entries in a Dictionary alongside the dense part.
		for i in arr.size():
			assoc[i] = arr[i]
		_objects[slot] = assoc
		return assoc
	return arr


func _read_object():
	var h := _u29()
	if h & 1 == 0:
		return _objects[h >> 1]
	var traits: Dictionary
	if h & 2 == 0:
		traits = _traits[h >> 2]
	else:
		traits = {"externalizable": (h & 4) != 0, "dynamic": (h & 8) != 0, "names": [], "class": ""}
		var count := h >> 4
		traits["class"] = _read_string()
		for i in count:
			traits["names"].append(_read_string())
		_traits.append(traits)
	var o := {}
	_objects.append(o)
	if traits["externalizable"]:
		_err = "Externalizable class not supported: " + traits["class"]
		return o
	for name in traits["names"]:
		o[name] = _read_value()
	if traits["dynamic"]:
		while _err == "":
			var key := _read_string()
			if key == "":
				break
			o[key] = _read_value()
	return o


# ---------------------------------------------------------------- encoding

func _w8(v: int) -> void:
	_out.append(v & 0xFF)


func _w29(v: int) -> void:
	v &= 0x1FFFFFFF
	if v < 0x80:
		_w8(v)
	elif v < 0x4000:
		_w8(((v >> 7) & 0x7F) | 0x80)
		_w8(v & 0x7F)
	elif v < 0x200000:
		_w8(((v >> 14) & 0x7F) | 0x80)
		_w8(((v >> 7) & 0x7F) | 0x80)
		_w8(v & 0x7F)
	else:
		_w8(((v >> 22) & 0x7F) | 0x80)
		_w8(((v >> 15) & 0x7F) | 0x80)
		_w8(((v >> 8) & 0x7F) | 0x80)
		_w8(v & 0xFF)


func _write_string(s: String) -> void:
	if s == "":
		_w29(1)
		return
	if _string_refs.has(s):
		_w29(_string_refs[s] << 1)
		return
	_string_refs[s] = _string_refs.size()
	var u := s.to_utf8_buffer()
	_w29((u.size() << 1) | 1)
	_out.append_array(u)


func _write_value(v) -> void:
	match typeof(v):
		TYPE_NIL:
			_w8(0x01)
		TYPE_BOOL:
			_w8(0x03 if v else 0x02)
		TYPE_INT:
			if v >= -0x10000000 and v <= 0x0FFFFFFF:
				_w8(0x04)
				_w29(v)
			else:
				_write_double(float(v))
		TYPE_FLOAT:
			if v == floor(v) and absf(v) <= 0x0FFFFFFF:
				_w8(0x04)
				_w29(int(v))
			else:
				_write_double(v)
		TYPE_STRING, TYPE_STRING_NAME:
			_w8(0x06)
			_write_string(String(v))
		TYPE_PACKED_BYTE_ARRAY:
			_w8(0x0C)
			_w29((v.size() << 1) | 1)
			_out.append_array(v)
		TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY:
			_w8(0x09)
			_w29((v.size() << 1) | 1)
			_w29(1)
			for e in v:
				_write_value(e)
		TYPE_DICTIONARY:
			_w8(0x0A)
			_w29(0x0B)        # inline traits, dynamic, 0 sealed members
			_write_string("")
			for k in v:
				_write_string(str(k))
				_write_value(v[k])
			_w29(1)
		_:
			_w8(0x01)


func _write_double(d: float) -> void:
	_w8(0x05)
	var b := PackedByteArray()
	b.resize(8)
	b.encode_double(0, d)
	b.reverse()
	_out.append_array(b)
