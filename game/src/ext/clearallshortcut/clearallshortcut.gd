extends SDTExtension
## Built-in reimplementation of the Loader's clearAllShortcut (Default folder): the right arrow key clears the spit
## and cum strands, her running mascara and the lipstick on him at once (the key from its settings file, "shortcut").
## Written from its decompiled code.

const KEY_RIGHT := 39


func _init() -> void:
	id = "clearallshortcut"
	title = "clearAllShortcut"
	description = "clearAllShortcut: the right arrow key clears spit and cum strands, mascara and lipstick."
	default_enabled = true


func _enable() -> void:
	on_key(KEY_RIGHT, clear_all, "clear all")
	menu_control("help", "Keys", MenuSchema.note("→ (right arrow): clear spit, cum, mascara and lipstick (clearAllShortcut)"))


func clear_all() -> void:
	if g.her == null:
		return
	g.strandControl.clearSpitStrands()
	g.strandControl.clearCumStrands()
	g.her.clearMascara()
	g.him.clearLipstick()
