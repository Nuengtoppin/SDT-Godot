class_name LoadedModPackage
extends RefCounted
## Port of obj.LoadedModPackage: one loaded mod file (or custom hair / background image), its path, and the
## elements it contributed (with their on/off status, saved as a "1010" status string).

var sourceFile: FlashFileReference
var dataName: String
var modName: String = ""
var modCreator: String = ""
var filePath: String = ""
var filePathOkay := false
var modElements: Array = []
var totalChildMods: int = 0
var loadedStatusString: String = ""
var loadingErrorHandler: Callable
var loadingSuccessHandler: Callable
var loadingInitHandler: Callable
## Port extension: the items of the package chosen from a picker (ModCatalog); empty = the whole package. Saved
## as "<path>|<item>+<item>...".
var items: Array = []


func _init(pDataName: String, src: FlashFileReference = null) -> void:
	sourceFile = src
	dataName = pDataName


func setFilePath(p: String) -> void:
	filePath = p


func setModDetails(n, creator) -> void:
	modName = str(n) if n != null else ""
	modCreator = str(creator) if creator != null else ""


func getElementStatusString() -> String:
	if modElements.is_empty():
		return ""
	var s := ","
	for m in modElements:
		s += "1" if m.active else "0"
	return s


func setStatusString(s: String) -> void:
	loadedStatusString = s


func applyStatusString() -> void:
	if loadedStatusString.length() == modElements.size():
		for i in modElements.size():
			if loadedStatusString[i] == "0":
				modElements[i].kill()
				if modElements[i].overwrite:
					g.customElementLoader.getResetFunction(modElements[i].modType).call()


var titleString: String:
	get:
		if modName and modCreator:
			return modName + " - " + modCreator
		if modName:
			return modName
		return fileName


func dataString() -> String:
	return (";" + dataName + ":" + filePath if filePathOkay else "") + getElementStatusString()


func tryToLoadFilePath(p: String, onError: Callable = Callable(), onSuccess: Callable = Callable(),
		onInit: Callable = Callable()) -> FlashLoader:
	filePath = p
	var l := FlashLoader.new()
	loadingErrorHandler = onError
	loadingSuccessHandler = onSuccess
	loadingInitHandler = onInit
	l.contentLoaderInfo.addEventListener(FlashEvent.IO_ERROR, fileIOErrorHandler)
	l.contentLoaderInfo.addEventListener(FlashEvent.COMPLETE, fileLoaderComplete)
	l.contentLoaderInfo.addEventListener(FlashEvent.INIT, fileLoaderInit)
	if filePath.contains("|"):
		items = Array(filePath.get_slice("|", 1).split("+")).map(func(v): return int(v))
	l.load(filePath.get_slice("|", 0))
	return l


func fileIOErrorHandler(e: FlashEvent) -> void:
	e.target.removeEventListener(FlashEvent.IO_ERROR, fileIOErrorHandler)
	if loadingErrorHandler.is_valid():
		loadingErrorHandler.call(e)


func fileLoaderComplete(e: FlashEvent) -> void:
	e.target.removeEventListener(FlashEvent.COMPLETE, fileLoaderComplete)
	filePathOkay = true
	if loadingSuccessHandler.is_valid():
		loadingSuccessHandler.call(e)


func fileLoaderInit(e: FlashEvent) -> void:
	e.target.removeEventListener(FlashEvent.INIT, fileLoaderInit)
	if loadingInitHandler.is_valid():
		loadingInitHandler.call(e)


func hasFilePath() -> bool:
	return filePathOkay


var path: String:
	get: return filePath


var fileName: String:
	get:
		if sourceFile:
			return sourceFile.name
		return filePath


func addElement(m) -> void:
	modElements.append(m)
	totalChildMods += 1


func removeElement(_m) -> void:
	if totalChildMods > 0:
		totalChildMods -= 1


func hasInstancedMods() -> bool:
	return totalChildMods > 0
