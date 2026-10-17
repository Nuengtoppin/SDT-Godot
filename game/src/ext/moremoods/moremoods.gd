extends SDTExtension
## Built-in reimplementation of sby's Loader mod moremoods (v18): 22 moods besides vanilla's four, each with its own
## face, eyes, breathing and behaviour, the [<MOOD>_MOOD] dialogue triggers and a mood selector in the Scene menu.
## Port's own code, from the mod's mood documentation and behaviour.
##
## How moods work (as in moremoods): her.setMood is taken over; each mood shows one of the four vanilla mouth
## shapes and sets a vanilla mood underneath (mostly "Normal"); the real mood is Moods.current() / `mood`, the
## dialogue variable "moremoods" and the character code field "moremoods".
##
## Stage 1: moods, face, triggers, selector, character code. The per-mood eyes, breathing and behaviour come next.

const MOODS := ["Normal", "Happy", "Angry", "Ahegao", "Upset", "Worried", "Aggressive", "Drugged", "Frightened",
	"Spent", "Submissive", "Depressed", "Nervous", "Elated", "Disgusted", "Broken", "Excited", "Smug", "Horny", "Tease",
	"Overwhelmed", "Android", "Devoted", "Professional", "Numb", "Asleep"]
const VANILLA := ["Normal", "Happy", "Angry", "Ahegao"]

## Mouth shape (one of the vanilla face frames) for each added mood.
const MOUTH := {"Upset": "Angry", "Worried": "Angry", "Aggressive": "Ahegao", "Drugged": "Ahegao", "Frightened": "Angry",
	"Spent": "Normal", "Submissive": "Normal", "Depressed": "Angry", "Nervous": "Ahegao", "Elated": "Ahegao",
	"Disgusted": "Angry", "Broken": "Angry", "Excited": "Ahegao", "Smug": "Ahegao", "Horny": "Ahegao", "Tease": "Ahegao",
	"Overwhelmed": "Ahegao", "Android": "Normal", "Devoted": "Ahegao", "Professional": "Normal", "Numb": "Normal"}
const ASLEEP_MOUTHS := ["Normal", "Ahegao", "Angry"]

## The current mood (vanilla or added).
var mood_name := "Normal"
## The mood uses the angry mouth (the lips are drawn accordingly).
var angry_lips := false
## The mood keeps her tongue out all the time (Spent with the setting, Broken).
var always_tongue_out := false
## 10: she can speak; 5: she cannot (Asleep without speaking dialogue); read by gaggeddialog-style features.
var can_speak_level := 10
## Frames until the mood's next timer action (drool, wince, ...).
var random_timer := 0
var lower_eyelid_level := 0.0

var _label: ExtButton
var face = null   # mm_face.gd

const FaceScript := preload("res://src/ext/moremoods/mm_face.gd")


func _init() -> void:
	id = "moremoods"
	title = "moremoods"
	description = "22 more moods for her, with their own face, eyes, breathing and behaviour (from sby's moremoods)."
	default_enabled = true


func _setup() -> void:
	setting("alphabetizemoods", true, {"label": "Mood selector in alphabetical order"})
	setting("shufflemoods", true, {"label": "Shuffle picks the added moods too"})
	setting("spenttongueout", true, {"label": "Spent: tongue always out"})
	setting("asleepmouthshape", 2, {"label": "Asleep: mouth shape (0 normal, 1 happy, 2 angry)", "min": 0, "max": 2})
	setting("asleepspeakingdialog", false, {"label": "Asleep: allow speaking dialogue"})
	for m in MOODS:
		setting("disable" + m + "Selection", false, {"label": "Hide %s in the mood selector" % m})
	# eyes (moremoods settings file values)
	setting("startingeyerollmode", 0, {"label": "Eye roll mode for new characters (0 off, 1 roll, 2 roll + cross-eyed)", "min": 0, "max": 2})
	setting("startingeyelidmode", 0, {"label": "Upper eyelid mode for new characters (0-3)", "min": 0, "max": 3})
	setting("startingeyelidslider", 0.5, {"label": "Upper eyelid limit for new characters", "min": 0.0, "max": 1.0})
	setting("eyerolltargetangle", 62.0, {"label": "Eye roll angle", "min": 0.0, "max": 180.0})
	setting("limiteyerollpassoutangle", true, {"label": "Keep the irises visible when her eyes roll up"})
	setting("eyelidslidereyeposbaselimit", 54.0, {"label": "Eye angle limit: base", "min": 0.0, "max": 180.0})
	setting("eyelidslidereyeposscalelimit", 35.0, {"label": "Eye angle limit: eyelid scale", "min": 0.0, "max": 180.0})
	setting("eyelidslidereyeposscaley", 30.0, {"label": "Eye angle limit: pupil scale", "min": 0.0, "max": 180.0})
	setting("feareyesamount", 15.0, {"label": "Frightened / Nervous / Overwhelmed: eye jitter", "min": 0.0, "max": 39.0})
	setting("submissivenormaleye", 85.0, {"label": "Submissive: where she looks (y)", "min": -2000.0, "max": 2000.0})
	setting("submissivehimeye", 200.0, {"label": "Submissive: where she looks when looking at him (y)", "min": -2000.0, "max": 2000.0})
	setting("androidmoodpassouteyelid", 0, {"label": "Android: eyelid when passed out", "min": 0, "max": 150})
	setting("androidmoodpassouteyeycord", -150.0, {"label": "Android: where she looks when passed out (y)", "min": -8000.0, "max": 8000.0})
	setting("asleepclosedeyelidsthroatmax", 25.0, {"label": "Asleep: eyelid reaction to deep throat", "min": 0.0, "max": 50.0})
	setting("asleepeyebrowshape", 0, {"label": "Asleep: eyebrows (0 normal, 1 worried, 2 angry)", "min": 0, "max": 2})


func _enable() -> void:
	for m in MOODS:
		if not m in VANILLA:
			Moods.register(m, id)
	face = FaceScript.new(self)
	face.eyeroll_mode = get_setting("startingeyerollmode")
	face.eyelid_mode = get_setting("startingeyelidmode")
	face.eyelid_slider = get_setting("startingeyelidslider")
	face.hook()
	hook_before(&"Her.setMood", func(c): c.cancel(); set_mood(c.args[0]))
	_register_triggers()
	charcode_field("moremoods", func(): return mood_name, func(v, _l): _load_code_mood(v), Callable(), false)
	menu_button("sceneMenu", -330 - 21, 40, "◄", func(): _cycle(-1), 20, 20)
	_label = menu_button("sceneMenu", -330, 40, mood_name, func(): pass, 100, 20)
	menu_button("sceneMenu", -330 + 100 + 1, 40, "►", func(): _cycle(1), 20, 20)
	mood_name = g.her.currentMood
	_update_label()
	_store_dialogue_var()


func _disable() -> void:
	# back to the vanilla mood underneath
	var vanilla: String = g.her.currentMood
	mood_name = vanilla
	g.her.setMood(vanilla)


# ---------------------------------------------------------------- setting the mood

## moremoods' setMood: the mouth shape and vanilla mood for the mood, tongue, eyes, lips.
func set_mood(m: String) -> void:
	var her = g.her
	mood_name = m
	_store_dialogue_var()
	var face: String
	if m == "Asleep":
		face = ASLEEP_MOUTHS[clampi(get_setting("asleepmouthshape"), 0, 2)]
	elif MOUTH.has(m):
		face = MOUTH[m]
	else:
		face = m
	her.head.face.gotoAndStop(face)
	her.head.headTan.face.gotoAndStop(face)
	her.topLipstickContainer.gotoAndStop(face)
	angry_lips = MOUTH.has(m) and face == "Angry"
	her.currentMood = m if not MOUTH.has(m) and m != "Asleep" else "Normal"
	can_speak_level = 5 if m == "Asleep" and not get_setting("asleepspeakingdialog") else 10
	random_timer = int(floor(randf() * 240)) + 300
	her.eye.ball.irisContainer.x = -50.65
	her.eye.ball.highlights.x = 20.95
	her.updateLips()
	her.updateEyes()
	g.characterControl.setLipFills()
	lower_eyelid_level = 0
	her.tears.clearLowerEyelid(200 - her.eyelidMotion["pos"])
	her.tongue.doNothing()
	if m == Her.AHEGAO_MOOD or (m == "Spent" and get_setting("spenttongueout")) or m == "Broken":
		her.tongue.hangOut()
		always_tongue_out = m != Her.AHEGAO_MOOD
	else:
		her.tongue.stopHangingOut()
		always_tongue_out = false
	if m != Her.ANGRY_MOOD:
		her.clenchTeeth = false
	_update_label()
	Moods.set_extended(m)


## Frames she has been biting (bite behaviour comes with the mood behaviours).
func bite_timer() -> int:
	return 0


func _store_dialogue_var() -> void:
	g.dialogueControl.advancedController._dialogueDataStore["moremoods"] = mood_name


## A character code's "moremoods" field wins over its vanilla "mood" (applied after it).
func _load_code_mood(v: String) -> void:
	var m := v.get_slice(",", 0)
	if m in MOODS:
		g.her.setMood(m)


func _register_triggers() -> void:
	var da = Extensions.get_extension("dialogueactions")
	if da == null or not da.enabled:
		push_warning("moremoods: DialogueActions is off, the [<MOOD>_MOOD] triggers are not available")
		return
	for m in MOODS:
		if m in VANILLA:
			continue
		var name: String = m
		if not da.has_trigger(name.to_upper() + "_MOOD", 0):
			da.register_trigger(name.to_upper() + "_MOOD", 0, func(_a): g.her.setMood(name))


# ---------------------------------------------------------------- selector

func selectable() -> Array:
	var list: Array = MOODS.filter(func(m): return not get_setting("disable" + m + "Selection"))
	if get_setting("alphabetizemoods"):
		list.sort()
	return list


func _cycle(dir: int) -> void:
	var list := selectable()
	if list.is_empty():
		return
	var i := list.find(mood_name)
	if get_setting("alphabetizemoods"):
		i = posmod(i + dir, list.size()) if i != -1 else 0
	else:
		i = clampi(i + dir, 0, list.size() - 1) if i != -1 else 0
	g.her.setMood(list[i])


func _update_label() -> void:
	if _label != null:
		_label.set_text(mood_name)
