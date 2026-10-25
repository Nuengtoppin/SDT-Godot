class_name DevSchema
extends RefCounted
## Port addition: the developer panel's sections (DevMenu), in the menu's spec format (see MenuWidgets). Extensions can
## add controls here too: SDTMenu.add_control() with "section" set to one of these ids.
##   dev_tools   workbench for experimental tools (empty for now)
##   dev_eyes, dev_mouth, dev_fluids, dev_state, dev_him   her and his behaviours (DevBehaviour): call, automation
##   dev_info    live values: her state by the same groups, engine, extensions
##   dev_panel   the panel's own settings, automation as a whole


static func sections() -> Array:
	return [_tools()] + DevBehaviour.sections() + [_info(), _panel()]


static func _tools() -> Dictionary:
	return {"id": "dev_tools", "name": "Tools", "groups": [
		{"title": "Workbench", "controls": [
			MenuSchema.note("Experimental and diagnostic tools appear here."),
		]},
	]}


static func _info() -> Dictionary:
	return {"id": "dev_info", "name": "Info", "groups": [
		{"title": "Eyes", "controls": [
			value("Looking at", "Where her eyes are aimed.", func():
				var t: Vector2 = g.her.currentLookTarget
				return "his face" if t == g.her.hisFace else ("down" if t == g.her.eyesDown else "elsewhere")),
			value("Eye closed", "Closed by cum in her eye (opens when clean or after 40 s).",
				func(): return _yes(g.her.eyelidMotion["isClosed"])),
			value("Tears", "Tear spots on her face / tears running.",
				func(): return "%d / %d" % [g.her.tears.tearSpotList.size(), g.her.tears.tearList.size()]),
		]},
		{"title": "Mouth", "controls": [
			value("Cum in mouth", "Units in her mouth (she swallows or drools it).",
				func(): return "%d of %d" % [g.her.cumInMouth, g.her.maxCumInMouth]),
			value("Swallowing", "", func(): return _yes(g.her.swallowing)),
			value("Teeth clenched", "Clenched teeth keep him out.", func(): return _yes(g.her.clenchTeeth)),
			value("Cough build-up", "Builds up while held deep; she coughs at the next cough time.",
				func(): return "%.1f" % g.her.coughBuild),
		]},
		{"title": "Fluids", "controls": [
			value("Drooling", "Spit / cum.", func(): return "%s / %s" % [_yes(g.her.droolingSpit), _yes(g.her.droolingCum)]),
			value("Sweat droplets", "", func(): return str(Sweat.droplet_count())),
			value("Wetness build-up", "Grows in Happy and Ahegao moods; unfinished in the original (shows nothing).",
				func(): return "%.0f" % g.her.wetGenerate),
		]},
		{"title": "State", "controls": [
			value("Mood", "Her mood; an extended mood (moremoods) in brackets.", func():
				return g.her.currentMood + (" (%s)" % Moods.current() if Moods.is_extended() else "")),
			value("Breath used", "Out of breath at the top; she passes out if it stays there.",
				func(): return "%.0f%%" % (g.breathLevel / g.breathLevelMax * 100.0)),
			value("Passing out", "Builds while out of breath; at the top she passes out.",
				func(): return "out" if g.her.passedOut else "%.0f%%" % (g.her.passOutFactor / g.her.passOutMax * 100.0)),
			value("Pace (vigour)", "Built from movement, falls by itself; above 1000 she winces.",
				func(): return "%.0f of 1050" % g.her.vigour),
		]},
		{"title": "Him", "controls": [
			value("Pleasure", "He comes after 2 s at the top.", func():
				return "%.0f%%" % minf(100.0, g.him.pleasure / g.him.ejacPleasure * 100.0)),
			value("Ejaculating", "", func(): return _yes(g.him.ejaculating)),
		]},
		{"title": "Engine", "controls": [
			value("Godot", "Engine version.", func(): return Engine.get_version_info()["string"]),
			value("Frame rate", "Frames drawn per second.", func(): return "%d fps" % Engine.get_frames_per_second()),
			value("Game tick", "Game logic steps since the start (30 per second, stopped while paused).",
				func(): return str(Flash.tick_count)),
		]},
		{"title": "Extensions", "controls": [
			value("Extensions on", "Extensions switched on, of all found.", func():
				return "%d of %d" % [Extensions.all.filter(func(e): return e.enabled).size(), Extensions.all.size()]),
			value("Hook points in use", "Game methods with extension handlers right now (Hooks).",
				func(): return str(Hooks.registered().size())),
		]},
	]}


static func _panel() -> Dictionary:
	return {"id": "dev_panel", "name": "Panel", "groups": [
		{"title": "Developer mode", "controls": [
			MenuSchema.toggle("Developer mode", "This panel. Off: it closes and its DEBUG tab goes away (back on in Settings › Menu).",
				SDTMenu.dev_mode_enabled, SDTMenu.set_dev_mode),
			MenuSchema.note("The panel opens on the side opposite the menu: Settings › Menu › Menu side moves both. It does not pause the game."),
		]},
		{"title": "Automation", "controls": [
			value("Switched off", "Behaviours the game no longer does by itself (Eyes, Mouth, Fluids, State, Him tabs).",
				func(): return "%d of %d" % [DevBehaviour.off_count(), DevBehaviour.hooks().size()]),
			MenuSchema.actions("", "", [
				["Freeze all", func(): DevBehaviour.set_all(false), "She and he do nothing by themselves; the call buttons still work."],
				["Restore all", func(): DevBehaviour.set_all(true), "Back to the game doing everything by itself."]],
				{"keywords": "automation freeze profile"}),
			MenuSchema.toggle("Remember after restart", "On: the switched-off automation comes back at the next start. Off: every start is the normal game (this session keeps what you switched off; Restore all clears it now).",
				DevBehaviour.remember, DevBehaviour.set_remember, {"keywords": "automation profile save"}),
		]},
	]}


static func _yes(v: bool) -> String:
	return "yes" if v else "no"


## A read-only value: label on the left, the value on the right, re-read while the panel is open.
static func value(label: String, tip: String, get_fn: Callable) -> Dictionary:
	return {"type": "custom", "label": label, "tip": tip, "wide": false, "keywords": "debug",
		"build": func():
			var l := Label.new()
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			l.add_theme_color_override("font_color", MenuTheme.ACCENT)
			l.set_meta("refresh", func(): l.text = str(get_fn.call()))
			return l}
