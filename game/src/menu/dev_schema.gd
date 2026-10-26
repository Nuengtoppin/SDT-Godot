class_name DevSchema
extends RefCounted
## Port addition: the developer panel's sections (DevMenu), in the menu's spec format (see MenuWidgets). Extensions can
## add controls here too: SDTMenu.add_control() with "section" set to one of these ids.
##   dev_tools   workbench for experimental tools (empty for now)
##   dev_eyes, dev_mouth, dev_fluids, dev_state, dev_him   her and his behaviours (DevBehaviour): call, automation
##   dev_body    debug layers drawn over body parts (DevBodyOverlay): the neck and her throat's rings (ThroatRings)
##   dev_info    live values: her state by the same groups, engine, extensions
##   dev_panel   the panel's own settings, automation as a whole


static func sections() -> Array:
	return [_tools()] + DevBehaviour.sections() + [_body(), _info(), _panel()]


static func _tools() -> Dictionary:
	return {"id": "dev_tools", "name": "Tools", "groups": [
		{"title": "Workbench", "controls": [
			MenuSchema.note("Experimental and diagnostic tools appear here."),
		]},
	]}


static func _body() -> Dictionary:
	var neck := func(): return g.her.head.neck
	return {"id": "dev_body", "name": "Body", "groups": [
		{"title": "Debug layers", "controls": [
			MenuSchema.note("Drawn over the game, read only: straight lines through the points (the game draws curves through them). The same layers for every body part; legs and breasts come next."),
			{"type": "slider", "label": "Line width", "tip": "Width of the outlines and axes, in screen pixels.", "min": 0.5, "max": 3.0, "step": 0.25,
				"get": func(): return DevBodyOverlay.line_width, "set": func(v: float): DevBodyOverlay.line_width = v,
				"format": func(v): return "%.2f" % v},
			{"type": "slider", "label": "Point size", "tip": "Radius of the control points, in screen pixels.", "min": 0.5, "max": 4.0, "step": 0.25,
				"get": func(): return DevBodyOverlay.point_radius, "set": func(v: float): DevBodyOverlay.point_radius = v,
				"format": func(v): return "%.2f" % v},
			MenuSchema.actions("", "", [["Hide all layers", func(): DevBodyOverlay.clear(), "Switch every debug layer off."]]),
		]},
		{"title": "Neck", "controls": [
			_layer("neck", "base", "Source outline", "Cyan: the neck's outline from the symbol, respaced, before the throat bulge and swallow wave."),
			_layer("neck", "rendered", "Rendered outline", "Pink: the outline drawn this tick (throat bulge, swallow wave). Blue: the highlight."),
			_layer("neck", "points", "Control points", "The outline points (cyan) and highlight points (blue) the neck is drawn through."),
			_layer("neck", "axis", "Neck to torso axis", "Yellow: from the neck's origin to her torso's."),
			value("Points", "Outline points (the front of the neck is resampled into 30) / highlight points.",
				func(): return "%d / %d" % [neck.call().neckPoints.size(), neck.call().highlightPoints.size()]),
			value("Throat depth", "How deep he is, as the neck's bulge sees it (0 at her lips, 1 = 400 deep; below 0: outside her mouth).",
				func(): return "%.2f" % neck.call().lastDepth),
			value("Swallow wave", "Where the swallow bulge is along the neck while she swallows.",
				func(): return "%.0f%%" % (neck.call().swallowProgress * 100.0) if neck.call().swallowing else "no"),
			value("Neck angle", "The neck's rotation.", func(): return "%.1f°" % wrapf(neck.call().rotation_degrees, -180.0, 180.0)),
		]},
		_throat(),
	]}


## Her throat's rings (ThroatRings): stage 1, worked out but changing nothing in the game yet.
static func _throat() -> Dictionary:
	var e: Dictionary = ThroatRings.entrance
	var c: Dictionary = ThroatRings.collar
	var stretch_ext := func():
		var x = Extensions.get_extension("throatresiststretch")
		return "acting" if x != null and x.enabled and x.get_setting("on") else "read only"
	return {"title": "Throat rings", "controls": [
		MenuSchema.note("Read only for now: the rings are worked out from what he does, but change nothing in the game yet. Depth: 0 at her lips, 1 = 400 deep."),
		_layer("throat", "zones", "Rings on the neck", "A line across the neck at each ring's top and bottom edge: green (not stretched) to red (fully stretched), thicker while he presses on it, grey once it would have snapped. White dot: his tip; blue dot: the swallow wave."),
		value("Tip / push", "How deep his tip is, and how hard he pushes in this tick (0..1, from his movement).",
			func(): return "%.2f / %.2f" % [ThroatRings.tip, ThroatRings.push]),
		value("Entrance edges", "The throat entrance ring: where the game's resistance at the way into her throat starts and ends. Its tightness is her throat resistance slider.",
			func(): return _edges(e)),
		value("Entrance stretch", "How far the ring has stretched (0..1) / how hard he presses on it / how much it would hold him back.",
			func(): return _ring_state(e)),
		value("Entrance ring", "Acting: Behaviour > Resistance > Throat loosens is on, so its stretch lowers the entrance's resistance and keeps her neck drawn stretched. Read only: worked out for this tab only.",
			stretch_ext),
		value("Collar edges", "The collar ring, from the collar's picture on her neck (its band, at most 70 px), plus the adjustments below; the adjustments and the material are kept for each collar.",
			func(): return "%s: %s" % [ThroatRings.collar_name, _edges(c)] if c["on"] else "no collar"),
		value("Collar stretch", "How far the collar has stretched / how hard he presses on it / how much it would hold him back.",
			func(): return _ring_state(c) if c["on"] else "—"),
		value("Collar durability", "What is left before it would snap; it wears while he presses on it, more when it is stretched, and recovers at rest.",
			func(): return "doesn't break" if not is_finite(c["max_durability"]) else ("would have snapped" if c["snapped"] else "%.0f / %.0f" % [c["durability"], c["max_durability"]])),
		MenuSchema.choice("Collar material", "Sets tightness, stiffness and durability together. Band: tight-ish, stretches, breaks easily. Leather: holds, breaks hard. Metal: does not give and does not break.",
			ThroatRings.MATERIALS.keys(), func(): return ThroatRings.collar_material, func(v): ThroatRings.set_collar_material(v)),
		{"type": "slider", "label": "Collar tightness", "tip": "How hard the collar holds (the material sets it; change it here).", "min": 0.0, "max": 1.0, "step": 0.05,
			"get": func(): return c["tight"], "set": func(v: float): c["tight"] = v, "format": func(v): return "%.2f" % v},
		{"type": "slider", "label": "Collar top edge", "tip": "Moves the ring's top edge from where the collar's picture puts it (depth units).", "min": -0.15, "max": 0.15, "step": 0.005,
			"get": func(): return ThroatRings.collar_top_adjust, "set": func(v: float): ThroatRings.adjust_collar(v, ThroatRings.collar_bottom_adjust),
			"format": func(v): return "%+.3f" % v},
		{"type": "slider", "label": "Collar bottom edge", "tip": "Moves the ring's bottom edge: narrow it for a thin band so the ring does not cover half of a wide collar's picture.", "min": -0.15, "max": 0.15, "step": 0.005,
			"get": func(): return ThroatRings.collar_bottom_adjust, "set": func(v: float): ThroatRings.adjust_collar(ThroatRings.collar_top_adjust, v),
			"format": func(v): return "%+.3f" % v},
		_vp("Neck.throatBulge", "How much her throat bulges (her throat bulge setting, then what extensions add)."),
		_vp("Neck.bulgeCap", "The most the bulge pushes her neck out, in pixels (the game's: 35)."),
		_vp("Her.resistance", "What holds him back as he pushes in (the game's throat resistance zones)."),
		_vp("Her.pushBack", "What pushes her head back off him each tick (0 in the game)."),
		_vp("Neck.depth", "How deep the throat bulge sits (his depth / 400; a loosened throat keeps it deeper)."),
		MenuSchema.actions("", "", [
			["Reset stretch", func(): ThroatRings.reset_stretch(), "Every ring back to not stretched."],
			["Repair", func(): ThroatRings.repair(), "Durability back to full; a snapped ring holds again."]]),
	]}


## A value point's row: the game's number -> what the game uses, or that nothing changes it.
static func _vp(name: String, tip: String) -> Dictionary:
	return value(name, "Value point: " + tip, func():
		var sn := StringName(name)
		if not ValuePoints.has(sn) and not ValuePoints._points.has(sn):
			return "game's"
		var l = ValuePoints.last.get(sn)
		return "set, not asked yet" if l == null else "%.3f → %.3f" % [l[0], l[1]])


static func _edges(r: Dictionary) -> String:
	return "%.2f – %.2f" % [r["top"], r["bottom"]]


static func _ring_state(r: Dictionary) -> String:
	return "%.2f / %.2f / %.2f" % [r["stretch"], r["pressure"], r["hold"]]


static func _layer(part: String, layer: String, label: String, tip: String) -> Dictionary:
	return MenuSchema.toggle(label, tip, func(): return DevBodyOverlay.is_on(part, layer),
		func(on: bool): DevBodyOverlay.set_on(part, layer, on), {"keywords": "debug overlay " + part})


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
