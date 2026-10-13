class_name AdvancedDialogueController
extends RefCounted
## Port of obj.dialogue.AdvancedDialogueController: the variable store behind dialogue "set" / "check" settings and
## *variable* substitution in lines.

static var _reCompare := RegEx.create_from_string("[>|<|=]")
static var _reVar := RegEx.create_from_string("\\*(.*?)\\*")

var _dialogueDataStore: Dictionary


func _init() -> void:
	reset()


func reset() -> void:
	_dialogueDataStore = {}


func readAdvancedLineSettings(line: DialogueLine) -> void:
	if line.settings.get("set"):
		setValues(line.settings["set"])


func setValues(values) -> void:
	if not (values is Dictionary):
		return
	for k in values:
		var v = values[k]
		if v is String and not AS3.isNaN(v):
			if not _dialogueDataStore.has(k):
				_dialogueDataStore[k] = 0.0
			if v.begins_with("-"):
				_dialogueDataStore[k] = AS3.Number(_dialogueDataStore[k]) + AS3.Number(v)
				outputLog(k + ": decrement by " + AS3.toString(AS3.Number(v)) + " = " + AS3.toString(_dialogueDataStore[k]))
			elif v.begins_with("+"):
				_dialogueDataStore[k] = AS3.Number(_dialogueDataStore[k]) + AS3.Number(v)
				outputLog(k + ": increment by " + AS3.toString(AS3.Number(v)) + " = " + AS3.toString(_dialogueDataStore[k]))
		else:
			outputLog("Storing " + k + " = " + AS3.toString(v))
			_dialogueDataStore[k] = v


func canPlay(line: DialogueLine) -> bool:
	if not line.settings.get("check"):
		return true
	outputLog("Running checks for line: \"" + line.phrase + "\"")
	var checks = line.settings["check"]
	if not (checks is Dictionary):
		return true
	for k in checks:
		var want = checks[k]
		var numeric := AS3.isNumber(want)
		var target := AS3.Number(_reCompare.sub(AS3.toString(want), "", true))
		if not numeric and want is String:
			numeric = not is_nan(target)
		var have = _dialogueDataStore[k] if _dialogueDataStore.has(k) else (0.0 if numeric else false)
		if AS3.isNumber(have) and want is String and numeric:
			var ok := true
			if want.begins_with(">"):
				ok = have >= target if want.substr(1, 1) == "=" else have > target
			elif want.begins_with("<"):
				ok = have <= target if want.substr(1, 1) == "=" else have < target
			else:
				ok = have == target
			if not ok:
				outputLog("   Line will not play: \"" + k + "\" needs to be " + AS3.toString(want)
					+ " but is currently set to " + _storedString(k))
				return false
		if typeof(have) == TYPE_BOOL and (want is String and (want == "true" or want == "false")):
			want = want == "true"
		if not (numeric and want is String) and not AS3.looseEquals(have, want):
			outputLog("   Line will not play: \"" + k + "\" needs to be " + AS3.toString(want)
				+ " but is currently set to " + _storedString(k))
			return false
	outputLog("   Okay.")
	return true


func _storedString(k: String) -> String:
	return AS3.toString(_dialogueDataStore[k]) if _dialogueDataStore.has(k) else "undefined"


func replaceValues(s: String) -> String:
	var out := ""
	var last := 0
	for m in _reVar.search_all(s):
		out += s.substr(last, m.get_start() - last)
		var k := m.get_string(1)
		if _dialogueDataStore.has(k):
			out += AS3.toString(_dialogueDataStore[k])
		last = m.get_end()
	return out + s.substr(last)


func outputLog(s: String) -> void:
	g.dialogueEditor.appendLog(s)
