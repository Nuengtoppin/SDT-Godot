extends SDTExtension
## Built-in reimplementation of the Loader mod monitordialog (sby, v3): a panel showing how the dialogue picks her
## lines, for writing and testing dialogues. Line types with build (or a build delay) come first, sorted by priority
## and build; types that had some in the last ~10 seconds follow below a gap.
##   q: the queued line   t: her next-line timer (she tries to speak at 20)   l: the line type being said
##   p: priority   db: build delay   bl: build level (she can say it above 20)   mb: max build   rs: reduce speed

const KEEP_TICKS := 300

var panel: MonitorPanel = null
var _seen := {}   # line type -> ticks it stays listed after its build ran out


func _init() -> void:
	id = "monitordialog"
	title = "monitordialog"
	description = "A panel showing the dialogue's line types, their build, priority and timers (for dialogue writers)."
	default_enabled = true


func _setup() -> void:
	setting("visible", false, {"label": "Show the dialogue monitor"})


func _enable() -> void:
	on_late_tick(_tick)
	menu_control("dialogue", "Dialogue", MenuSchema.setting_control(self, "visible",
		{"tip": "A panel with the dialogue's line types, their build and priority, for writing dialogues."}))


func _disable() -> void:
	_remove()


func _setting_changed(key: String, value) -> void:
	if key == "visible" and not value:
		_remove()


func _remove() -> void:
	if panel != null and is_instance_valid(panel) and panel._flash_parent != null:
		panel._flash_parent.removeChild(panel)
	panel = null


class MonitorPanel:
	extends FlashSprite
	var left := ""
	var right := ""

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		for col in [[Vector2(350, 50), 120.0, left], [Vector2(470, 50), 500.0, right]]:
			draw_rect(Rect2(col[0], Vector2(col[1], 300)), Color(1, 1, 1, 0.6))
			var y: float = col[0].y + 11
			for line in str(col[2]).split("\n"):
				if y > col[0].y + 298:
					break
				draw_string(font, Vector2(col[0].x + 2, y), line, HORIZONTAL_ALIGNMENT_LEFT, col[1] - 4, 10,
					Color(0, 0, 0, 0.6))
				y += 12


func _tick() -> void:
	if not get_setting("visible") or g.dialogueControl == null:
		return
	if panel == null or not is_instance_valid(panel):
		panel = MonitorPanel.new()
		panel.mouseEnabled = false
		panel.mouseChildren = false
	g.container.addChild(panel)   # (again) on top
	var dc = g.dialogueControl
	var left: String = "q:" + (dc.queuedPhrase if _seen.get("queued", 0) > 0 else "") + "\n"
	var right: String = "t:%d    l:%s\n" % [int(dc.nextLineTimer), dc.sayingState]
	var list: Array = []
	for k in dc.states:
		list.append([k, dc.states[k]])
	list.sort_custom(func(a, b): return _order(a[1], b[1]) > 0)
	var gap := true
	for e in list:
		var s: DialogueState = e[1]
		var active: bool = s._noBuildDelay != 0 or s._buildLevel != 0
		if active:
			_seen[e[0]] = KEEP_TICKS
		elif _seen.get(e[0], 0) > 0:
			_seen[e[0]] -= 1
		if not active and gap:
			left += "\n"
			right += "\n"
			gap = false
		if active or _seen.get(e[0], 0) > 0:
			left += str(e[0]) + "\n"
			right += "p:%d  db:%03d  bl:%03d  mb:%03d  rs:%s\n" % [s._priority, int(s._noBuildDelay),
				int(s._buildLevel), int(s._maxBuild), str(s._defaultReduceSpeed)]
	if left != panel.left or right != panel.right:
		panel.left = left
		panel.right = right
		panel.queue_redraw()


## Line types with build first (by priority, then build), then the others.
static func _order(a: DialogueState, b: DialogueState) -> int:
	var pa: int = -5 if a._buildLevel == 0 else a._priority
	var pb: int = -5 if b._buildLevel == 0 else b._priority
	if pa != pb:
		return pa - pb
	if a._buildLevel != b._buildLevel:
		return 1 if a._buildLevel > b._buildLevel else -1
	return a._priority - b._priority
