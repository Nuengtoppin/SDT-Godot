class_name FlashEvent
extends RefCounted
## flash.events.Event plus the mouse / keyboard / timer fields used by the game.

const ENTER_FRAME := "enterFrame"
const ADDED := "added"
const ADDED_TO_STAGE := "addedToStage"
const REMOVED := "removed"
const REMOVED_FROM_STAGE := "removedFromStage"
const COMPLETE := "complete"
const CHANGE := "change"
const SELECT := "select"
const CANCEL := "cancel"
const INIT := "init"
const MOUSE_LEAVE := "mouseLeave"
const SOUND_COMPLETE := "soundComplete"
const RESIZE := "resize"

const CLICK := "click"
const DOUBLE_CLICK := "doubleClick"
const MOUSE_DOWN := "mouseDown"
const MOUSE_UP := "mouseUp"
const MOUSE_MOVE := "mouseMove"
const MOUSE_OVER := "mouseOver"
const MOUSE_OUT := "mouseOut"
const ROLL_OVER := "rollOver"
const ROLL_OUT := "rollOut"
const MOUSE_WHEEL := "mouseWheel"

const KEY_DOWN := "keyDown"
const KEY_UP := "keyUp"
const FOCUS_IN := "focusIn"
const FOCUS_OUT := "focusOut"

const TIMER := "timer"
const TIMER_COMPLETE := "timerComplete"
const IO_ERROR := "ioError"

const CAPTURING_PHASE := 1
const AT_TARGET := 2
const BUBBLING_PHASE := 3

var type: String
var bubbles: bool
var cancelable: bool
var target: Object = null
var current_target: Object = null
var event_phase: int = AT_TARGET
var default_prevented := false
var _stop := false
var _stop_immediate := false

# Mouse
var stage_x: float = 0.0
var stage_y: float = 0.0
var local_x: float = 0.0
var local_y: float = 0.0
var delta: int = 0
var related_object: Object = null
var button_down := false
# Keyboard (key_code uses Flash/Windows virtual key codes, as the original game does)
var key_code: int = 0
var char_code: int = 0
# Modifiers
var shift_key := false
var ctrl_key := false
var alt_key := false
# Generic payload (e.g. loaded data)
var data = null


func _init(p_type: String, p_bubbles: bool = false, p_cancelable: bool = false) -> void:
	type = p_type
	bubbles = p_bubbles
	cancelable = p_cancelable


func stop_propagation() -> void:
	_stop = true


func stop_immediate_propagation() -> void:
	_stop = true
	_stop_immediate = true


func prevent_default() -> void:
	if cancelable:
		default_prevented = true


static func mouse(p_type: String, bubbles_: bool = true) -> FlashEvent:
	var e := FlashEvent.new(p_type, bubbles_)
	var p := Flash.mouse_position()
	e.stage_x = p.x
	e.stage_y = p.y
	e.shift_key = Input.is_key_pressed(KEY_SHIFT)
	e.ctrl_key = Input.is_key_pressed(KEY_CTRL)
	e.alt_key = Input.is_key_pressed(KEY_ALT)
	e.button_down = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	return e
