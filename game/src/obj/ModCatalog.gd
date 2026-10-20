class_name ModCatalog
extends RefCounted
## Port extension (not in the original game): mods in Mods/Clothing and Mods/Hair are found automatically and each
## item they register becomes an option in its costume picker (or the hair picker), after the built-in options.
## Items of one mod that go to the same picker form one option (a hairstyle's parts, a gag's front and back).
## Choosing one applies those items exactly like loading the mod does (CustomElementLoader.parseMod), with the
## package saved as "<path>|<item>+<item>..." so saved characters restore just them. A pack's character preset
## (charData) and dialogue are not applied.
##
## New mods are converted on a worker thread and inspected once (which items, their types and slots); the result is
## cached next to the conversion (catalog.json), so later startups only read small files.

const SCAN_FOLDERS := ["Clothing", "Hair", "Backgrounds"]
const IMAGE_EXTENSIONS := ["png", "jpg", "jpeg", "gif", "bmp"]
const CATALOG_VERSION := 1
const HAIR_TYPES := [ModTypes.HAIR, ModTypes.DYNAMIC_HAIR]

## Entries: {path, items: Array[int], title, modTypes: Array[String], helper (costume pickers only)}
var entries: Array = []
var hair_entries: Array = []
var bg_entries: Array = []
## Lists extensions add for their mod types (add_picker): mod type -> list key; key -> entries (one per mod, all its
## items of those types). Shown as on / off switches, so several can be on (ExtraMod's face and eye mods stack).
var picker_types: Dictionary = {}
var picker_entries: Dictionary = {}
var _seen: Array = []         # [path, catalog] of every mod looked at, for lists added later
var _queue: Array = []        # paths still to inspect
var _converting: Dictionary = {}  # task id -> [path, bytes, dir]
var _busy := false


func start() -> void:
	for sub in SCAN_FOLDERS:
		_scan(Flash.mods_dir(sub))
	Flash.add_enter_frame(self, _tick)


func _scan(dir: String) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		var ext := f.get_extension().to_lower()
		if ext == "swf":
			_queue.append(dir.path_join(f))
		elif ext in IMAGE_EXTENSIONS and dir.begins_with(Flash.mods_dir("Backgrounds")):
			# background images: shown like the vanilla "Import background"
			var e := {"path": _relative(dir.path_join(f)), "image": true, "items": [], "modTypes": [],
				"title": f.get_basename().replace("_", " ").strip_edges(), "picker": "bg"}
			entries.append(e)
			bg_entries.append(e)
	for sub in d.get_directories():
		_scan(dir.path_join(sub))


## One mod per tick: cached catalogs are read directly, new mods are converted on a worker thread and then
## inspected on the main thread (their frame scripts must run to know what they contain).
func _tick() -> void:
	for id in _converting.keys():
		if WorkerThreadPool.is_task_completed(id):
			WorkerThreadPool.wait_for_task_completion(id)
			var job: Array = _converting[id]
			_converting.erase(id)
			_inspect(job[0], job[1])
			return
	if _queue.is_empty():
		if _converting.is_empty():
			Flash.remove_enter_frame(self, _tick)
			_sync_loaded()
		return
	if _converting.size() >= 2:
		return
	var path: String = _queue.pop_front()
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return
	var dir := FlashSwfMod.CACHE_ROOT.path_join(FlashSwfMod._sha256(bytes))
	var cat := _read_catalog(dir)
	if not cat.is_empty():
		_add(path, cat)
		return
	if FlashSwfMod.is_converted(dir):
		_inspect(path, bytes)
		return
	var scale: float = Flash.base_library.scale
	var id := WorkerThreadPool.add_task(func(): FlashSwfMod.convert_swf(bytes, dir, scale), false, "convert mod")
	_converting[id] = [path, bytes]


static func _read_catalog(dir: String) -> Dictionary:
	var p := dir.path_join("catalog.json")
	if not FileAccess.file_exists(p):
		return {}
	var c = JSON.parse_string(FileAccess.get_file_as_string(p))
	if c == null or int(c.get("version", 0)) != CATALOG_VERSION:
		return {}
	return c


func _inspect(path: String, bytes: PackedByteArray) -> void:
	var mod := FlashSwfMod.load_mod(bytes, path)
	if mod == null:
		return
	var root = mod.instantiate_root()
	var cat := {"version": CATALOG_VERSION, "items": []}
	if root != null and root.get("MOD_VERSION") != null:
		cat["modName"] = str(root.get("modName")) if root.get("modName") else ""
		cat["modCreator"] = str(root.get("modCreator")) if root.get("modCreator") else ""
		var mods = root.get("mods")
		for i in (mods.size() if mods is Array else 0):
			var m = mods[i]
			if m is FlashDisplayObject:
				cat["items"].append({"item": i, "name": m.flash_name, "modType": str(m.get("modType")),
					"targetElement": str(m.get("targetElement")) if m.get("targetElement") else ""})
	if root != null:
		root.queue_free()
	var f := FileAccess.open(mod.library.path.path_join("catalog.json"), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(cat))
		f.close()
	_add(path, cat)


## Adds a list for mods with items of `mod_types` (see picker_types), including mods already scanned.
func add_picker(key: String, mod_types: Array) -> void:
	for t in mod_types:
		picker_types[t] = key
	picker_entries[key] = []
	for s in _seen:
		_add(s[0], s[1], key)


func remove_picker(key: String) -> void:
	for t in picker_types.keys():
		if picker_types[t] == key:
			picker_types.erase(t)
	var gone: Array = picker_entries.get(key, [])
	entries = entries.filter(func(e): return not e in gone)
	picker_entries.erase(key)


## Whether the entry's mod is on (some of its items are placed).
func is_applied(e: Dictionary) -> bool:
	for lm in g.customElementLoader.instancedModElements:
		if lm.sourcePackage != null and _same_path(lm.sourcePackage.filePath.get_slice("|", 0), e["path"]):
			return true
	return false


static func _same_path(a: String, b: String) -> bool:
	return a == b or Flash.resolve_content_path(a) == Flash.resolve_content_path(b)


## Takes off one entry's mod (its own items only, other mods of the same types stay).
func remove_entry(e: Dictionary) -> void:
	var cel := g.customElementLoader
	var i := 0
	while i < cel.instancedModElements.size():
		var lm: LoadedMod = cel.instancedModElements[i]
		if lm.sourcePackage != null and _same_path(lm.sourcePackage.filePath.get_slice("|", 0), e["path"]):
			lm.kill()
			cel.instancedModElements.remove_at(i)
			continue
		i += 1
	cel.checkLoadedModPackages()
	cel.updateInstancedModElements()
	g.inGameMenu.charStoring.populateMods()


## Adds a mod's items to the pickers they belong to (only_key: just to that extension list).
func _add(path: String, cat: Dictionary, only_key = null) -> void:
	if only_key == null:
		_seen.append([path, cat])
	var rel := _relative(path)
	var title: String = cat.get("modName", "")
	if title == "":
		title = path.get_file().get_basename().replace("_", " ").strip_edges()
	# one option per picker: the mod's items for that picker are applied together
	var groups: Array = []   # [picker key, entry]
	for it in cat.get("items", []):
		var key = _picker_key(it)
		if key == null or (only_key != null and not is_same(key, only_key)):
			continue
		var e := {}
		for gr in groups:
			if is_same(gr[0], key):
				e = gr[1]
		if e.is_empty():
			e = {"path": rel, "items": [], "modTypes": [], "title": title}
			groups.append([key, e])
		e["items"].append(int(it["item"]))
		if not e["modTypes"].has(it["modType"]):
			e["modTypes"].append(it["modType"])
	for gr in groups:
		var key = gr[0]
		var e: Dictionary = gr[1]
		entries.append(e)
		if key is String and picker_entries.has(key):
			e["picker"] = key
			picker_entries[key].append(e)
		elif key is String:
			e["picker"] = key
			(hair_entries if key == "hair" else bg_entries).append(e)
		else:
			e["helper"] = key
			key.modEntries.append(e)


## The picker an item goes to: a costume element helper, "hair", or null (not selectable, e.g. Loader-only types).
func _picker_key(it: Dictionary):
	if picker_types.has(it["modType"]):
		return picker_types[it["modType"]]
	if it["modType"] in HAIR_TYPES:
		return "hair"
	if it["modType"] == ModTypes.BACKGROUND:
		return "bg"
	var key: String = it["targetElement"] if it["targetElement"] != "" else it["modType"]
	if it["modType"] == ModTypes.HAIR_COSTUME:
		return g.characterControl.headwearControl
	var helper = g.customElementLoader.modTargetHelpers.get(key)
	if helper != null and helper.hasCostumeHelper:
		return helper.characterElementHelper
	return null


static func _relative(path: String) -> String:
	var root := Flash.content_root().path_join("")
	return path.substr(root.length()) if path.begins_with(root) else path


# ---------------------------------------------------------------- applying

## Applies one catalog entry like loading its mod would (only that item).
func apply(e: Dictionary) -> void:
	var cel := g.customElementLoader
	var full := Flash.resolve_content_path(e["path"])
	var bytes := FileAccess.get_file_as_bytes(full)
	var mod := FlashSwfMod.load_mod(bytes, full) if not bytes.is_empty() else null
	if mod == null:
		push_warning("Mod not found: %s" % e["path"])
		return
	var root = mod.instantiate_root()
	var mods = root.get("mods") if root != null else null
	if not mods is Array:
		return
	var pkg := LoadedModPackage.new("swfMod")
	pkg.setFilePath("%s|%s" % [e["path"], "+".join(PackedStringArray(e["items"].map(func(i): return str(i))))])
	pkg.filePathOkay = true
	pkg.setModDetails(root.get("modName"), root.get("modCreator"))
	cel.loadedModPackages.append(pkg)
	cel.loadingModPackage = pkg
	cel.blockSwfCharData = true
	for i in e["items"]:
		if i < mods.size():
			cel.parseMod(mods[i])
	cel.blockSwfCharData = false
	cel.loadingModPackage = null
	# The whole mod was built to get at these items: free what was not placed (root, other items, containers).
	Flash.dispose_later(root)
	for m in mods:
		if m is FlashDisplayObject:
			Flash.dispose_later(m)
	cel.updateInstancedModElements()
	g.inGameMenu.charStoring.populateMods()


## Removes an applied entry (its mod type's instanced elements).
func remove(e: Dictionary) -> void:
	g.customElementLoader.clearModTypes(e["modTypes"])


## Marks items restored before the scan finished (saved character loaded at startup) as their pickers' options.
func _sync_loaded() -> void:
	var cel := g.customElementLoader
	for pkg in cel.loadedModPackages:
		if not pkg.items.is_empty():
			mark_selected(pkg.filePath.get_slice("|", 0), pkg.items)
	if cel.customBGLoaded and cel.proxyBGPackage and cel.proxyBGPackage.hasFilePath():
		mark_selected(cel.proxyBGPackage.path, [])


## Shows a restored saved item as the current option of its picker.
func mark_selected(path: String, items: Array) -> void:
	var e := find(path, items)
	if e.is_empty():
		return
	if e.has("helper"):
		var h: CharacterElementHelper = e["helper"]
		h.modEntryIndex = h.modEntries.find(e)
		h.updateMenuList.call(e["title"])
	elif picker_entries.has(e.get("picker", "")):
		pass   # on / off lists read is_applied()
	elif e.get("picker") == "bg":
		g.inGameMenu.bgModIndex = bg_entries.find(e)
		g.inGameMenu.updateBGPicker()
	else:
		g.inGameMenu.hairModIndex = hair_entries.find(e)
		g.inGameMenu.customMenu.mlHair.itemLabel.text = e["title"]


## Finds the entry for a saved "<path>|<items>" (to show it as selected when a saved character restores it).
func find(path: String, items: Array) -> Dictionary:
	for e in entries:
		if e["items"] == items and (e["path"] == path or Flash.resolve_content_path(e["path"]) == Flash.resolve_content_path(path)):
			return e
	return {}
