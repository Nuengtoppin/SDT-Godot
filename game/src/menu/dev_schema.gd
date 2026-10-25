class_name DevSchema
extends RefCounted
## Port addition: the developer panel's sections (DevMenu), in the menu's spec format (see MenuWidgets). Extensions can
## add controls here too: SDTMenu.add_control() with "section" set to one of these ids.
##   dev_tools   workbench for experimental tools (empty for now)
##   dev_info    live values: frame rate, game tick, mood, extensions and hook points in use
##   dev_panel   the panel's own settings


static func sections() -> Array:
	return [_tools(), _info(), _panel()]


static func _tools() -> Dictionary:
	return {"id": "dev_tools", "name": "Tools", "groups": [
		{"title": "Workbench", "controls": [
			MenuSchema.note("Experimental and diagnostic tools appear here."),
		]},
	]}


static func _info() -> Dictionary:
	return {"id": "dev_info", "name": "Info", "groups": [
		{"title": "Engine", "controls": [
			value("Godot", "Engine version.", func(): return Engine.get_version_info()["string"]),
			value("Frame rate", "Frames drawn per second.", func(): return "%d fps" % Engine.get_frames_per_second()),
			value("Game tick", "Game logic steps since the start (30 per second, stopped while paused).",
				func(): return str(Flash.tick_count)),
		]},
		{"title": "Her", "controls": [
			value("Mood", "Her mood; an extended mood (moremoods) in brackets.", func():
				if g.her == null:
					return "-"
				return g.her.currentMood + (" (%s)" % Moods.current() if Moods.is_extended() else "")),
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
	]}


## A read-only value: label on the left, the value on the right, re-read while the panel is open.
static func value(label: String, tip: String, get_fn: Callable) -> Dictionary:
	return {"type": "custom", "label": label, "tip": tip, "wide": false, "keywords": "debug",
		"build": func():
			var l := Label.new()
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			l.add_theme_color_override("font_color", MenuTheme.ACCENT)
			l.set_meta("refresh", func(): l.text = str(get_fn.call()))
			return l}
