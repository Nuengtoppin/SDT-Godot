extends SDTExtension
## Built-in reimplementation of the Loader mod menualphatoggle (sby, V2): a see-through menu, to watch her while
## changing things. The classic menu gets the mod's button at its top left (the menu at 80%, its background at 25%,
## the mod's settings); the new menu has the option in Settings > Menu (its panel's background at 25%; its option
## boxes and text stay solid, readable over the game). Off by default; unlike the mod's button it is remembered.

const MENU_ALPHA := 0.8
const BACKGROUND_ALPHA := 0.25

var _button: ExtButton = null


func _init() -> void:
	id = "menualphatoggle"
	title = "menualphatoggle"
	description = "menualphatoggle (sby): a see-through menu (Settings > Menu, or the button at the classic menu's top left)."
	default_enabled = true


func _setup() -> void:
	setting("see_through", false, {"label": "See-through menu", "desc": "The menu lets you see the game behind it."})


func _enable() -> void:
	menu_control("settings", "Menu", MenuSchema.setting_control(self, "see_through"))
	_button = ExtButton.new(20, 20, "α", 14)
	_button.x = 5
	_button.y = -223
	_button.on_click = func(): set_setting("see_through", not get_setting("see_through"))
	g.inGameMenu.addChild(_button)
	Extensions._add_widget(self, _button)
	_apply(get_setting("see_through"))


func _disable() -> void:
	_apply(false)
	_button = null


func _setting_changed(_key: String, _value) -> void:
	_apply(get_setting("see_through"))


func _apply(on: bool) -> void:
	var igm = g.inGameMenu
	if igm != null:
		igm.alpha = MENU_ALPHA if on else 1.0
		igm.getChildAt(1).alpha = BACKGROUND_ALPHA if on else 1.0   # the menu's background ("instance585")
	if _button != null:
		_button.set_color(0x00FF00 if on else 0xFFFFFF)
	var m = SDTMenu.instance
	if m != null:
		m.set_see_through(on, BACKGROUND_ALPHA)
