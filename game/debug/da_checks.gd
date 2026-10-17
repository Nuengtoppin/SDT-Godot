extends RefCounted
## Checks of the built-in DialogueActions (src/ext/dialogueactions): arithmetic, trigger matching, variables,
## inserts, set / check, globals, objects, saved variables, line types and instant lines.
## Run by tools/regress.sh (main.gd --driver); prints "DA CHECKS: n passed, m failed" and quits.

const MathScript := preload("res://src/ext/dialogueactions/da_math.gd")

var _pass := 0
var _fail := 0
var _phase := 0
var _t0 := 0
var da = null


func _check(name: String, ok: bool, detail := "") -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
	print("CHECK %s %s%s" % ["ok  " if ok else "FAIL", name, "" if ok or detail == "" else " (%s)" % detail])


func step(_frame: int) -> void:
	if not Extensions.started:
		return
	match _phase:
		0:
			da = Extensions.get_extension("dialogueactions")
			_check("DialogueActions on by default", da != null and da.enabled)
			if da == null or not da.enabled:
				_finish()
				return
			Flash.stage.getChildAt(0).playClicked()
			_math_checks()
			_trigger_checks()
			_variable_checks()
			_line_checks()
			_start_line_setup()
			_t0 = Flash.tick_count
			_phase = 1
		1:
			if Flash.tick_count > _t0 + 90:
				_check("start line plays after loading", g.dialogueControl.sayingPhrase == "Starting now",
					g.dialogueControl.sayingPhrase)
				_finish()


func _finish() -> void:
	print("DA CHECKS: %d passed, %d failed" % [_pass, _fail])
	Flash.get_tree().quit(1 if _fail > 0 else 0)
	_phase = 99


func _math_checks() -> void:
	var cases := {"10 + 20": 30.0, "10 - 20": -10.0, "10 / 20": 0.5, "4 + 2 / 2": 3.0, "4 + ( 2 / 2 )": 5.0,
		"10 != 20": 1.0, "10 == 10": 1.0, "10 >= 20": 0.0, "10 <= 20": 1.0, "10 > 20": 0.0, "10 < 20": 1.0,
		"10 = 20": 20.0, "1 && 0": 0.0, "1 || 0": 1.0, "10 % 4": 2.0, "10 \\ 3": 3.0, "-5 + 2": -3.0,
		"( 1 + 2 ) * ( 3 + 4 )": 21.0, "2 * 3 + 1": 7.0}
	var bad: Array = []
	for e in cases:
		var r := MathScript.evaluate(e)
		if not is_equal_approx(r, cases[e]):
			bad.append("%s = %s" % [e, r])
	_check("arithmetic (left to right, parentheses)", bad.is_empty(), str(bad))
	_check("text result is NaN", is_nan(MathScript.evaluate("abc + 1")))
	_check("operator detection", MathScript.operator_index("a + b") == 2 and MathScript.operator_index("plain") == -1
		and MathScript.operator_index("+") == -2)


func _trigger_checks() -> void:
	var got: Array = []
	da.register_trigger("TEST_JOINED", 0, func(_a): got.append("joined"))
	da.register_trigger("TESTARGS", 2, func(a): got.append(a))
	da.register_trigger("TESTANY", -1, func(a): got.append(["any", a.size()]))
	_check("name with '_' found by joining", da.run_code("[TEST_JOINED]") and got.back() == "joined")
	_check("arguments split at '_'", da.run_code("[TESTARGS_a_b]") and got.back() == ["a", "b"], str(got.back()))
	_check("any-argument trigger", da.run_code("[TESTANY_1_2_3]") and got.back() == ["any", 3], str(got.back()))
	_check("wrong argument count not recognised", not da.run_code("[TESTARGS_a]"))
	_check("several triggers from code", da.run_code("[TEST_JOINED][TESTARGS_x_y]") and got.back() == ["x", "y"])
	# in a spoken line: the trigger runs, the line goes on without a pause; unknown words go to the game
	var dc = g.dialogueControl
	var st: Dictionary = dc.advancedController._dialogueDataStore
	dc.startSpeakingPhrase(DialogueLine.new("hello [SETVAR_inline_9] there [someline] end", {"style": "Thought"}))
	var spoken := ""
	for i in 300:
		if dc.speaking:
			spoken += dc.nextChar()
		elif dc.waitingToContinue:
			dc.continueSpeaking()
	_check("trigger in a line runs", st.get("inline") == 9.0, str(st.get("inline")))
	_check("unknown word left to the game (queued line)", dc.queuedPhrase == "someline", dc.queuedPhrase)
	_check("line spoken to the end, triggers not shown", spoken.ends_with("end") and not "[" in spoken, spoken)


func _variable_checks() -> void:
	var dc = g.dialogueControl
	var adc = dc.advancedController
	var st: Dictionary = adc._dialogueDataStore
	da.run_code("[SETVAR_x_5]")
	_check("SETVAR number", st.get("x") == 5.0)
	da.run_code("[SETVAR_x_+=2]")
	_check("SETVAR +=", st.get("x") == 7.0, str(st.get("x")))
	da.run_code("[SETVAR_x_-=10]")
	_check("SETVAR -=", st.get("x") == -3.0, str(st.get("x")))
	da.run_code("[SETVAR_name_Anna]")
	da.run_code("[APPENDVAR_name_bel]")
	_check("SETVAR text, APPENDVAR", st.get("name") == "Annabel", str(st.get("name")))
	da.run_code("[SETVARBYNAME_copy_x]")
	_check("SETVARBYNAME", st.get("copy") == -3.0, str(st.get("copy")))
	_check("insert local", adc.replaceValues("x is *x*") == "x is -3")
	_check("insert arithmetic", adc.replaceValues("*x + 10*") == "7", adc.replaceValues("*x + 10*"))
	_check("insert unknown is empty", adc.replaceValues("[*nothing*]") == "[]")
	var r := AS3.Number(adc.replaceValues("*da.random*"))
	_check("mod variable da.random", r >= 0.0 and r < 1.0)
	adc.setValues({"y": "+3"})
	adc.setValues({"y": "+3"})
	_check("set attribute adds signed numbers", st.get("y") == 6.0, str(st.get("y")))
	var seen: Array = []
	da.vars.register("test.modvar", func(): return 5, func(v): seen.append(v))
	adc.setValues({"test.modvar": 42})
	_check("mod variable write handler", seen == [42] and not st.has("test.modvar"))
	var line := DialogueLine.new("check line", {"check": {"test.modvar": 5}, "style": "Thought"})
	_check("check reads mod variables", adc.canPlay(line) and not st.has("test.modvar"))
	var line2 := DialogueLine.new("check line", {"check": {"test.modvar": 6}, "style": "Thought"})
	_check("check with wrong value fails", not adc.canPlay(line2))
	var listened: Array = []
	da.vars.add_listener("watched", func(o, n): listened.append([o, n]))
	da.run_code("[SETVAR_watched_1]")
	_check("write listener", listened == [[null, 1.0]], str(listened))
	# globals
	da.run_code("[SETGLOBAL_g1_hello]")
	da.run_code("[LOADGLOBALS_g1]")
	_check("SETGLOBAL + LOADGLOBALS", st.get("g1") == "hello")
	da.run_code("[SETVAR_g1_bye]")
	_check("linked global follows the local", da.vars.globals["g1"]["value"] == "bye")
	da.run_code("[UNREGISTERGLOBALS_g1]")
	da.run_code("[SETVAR_g1_later]")
	_check("unlinked global keeps its value", da.vars.globals["g1"]["value"] == "bye")
	da.run_code("[SETVAR_reg_3]")
	da.run_code("[REGISTERGLOBALS_reg]")
	_check("REGISTERGLOBALS", da.vars.globals["reg"]["value"] == 3.0 and da.vars.globals["reg"]["linked"])
	# objects
	da.run_code("[DEFINEOBJECT_Info._top_shoes]")
	_check("DEFINEOBJECT", st.get("Info.top") == 0 and st.get("Info.shoes") == 0)
	da.run_code("[SETVAR_src.top_red]")
	da.run_code("[SETVAR_src.shoes_blue]")
	da.run_code("[SETVAR_src.hat_green]")
	da.run_code("[COPYOBJECT_0_dst._src.]")
	_check("COPYOBJECT", st.get("dst.top") == "red" and st.get("dst.hat") == "green")
	da.run_code("[COPYOBJECT_0_part._src._USING_Info.]")
	_check("COPYOBJECT USING", st.get("part.top") == "red" and st.get("part.shoes") == "blue" and not st.has("part.hat"))
	da.run_code("[SPLITSTRING_abc_s]")
	_check("SPLITSTRING", st.get("s.length") == 3 and st.get("s.charAt.1") == "b")
	# saved variables
	da.run_code("[SAVESETVARS_testsave_x_src.]")
	da.run_code("[SETVAR_x_100]")
	da.run_code("[SAVEGETVARS_testsave_x]")
	_check("SAVESETVARS / SAVEGETVARS", st.get("x") == -3.0, str(st.get("x")))
	_check("save file next to the save files", FileAccess.file_exists(da.data_dir().path_join("saves/testsave.json")))
	da.run_code("[SAVEDELETE_testsave]")
	_check("SAVEDELETE", not FileAccess.file_exists(da.data_dir().path_join("saves/testsave.json")))
	_check("old VA_ form", da.run_code("[VA_SET_VARIABLE_va_4]") and st.get("va") == 4.0)


func _line_checks() -> void:
	var dc = g.dialogueControl
	var st: Dictionary = dc.advancedController._dialogueDataStore
	dc.loadCustomDialogue('dialogue_name:"da test"\n' +
		'intro:"[mytype]"{"style":"Thought"}\n' +
		'mytype:"instant played"{"style":"Thought"}\n' +
		'go_INSTANT:"[SETVAR_k_1] [SETVAR_k2_2] [after]"{"style":"Thought"}\n' +
		'after:"done line"{"style":"Thought"}\n' +
		'choking:"cough"{"style":"Thought"}\n', false)
	_check("line types get states", dc.states.has("choking") and not dc.states.has("orgasm"))
	dc.startSpeakingPhrase(dc.library.getPhrases("intro")[0])
	_check("single-trigger line plays that line type at once", dc.sayingPhrase == "instant played", dc.sayingPhrase)
	dc.stopSpeaking()
	dc.sayRandomPhrase("go_INSTANT")
	_check("_INSTANT line runs its triggers at once", st.get("k") == 1.0 and st.get("k2") == 2.0)
	_check("_INSTANT line goes on to the queued line", dc.sayingPhrase == "done line", dc.sayingPhrase)
	dc.stopSpeaking()


func _start_line_setup() -> void:
	var dc = g.dialogueControl
	dc.stopSpeaking()
	dc.loadCustomDialogue('dialogue_name:"start test"\nstart:"Starting now"{"style":"Thought"}\n', false)
