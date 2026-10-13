class_name AS3JSON
extends RefCounted
## Port of com.adobe.serialization.json (as3corelib JSON): encoder + decoder with the same leniency in
## non-strict mode (trailing commas, comments, NaN, hex numbers, nbsp whitespace) so existing user dialogue
## files parse exactly as they did in Flash. GDScript has no exceptions: on a parse error decode() returns null
## and `lastError` holds the message (empty on success).

static var lastError := ""

const T_NONE := 0
const T_LBRACE := 1
const T_RBRACE := 2
const T_LBRACKET := 3
const T_RBRACKET := 4
const T_COMMA := 5
const T_COLON := 6
const T_TRUE := 7
const T_FALSE := 8
const T_NULL := 9
const T_STRING := 10
const T_NUMBER := 11
const T_NAN := 12

static var _reControl := RegEx.create_from_string("[\\x00-\\x1F]")

var _strict: bool
var _s: String
var _loc: int = 0
var _ch: String = ""
var _err := ""
var _tokType: int = T_NONE
var _tokValue = null
var _hasTok := false


static func encode(v) -> String:
	return _convert(v)


static func decode(s: String, strict: bool = true):
	var d := AS3JSON.new()
	d._strict = strict
	d._s = s
	d._nextChar()
	d._nextToken()
	var v = d._parseValue()
	if d._err == "" and strict:
		d._nextToken()
		if d._hasTok:
			d._parseError("Unexpected characters left in input stream")
	lastError = d._err
	return null if d._err else v


## AS3 Number.toString(): integers without a decimal point, others with up to 15 significant digits.
static func numStr(n: float) -> String:
	if is_nan(n):
		return "NaN"
	if is_inf(n):
		return "Infinity" if n > 0 else "-Infinity"
	if n == floor(n) and absf(n) < 1e15:
		return str(int(n))
	var digits := 15 - int(floor(log(absf(n)) / log(10.0))) - 1
	return String.num(n, clampi(digits, 0, 20))


static func _convert(v) -> String:
	match typeof(v):
		TYPE_STRING, TYPE_STRING_NAME:
			return _escape(String(v))
		TYPE_INT:
			return str(v)
		TYPE_FLOAT:
			return numStr(v) if is_finite(v) else "null"
		TYPE_BOOL:
			return "true" if v else "false"
		TYPE_ARRAY:
			var parts: PackedStringArray = []
			for e in v:
				parts.append(_convert(e))
			return "[" + ",".join(parts) + "]"
		TYPE_DICTIONARY:
			var parts: PackedStringArray = []
			for k in v:
				if v[k] is Callable:
					continue
				parts.append(_escape(str(k)) + ":" + _convert(v[k]))
			return "{" + ",".join(parts) + "}"
	return "null"


static func _escape(s: String) -> String:
	var out := ""
	for i in s.length():
		var c := s[i]
		match c:
			"\"": out += "\\\""
			"\\": out += "\\\\"
			"\b": out += "\\b"
			"\f": out += "\\f"
			"\n": out += "\\n"
			"\r": out += "\\r"
			"\t": out += "\\t"
			_:
				var code := c.unicode_at(0)
				if code < 32:
					var h := "%x" % code
					out += "\\u" + ("00" if h.length() == 2 else "000") + h
				else:
					out += c
	return "\"" + out + "\""


func _parseError(msg: String) -> void:
	if _err == "":
		_err = "%s (at %d)" % [msg, _loc]


func _nextChar() -> String:
	_ch = _s[_loc] if _loc < _s.length() else ""
	_loc += 1
	return _ch


func _nextToken() -> void:
	_hasTok = false
	_tokType = T_NONE
	_tokValue = null
	if _err:
		return
	_skipIgnored()
	if _err:
		return
	_hasTok = true
	match _ch:
		"{":
			_tokType = T_LBRACE
			_tokValue = "{"
			_nextChar()
		"}":
			_tokType = T_RBRACE
			_tokValue = "}"
			_nextChar()
		"[":
			_tokType = T_LBRACKET
			_tokValue = "["
			_nextChar()
		"]":
			_tokType = T_RBRACKET
			_tokValue = "]"
			_nextChar()
		",":
			_tokType = T_COMMA
			_tokValue = ","
			_nextChar()
		":":
			_tokType = T_COLON
			_tokValue = ":"
			_nextChar()
		"t":
			var w := "t" + _nextChar() + _nextChar() + _nextChar()
			if w == "true":
				_tokType = T_TRUE
				_tokValue = true
				_nextChar()
			else:
				_parseError("Expecting 'true' but found " + w)
		"f":
			var w := "f" + _nextChar() + _nextChar() + _nextChar() + _nextChar()
			if w == "false":
				_tokType = T_FALSE
				_tokValue = false
				_nextChar()
			else:
				_parseError("Expecting 'false' but found " + w)
		"n":
			var w := "n" + _nextChar() + _nextChar() + _nextChar()
			if w == "null":
				_tokType = T_NULL
				_tokValue = null
				_nextChar()
			else:
				_parseError("Expecting 'null' but found " + w)
		"N":
			var w := "N" + _nextChar() + _nextChar()
			if w == "NaN":
				_tokType = T_NAN
				_tokValue = NAN
				_nextChar()
			else:
				_parseError("Expecting 'NaN' but found " + w)
		"\"":
			_readString()
		_:
			if _isDigit(_ch) or _ch == "-":
				_readNumber()
			elif _ch == "":
				_hasTok = false
			else:
				_parseError("Unexpected " + _ch + " encountered")


func _readString() -> void:
	var end := _loc
	while true:
		end = _s.find("\"", end)
		if end < 0:
			_parseError("Unterminated string literal")
			return
		var bs := 0
		var j := end - 1
		while j >= 0 and _s[j] == "\\":
			bs += 1
			j -= 1
		if bs % 2 == 0:
			break
		end += 1
	_tokType = T_STRING
	_tokValue = _unescape(_s.substr(_loc, end - _loc))
	_loc = end + 1
	_nextChar()


func _unescape(p: String) -> String:
	if _strict and _reControl.search(p):
		_parseError("String contains unescaped control character (0x00-0x1F)")
	var out := ""
	var pos := 0
	var n := p.length()
	while true:
		var bi := p.find("\\", pos)
		if bi < 0:
			out += p.substr(pos)
			break
		out += p.substr(pos, bi - pos)
		pos = bi + 2
		var c := p[bi + 1] if bi + 1 < n else ""
		match c:
			"\"": out += "\""
			"\\": out += "\\"
			"n": out += "\n"
			"r": out += "\r"
			"t": out += "\t"
			"u":
				if pos + 4 > n:
					_parseError("Unexpected end of input.  Expecting 4 hex digits after \\u.")
					return out
				var hex := p.substr(pos, 4)
				for h in hex:
					if not _isHexDigit(h):
						_parseError("Excepted a hex digit, but found: " + h)
						return out
				out += char(hex.hex_to_int())
				pos += 4
			"f": out += "\f"
			"/": out += "/"
			"b": out += "\b"
			_: out += "\\" + c
		if pos >= n:
			break
	return out


func _readNumber() -> void:
	var s := ""
	var hex := false
	if _ch == "-":
		s += "-"
		_nextChar()
	if not _isDigit(_ch):
		_parseError("Expecting a digit")
		return
	if _ch == "0":
		s += _ch
		_nextChar()
		if _isDigit(_ch):
			_parseError("A digit cannot immediately follow 0")
			return
		elif not _strict and _ch == "x":
			hex = true
			s += _ch
			_nextChar()
			if _isHexDigit(_ch):
				s += _ch
				_nextChar()
			else:
				_parseError("Number in hex format require at least one hex digit after \"0x\"")
				return
			while _isHexDigit(_ch):
				s += _ch
				_nextChar()
	else:
		while _isDigit(_ch):
			s += _ch
			_nextChar()
	if _ch == ".":
		s += "."
		_nextChar()
		if not _isDigit(_ch):
			_parseError("Expecting a digit")
			return
		while _isDigit(_ch):
			s += _ch
			_nextChar()
	if _ch == "e" or _ch == "E":
		s += "e"
		_nextChar()
		if _ch == "+" or _ch == "-":
			s += _ch
			_nextChar()
		if not _isDigit(_ch):
			_parseError("Scientific notation number needs exponent value")
			return
		while _isDigit(_ch):
			s += _ch
			_nextChar()
	var v: float
	if hex:
		# Number("0x1f") parses the hex; a fraction or exponent after it makes it NaN in AS3.
		var neg := s.begins_with("-")
		var body := s.substr(3 if neg else 2)
		if "." in body or "e" in body:
			v = NAN
		else:
			v = float(body.hex_to_int()) * (-1.0 if neg else 1.0)
	else:
		v = s.to_float()
	if is_finite(v):
		_tokType = T_NUMBER
		_tokValue = v
	else:
		_parseError("Number " + str(v) + " is not valid!")


func _skipIgnored() -> void:
	while true:
		var start := _loc
		_skipWhite()
		_skipComments()
		if _err or start == _loc:
			break


func _skipComments() -> void:
	if _ch != "/":
		return
	_nextChar()
	match _ch:
		"/":
			while true:
				_nextChar()
				if _ch == "\n" or _ch == "":
					break
			_nextChar()
		"*":
			_nextChar()
			while true:
				if _ch == "*":
					_nextChar()
					if _ch == "/":
						break
				else:
					_nextChar()
				if _ch == "":
					_parseError("Multi-line comment not closed")
					return
			_nextChar()
		_:
			_parseError("Unexpected " + _ch + " encountered (expecting '/' or '*' )")


func _skipWhite() -> void:
	while _isWhite(_ch):
		_nextChar()


func _isWhite(c: String) -> bool:
	if c == " " or c == "\t" or c == "\n" or c == "\r":
		return true
	return not _strict and c != "" and c.unicode_at(0) == 160


func _isDigit(c: String) -> bool:
	return c != "" and c >= "0" and c <= "9"


func _isHexDigit(c: String) -> bool:
	return _isDigit(c) or (c != "" and ((c >= "A" and c <= "F") or (c >= "a" and c <= "f")))


func _parseArray() -> Array:
	var a: Array = []
	_nextToken()
	if _tokType == T_RBRACKET:
		return a
	if not _strict and _tokType == T_COMMA:
		_nextToken()
		if _tokType == T_RBRACKET:
			return a
		_parseError("Leading commas are not supported.  Expecting ']' but found " + str(_tokValue))
		return a
	while _err == "":
		a.append(_parseValue())
		_nextToken()
		if _tokType == T_RBRACKET:
			break
		if _tokType == T_COMMA:
			_nextToken()
			if not _strict and _tokType == T_RBRACKET:
				return a
		else:
			_parseError("Expecting ] or , but found " + str(_tokValue))
	return a


func _parseObject() -> Dictionary:
	var o := {}
	_nextToken()
	if _tokType == T_RBRACE:
		return o
	if not _strict and _tokType == T_COMMA:
		_nextToken()
		if _tokType == T_RBRACE:
			return o
		_parseError("Leading commas are not supported.  Expecting '}' but found " + str(_tokValue))
		return o
	while _err == "":
		if _tokType != T_STRING:
			_parseError("Expecting string but found " + str(_tokValue))
			break
		var key := str(_tokValue)
		_nextToken()
		if _tokType != T_COLON:
			_parseError("Expecting : but found " + str(_tokValue))
			break
		_nextToken()
		o[key] = _parseValue()
		_nextToken()
		if _tokType == T_RBRACE:
			break
		if _tokType == T_COMMA:
			_nextToken()
			if not _strict and _tokType == T_RBRACE:
				return o
		else:
			_parseError("Expecting } or , but found " + str(_tokValue))
	return o


func _parseValue():
	if _err:
		return null
	if not _hasTok:
		_parseError("Unexpected end of input")
		return null
	match _tokType:
		T_LBRACE:
			return _parseObject()
		T_LBRACKET:
			return _parseArray()
		T_STRING, T_NUMBER, T_TRUE, T_FALSE, T_NULL:
			return _tokValue
		T_NAN:
			if not _strict:
				return _tokValue
	_parseError("Unexpected " + str(_tokValue))
	return null
