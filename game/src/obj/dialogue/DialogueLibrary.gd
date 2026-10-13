class_name DialogueLibrary
extends RefCounted
## Port of obj.dialogue.DialogueLibrary: the built-in lines per mood, plus custom dialogue loaded from text files,
## the dialogue editor or mods, and the exporter that writes the text format back out.
##
## Note: AS3 Dictionary lookups treat a missing key as falsy but an empty Array as truthy; the checks below use
## has() to keep that meaning.

const DEFAULT_NAME := "Default"
const OTHER_FINISH := "Other"

static var allDialogueTypes: Array = []

# AS3/JS "." does not match \r, PCRE's does; dialogue files use CRLF, so the patterns use [^\r\n] instead.
const _ANY := "[^\\r\\n]"
static var _reInitial := RegEx.create_from_string("initial_settings:(" + _ANY + "*)")
static var _reAllClear := RegEx.create_from_string("all:\\s?\"CLEAR\"")
static var _reFinishClear := RegEx.create_from_string("finish:\\s?\"CLEAR\"")
static var _reFinishLine := RegEx.create_from_string("finish(" + _ANY + "+):\"(" + _ANY + "*)\"")
static var _reLibraryLine := RegEx.create_from_string("(" + _ANY + "*?):\"(" + _ANY + "*?)\"(" + _ANY + "*)")
static var _reWhite := RegEx.create_from_string("\\s")

var dialogueLibraryName := "Default"
var normalLibrary: Dictionary
var happyLibrary: Dictionary
var angryLibrary: Dictionary
var ahegaoLibrary: Dictionary
var finishes: Dictionary
var customLibrary: Dictionary = {}
var customFinishes: Dictionary = {}
var initialSettingsObject = null
var customAudio: Dictionary = {}
var customClears: Dictionary = {}
var allCleared := false
var finishesCleared := false
var dialogueTypes: Array
var dialogueTypesPattern: RegEx

var libraryName: String:
	get: return dialogueLibraryName


func _init() -> void:
	prepareLibraries()
	prepareTypeArray()
	for t in dialogueTypes:
		checkMissingDialogue(normalLibrary, t)
		checkMissingDialogue(happyLibrary, t)
		checkMissingDialogue(angryLibrary, t)
		checkMissingDialogue(ahegaoLibrary, t)
	customLibrary = {}
	customClears = {}
	customAudio = {}


func checkMissingDialogue(lib: Dictionary, t: String) -> void:
	if lib.get(t) == null:
		lib[t] = []


func setLibraryName(n: String) -> void:
	dialogueLibraryName = n
	g.inGameMenu.setDialogueLibraryName(dialogueLibraryName)


func getMoodLibrary() -> Dictionary:
	match g.her.mood:
		Her.ANGRY_MOOD:
			return angryLibrary
		Her.HAPPY_MOOD:
			return happyLibrary
		Her.AHEGAO_MOOD:
			return ahegaoLibrary
	return normalLibrary


func getCurrentDialogue() -> Dictionary:
	var out := {}
	for t in dialogueTypes:
		if customLibrary.has(t):
			out[t] = customLibrary[t]
		elif not allCleared:
			out[t] = getMoodLibrary().get(t)
	for t in customLibrary:
		if not getMoodLibrary().has(t):
			out[t] = customLibrary[t]
	return out


func getCurrentFinishes() -> Dictionary:
	return (customFinishes if finishesCleared else finishes).duplicate()


func getPhrases(t: String) -> Array:
	if customClears.get(t, false) or allCleared or not getMoodLibrary().has(t):
		return customLibrary.get(t, [])
	return getMoodLibrary()[t] + customLibrary.get(t, [])


func getFinishes(n: int) -> Array:
	if finishesCleared:
		if customFinishes.has(n):
			return customFinishes[n]
		return customFinishes.get(OTHER_FINISH, [])
	if customFinishes.has(n):
		return customFinishes[n]
	if finishes.has(n):
		return finishes[n]
	return finishes.get(OTHER_FINISH, []) + customFinishes.get(OTHER_FINISH, [])


func playAudio(p: String) -> AudioMod:
	var a: AudioMod = customAudio.get(p)
	if a:
		g.soundControl.playDialogue(a)
	return a


func playInterruptAudio(p: String) -> AudioMod:
	var a: AudioMod = customAudio.get(p)
	if a:
		g.soundControl.playDialogueInterrupt(a)
	return a


func resetCustomDialogue() -> void:
	customLibrary = {}
	customClears = {}
	customFinishes = {}
	customAudio = {}
	allCleared = false
	finishesCleared = false
	setLibraryName(DEFAULT_NAME)
	g.soundControl.resetAudioMods()


func setDialogueLibraryName(n: String) -> void:
	dialogueLibraryName = n


func setupDialogueMod(n: String, clearAll: bool) -> void:
	setLibraryName(n)
	if clearAll:
		resetCustomDialogue()
		allCleared = true


## A dialogue element from a mod: {lineType, dialogueLine, [audio: FlashSound, volume]}.
func loadDialogueMod(m) -> void:
	if m.has("lineType") and m.has("dialogueLine"):
		var t := str(m["lineType"])
		var line := str(m["dialogueLine"])
		if not customLibrary.has(t):
			customLibrary[t] = []
		customLibrary[t].append(DialogueLine.new(line))
		if m.has("audio") and m.has("volume"):
			var a := AudioMod.new(m["audio"], float(m["volume"]))
			customAudio[line] = a
			if t == "cough":
				g.soundControl.loadAudioMod("cough", a)


func loadFromDialogueEditor(lines: Array) -> void:
	var fin := {}
	allCleared = true
	for l in lines:
		if l.finish:
			var k = _finishKey(l.trigger.replace("finish", ""))
			if not fin.has(k):
				fin[k] = []
			fin[k].append(l.getDialogueLine())
		else:
			if not customLibrary.has(l.trigger):
				customLibrary[l.trigger] = []
			customLibrary[l.trigger].append(l.getDialogueLine())
	finishesCleared = true
	customFinishes = fin


## Finish counts are keyed by number (AS3 Dictionary keys 1 and "1" differ, but Number keys 1 and 1.0 match).
func _finishKey(s: String):
	var n := AS3.Number(s)
	if not is_nan(n) and n == floor(n):
		return int(n)
	return s


func loadCustomDialogue(text: String) -> void:
	if not text:
		return
	resetCustomDialogue()
	outputLog("Loading custom dialogue.\n------------------------------")
	var nameRe := RegEx.create_from_string(Dialogue.DIALOGUE_NAME_KEY + ":\\s?\"(" + _ANY + "+?)\"")
	var nameFound := nameRe.search(text)
	if nameFound:
		setLibraryName(nameFound.get_string(1))
	else:
		setLibraryName("No name")
	var initial := _reInitial.search(text)
	if initial:
		text = _reInitial.sub(text, "", false)
		outputLog("Reading initial settings.")
		var v = AS3JSON.decode(initial.get_string(1), false)
		if AS3JSON.lastError == "":
			initialSettingsObject = v
			outputLog("   Okay.")
			g.dialogueControl.advancedController.setValues(initialSettingsObject)
		else:
			initialSettingsObject = {}
			outputLog("ERROR - Could not decode initial settings:\n   " + initial.get_string(1) + "\n   "
				+ AS3JSON.lastError)
	if _reAllClear.search(text):
		allCleared = true
	if _reFinishClear.search(text):
		finishesCleared = true
	# Finish lines are consumed first (replaced by ""), then every remaining trigger:"line"{settings} line.
	var rest := ""
	var last := 0
	for m in _reFinishLine.search_all(text):
		rest += text.substr(last, m.get_start() - last)
		customFinishPopulator(m.get_string(1), m.get_string(2))
		last = m.get_end()
	text = rest + text.substr(last)
	for m in _reLibraryLine.search_all(text):
		customLibraryPopulator(m.get_string(1), m.get_string(2), m.get_string(3))
	outputLog("Done.\n------------------------------")


func customLibraryPopulator(trigger: String, phrase: String, settingsText: String) -> void:
	if trigger == "font":
		g.dialogueControl.setCustomFont(phrase)
		return
	if phrase == "CLEAR":
		customClears[trigger] = true
	elif trigger != "all" and trigger != Dialogue.DIALOGUE_NAME_KEY:
		if allDialogueTypes.has(trigger) and not customClears.get(trigger, false):
			customClears[trigger] = true
		if not customLibrary.has(trigger):
			customLibrary[trigger] = []
		outputLog("Adding custom line: \"" + phrase + "\"")
		var settings = AS3JSON.decode(settingsText, false)
		if AS3JSON.lastError != "":
			settings = null
			if _reWhite.sub(settingsText, "", true) != "":
				outputLog("ERROR - Could not decode custom settings:\n   " + settingsText + "\n   " + AS3JSON.lastError)
		if not (settings is Dictionary):
			settings = null
		customLibrary[trigger].append(DialogueLine.new(phrase, settings))


func customFinishPopulator(countText: String, phrase: String) -> void:
	var n := AS3.Number(countText)
	if not is_nan(n):
		var k = _finishKey(countText)
		if not customFinishes.has(k):
			customFinishes[k] = []
		finishesCleared = true
		customFinishes[k].append(DialogueLine.new(phrase))
	elif countText == OTHER_FINISH:
		if not customFinishes.has(OTHER_FINISH):
			customFinishes[OTHER_FINISH] = []
		finishesCleared = true
		customFinishes[OTHER_FINISH].append(DialogueLine.new(phrase))


func exportLibrary() -> String:
	var nl := "\r\n"
	var out := Dialogue.DIALOGUE_NAME_KEY + ":\"" + dialogueLibraryName + "\"" + nl + nl
	if initialSettingsObject != null:
		var s := AS3JSON.encode(initialSettingsObject)
		if s and s != "{}":
			out += "initial_settings:" + s + nl + nl
	if allCleared:
		out += "all:\"CLEAR\""
	var current := getCurrentDialogue()
	for stateName in current:
		var lines = current[stateName]
		if lines == null:
			continue
		for l in lines:
			out += nl + str(stateName) + ":" + l.export()
	if finishesCleared:
		out += nl + nl + "finish:\"CLEAR\""
		var fin := getCurrentFinishes()
		for stateName in fin:
			for l in fin[stateName]:
				out += nl + "finish" + str(stateName) + ":" + "\"" + l.phrase + "\""
	return out


func appendLibrary(s: String, lines: Array, t: String) -> String:
	for l in lines:
		s += t + ":\"" + l.phrase + "\"\n"
	return s


func customEscape(s: String) -> String:
	s = s.replace("\\", "%22")
	s = s.replace("*", "%2A")
	return s.replace(":", "%3A")


func outputLog(s: String) -> void:
	g.dialogueEditor.appendLog(s)


func prepareTypeArray() -> void:
	dialogueTypes = [Dialogue.INTRO, Dialogue.HEAD_GRABBED, Dialogue.PULLED_UP, Dialogue.PULLED_DOWN,
		Dialogue.RESISTANCE, Dialogue.GENERAL, Dialogue.INTERRUPT, Dialogue.COUGH, Dialogue.FIRST_THROAT,
		Dialogue.FIRST_DT, Dialogue.PULL_OFF, Dialogue.HELD, Dialogue.WAKE, Dialogue.LICK_PENIS, Dialogue.LICK_BALLS,
		Dialogue.VIGOROUS, Dialogue.HAND_JOB_STROKE, Dialogue.PRE_CUM, Dialogue.CUM_ON_FACE, Dialogue.CUM_IN_MOUTH,
		Dialogue.CUM_IN_THROAT, Dialogue.CUM_IN_EYE, Dialogue.CUM_IN_NOSE, Dialogue.SWALLOW, Dialogue.DROOL,
		Dialogue.RESTART]
	DialogueLibrary.allDialogueTypes = dialogueTypes
	dialogueTypesPattern = RegEx.create_from_string("(" + "|".join(dialogueTypes) + "):\\s?\"(.+?)\"")


# BEGIN generated by tools/port_dialogue_lib.py
func prepareLibraries() -> void:
	var _loc1_: Array = []
	var _loc2_: Array = []
	var _loc3_: Array = []
	var _loc4_: Array = []
	var _loc5_: Array = []
	var _loc6_: Array = []
	var _loc7_: Array = []
	var _loc8_: Array = []
	var _loc9_: Array = []
	var _loc10_: Array = []
	var _loc11_: Array = []
	var _loc12_: Array = []
	var _loc13_: Array = []
	var _loc14_: Array = []
	var _loc15_: Array = []
	var _loc16_: Array = []
	var _loc17_: Array = []
	var _loc18_: Array = []
	var _loc19_: Array = []
	var _loc20_: Array = []
	var _loc21_: Array = []
	var _loc22_: Array = []
	var _loc23_: Array = []
	var _loc24_: Array = []
	var _loc25_: Array = []
	var _loc26_: Array = []
	var _loc27_: Array = []
	var _loc28_: Array = []
	var _loc29_: Array = []
	var _loc30_: Array = []
	var _loc31_: Array = []
	var _loc32_: Array = []
	var _loc33_: Array = []
	var _loc34_: Array = []
	var _loc35_: Array = []
	var _loc36_: Array = []
	var _loc37_: Array = []
	var _loc38_: Array = []
	var _loc39_: Array = []
	var _loc40_: Array = []
	var _loc41_: Array = []
	var _loc42_: Array = []
	var _loc43_: Array = []
	var _loc44_: Array = []
	var _loc45_: Array = []
	var _loc46_: Array = []
	_loc1_ = []
	_loc2_ = []
	_loc3_ = []
	_loc3_.append(DialogueLine.new("I can\'t take it any deeper!"))
	_loc3_.append(DialogueLine.new("I can\'t go any deeper."))
	_loc3_.append(DialogueLine.new("I don\'t think I can take any more."))
	_loc3_.append(DialogueLine.new("Stop pushing me down* YOU*!"))
	_loc3_.append(DialogueLine.new("Stop pushing me so far down!"))
	_loc3_.append(DialogueLine.new("That\'s deep enough* YOU*!"))
	_loc4_ = []
	_loc4_ = []
	_loc4_.append(DialogueLine.new("I can take it deeper, keep going."))
	_loc4_.append(DialogueLine.new("That\'s it* YOU*, push it in!"))
	_loc4_.append(DialogueLine.new("Do you want to go deeper* YOU*?"))
	_loc4_.append(DialogueLine.new("I got a bit further that time* YOU*."))
	_loc4_.append(DialogueLine.new("Don\'t worry* YOU*, I can take it."))
	_loc5_ = []
	_loc5_ = []
	_loc5_.append(DialogueLine.new("What do you think you\'re doing?!"))
	_loc5_.append(DialogueLine.new("Quit trying to force it in!"))
	_loc5_.append(DialogueLine.new("Stop pushing me down* YOU*!"))
	_loc5_.append(DialogueLine.new("Stop pushing me so far down!"))
	_loc5_.append(DialogueLine.new("That\'s deep enough* YOU*!"))
	_loc6_ = []
	_loc6_ = []
	_loc6_.append(DialogueLine.new("I can\'t take any more than that!"))
	_loc6_.append(DialogueLine.new("I can\'t take it all!"))
	_loc6_.append(DialogueLine.new("That\'s as deep as I can take it!"))
	_loc6_.append(DialogueLine.new("Please* YOU*, stop!"))
	_loc6_.append(DialogueLine.new("That\'s too deep!"))
	_loc6_.append(DialogueLine.new("Too deep!"))
	_loc6_.append(DialogueLine.new("You\'re making me gag* YOU*!"))
	_loc6_.append(DialogueLine.new("You\'re making me choke* YOU*!"))
	_loc6_.append(DialogueLine.new("I\'ll choke!"))
	_loc6_.append(DialogueLine.new("You\'re choking me!"))
	_loc6_.append(DialogueLine.new("You can\'t push it any deeper!"))
	_loc6_.append(DialogueLine.new("That\'s my throat!"))
	_loc6_.append(DialogueLine.new("Stop!"))
	_loc7_ = []
	_loc7_ = []
	_loc7_.append(DialogueLine.new("Nearly... I think I can take it all now."))
	_loc7_.append(DialogueLine.new("Come on, push it all the way in."))
	_loc7_.append(DialogueLine.new("You\'re nearly in my throat."))
	_loc8_ = []
	_loc8_ = []
	_loc8_.append(DialogueLine.new("Are you trying to force it all down my throat?!"))
	_loc8_.append(DialogueLine.new("Hey! You\'re hitting my throat!"))
	_loc8_.append(DialogueLine.new("That\'s my throat, stop trying to push it deeper!"))
	_loc8_.append(DialogueLine.new("That\'s my throat!"))
	_loc8_.append(DialogueLine.new("You can\'t force it any deeper!"))
	_loc9_ = []
	_loc9_ = []
	_loc9_.append(DialogueLine.new("I can\'t believe you made me take it all*, YOU*."))
	_loc9_.append(DialogueLine.new("You forced it into my throat!"))
	_loc9_.append(DialogueLine.new("My throat!"))
	_loc9_.append(DialogueLine.new("That\'s my throat*, YOU*!"))
	_loc9_.append(DialogueLine.new("You pushed it all the way in..."))
	_loc10_ = []
	_loc10_ = []
	_loc10_.append(DialogueLine.new("I swallowed it all! It made my throat feel so full."))
	_loc10_.append(DialogueLine.new("I can\'t believe I took it all!"))
	_loc10_.append(DialogueLine.new("I can\'t believe I swallowed it all!"))
	_loc10_.append(DialogueLine.new("Ahh... push it all the way in again."))
	_loc10_.append(DialogueLine.new("That was amazing, push it into my throat again!"))
	_loc11_ = []
	_loc11_ = []
	_loc11_.append(DialogueLine.new("I can\'t believe you!"))
	_loc11_.append(DialogueLine.new("That\'s enough! Don\'t push it into my throat again."))
	_loc11_.append(DialogueLine.new("That\'s enough! Don\'t do that again."))
	_loc12_ = []
	_loc12_ = []
	_loc12_.append(DialogueLine.new("That\'s too deep!"))
	_loc12_.append(DialogueLine.new("Stop pushing me down!"))
	_loc12_.append(DialogueLine.new("Stop forcing me down!"))
	_loc12_.append(DialogueLine.new("Stop making me take it so deep!"))
	_loc12_.append(DialogueLine.new("Stop making me take it all!"))
	_loc12_.append(DialogueLine.new("Stop pushing it in so deep!"))
	_loc12_.append(DialogueLine.new("I can\'t breathe!"))
	_loc12_.append(DialogueLine.new("Don\'t push me down!"))
	_loc12_.append(DialogueLine.new("Let me off!"))
	_loc12_.append(DialogueLine.new("Let me breathe!"))
	_loc13_ = []
	_loc13_ = []
	_loc13_.append(DialogueLine.new("Ahh! My throat feels so full."))
	_loc13_.append(DialogueLine.new("Do you like my throat?"))
	_loc13_.append(DialogueLine.new("Do you like it?"))
	_loc13_.append(DialogueLine.new("Push it in again, I can take it."))
	_loc14_ = []
	_loc14_ = []
	_loc14_.append(DialogueLine.new("Let me off!"))
	_loc14_.append(DialogueLine.new("Let me breathe!"))
	_loc14_.append(DialogueLine.new("Stop pushing me down!"))
	_loc14_.append(DialogueLine.new("Stop forcing me down!"))
	_loc15_ = []
	_loc15_ = []
	_loc15_.append(DialogueLine.new("Wait... let me catch my breath."))
	_loc15_.append(DialogueLine.new("Can\'t... breathe!"))
	_loc15_.append(DialogueLine.new("Let me breathe* YOU*!"))
	_loc15_.append(DialogueLine.new("I can\'t breathe!"))
	_loc15_.append(DialogueLine.new("I\'m going to pass out!"))
	_loc15_.append(DialogueLine.new("I\'m going to faint!"))
	_loc15_.append(DialogueLine.new("I can\'t take it for so long!"))
	_loc15_.append(DialogueLine.new("Don\'t hold me down for so long*, YOU*!"))
	_loc16_ = []
	_loc16_ = []
	_loc16_.append(DialogueLine.new("You\'re making my head spin!"))
	_loc16_.append(DialogueLine.new("You\'re making me so dizzy!"))
	_loc16_.append(DialogueLine.new("I can take it, just let me catch my breath."))
	_loc16_.append(DialogueLine.new("Don\'t worry* YOU*, I can take it."))
	_loc16_.append(DialogueLine.new("My throat feels so full."))
	_loc17_ = []
	_loc17_ = []
	_loc17_.append(DialogueLine.new("Let me off!"))
	_loc17_.append(DialogueLine.new("Let me breathe!"))
	_loc17_.append(DialogueLine.new("What are you trying to do?!"))
	_loc17_.append(DialogueLine.new("Get off me!"))
	_loc17_.append(DialogueLine.new("Stop holding me down!"))
	_loc18_ = []
	_loc18_ = []
	_loc18_.append(DialogueLine.new("Wh- where..."))
	_loc18_.append(DialogueLine.new("What happened?"))
	_loc18_.append(DialogueLine.new("Wha-?"))
	_loc18_.append(DialogueLine.new("*YOU, *... you made me faint!"))
	_loc18_.append(DialogueLine.new("*YOU, *... you made me pass out!"))
	_loc19_ = []
	_loc19_ = []
	_loc19_.append(DialogueLine.new("I told you to let me breathe!"))
	_loc19_.append(DialogueLine.new("What were you thinking?! I need to breathe!"))
	_loc19_.append(DialogueLine.new("I can\'t believe you, you made me pass out!"))
	_loc20_ = []
	_loc20_ = []
	_loc20_.append(DialogueLine.new("Slow down* YOU*!"))
	_loc20_.append(DialogueLine.new("Wait! Slow down!"))
	_loc20_.append(DialogueLine.new("You\'re too rough!"))
	_loc20_.append(DialogueLine.new("You\'re being too rough!"))
	_loc20_.append(DialogueLine.new("Stop being so rough!"))
	_loc20_.append(DialogueLine.new("It\'s too rough!"))
	_loc20_.append(DialogueLine.new("You\'re tearing my throat!"))
	_loc20_.append(DialogueLine.new("My throat!"))
	_loc20_.append(DialogueLine.new("You\'re going to tear my throat!"))
	_loc20_.append(DialogueLine.new("Wait! You\'re being too rough!"))
	_loc20_.append(DialogueLine.new("I can\'t take any more* YOU*!"))
	_loc21_ = []
	_loc21_ = []
	_loc21_.append(DialogueLine.new("Keep going* YOU*!"))
	_loc21_.append(DialogueLine.new("Yes! Fuck my throat* YOU*!"))
	_loc21_.append(DialogueLine.new("Use my mouth like a pussy* YOU*!"))
	_loc21_.append(DialogueLine.new("I can take it, don\'t stop!"))
	_loc21_.append(DialogueLine.new("You\'re making my head spin."))
	_loc22_ = []
	_loc22_ = []
	_loc22_.append(DialogueLine.new("What do you think you\'re doing?!"))
	_loc22_.append(DialogueLine.new("Stop!"))
	_loc23_ = []
	_loc23_ = []
	_loc23_.append(DialogueLine.new("Are you almost there?"))
	_loc23_.append(DialogueLine.new("Are you nearly there?"))
	_loc24_ = []
	_loc24_ = []
	_loc24_.append(DialogueLine.new("Come on* YOU*, give me your cum!"))
	_loc24_.append(DialogueLine.new("Cum for me* YOU*!"))
	_loc24_.append(DialogueLine.new("Cum on my face* YOU*!"))
	_loc24_.append(DialogueLine.new("Give it to me* YOU*!"))
	_loc25_ = []
	_loc25_ = []
	_loc25_.append(DialogueLine.new("Are you done yet?"))
	_loc25_.append(DialogueLine.new("Hurry up and finish!"))
	_loc26_ = []
	_loc26_ = []
	_loc26_.append(DialogueLine.new("Ugh... you didn\'t have to shoot all over my face."))
	_loc26_.append(DialogueLine.new("You came all over my face."))
	_loc26_.append(DialogueLine.new("You came all over me."))
	_loc26_.append(DialogueLine.new("Ugh... it\'s everywhere."))
	_loc26_.append(DialogueLine.new("*YOUR cum... *It\'s all over my face."))
	_loc26_.append(DialogueLine.new("*YOUR cum... *It\'s everywhere."))
	_loc26_.append(DialogueLine.new("It\'s so hot."))
	_loc27_ = []
	_loc27_ = []
	_loc27_.append(DialogueLine.new("You came so much!"))
	_loc27_.append(DialogueLine.new("You came all over me."))
	_loc27_.append(DialogueLine.new("*YOUR cum... *It\'s all over my face."))
	_loc27_.append(DialogueLine.new("*YOUR cum... *It\'s everywhere."))
	_loc27_.append(DialogueLine.new("It\'s so warm."))
	_loc28_ = []
	_loc28_ = []
	_loc28_.append(DialogueLine.new("Did you have to shoot all over my face?!"))
	_loc28_.append(DialogueLine.new("Ugh! You\'ve covered me in it!"))
	_loc29_ = []
	_loc29_ = []
	_loc29_.append(DialogueLine.new("Swallow it?"))
	_loc29_.append(DialogueLine.new("Swallow?"))
	_loc29_.append(DialogueLine.new("Drink it?"))
	_loc29_.append(DialogueLine.new("You want me to swallow it?"))
	_loc30_ = []
	_loc30_ = _loc29_.duplicate()
	_loc30_.append(DialogueLine.new("Can I swallow it?"))
	_loc30_.append(DialogueLine.new("Can I drink it?"))
	_loc30_.append(DialogueLine.new("So much..."))
	_loc31_ = []
	_loc31_ = []
	_loc31_.append(DialogueLine.new("You expect me to swallow this?"))
	_loc31_.append(DialogueLine.new("Ugh... what were you thinking?!"))
	_loc31_.append(DialogueLine.new("You want me to swallow this?"))
	_loc32_ = []
	_loc32_ = []
	_loc32_.append(DialogueLine.new("I\'m so full."))
	_loc32_.append(DialogueLine.new("I can feel it all inside me."))
	_loc32_.append(DialogueLine.new("I can feel it inside me."))
	_loc32_.append(DialogueLine.new("You came right down my throat..."))
	_loc32_.append(DialogueLine.new("You came straight into my stomach."))
	_loc33_ = []
	_loc33_ = []
	_loc33_.append(DialogueLine.new("Ugh, you came right down my throat!"))
	_loc33_.append(DialogueLine.new("At least I didn\'t have to taste it."))
	_loc33_.append(DialogueLine.new("Ugh, I can feel it all down my throat."))
	_loc34_ = []
	_loc34_ = []
	_loc34_.append(DialogueLine.new("My eyes!"))
	_loc34_.append(DialogueLine.new("I can\'t see!"))
	_loc34_.append(DialogueLine.new("Ow!"))
	_loc35_ = []
	_loc36_ = []
	_loc36_ = []
	_loc36_.append(DialogueLine.new("I\'m so full."))
	_loc36_.append(DialogueLine.new("I can\'t believe you made me drink it all*, YOU*."))
	_loc36_.append(DialogueLine.new("I can\'t believe you made me swallow it all*, YOU*."))
	_loc36_.append(DialogueLine.new("I can still taste it."))
	_loc36_.append(DialogueLine.new("I can feel it all inside me."))
	_loc36_.append(DialogueLine.new("So much..."))
	_loc37_ = []
	_loc37_ = []
	_loc37_.append(DialogueLine.new("Mm, I can still taste it."))
	_loc37_.append(DialogueLine.new("I can feel it all inside me."))
	_loc37_.append(DialogueLine.new("So much..."))
	_loc38_ = []
	_loc38_ = []
	_loc38_.append(DialogueLine.new("Ugh, it tastes horrible."))
	_loc38_.append(DialogueLine.new("I can\'t believe you made me drink it all*, YOU*."))
	_loc38_.append(DialogueLine.new("I can\'t believe you made me swallow it all*, YOU*."))
	_loc39_ = []
	_loc39_ = []
	_loc39_.append(DialogueLine.new("I couldn\'t swallow it all* YOU*."))
	_loc39_.append(DialogueLine.new("I couldn\'t drink it all."))
	_loc39_.append(DialogueLine.new("It tastes bitter"))
	_loc40_ = []
	_loc40_ = []
	_loc40_.append(DialogueLine.new("I couldn\'t swallow it all."))
	_loc40_.append(DialogueLine.new("I didn\'t mean to spill it* YOU*. Give me more?"))
	_loc41_ = []
	_loc41_ = []
	_loc41_.append(DialogueLine.new("I\'m not swallowing that!"))
	_loc41_.append(DialogueLine.new("I\'m not going to drink that!"))
	_loc41_.append(DialogueLine.new("Ugh, I can still taste it."))
	_loc42_ = []
	_loc42_ = []
	_loc42_.append(DialogueLine.new("W-wait... you still want more?!"))
	_loc42_.append(DialogueLine.new("W-wait... you want more?!"))
	_loc42_.append(DialogueLine.new("Again?!"))
	_loc42_.append(DialogueLine.new("You\'re still hard?!"))
	_loc42_.append(DialogueLine.new("H-hey, you\'re still going?!"))
	_loc42_.append(DialogueLine.new("Isn\'t *FINISHES* enough?!"))
	_loc43_ = []
	_loc43_ = []
	_loc43_.append(DialogueLine.new("You want more?"))
	_loc43_.append(DialogueLine.new("I can go more than *FINISHES* if you can."))
	_loc43_.append(DialogueLine.new("*FINISHES* isn\'t enough right? Keep going."))
	_loc44_ = []
	_loc44_ = []
	_loc44_.append(DialogueLine.new("Aren\'t you done?!"))
	_loc44_.append(DialogueLine.new("Again?!"))
	_loc44_.append(DialogueLine.new("Isn\'t *FINISHES* enough?!"))
	_loc45_ = []
	_loc45_ = []
	_loc45_.append(DialogueLine.new("-mphh!"))
	_loc45_.append(DialogueLine.new("-mph!"))
	_loc45_.append(DialogueLine.new("-!"))
	_loc45_.append(DialogueLine.new("-ghmph!"))
	_loc45_.append(DialogueLine.new("-mmbh!"))
	_loc45_.append(DialogueLine.new("-nngh!"))
	_loc45_.append(DialogueLine.new("-mmn!"))
	_loc45_.append(DialogueLine.new("-ghch!"))
	_loc45_.append(DialogueLine.new("-mmb!"))
	_loc45_.append(DialogueLine.new("-mmbh!"))
	_loc45_.append(DialogueLine.new("-mnh!"))
	_loc45_.append(DialogueLine.new("-ng!"))
	_loc46_ = []
	_loc46_ = []
	_loc46_.append(DialogueLine.new("-aghck"))
	_loc46_.append(DialogueLine.new("-ack"))
	_loc46_.append(DialogueLine.new("-ackph"))
	_loc46_.append(DialogueLine.new("-agph"))
	_loc46_.append(DialogueLine.new("-achf"))
	normalLibrary = {}
	normalLibrary[Dialogue.INTRO] = _loc2_
	normalLibrary[Dialogue.RESISTANCE] = _loc3_
	normalLibrary[Dialogue.GENERAL] = _loc1_
	normalLibrary[Dialogue.INTERRUPT] = _loc45_
	normalLibrary[Dialogue.COUGH] = _loc46_
	normalLibrary[Dialogue.FIRST_THROAT] = _loc6_
	normalLibrary[Dialogue.FIRST_DT] = _loc9_
	normalLibrary[Dialogue.PULL_OFF] = _loc12_
	normalLibrary[Dialogue.HELD] = _loc15_
	normalLibrary[Dialogue.WAKE] = _loc18_
	normalLibrary[Dialogue.VIGOROUS] = _loc20_
	normalLibrary[Dialogue.PRE_CUM] = _loc23_
	normalLibrary[Dialogue.CUM_ON_FACE] = _loc26_
	normalLibrary[Dialogue.CUM_IN_MOUTH] = _loc29_
	normalLibrary[Dialogue.CUM_IN_THROAT] = _loc32_
	normalLibrary[Dialogue.CUM_IN_EYE] = _loc34_
	normalLibrary[Dialogue.CUM_IN_NOSE] = _loc35_
	normalLibrary[Dialogue.SWALLOW] = _loc36_
	normalLibrary[Dialogue.DROOL] = _loc39_
	normalLibrary[Dialogue.RESTART] = _loc42_
	happyLibrary = {}
	happyLibrary[Dialogue.INTRO] = _loc2_
	happyLibrary[Dialogue.RESISTANCE] = _loc4_
	happyLibrary[Dialogue.GENERAL] = _loc1_
	happyLibrary[Dialogue.INTERRUPT] = _loc45_
	happyLibrary[Dialogue.COUGH] = _loc46_
	happyLibrary[Dialogue.FIRST_THROAT] = _loc7_
	happyLibrary[Dialogue.FIRST_DT] = _loc10_
	happyLibrary[Dialogue.PULL_OFF] = _loc13_
	happyLibrary[Dialogue.HELD] = _loc16_
	happyLibrary[Dialogue.WAKE] = _loc18_
	happyLibrary[Dialogue.VIGOROUS] = _loc21_
	happyLibrary[Dialogue.PRE_CUM] = _loc24_
	happyLibrary[Dialogue.CUM_ON_FACE] = _loc27_
	happyLibrary[Dialogue.CUM_IN_MOUTH] = _loc30_
	happyLibrary[Dialogue.CUM_IN_THROAT] = _loc32_
	happyLibrary[Dialogue.CUM_IN_EYE] = _loc34_
	happyLibrary[Dialogue.CUM_IN_NOSE] = _loc35_
	happyLibrary[Dialogue.SWALLOW] = _loc37_
	happyLibrary[Dialogue.DROOL] = _loc40_
	happyLibrary[Dialogue.RESTART] = _loc43_
	angryLibrary = {}
	angryLibrary[Dialogue.INTRO] = _loc2_
	angryLibrary[Dialogue.RESISTANCE] = _loc5_
	angryLibrary[Dialogue.GENERAL] = _loc1_
	angryLibrary[Dialogue.INTERRUPT] = _loc45_
	angryLibrary[Dialogue.COUGH] = _loc46_
	angryLibrary[Dialogue.FIRST_THROAT] = _loc8_
	angryLibrary[Dialogue.FIRST_DT] = _loc11_
	angryLibrary[Dialogue.PULL_OFF] = _loc14_
	angryLibrary[Dialogue.HELD] = _loc17_
	angryLibrary[Dialogue.WAKE] = _loc19_
	angryLibrary[Dialogue.VIGOROUS] = _loc22_
	angryLibrary[Dialogue.PRE_CUM] = _loc25_
	angryLibrary[Dialogue.CUM_ON_FACE] = _loc28_
	angryLibrary[Dialogue.CUM_IN_MOUTH] = _loc31_
	angryLibrary[Dialogue.CUM_IN_THROAT] = _loc33_
	angryLibrary[Dialogue.CUM_IN_EYE] = _loc34_
	angryLibrary[Dialogue.CUM_IN_NOSE] = _loc35_
	angryLibrary[Dialogue.SWALLOW] = _loc38_
	angryLibrary[Dialogue.DROOL] = _loc41_
	angryLibrary[Dialogue.RESTART] = _loc44_
	ahegaoLibrary = {}
	finishes = {}
	finishes[1] = [DialogueLine.new("once")]
	finishes[2] = [DialogueLine.new("twice")]
	finishes[3] = [DialogueLine.new("three times")]
	finishes[4] = [DialogueLine.new("four times")]
	finishes[5] = [DialogueLine.new("five times")]
	finishes[6] = [DialogueLine.new("six times")]
	finishes[7] = [DialogueLine.new("seven times")]
	finishes[8] = [DialogueLine.new("eight times")]
	finishes[9] = [DialogueLine.new("nine times")]
	finishes[10] = [DialogueLine.new("ten times")]
	finishes[OTHER_FINISH] = [DialogueLine.new("that many times")]
# END generated
