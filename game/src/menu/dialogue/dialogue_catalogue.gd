class_name DialogueCatalogue
extends RefCounted
## Port addition: what the dialogue editor (DialogueEditorPanel) knows about line types, actions and wildcards: the
## game's own with a short description each, plus whatever DialogueActions and the extensions built on it registered
## (their names and owners come from the trigger registry; descriptions only where listed here).

## The game's line types, in the order the game knows them, with when she says them.
const LINE_TYPES := {
	"intro": "when play starts",
	"general": "at random while nothing else is going on",
	"zero_state": "the empty state: lines here are not said on their own",
	"resistance": "while she resists going deeper",
	"first_throat": "the first time he goes into her throat",
	"first_dt": "the first deepthroat",
	"pull_off": "after she pulls off",
	"held": "while he holds her head",
	"wake": "when she wakes up after passing out",
	"vigorous": "while it is rough",
	"lick_penis": "while she licks his penis",
	"lick_balls": "while she licks his balls",
	"pre_cum": "just before he comes",
	"cum_on_face": "after he comes on her face",
	"cum_in_mouth": "after he comes in her mouth",
	"cum_in_throat": "after he comes in her throat",
	"cum_in_eye": "with cum in her eye",
	"cum_in_nose": "with cum in her nose",
	"swallow": "after she swallows",
	"drool": "while she drools",
	"head_grabbed": "when he grabs her head",
	"pulled_up": "when he pulls her up",
	"pulled_down": "when he pulls her down",
	"hand_job_stroke": "while she strokes him",
	"restart": "when he starts moving again after coming",
	"queued": "after a line whose Next line is queued",
}

## Wildcard line types: lines that stand in for a word in other lines.
const WILDCARD_TYPES := {
	"cough": "the text a cough inside a line shows as",
	"interrupt": "what she says when a line is cut off",
}

## DialogueActions' line types.
const DA_LINE_TYPES := {
	"start": "once, when play starts (DialogueActions)",
	"orgasm": "when she comes (DialogueActions)",
	"passed_out": "while she is passed out (DialogueActions)",
	"choking": "while she is choking (DialogueActions)",
}

## The game's own actions, grouped, with what each does.
const ACTIONS := [
	["Eyes", [["BLINK", "she blinks"], ["CLOSE_EYES", "closes her eyes until OPEN_EYES"], ["OPEN_EYES", "opens her eyes"],
		["LOOK_UP", "looks up at his face"], ["LOOK_DOWN", "looks down"], ["SHOCK", "eyes wide for a moment"],
		["ADD_TEARS", "a tear"]]],
	["Mouth", [["SWALLOW", "swallows"], ["DROOL", "drools"], ["COUGH", "coughs"], ["CLENCH_TEETH", "clenches her teeth"],
		["WINCE", "winces"]]],
	["Mood and style", [["NORMAL_MOOD", "mood: Normal"], ["HAPPY_MOOD", "mood: Happy"], ["ANGRY_MOOD", "mood: Angry"],
		["AHEGAO_MOOD", "mood: Ahegao"], ["NORMAL_STYLE", "his movement: normal"],
		["FACE_FUCK_STYLE", "his movement: rough"]]],
	["Him", [["HOLD", "he holds her head"], ["RELEASE", "he lets go"], ["EJACULATE", "he comes"]]],
	["Her arms", [["ARMS_BACK", "both arms behind her back"], ["ARMS_LEGS", "hands on her legs"],
		["ARMS_HIS_LEGS", "hands on his legs"], ["ARMS_HAND_JOB", "hands on him"], ["ARMS_LOOSE", "arms loose"],
		["LEFT_ARM_BACK", ""], ["LEFT_ARM_LEGS", ""], ["LEFT_ARM_HIS_LEGS", ""], ["LEFT_ARM_HAND_JOB", ""],
		["LEFT_ARM_LOOSE", ""], ["RIGHT_ARM_BACK", ""], ["RIGHT_ARM_LEGS", ""], ["RIGHT_ARM_HIS_LEGS", ""],
		["RIGHT_ARM_HAND_JOB", ""], ["RIGHT_ARM_LOOSE", ""], ["TAP_HANDS", "taps her hands"]]],
]

## The game's wildcards (*NAME* in a line).
const WILDCARDS := [["YOU", "his name, or \"you\""], ["YOUR", "his name's possessive, or \"your\""],
	["ME", "her name, or \"me\""], ["MY", "her name's possessive, or \"my\""],
	["FINISHES", "how often he has come (the finish lines)"]]

## Short descriptions of extension actions (by trigger name); the rest show only who adds them.
const EXT_DESCRIPTIONS := {
	"LOOK_DOWN": "looks down for <ms> (MoreTriggers)",
	"SHOCK": "eyes wide for <ms> (MoreTriggers)",
	"CLOSE_MOUTH": "keeps her mouth closed for <ms>",
	"MOAN": "a moan",
	"SLAP": "a slap sound",
	"GAG": "gags",
	"TONGUE_OUT": "sticks her tongue out",
	"TONGUE_IN": "takes her tongue in",
	"DEEPTHROAT": "he goes in deep",
	"HIDE_HIM": "hides him",
	"SHOW_HIM": "shows him again",
	"AUTO_HARD": "auto mode: hard",
	"AUTO_OFF": "auto mode off",
	"INSTANT_FLASH": "a white flash",
	"CLEARLINES": "clears queued lines",
	"LOAD_CHARCODE": "loads a character code",
	"VA_SET_VARIABLE": "sets a variable: _<name>_<value>",
	"VA_SET_GLOBALVARIABLE": "sets a global variable",
}


## Every action for the picker and the autocomplete: {"name", "insert", "desc", "group", "owner"} (owner "" = the
## game). Extension triggers come from DialogueActions' registry while it is on.
static func actions() -> Array:
	var out: Array = []
	for grp in ACTIONS:
		for a in grp[1]:
			out.append({"name": a[0], "insert": "[" + a[0] + "]", "desc": a[1], "group": grp[0], "owner": ""})
	var da = _da()
	if da == null:
		return out
	var owners := {}
	for ext_id in da._owned:
		for t in da._owned[ext_id]:
			owners[t[0] + "|" + str(t[1])] = ext_id
	var names: Array = da._triggers.keys()
	names.sort()
	for n in names:
		for argc in da._triggers[n]:
			var owner: String = owners.get(n + "|" + str(argc), "dialogueactions")
			var shown: String = n
			if argc > 0:
				for i in argc:
					shown += "_<%s>" % ("ms" if argc == 1 and EXT_DESCRIPTIONS.get(n, "").contains("<ms>") else "arg%d" % (i + 1))
			elif argc < 0:
				shown += "_<args…>"
			out.append({"name": shown, "insert": "[" + shown.get_slice("_<", 0) + ("_" if argc != 0 else "") + "]",
				"desc": EXT_DESCRIPTIONS.get(n, ""), "group": _owner_title(owner), "owner": owner})
	return out


## Wildcards and DialogueActions variables: {"name", "insert", "desc", "group", "owner"}.
static func wildcards() -> Array:
	var out: Array = []
	for w in WILDCARDS:
		out.append({"name": w[0], "insert": "*" + w[0] + "*", "desc": w[1], "group": "Wildcards", "owner": ""})
	return out


static func variables() -> Array:
	var out: Array = []
	var da = _da()
	if da == null or da.vars == null:
		return out
	var names: Array = da.vars._read.keys()
	for k in da.vars.store().keys():
		if not names.has(k):
			names.append(k)
	names.sort()
	for n in names:
		out.append({"name": str(n), "insert": "*" + str(n) + "*", "desc": "", "group": "Variables", "owner": "dialogueactions"})
	return out


## When a line type is said ("" if unknown).
static func describe_type(t: String) -> String:
	if LINE_TYPES.has(t):
		return LINE_TYPES[t]
	if WILDCARD_TYPES.has(t):
		return WILDCARD_TYPES[t]
	if DA_LINE_TYPES.has(t):
		return DA_LINE_TYPES[t]
	if t.begins_with("button"):
		return "when the player clicks dialogue button " + t.substr(6) + " (DialogueActions)"
	if t.begins_with("finish"):
		return "how she counts finish " + t.substr(6) + " (the *FINISHES* wildcard)"
	return ""


static func _da():
	if not Extensions.is_on("dialogueactions"):
		return null
	return Extensions.get_extension("dialogueactions")


static func _owner_title(ext_id: String) -> String:
	var e = Extensions.get_extension(ext_id)
	return e.title if e != null and e.title != "" else ext_id
