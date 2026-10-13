class_name FlashStage
extends FlashSprite
## flash.display.Stage: root of the display list, plus keyboard focus and the quality setting.

## "low" / "medium" / "high" / "best". Kept for the game's quality option; rendering is unaffected.
var quality: String = "high"
var stageWidth: int = 700
var stageHeight: int = 600


var focus: FlashDisplayObject:
	get:
		return Flash.get_focus()
	set(value):
		Flash.set_focus(value)
		if value is FlashTextField:
			value.grab_input_focus()
		elif get_viewport() != null and get_viewport().gui_get_focus_owner() != null:
			get_viewport().gui_get_focus_owner().release_focus()
