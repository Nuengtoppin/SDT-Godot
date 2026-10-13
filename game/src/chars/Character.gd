class_name Character
extends RefCounted
## Port of chars.Character: base preset (appearance defaults) for the built-in characters.

var charName := "xxx"
var charShortName := "xxx"
var mood: String = Her.NORMAL_MOOD
var skinType: int = 0
var noseType: int = 0
var eyebrowType: int = 0
var earType := "normal"
var iris := "normal"
var breastSize: int = 70
var hairTop := "SDChan"
var hairUnder := "SDChan"
var hairBack := "SDChan"
var hairBottom := "SDChan"
var costume := "SDChan"
var collar: int = 1
var collarFill = {"r": 0, "g": 0, "b": 0, "a": 1}
var collarFill2 = null
var cuffs: int = 1
var cuffsFill = {"r": 0, "g": 0, "b": 0, "a": 1}
var headwear := "None"
var headwearFill = null
var headwearFill2 = null
var earring := "None"
var earringFill = null
var bodyScale: float = 1.0
var armPos := "Back"
var irisFill = {"r": 56, "g": 100, "b": 137, "a": 1}
var eyebrowFill = {"r": 89, "g": 67, "b": 51, "a": 1}
var eyebrowLine = {"r": 0, "g": 0, "b": 0, "a": 1}
var scalpFill = {"r": 211, "g": 158, "b": 90}
var lipstickFill = {"r": 0, "g": 0, "b": 0, "a": 0}
var eyeShadow = {"r": 55, "g": 26, "b": 99, "a": 1}
var sclera = {"r": 255, "g": 255, "b": 255, "a": 1}
var blush = {"r": 196, "g": 80, "b": 77, "a": 0.35}
var freckles = {"r": 60, "g": 24, "b": 24, "a": 0.8}
var freckleAmount: float = 0.0
var mascara = {"r": 0, "g": 0, "b": 0, "a": 1}
var bg: int = 3
var gag := "none"
var armwearFill = {"r": 0, "g": 0, "b": 0, "a": 1}
var armwear := "none"
var legwearFill = {"r": 0, "g": 0, "b": 0, "a": 1}
var legwear := "none"
var footwearFill = {"r": 0, "g": 0, "b": 0, "a": 1}
var footwear := "none"
var pantiesFill = {"r": 255, "g": 255, "b": 255, "a": 1}
var panties := "none"
var braFill = {"r": 255, "g": 255, "b": 255, "a": 1}
var bra := "none"
var eyewear := "none"
var eyewearFill = {"r": 0, "g": 0, "b": 0, "a": 1}
var dialogue := ""
var defaultCostume := ""
var altCostume := ""


func generateElements() -> Array:
	return []
