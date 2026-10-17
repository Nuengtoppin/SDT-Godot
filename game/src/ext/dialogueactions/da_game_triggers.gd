extends RefCounted
## DialogueActions triggers that act on the game: sounds, her and his actions, arms, penis, cleaning, bouncing,
## tongue, auto mode, screen flashes, masturbation and the drip effect; and the game values dialogues read and
## write (da.pleasurePercentage, da.breathPercentage, ...). Port's own implementation of the documented behaviour.

const PUSSYDRIP_FRAMES := 50
const BOUNCE_POWER := 0.15
const BLOCK_VAR := "da.blockingOrgasm"

var da
var vars
var sfx_volume := 0.5
## Voice clips of DialogueActions' own SLAP / OW / AH_HARD / OH_HARD / OH_SOFT sounds: not part of the game, read
## from Mods/Dialogue/DialogueActions/<name>.mp3 (or .ogg / .wav) when the player has them.
var voice := 1
var fader: FlashSprite = null
var _fade_alpha_step := 0.02
var _fade_in := false
var _fade_out := false
var _fade_delay := -1
var _fade_last := 0
var _fade_color := "000000"
var _fade_then := Callable()
var _bgm: FlashSoundChannel = null
var _bgm_volume := 1.0
var _sfx: FlashSoundChannel = null
var _gagging := false
var _cum_boost := false
var blocking := false
# masturbation (her pleasure 0..1) and drip
var masturbating := false
var _fixing := false
var _cooldown := false
var her_pleasure := 0.0
var _mas_state := 0
var _theta := 0.0
var _drip := 0
var _dripping := false
var _her_orgasm := false
# rubbing his crotch
var _rubbing := false
var _rub_delta := 0.0


func _init(p_da) -> void:
	da = p_da
	vars = da.vars


func register() -> void:
	var t: Callable = Callable(da, "register_trigger")
	# sounds
	t.call("MOAN", 0, func(_a): _play_random(["sfxMoan1", "sfxMoanSuck1", "sfxMoanSuck2"], [0.3, 0.6]))
	t.call("GAG", 0, func(_a): _gag())
	for v in ["SLAP", "OW", "AH_HARD", "OH_HARD", "OH_SOFT"]:
		var name: String = v
		t.call(name, 0, func(_a): _voice_clip(name))
	t.call("SETVOICE", 1, func(a): _set_voice(a[0]))
	t.call("PLAY_BGM", 1, func(a): _play_bgm(a[0]))
	t.call("STOP_BGM", 0, func(_a): _stop_bgm())
	t.call("PLAY_SFX", 1, func(a): _play_sfx(a[0]))
	t.call("STOP_SFX", 0, func(_a): _stop_sfx())
	vars.register_write("da.bgm.volume", func(v): _set_bgm_volume(v))
	# her
	t.call("WAKE_UP", 0, func(_a): g.her.wakeUp())
	t.call("KNOCK_OUT", 0, func(_a): g.her.passOut())
	t.call("DEEPTHROAT", 0, func(_a): g.her.maxIntroDist = 150)
	t.call("RESET_RESIST", 0, func(_a): _reset_resist())
	t.call("RANDOMIZE_HER", 0, func(_a): g.inGameMenu.shuffle())
	t.call("MASTURBATE_ON", 0, func(_a): _masturbate_on())
	t.call("MASTURBATE_OFF", 0, func(_a): _masturbate_off())
	t.call("MASTURBATE_STOP", 0, func(_a): _masturbate_stop())
	t.call("PUSSYDRIP", 0, func(_a): _start_drip(PUSSYDRIP_FRAMES))
	t.call("PUSSYDRIP", 1, func(a): _start_drip(AS3.Number(a[0])))
	t.call("TONGUE_OUT", 0, func(_a): g.her.tongue.hangOut())
	t.call("TONGUE_IN", 0, func(_a): g.her.tongue.stopHangingOut())
	t.call("BOUNCE_TITS", 0, func(_a): _bounce(BOUNCE_POWER))
	t.call("BOUNCE_TITS", 1, func(a): _bounce(AS3.Number(a[0])))
	# him
	t.call("HIDE_HIM", 0, func(_a): _show_him(false))
	t.call("SHOW_HIM", 0, func(_a): _show_him(true))
	t.call("HIDE_HIS_ARM", 0, func(_a): if g.him.visible: g.him.armContainer.visible = false)
	t.call("SHOW_HIS_ARM", 0, func(_a): if g.him.visible: g.him.armContainer.visible = true)
	t.call("CUM", 0, func(_a): g.him.pleasure = g.him.ejacPleasure * 0.95; _cum_boost = true)
	t.call("CUM_BLOCK_ON", 0, func(_a): blocking = true)
	t.call("CUM_BLOCK_OFF", 0, func(_a): blocking = false)
	t.call("HIDE_PENIS", 0, func(_a): g.him.currentPenis._tip.x = 0; g.him.penis.visible = false)
	t.call("SHOW_PENIS", 0, func(_a): g.him.currentPenis._tip.x = -315; g.him.penis.visible = true)
	t.call("HIDE_BALLS", 0, func(_a): g.him.setBalls(0))
	t.call("SHOW_BALLS", 0, func(_a): g.him.setBalls(1))
	# arms
	t.call("ARMS_HIS_CROTCH", 0, func(_a): _arms_his_crotch())
	t.call("ARMS_CROTCH", 0, func(_a): _arms_crotch())
	t.call("RIGHT_ARM_BREAST", 0, func(_a): _arm_breast(false))
	t.call("LEFT_ARM_BREAST", 0, func(_a): _arm_breast(true))
	t.call("ARMS_BREAST", 0, func(_a): _arm_breast(true); _arm_breast(false))
	t.call("RUB_HIS_CROTCH_ON", 0, func(_a): _rub(true))
	t.call("RUB_HIS_CROTCH_OFF", 0, func(_a): _rub(false))
	t.call("FIX_ARMS", 0, func(_a): g.her.leftArmIK.reversedEnd = false; g.her.rightArmIK.reversedEnd = false; _rub(false))
	t.call("FIX_LEFT_ARM", 0, func(_a): g.her.leftArmIK.reversedEnd = false)
	t.call("FIX_RIGHT_ARM", 0, func(_a): g.her.rightArmIK.reversedEnd = false; _rub(false))
	# cleaning
	t.call("CLEAN_CUM", 0, func(_a): g.strandControl.clearCumStrands())
	t.call("CLEAN_SPIT", 0, func(_a): g.strandControl.clearSpitStrands())
	t.call("CLEAN_LIPSTICK", 0, func(_a): g.him.clearLipstick())
	t.call("CLEAN_MASCARA", 0, func(_a): g.her.clearMascara())
	t.call("CLEAN_ALL", 0, func(_a): _clean_all())
	# auto mode
	t.call("AUTO_OFF", 0, func(_a): _auto(-1))
	t.call("AUTO_NORMAL", 0, func(_a): _auto(0))
	t.call("AUTO_SOFT", 0, func(_a): _auto(1))
	t.call("AUTO_HARD", 0, func(_a): _auto(2))
	t.call("AUTO_SELF", 0, func(_a): _auto(3))
	# screen flashes
	t.call("FLASH", 1, func(a): _flash(a[0], -1, false))
	t.call("FLASH", 2, func(a): _flash(a[0], int(AS3.Number(a[1])), false))
	t.call("INSTANT_FLASH", 1, func(a): _flash(a[0], -1, true))
	t.call("INSTANT_FLASH", 2, func(a): _flash(a[0], int(AS3.Number(a[1])), true))
	t.call("END_FLASH", 0, func(_a): _end_flash())
	t.call("INSTANT_END_FLASH", 0, func(_a): _instant_end_flash())
	t.call("FLASH_CHANGE_COLOR", 1, func(a): _ensure_fader(); _fade_color = a[0]; _draw_fader())
	t.call("FADE_BACKGROUND", 1, func(a): _flash(a[0], -1, false); _fade_then = func(): da.run_code("[CHANGE_BACKGROUND]"))
	# game values
	vars.register("da.pleasurePercentage", _his_pleasure, _set_his_pleasure)
	vars.register("da.breathPercentage", func(): return 100.0 - g.currentBreathLevel / g.breathLevelMax * 100.0,
		func(v): _set_inverted_percent(v, "breath"))
	vars.register("da.oxygenPercentage", func(): return 100.0 - g.her.passOutFactor / g.her.passOutMax * 100.0,
		func(v): _set_inverted_percent(v, "oxygen"))
	vars.register("da.masturbation.herpleasure", func(): return her_pleasure * 100.0, _set_her_pleasure)
	vars.register("da.canSpeakLineTrigger", _can_speak, Callable())
	vars.register("da.her.clenchingTeeth", func(): return g.her.teethClenched, Callable())
	vars.register(BLOCK_VAR, func(): return 1 if blocking else 0, _set_block)
	vars.register("da.him.ejaculating", func(): return g.him.ejaculating, Callable())
	vars.register("da.finishes", func(): return g.him.finishes if "finishes" in g.him else 0, Callable())
	vars.register("da.mouthfull", func(): return g.her.mouthFull, Callable())


## Every tick (DialogueActions' ENTER_FRAME work): flashes, gag render, CUM boost, cum block, masturbation, drip.
func tick() -> void:
	_tick_fader()
	if _gagging:
		var neck = g.her.head.neck
		neck.swallowProgress = maxf(0.0, neck.swallowProgress - 0.08)
		if neck.swallowProgress < 0.2:
			neck.swallowProgress = 1.0
			_gagging = false
	if _rubbing:
		var c := cos(_rub_delta)
		g.her.rightArmIK.newTarget(Vector2(g.her.rightHandOnHim.x - 10 + c * 10, g.her.rightHandOnHim.y - 50 + c * 50), g.him.leftLeg, true)
		g.her.rightArmIK.setEndRotationTarget(-170, [g.him.leftLeg])
		_rub_delta += 0.05
	if g.gamePaused or not g.gameRunning:
		return
	if _cum_boost:
		if not g.him.ejaculating:
			g.him.pleasure += maxf(g.him.ejacPleasure * 0.01 / 30.0 + 0.08, 0.06)
		else:
			_cum_boost = false
	if blocking:
		g.him.maxPleasureTimer = 0
	if masturbating:
		_masturbate_tick()
	elif _fixing:
		_fix_tick()
	elif _dripping:
		_drip_tick()
	if _cooldown:
		her_pleasure = maxf(her_pleasure - 0.0005, 0.0)
		if her_pleasure == 0.0:
			_cooldown = false


# ---------------------------------------------------------------- sounds

func _play(sound: String, volume: float) -> void:
	var s := FlashSound.named(sound)
	if s != null:
		s.play(0, 0, FlashSoundTransform.new(volume))


## First sound up to the first threshold, the second up to the next, else the last (DialogueActions' odds).
func _play_random(sounds: Array, thresholds: Array) -> void:
	var r := randf()
	var i := 0
	while i < thresholds.size() and r > thresholds[i]:
		i += 1
	_play(sounds[i], sfx_volume)


func _gag() -> void:
	_play_random(["sfxWretch1", "sfxWretch2", "sfxWretch3"], [0.3, 0.6])
	if not _gagging:
		_gagging = true
		g.her.head.neck.swallow()
		g.her.head.neck.swallowProgress = 0.94


const VOICE_CLIPS := {"SLAP": ["Slap01"], "OW": ["Ow01", "Ow02"], "AH_HARD": ["AhHard01", "AhHard02", "AhHard03", "AhHard04", "AhHard05"],
	"OH_HARD": ["OhHard01", "OhHard02", "OhHard03", "OhHard04", "OhHard05"],
	"OH_SOFT": ["OhSoft01", "OhSoft02", "OhSoft03", "OhSoft04", "OhSoft05"]}


func _voice_clip(trigger: String) -> void:
	var clips: Array = VOICE_CLIPS[trigger]
	var name: String = clips[int(randf() * clips.size()) % clips.size()]
	if voice == 2 and trigger != "SLAP":
		name = (clips[0] if trigger == "OW" else name) + "_2"
	var dir := Flash.mods_dir("Dialogue").path_join("DialogueActions")
	for ext in ["mp3", "ogg", "wav"]:
		var p := dir.path_join(name + "." + ext)
		if FileAccess.file_exists(p):
			var s := FlashSound.from_file(p)
			if s != null:
				s.play()
			return
	vars.dlog("sound %s missing: put DialogueActions' voice clips in %s" % [name, dir])


func _set_voice(v: String) -> void:
	var n := AS3.Number(v)
	if n == 1 or n == 2:
		voice = int(n)
	else:
		vars.dlog("invalid voice id " + v)


func _file(name: String) -> String:
	var p := Flash.resolve_content_path(name)
	if FileAccess.file_exists(p):
		return p
	for sub in ["", "Dialogue", "Characters"]:
		var q := Flash.mods_dir(sub).path_join(name)
		if FileAccess.file_exists(q):
			return q
	return ""


func _play_bgm(name: String) -> void:
	_stop_bgm()
	var p := _file(name)
	if p == "":
		vars.dlog("BGM not found: " + name)
		return
	var s := FlashSound.from_file(p)
	if s != null:
		_bgm = s.play(0, 999999, FlashSoundTransform.new(_bgm_volume))


func _stop_bgm() -> void:
	if _bgm != null:
		_bgm.stop()
		_bgm = null


func _set_bgm_volume(v) -> void:
	_bgm_volume = clampf(AS3.Number(v), 0.0, 1.0)
	if _bgm != null:
		_bgm.soundTransform = FlashSoundTransform.new(_bgm_volume)


func _play_sfx(name: String) -> void:
	_stop_sfx()
	var p := _file(name)
	if p == "":
		vars.dlog("SFX not found: " + name)
		return
	var s := FlashSound.from_file(p)
	if s != null:
		_sfx = s.play()


func _stop_sfx() -> void:
	if _sfx != null:
		_sfx.stop()
		_sfx = null


# ---------------------------------------------------------------- her and him

func _reset_resist() -> void:
	var her = g.her
	var menu = g.inGameMenu
	her.setIntroResistance(menu.costumeMenu.resistanceSlider.currentValue(100))
	her.setThroatResistance(menu.costumeMenu.throatResistanceSlider.currentValue(100))
	her.maxIntroDist = her.introStartDist
	her.firstDT = true
	her.intro = true
	g.him.deepestPos = 0


func _bounce(power: float) -> void:
	if is_nan(power):
		return
	g.her.leftBreastController.accelerate(power)
	g.her.rightBreastController.accelerate(power)


func _show_him(on: bool) -> void:
	g.him.visible = on
	g.him.armContainer.visible = on
	g.him.overLayer.visible = on


func _clean_all() -> void:
	g.strandControl.clearCumStrands()
	g.strandControl.clearSpitStrands()
	g.him.clearLipstick()
	g.her.clearMascara()


func _auto(mode: int) -> void:
	if mode < 0:
		g.autoModeOn = false
	else:
		g.setAuto(mode)
		g.autoModeOn = true
	g.automaticControl.startAuto(g.currentPos)
	g.inGameMenu.updateAutoList()
	g.inGameMenu.setCBAuto()


func _arms_his_crotch() -> void:
	var her = g.her
	her.setRightArmPosition(2)
	her.setLeftArmPosition(2)
	g.inGameMenu.updateArmsList()
	her.rightArmIK.newTarget(Vector2(her.rightHandOnHim.x - 20, her.rightHandOnHim.y - 100), g.him.leftLeg, true)
	her.leftArmIK.newTarget(Vector2(her.leftHandOnHim.x - 20, her.leftHandOnHim.y - 100), g.him.rightLeg, true)
	her.rightArmIK.setEndRotationTarget(-170, [g.him.leftLeg])
	her.leftArmIK.setEndRotationTarget(-185, [g.him.rightLeg])
	her.rightArmIK.reversedEnd = false
	her.leftArmIK.reversedEnd = false


func _arms_crotch() -> void:
	var her = g.her
	her.setArmPosition(1)
	her.setArmPosition(-1)
	her.leftArmIK.newTarget(Vector2(-100, 300), her.torso.back, true)
	her.leftArmIK.setEndRotationTarget(50, [her.torso.back, her.torso])


## A hand cupping her breast (DialogueActions' targets on the nipple of each breast).
func _arm_breast(left: bool) -> void:
	var her = g.her
	var size: float = g.characterControl.breastSize
	var target := Vector2(10 - maxf(50, size / 2), 95 - size / 8)
	var angle := -255 + minf(120, size * 0.85)
	if left:
		her.setLeftArmPosition(1, true)
		var b = her.torsoBack.leftBreast
		her.leftArmIK.newTarget(target, b.nipple, true)
		her.leftArmIK.reversedEnd = true
		her.leftArmIK.setEndRotationTarget(angle, [b.nipple, b, her.torsoBack, her])
	else:
		her.setRightArmPosition(1, true)
		var b = her.torso.midLayer.rightBreast
		her.rightArmIK.newTarget(target, b.nipple, true)
		her.rightArmIK.reversedEnd = true
		her.rightArmIK.setEndRotationTarget(angle, [b.nipple, b, her.torso.midLayer, her.torso, her])


func _rub(on: bool) -> void:
	if on:
		_rubbing = true
		g.her.setRightArmPosition(2)
		g.her.rightArmIK.reversedEnd = false
		g.her.rightArmIK.setEndRotationTarget(-170, [g.him.leftLeg])
		g.inGameMenu.updateArmsList()
	elif _rubbing:
		_rubbing = false
		g.her.setRightArmPosition(2)


# ---------------------------------------------------------------- masturbation and drip

func _masturbate_on() -> void:
	if not masturbating:
		g.her.setLeftArmPosition(1)
		masturbating = true
		_fixing = false


func _masturbate_off() -> void:
	if masturbating:
		masturbating = false
		_fixing = true


func _masturbate_stop() -> void:
	_masturbate_off()
	_fixing = false
	g.her.setLeftArmPosition(g.her.currentLeftArmPosition)
	g.her.updateArms()
	_cooldown = true


func _hand_target() -> Vector2:
	return Vector2(-25 + cos(_theta) * 2, 240 + sin(_theta) * 12)


func _masturbate_tick() -> void:
	var her = g.her
	_drip_tick()
	_cooldown = false
	if her.getChildAt(1) != her.leftArmContainer:
		her.addChildAt(her.leftArmContainer, 1)
	her.leftArmIK.newTarget(_hand_target(), her.torso.back, true)
	her.leftArmIK.setEndRotationTarget(45, [her.torso.back, her.torso])
	her_pleasure += 0.0005 + her.vigour / 1000000.0
	if _mas_state == 0 and not _dripping:
		_theta = fmod(_theta + maxf(her_pleasure, 0.2) + her.vigour / 3000.0, 360.0)
		if her_pleasure >= 1:
			her_pleasure = 0
			_mas_state = 1
	elif _mas_state == 1:
		_her_orgasm = true
		_start_drip(PUSSYDRIP_FRAMES)
		_mas_state = 0


## After MASTURBATE_OFF her hand slows down until her pleasure has dropped, then the arm goes back.
func _fix_tick() -> void:
	var her = g.her
	_drip_tick()
	if her_pleasure > 0.2:
		her_pleasure -= 0.0005
		her.leftArmIK.newTarget(_hand_target(), her.torso.back, true)
		_theta -= maxf(her_pleasure, 0.2) + her.vigour / 3000.0
		_theta = maxf(_theta + 360, 360)
	else:
		her_pleasure = 0
		_mas_state = 0
		_masturbate_stop()


func _start_drip(frames: float) -> void:
	if is_nan(frames):
		return
	var her = g.her
	her.closeEye()
	_dripping = true
	_drip += int(frames)
	if not her.speaking and not her.mouthFull and not her.passedOut and not her.swallowing and _her_orgasm:
		_play("sfxMoan2", sfx_volume)


func _drip_tick() -> void:
	if not _dripping:
		return
	var her = g.her
	if _drip > 0:
		_drip -= 1
		var backside = her.torso.get("backside")
		var from: Vector2 = backside.localToGlobal(Vector2(30, 240)) if backside != null else her.torso.localToGlobal(Vector2(30, 240))
		var d := Droplet.new(g.sceneLayer.globalToLocal(from), Vector2(randf() * 18 - 5, randf() * 25), randf() + 0.1, 0.01)
		d.padding = 2000
		g.strandBackLayer.addChild(d)
	else:
		her.openEye()
		_dripping = false
		if _her_orgasm:
			her.setSpeaking(false)
			g.dialogueControl.buildState("orgasm", 130)
			_her_orgasm = false


# ---------------------------------------------------------------- screen flashes (a coloured layer over the scene)

func _ensure_fader() -> void:
	if fader == null or not is_instance_valid(fader):
		fader = FlashSprite.new()
		fader.mouseEnabled = false
		fader.mouseChildren = false
		fader.alpha = 0
		var c: FlashSprite = g.container
		c.addChildAt(fader, c.getChildIndex(g.dialogueControl))


func _draw_fader() -> void:
	fader.graphics.clear()
	fader.graphics.beginFill(("0x" + _fade_color).hex_to_int() if _fade_color.is_valid_hex_number() else 0, 1.0)
	fader.graphics.drawRect(0, 0, 700, 600)
	fader.graphics.endFill()


## Fades the screen to a colour; `delay` ms after it is fully covered it fades back (-1: stays until END_FLASH).
func _flash(hex: String, delay: int, instant: bool) -> void:
	_ensure_fader()
	_fade_color = hex
	_fade_delay = delay
	_draw_fader()
	_fade_in = true
	_fade_out = false
	fader.alpha = 1.0 if instant else 0.0
	_fade_last = Flash.getTimer()


func _end_flash() -> void:
	_ensure_fader()
	_fade_delay = 0
	if _fade_then.is_valid():
		var f := _fade_then
		_fade_then = Callable()
		f.call()
	_fade_in = false
	_fade_out = true


func _instant_end_flash() -> void:
	_ensure_fader()
	_fade_in = false
	_fade_out = false
	fader.alpha = 0
	fader.graphics.clear()


func _tick_fader() -> void:
	if fader == null or not is_instance_valid(fader):
		return
	if _fade_in:
		fader.alpha = minf(fader.alpha + _fade_alpha_step, 1.0)
		if fader.alpha >= 0.99 and _fade_delay != -1:
			var now := Flash.getTimer()
			_fade_delay = maxi(0, _fade_delay - (now - _fade_last))
			_fade_last = now
			if _fade_delay == 0:
				_end_flash()
		else:
			_fade_last = Flash.getTimer()
	elif _fade_out:
		fader.alpha = maxf(fader.alpha - _fade_alpha_step, 0.0)
		if fader.alpha <= 0.01:
			_instant_end_flash()


func remove() -> void:
	_stop_bgm()
	_stop_sfx()
	if fader != null and is_instance_valid(fader) and fader._flash_parent != null:
		fader._flash_parent.removeChild(fader)
	fader = null


# ---------------------------------------------------------------- game values

## His pleasure in percent (as the Loader's pleasure counter shows it).
func _his_pleasure() -> float:
	var p := int(g.him.pleasure / (g.him.ejacPleasure / 0.97) * 10000) / 100.0
	if p >= 97:
		p += g.him.maxPleasureTimer / 20.0
	return minf(100.0, p)


## "+n" / "-n" change the current value, a plain number sets it.
static func _relative(current: float, v) -> float:
	if v is String:
		if AS3.isNaN(v):
			return NAN
		if v.begins_with("+") or v.begins_with("-"):
			return current + AS3.Number(v)
		return AS3.Number(v)
	return AS3.Number(v)


func _set_his_pleasure(v) -> void:
	var n := _relative(_his_pleasure(), v)
	if is_nan(n):
		vars.dlog("da.pleasurePercentage: not a number: " + str(v))
		return
	g.him.pleasure = g.him.ejacPleasure / 97.0 * clampf(n, 0.0, 100.0)


## da.breathPercentage / da.oxygenPercentage: 100 = full breath; the game counts the other way round.
func _set_inverted_percent(v, which: String) -> void:
	var current: float = (100.0 - g.currentBreathLevel / g.breathLevelMax * 100.0) if which == "breath" else (100.0 - g.her.passOutFactor / g.her.passOutMax * 100.0)
	var n: float
	if v is String and not AS3.isNaN(v):
		n = current - AS3.Number(v) if (v.begins_with("+") or v.begins_with("-")) else AS3.Number(v)
	elif v is int or v is float:
		n = 100.0 - v
	else:
		vars.dlog("da.%sPercentage: not a number: %s" % [which, v])
		return
	n = clampf(n, 0.0, 100.0)
	if which == "breath":
		g.currentBreathLevel = g.breathLevelMax / 100.0 * n
	else:
		g.her.passOutFactor = g.her.passOutMax / 100.0 * n


func _set_her_pleasure(v) -> void:
	var n: float
	if v is String and not AS3.isNaN(v):
		n = her_pleasure + AS3.Number(v) / 100.0 if (v.begins_with("+") or v.begins_with("-")) else AS3.Number(v) / 100.0
	elif v is int or v is float:
		n = v / 100.0
	else:
		vars.dlog("da.masturbation.herpleasure: not a number: " + str(v))
		return
	her_pleasure = clampf(n, 0.0, 1.0)


func _can_speak() -> int:
	var her = g.her
	return 1 if not her.gagged and not her.mouthFull and not her.passedOut and not her.swallowing else 0


func _set_block(v) -> void:
	var n := AS3.Number(v)
	if n == 1:
		blocking = true
	elif n == 0:
		blocking = false
