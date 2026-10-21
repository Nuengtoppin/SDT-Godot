extends SDTExtension
## Built-in reimplementation of the Loader mod himnotletgo (sby, V3):
##   - "Doesn't let go" (Him > Arms, off by default like the mod): his hand stays on her head when she pulls back
##     (she is never released, his hand never opens);
##   - his arm positions in the character code, as "himRightArmPosition:Holding|Free" and
##     "himLeftArmPosition:Hidden|Loose", with "himNotLetGo:Normal|ForceHold" like the Loader mod (a full code
##     without himNotLetGo switches it off).
## Written from its source.

var hold := false


func _init() -> void:
	id = "himnotletgo"
	title = "himnotletgo"
	description = "himnotletgo (sby): his hand can stay on her head (Him > Arms); his arm positions are saved in the character code."
	default_enabled = true


func _enable() -> void:
	hook_before(&"Her.isReleased", func(c):
		if hold:
			c.cancel(false))
	hook_before(&"Him.openHand", func(c):
		if hold:
			c.cancel())
	charcode_field("himRightArmPosition", func(): return Him.armPositions[g.him.currentArmPosition],
		func(v, _l): g.him.findArmPosition(v, true))   # (remembered, so auto mode ends on it; the mod did not)
	charcode_field("himLeftArmPosition", func(): return Him.leftArmPositions[g.him.currentLeftArmPosition],
		func(v, _l): g.him.findLeftArmPosition(v))
	charcode_field("himNotLetGo", func(): return "ForceHold" if hold else "Normal",
		func(v, _l):
			if v == "Normal":
				hold = false
			elif v == "ForceHold":
				hold = true,
		func(_l): hold = false)
	menu_control("him", "Arms", MenuSchema.toggle("Doesn't let go",
		"His hand stays on her head when she pulls back.", func(): return hold,
		func(on: bool): hold = on; g.saveData.saveCharData()))


func _disable() -> void:
	hold = false
