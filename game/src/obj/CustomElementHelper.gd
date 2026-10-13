class_name CustomElementHelper
extends RefCounted
## Port of obj.CustomElementHelper: where a mod element type gets attached (named target containers).

var targetDictionary: Dictionary = {}
var singleElement := false
var characterElementHelper: CharacterElementHelper = null
var hasCostumeHelper := false


func _init(targets: Dictionary, helper: CharacterElementHelper = null) -> void:
	for k in targets:
		targetDictionary[k] = targets[k]
	if targets.size() == 1:
		singleElement = true
	if helper:
		characterElementHelper = helper
		hasCostumeHelper = true
