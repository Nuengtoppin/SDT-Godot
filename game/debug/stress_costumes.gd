extends RefCounted
## Scripted test (main.gd --driver): starts the game, then steps every costume picker and the hair picker through
## their options (built-in and mods) and back, the background picker likewise, and switches characters - four times. Prints orphan stats at the end.

const HELPERS := ["collar", "gag", "cuffs", "ankleCuffs", "eyewear", "panties", "armwear", "legwear", "legwearB",
	"bottoms", "footwear", "top", "bra", "headwear", "earring"]
var _actions: Array = []


func _init() -> void:
	_actions.append(func(): Flash.stage.getChildAt(0).playClicked())
	for rep in 4:
		_actions.append(func(): print("STRESS round ", rep, " mem=", OS.get_static_memory_usage() / 1048576, " orphans=", Flash.orphan_stats(0)))
		for h in HELPERS:
			for d in [1, -1]:
				for k in 12:
					_actions.append(func(): g.characterControl.get(h + "Control")._step(d))
		for d in [1, -1]:
			for k in 40:
				_actions.append(func(): g.inGameMenu._stepHair(d))
		for d in [1, -1]:
			for k in 8:
				_actions.append(func(): g.inGameMenu._stepBG(d))
				for w in 10:
					_actions.append(func(): pass)
		for k in range(1, 11):
			for w in 20:
				_actions.append(func(): pass)
			_actions.append(func(): g.characterControl.setChar(k, false))
	for w in 120:
		_actions.append(func(): pass)
	_actions.append(func(): print("STRESS DONE mem=", OS.get_static_memory_usage() / 1048576, " orphans=", Flash.orphan_stats(25)))


func step(frame: int) -> void:
	var i := frame - 20
	if i >= 0 and i < _actions.size():
		_actions[i].call()
	elif i == _actions.size():
		Flash.get_tree().quit()
