class_name DialogueState
extends RefCounted
## Port of obj.dialogue.DialogueState: build-up level, priority and phrase rotation for one dialogue state.

var _buildLevel: float = 0.0
var _maxBuild: float = 0.0
var _priority: int = 0
var _prevPhrases: Dictionary = {}
var _prevPhrasesLength: int = 0
var _lastUsed: int = 0
var _defaultReduceSpeed: float = 1.0
var _noBuildDelay: int = 0

var build: float:
	get: return _buildLevel
var max: float:
	get: return _maxBuild
var priority: int:
	get: return _priority


func _init(pMax: float, pPriority: int, reduceSpeed: float = 1.0) -> void:
	_maxBuild = pMax
	_priority = pPriority
	_defaultReduceSpeed = reduceSpeed


func buildState(v: float) -> void:
	if _noBuildDelay == 0:
		_buildLevel = minf(_maxBuild, _buildLevel + v)


func reduce(v: float = -1) -> void:
	if v == -1:
		v = _defaultReduceSpeed
	if _noBuildDelay > 0:
		_noBuildDelay -= 1
	_buildLevel = maxf(0, _buildLevel - v)


func clearBuild() -> void:
	_buildLevel = 0


func delayBuild(t: int = 120) -> void:
	_noBuildDelay = t


func maxBuild() -> void:
	_buildLevel = _maxBuild


func randomPhrase(list: Array) -> int:
	var n := list.size()
	if _prevPhrasesLength >= n:
		_prevPhrases = {}
		_prevPhrases[_lastUsed] = true
		_prevPhrasesLength = 1
	var free: Array = []
	for i in n:
		if not _prevPhrases.get(i, false):
			free.append(i)
	if free.is_empty():
		clearPrevPhrases()
		return 0
	var idx: int = free[int(floor(randf() * free.size()))]
	_prevPhrases[idx] = true
	_prevPhrasesLength += 1
	_lastUsed = idx
	return idx


func clearPrevPhrases() -> void:
	_prevPhrases = {}
	_prevPhrasesLength = 0
