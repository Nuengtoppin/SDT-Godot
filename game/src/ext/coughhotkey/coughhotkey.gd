extends SDTExtension
## Built-in reimplementation of the Loader mod coughhotkey (sby, V1): F makes her cough. With him in her mouth she
## coughs around him (the game's open cough, its sound and her cough line); otherwise she coughs on her own breath.
## Written from its source.

const KEY_F := 70


func _init() -> void:
	id = "coughhotkey"
	title = "coughhotkey"
	description = "coughhotkey (sby): F makes her cough."
	default_enabled = true


func _enable() -> void:
	on_key(KEY_F, cough, "cough")
	menu_control("help", "Keys", MenuSchema.note("F: she coughs (coughhotkey)"))


func cough() -> void:
	var her = g.her
	if her == null:
		return
	if her.mouthFull:
		her.openCough()
		g.soundControl.playCough()
		g.dialogueControl.cough()
	else:
		g.soundControl.stopBreathing(true)
		g.soundControl.playOpenCough()
		g.soundControl.openCoughing = true
		g.soundControl.breathing = true
