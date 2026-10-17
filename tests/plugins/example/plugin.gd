extends SDTExtension
## Test plugin for game/debug/ext_checks.gd: uses a helper script, a key, a menu button and a hook.

var helper = null
var key_presses := 0
var passouts := 0
var button: ExtButton = null


func _setup() -> void:
	setting("greeting", "hello")


func _enable() -> void:
	helper = load_script("helper.gd").new()
	on_key(120, func(): key_presses += 1, "test key F9")
	button = menu_button("optionsMenu", 0, 0, "E", func(): pass)
	hook_after(&"Her.passOut", func(_c): passouts += 1)
