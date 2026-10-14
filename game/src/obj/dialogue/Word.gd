class_name Word
extends RefCounted
## Port of obj.dialogue.Word: splits a word into consonant/vowel groups and picks a mouth shape for each.

static var _reAction := RegEx.create_from_string("\\[.*?\\]")
static var _reFirst := RegEx.create_from_string("(?i)\\W*\\w")
static var _reNotVowel := RegEx.create_from_string("[^aeiouy]")
static var _reNotCons := RegEx.create_from_string("(?i)[^bcdfghjklmnpqrstvwxz]")
static var _reCons := RegEx.create_from_string("(?i)[bcdfghjklmnpqrstvwxz]")
static var _reNonWord := RegEx.create_from_string("\\W")
static var _reFF := RegEx.create_from_string("(?i)f|ph")
static var _reMM := RegEx.create_from_string("(?i)m|p|b")
static var _reAH := RegEx.create_from_string("a|^a$")
static var _reEE := RegEx.create_from_string("(?i)^i$|ee|ea|oe|ou|^y$")
static var _reUH := RegEx.create_from_string("(?i)^e$|^u$|ou")
static var _reOH := RegEx.create_from_string("(?i)^o$|oa")
static var _reOO := RegEx.create_from_string("(?i)oo|w")
static var _reL := RegEx.create_from_string("(?i)l")

var word: String
var wordLength: int
var phonemes: Dictionary = {}
var actionWord := false

var action: String:
	get: return _reNonWord.sub(word, "", true)
var length: int:
	get: return wordLength


func _init(w: String) -> void:
	word = w
	wordLength = word.length()
	if _reAction.search(w):
		actionWord = true
		return
	var group := ""
	var m := _reFirst.search(word)
	if m:
		var inCons := _reNotVowel.search(m.get_string()) != null
		var i := 0
		while i < wordLength:
			var ch := word[i]
			if inCons:
				if _reNotCons.search(ch):
					inCons = false
					phonemes[i] = findPhonemes(group)
					group = ""
			elif _reCons.search(ch):
				inCons = true
				phonemes[i] = findPhonemes(group)
				group = ""
			group += ch
			i += 1
		phonemes[i] = findPhonemes(group)


func letter(i: int) -> String:
	return word[i] if i >= 0 and i < wordLength else ""


func phoneme(i: int):
	var p = phonemes.get(i)
	return p if p else null


func phonemeLength(i: int) -> int:
	var n := 0
	var start = phoneme(i)
	i += 1
	while i < wordLength and (not phoneme(i) or is_same(phoneme(i), start)):
		n += 1
		i += 1
	return n


func findPhonemes(s: String):
	var shape = null
	var sayL := false
	if s == "I":
		shape = Her.MouthShapeUH
	elif s:
		if _reFF.search(s):
			shape = Her.MouthShapeFF
		elif _reMM.search(s):
			shape = Her.MouthShapeMM
		elif _reAH.search(s):
			shape = Her.MouthShapeAH
		elif _reEE.search(s):
			shape = Her.MouthShapeEE
		elif _reUH.search(s):
			shape = Her.MouthShapeUH
		elif _reOH.search(s):
			shape = Her.MouthShapeOH
		elif _reOO.search(s):
			shape = Her.MouthShapeOO
		else:
			shape = Her.MouthShapeUH
		if _reL.search(s):
			sayL = true
	if shape:
		return {"phoneme": shape, "sayL": sayL}
	return null
