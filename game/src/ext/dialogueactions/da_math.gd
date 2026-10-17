extends RefCounted
## DialogueActions arithmetic for *a + b* inserts (port's own implementation of the documented behaviour).
##
## Operators: + - * / % \ (integer division) == != >= <= > < = && ||. No precedence: evaluated left to right,
## parentheses first ("4 + 2 / 2" is 3). "+" concatenates when a side is not a number. Comparisons give 1 or 0.
## The result is a Number (a non-numeric result is NaN), as in DialogueActions.

const OP_CHARS := "+-*%\\/!=><|&"
const DOUBLE_OPS := ["!=", "==", ">=", "<=", "||", "&&"]
const SINGLE_OPS := ["+", "-", "*", "%", "\\", "/", "=", ">", "<"]
## Names that are an operator on their own, and the operator characters a variable name may not contain.
const OPERATORS := ["+", "-", "*", "%", "/", "\\", "(", ")", "==", "!=", "<=", ">=", "||", "&&", ">", "<", "="]
const NAME_SPLITS := ["+", "-", "*", "%", "/", "\\", "(", ")", "==", "!=", "<=", ">=", "||", "&&", ">", "<", "="]


## -2: `s` is itself an operator; -1: no operator in it; else the position of the first operator.
static func operator_index(s: String) -> int:
	if s in OPERATORS:
		return -2
	var best := -1
	for op in NAME_SPLITS:
		var i := s.find(op)
		if i != -1 and (best == -1 or i < best):
			best = i
	return best


static func evaluate(expr: String) -> float:
	var eq := expr
	var operands: Array = []
	var ops: Array = []
	var part := ""
	var depth := 0
	var in_paren := false
	var paren_start := 0
	var paren_text := ""
	var i := 0
	while i < eq.length():
		var c := eq[i]
		if c == "(":
			depth += 1
			if not in_paren:
				paren_start = i
			in_paren = true
		elif c == ")":
			depth -= 1
		if in_paren:
			if depth == 0:
				# replace "( ... )" by its value and continue from where it started
				var inner := AS3.toString(evaluate(paren_text.substr(1)))
				eq = eq.substr(0, paren_start) + inner + eq.substr(paren_start + paren_text.length() + 1)
				paren_text = ""
				in_paren = false
				i = paren_start
				continue
			paren_text += c
		else:
			if c == " ":
				pass
			elif part.length() > 0:
				var pair := c + (eq[i + 1] if i + 1 < eq.length() else "")
				if not c in OP_CHARS:
					part += c
				elif c in ["+", "-", "*"]:
					operands.append(part)
					part = ""
					ops.append(c)
				elif pair in DOUBLE_OPS:
					operands.append(part)
					part = ""
					ops.append(pair)
					i += 1
				elif c in SINGLE_OPS:
					operands.append(part)
					part = ""
					ops.append(c)
			else:
				part += c
			if i == eq.length() - 1:
				operands.append(part)
		i += 1
	if operands.is_empty():
		return AS3.Number("")
	var acc = _value(operands[0])
	for k in ops.size():
		var op: String = ops[k]
		var rhs = operands[k + 1] if k + 1 < operands.size() else ""
		match op:
			"+":
				var r = _value(rhs)
				if acc is String or r is String:
					acc = AS3.toString(acc) + AS3.toString(r)
				else:
					acc = acc + r
			"-":
				acc = AS3.Number(acc) - AS3.Number(rhs)
			"*":
				acc = AS3.Number(acc) * AS3.Number(rhs)
			"%":
				acc = fmod(AS3.Number(acc), AS3.Number(rhs))
			"/":
				acc = _div(AS3.Number(acc), AS3.Number(rhs))
			"\\":
				acc = floor(_div(AS3.Number(acc), AS3.Number(rhs)))
			"!=":
				acc = 0.0 if AS3.looseEquals(acc, rhs) else 1.0
			"==":
				acc = 1.0 if AS3.looseEquals(acc, rhs) else 0.0
			">=":
				acc = 1.0 if AS3.Number(acc) >= AS3.Number(rhs) else 0.0
			"<=":
				acc = 1.0 if AS3.Number(acc) <= AS3.Number(rhs) else 0.0
			"<":
				acc = 1.0 if AS3.Number(acc) < AS3.Number(rhs) else 0.0
			">":
				acc = 1.0 if AS3.Number(acc) > AS3.Number(rhs) else 0.0
			"=":
				acc = rhs
			"||":
				acc = 1.0 if AS3.Number(acc) + AS3.Number(rhs) >= 1 else 0.0
			"&&":
				acc = 1.0 if AS3.Number(acc) + AS3.Number(rhs) == 2 else 0.0
	return AS3.Number(acc)


## An operand: its number if it is one, else the text.
static func _value(s):
	var n := AS3.Number(s)
	return s if is_nan(n) else n


static func _div(a: float, b: float) -> float:
	if b == 0.0:
		return NAN if a == 0.0 or is_nan(a) else (INF if a > 0 else -INF)
	return a / b
