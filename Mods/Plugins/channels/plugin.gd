extends SDTExtension
## Channels: one shared table of who controls a part of her behaviour right now, so extensions, dialogue triggers
## and manual tools stop overwriting each other. With nobody holding a channel and both settings on (the defaults)
## the game behaves exactly as without this plugin.
##
## Channels in this version:
##   gaze  - where she looks. The holder's target replaces every other look target (the game's own, moremoods'
##           mood looks, MoreTriggers' LOOK holds) and is aimed with the game's own Her.lookAt maths.
##   blink - her automatic blinking. While someone holds it she does not blink by herself; the holder (or anyone
##           while nobody holds it) can make her blink with blink_now().
##
## Settings: "Automatic blinking" and "Automatic look changes" switch the game's own automation off without anyone
## holding the channel.
##
## Rules:
## - Levels: MANUAL (300) > DIALOGUE (200) > MOD (100). A claim takes a channel that is free, already held by the
##   same owner, or held at a lower level. Equal level, other owner: refused (the first holder keeps it).
## - A holder loses the channel when it releases it, when its time runs out (ttl, in game ticks), when a higher
##   level takes it, when the extension with the owner's id is switched off, when a full character is loaded, or
##   when this plugin is switched off. on_lost(channel, reason) is called then.
## - Holders are never saved.
##
## Use from another extension:
##   var ch = Extensions.get_extension("channels")
##   if ch != null and ch.enabled:
##       ch.look_at(id, "his_face", ch.DIALOGUE, 90)   # 3 seconds
##       ch.claim(&"blink", id, ch.MOD)
##       ch.blink_now(id)
##       ch.release(&"blink", id)

const MANUAL := 300
const DIALOGUE := 200
const MOD := 100

const GAZE := &"gaze"
const BLINK := &"blink"
const CHANNELS: Array[StringName] = [GAZE, BLINK]

## Named look targets, resolved to Her's own points every time they are used.
const NAMED_TARGETS := {"his_face": "hisFace", "down": "eyesDown", "unfocused": "eyesUnfocused"}

## channel -> {"owner": String, "level": int, "ttl": int, "data": Dictionary, "on_lost": Callable}
var _held: Dictionary = {}
var _listeners: Array = []   # Callable(channel: StringName, old_owner: String, new_owner: String, reason: String)
var _allow_blink := false


func _init() -> void:
	title = "Channels"
	description = "Who controls her gaze and blinking right now (shared by extensions, dialogue and manual tools)."


func _setup() -> void:
	setting("auto_blink", true, {"label": "Automatic blinking",
		"desc": "Off: she does not blink by herself (blink_now() still works)."})
	setting("auto_look", true, {"label": "Automatic look changes",
		"desc": "Off: the game does not move her look target by itself (moods and dialogue still can)."})


func _enable() -> void:
	on_tick(_tick)
	# Earliest priority, so a holder wins over extensions that replace these methods (moremoods replaces lookAt).
	hook_before(&"Her.lookAt", _before_look_at, -1000)
	hook_before(&"Her.changeLookTarget", _before_change_look_target, -1000)
	hook_before(&"Her.blink", _before_blink, -1000)
	# Never written (the getter returns null); the reset runs when a full character code is loaded.
	charcode_field("sdtpChannels", func(): return null, func(_v, _l): pass, func(_l): release_all("character loaded"))


func _disable() -> void:
	release_all("plugin disabled")


# ---------------------------------------------------------------- the table

## Takes `channel` for `owner` at `level`. `ttl` > 0 releases it after that many game ticks. Returns false if a
## holder at the same or a higher level keeps it.
func claim(channel: StringName, owner: String, level: int, data: Dictionary = {}, ttl: int = -1,
		on_lost: Callable = Callable()) -> bool:
	if not channel in CHANNELS or owner == "":
		push_warning("channels: unknown channel '%s' or empty owner" % channel)
		return false
	var cur = _held.get(channel)
	if cur != null and cur["owner"] != owner and cur["level"] >= level:
		return false
	var changed: bool = cur == null or cur["owner"] != owner
	var old: String = cur["owner"] if cur != null else ""
	if cur != null and changed:
		_call_lost(cur, channel, "taken by " + owner)
	_held[channel] = {"owner": owner, "level": level, "ttl": ttl, "data": data.duplicate(), "on_lost": on_lost}
	if changed:
		_notify(channel, old, owner, "claimed")
	return true


## Gives `channel` back. Only its holder can release it.
func release(channel: StringName, owner: String) -> bool:
	var cur = _held.get(channel)
	if cur == null or cur["owner"] != owner:
		return false
	_drop(channel, "released")
	return true


## Gives back every channel `owner` holds.
func release_owner(owner: String, reason := "released") -> void:
	for channel in _held.keys():
		if _held[channel]["owner"] == owner:
			_drop(channel, reason)


func release_all(reason := "released") -> void:
	for channel in _held.keys():
		_drop(channel, reason)


## Changes the holder's data (e.g. the gaze target). Only its holder can.
func update(channel: StringName, owner: String, data: Dictionary) -> bool:
	var cur = _held.get(channel)
	if cur == null or cur["owner"] != owner:
		return false
	cur["data"].merge(data, true)
	return true


func owner_of(channel: StringName) -> String:
	var cur = _held.get(channel)
	return cur["owner"] if cur != null else ""


func level_of(channel: StringName) -> int:
	var cur = _held.get(channel)
	return cur["level"] if cur != null else 0


func is_held(channel: StringName) -> bool:
	return _held.has(channel)


## Every channel with its holder, for tools: [{channel, owner, level, ttl}].
func snapshot() -> Array:
	var out: Array = []
	for channel in CHANNELS:
		var cur = _held.get(channel)
		out.append({"channel": channel, "owner": cur["owner"] if cur != null else "",
			"level": cur["level"] if cur != null else 0, "ttl": cur["ttl"] if cur != null else -1})
	return out


## `fn(channel, old_owner, new_owner, reason)` whenever a channel changes hands ("" = nobody).
func add_listener(fn: Callable) -> void:
	if not _listeners.has(fn):
		_listeners.append(fn)


func remove_listener(fn: Callable) -> void:
	_listeners.erase(fn)


# ---------------------------------------------------------------- gaze and blink

## Takes the gaze for `owner` and points it at `target`: a point in the scene layer (like the game's own look
## targets) or one of "his_face", "down", "unfocused". Calling it again moves the target.
func look_at(owner: String, target, level := MOD, ttl := -1, on_lost: Callable = Callable()) -> bool:
	if owner_of(GAZE) == owner:
		update(GAZE, owner, {"target": target})
		if ttl != -1:
			_held[GAZE]["ttl"] = ttl
		return true
	return claim(GAZE, owner, level, {"target": target}, ttl, on_lost)


## The point the gaze holder looks at, or null when nobody holds the gaze.
func gaze_target():
	var cur = _held.get(GAZE)
	if cur == null:
		return null
	return _resolve(cur["data"].get("target"))


## Makes her blink now (without looking around). Refused while someone else holds the blink channel.
func blink_now(owner := "") -> bool:
	var her = g.her
	if her == null:
		return false
	var holder := owner_of(BLINK)
	if holder != "" and holder != owner:
		return false
	_allow_blink = true
	her.blink(false)
	_allow_blink = false
	return true


# ---------------------------------------------------------------- hooks and tick

func _before_look_at(c: Hooks.Call) -> void:
	var target = gaze_target()
	if target == null:
		return
	c.cancel()
	var her = c.obj
	her.currentLookTarget = target
	her.lookAt(target)   # the hook is inactive while its handlers run: this is the game's own lookAt


func _before_change_look_target(c: Hooks.Call) -> void:
	if is_held(GAZE) or not get_setting("auto_look"):
		c.cancel()


func _before_blink(c: Hooks.Call) -> void:
	if _allow_blink:
		return
	if is_held(BLINK) or not get_setting("auto_blink"):
		c.cancel()


func _tick() -> void:
	for channel in _held.keys():
		var cur: Dictionary = _held[channel]
		var ext: SDTExtension = Extensions.get_extension(cur["owner"])
		if ext != null and not ext.enabled:
			_drop(channel, "owner switched off")
			continue
		if cur["ttl"] > 0:
			cur["ttl"] -= 1
			if cur["ttl"] == 0:
				_drop(channel, "time ran out")


# ---------------------------------------------------------------- internals

func _resolve(target):
	if target is Vector2:
		return target
	if target is String or target is StringName:
		var field: String = NAMED_TARGETS.get(str(target), "")
		if field != "" and g.her != null:
			return g.her.get(field)
	return null


func _drop(channel: StringName, reason: String) -> void:
	var cur = _held.get(channel)
	if cur == null:
		return
	_held.erase(channel)
	_call_lost(cur, channel, reason)
	_notify(channel, cur["owner"], "", reason)


func _call_lost(cur: Dictionary, channel: StringName, reason: String) -> void:
	var fn: Callable = cur["on_lost"]
	if fn.is_valid():
		fn.call(channel, reason)


func _notify(channel: StringName, old_owner: String, new_owner: String, reason: String) -> void:
	for fn in _listeners.duplicate():
		if fn.is_valid():
			fn.call(channel, old_owner, new_owner, reason)
