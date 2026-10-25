class_name Tears
extends FlashMovieClip
## Port of obj.her.Tears: tear spots that swell and run down the cheek, leaving fading trails, and mascara that
## runs with them and can be smudged. Painted into small bitmaps like the original.

var tearArea := Rect2i(0, 0, 120, 150)
var lowerEyelidArea := Rect2i(0, 0, 50, 20)
var tearsData: FlashBitmapData
var tearsLayer: FlashBitmap
var mascaraData: FlashBitmapData
var mascaraLayer: FlashBitmap
var tearSpotsLayer: FlashSprite
var lowerEyelidData: FlashBitmapData
var lowerEyelidLayer: FlashBitmap
var lowerEyelidClear := true
var oldDataBuffer: FlashBitmapData
var alphaBlendMult: int = 255
var rgbBlendMult: int = 256
var tearList: Array = []
var tearSpotList: Array = []
var tearGraphic: FlashDisplayObject
var mascaraGraphic: FlashDisplayObject
var maxTears: int = 8
var speed: float = 0.25
var eyeA := Vector2(33, 1)
var eyeB := Vector2(40, 5)
var eyeC := Vector2(75, 4)
var eyeABVec: Vector2
var eyeBCVec: Vector2
var mascaraFadeTick: int = 0
var mascaraFadeRate: int = 20
var mascaraRGB: Dictionary = {"r": 0, "g": 0, "b": 0, "a": 1}
var lastSmudgeTarget = null
var lastSmudge := Vector2(-1, -1)
var currentSmudge := Vector2(-1, -1)
var smudgeVec := Vector2()
var smudgeSteps: int = 0
var smudgeToggle := false
var smudgeBrush: Array = []
## Ticks since tears last painted something; once every pixel has faded the per-tick fade is skipped.
var _tearsIdle: int = 1000


func _init() -> void:
	super()
	tearsData = FlashBitmapData.new(tearArea.size.x, tearArea.size.y, true, 0)
	oldDataBuffer = FlashBitmapData.new(tearArea.size.x, tearArea.size.y, true, 0)
	tearsLayer = FlashBitmap.new(tearsData, "auto", true)
	tearsLayer.y = -tearArea.size.y
	tearsLayer.alpha = 0.3
	addChild(tearsLayer)
	mascaraData = FlashBitmapData.new(tearArea.size.x, tearArea.size.y, true, 0)
	mascaraLayer = FlashBitmap.new(mascaraData, "auto", true)
	mascaraLayer.y = -tearArea.size.y
	addChild(mascaraLayer)
	tearSpotsLayer = FlashSprite.new()
	tearSpotsLayer.y = -tearArea.size.y
	addChild(tearSpotsLayer)
	tearGraphic = Flash.create("Tear")
	mascaraGraphic = Flash.create("MascaraSpot")
	eyeABVec = eyeB - eyeA
	eyeBCVec = eyeC - eyeB
	for i in 2:
		for j in range(-25, 26):
			if (i + j) % 2:
				smudgeBrush.append(Vector2i(i, j))


func addLowerEyelidMascaraLayer(c: FlashSprite) -> void:
	lowerEyelidData = FlashBitmapData.new(lowerEyelidArea.size.x, lowerEyelidArea.size.y, true, 0)
	lowerEyelidLayer = FlashBitmap.new(lowerEyelidData, "auto", true)
	c.addChild(lowerEyelidLayer)


func setMascaraRGB(c: Dictionary) -> void:
	mascaraRGB = c


func clearMascara() -> void:
	mascaraData.fillRect(tearArea, 0)
	tearsData.fillRect(tearArea, 0)
	lowerEyelidData.fillRect(lowerEyelidArea, 0)
	tearList.clear()
	_refresh()


func clearTearSpots() -> void:
	for s in tearSpotList:
		tearSpotsLayer.removeChild(s)
		s.queue_free()
	tearSpotList.clear()


func drawLowerEyelidMascara() -> void:
	lowerEyelidData.fillRect(lowerEyelidArea, 0)
	lowerEyelidData.draw_bitmap(mascaraData, Vector2i(-33, -3), Rect2i(0, 0, 50, 20))
	lowerEyelidClear = false
	lowerEyelidLayer.refresh()
	if Hooks.has(&"Tears.drawLowerEyelidMascara"):   # HOOK
		Hooks.after(&"Tears.drawLowerEyelidMascara", self)


func clearLowerEyelid(amount: float) -> void:
	if not lowerEyelidClear:
		amount = minf(20.0, amount * 0.4)
		lowerEyelidData.fillRect(Rect2i(0, 0, 50, int(amount)), 0)
		if amount == 20:
			lowerEyelidClear = true
		lowerEyelidLayer.refresh()
	if Hooks.has(&"Tears.clearLowerEyelid"):   # HOOK
		Hooks.after(&"Tears.clearLowerEyelid", self)


func addTears() -> void:
	for i in 3:
		addTearSpot()
	g.her.blink()


func addTearSpot() -> void:
	if Hooks.has(&"Tears.addTearSpot"):   # HOOK
		var h := Hooks.before(&"Tears.addTearSpot", self, [])
		if h.cancelled:
			return
	if g.tears and tearSpotList.size() + tearList.size() < maxTears:
		var r := randf()
		var spot := Flash.create("TearSpot")
		if randf() > 0.2:
			spot.x = eyeB.x + r * eyeBCVec.x
			spot.y = eyeB.y + r * eyeBCVec.y
		else:
			spot.x = eyeA.x + r * eyeABVec.x
			spot.y = eyeA.y + r * eyeABVec.y
		spot.scaleX = 0.5
		spot.scaleY = 0.5
		tearSpotsLayer.addChild(spot)
		tearSpotList.append(spot)


func releaseTears() -> void:
	var n := tearSpotList.size()
	var i := 0
	while i < n:
		if randf() > 0.5:
			releaseTear(i)
			i -= 1
			n -= 1
		i += 1


func releaseTear(i: int) -> void:
	var spot = tearSpotList[i]
	var tp := TearPoint.new(spot.x, spot.y, randf() + 1.5)
	tp.scaling = spot.scaleX
	tearList.append(tp)
	tearSpotsLayer.removeChild(spot)
	spot.queue_free()
	tearSpotList.remove_at(i)


func tick(headRotation: float) -> void:
	mascaraFadeTick += 1
	var mascaraChanged := false
	if mascaraFadeTick >= mascaraFadeRate:
		mascaraFadeTick = 0
		oldDataBuffer = mascaraData.clone()
		mascaraData.fillRect(tearArea, 0)
		mascaraData.merge(oldDataBuffer, tearArea, Vector2i(), rgbBlendMult, rgbBlendMult, rgbBlendMult, alphaBlendMult)
		mascaraChanged = true
	var n := tearSpotList.size()
	var i := 0
	while i < n:
		if tearSpotList[i].scaleX < 1.5:
			tearSpotList[i].scaleX *= 1.01
			tearSpotList[i].scaleY *= 1.01
		elif randf() > 0.01:
			releaseTear(i)
			i -= 1
			n -= 1
		i += 1
	headRotation += rotation_degrees - 0.15
	headRotation = -headRotation * PI / 180.0
	_tearsIdle += 1
	if _tearsIdle < 260 or not tearList.is_empty():
		# merge(old, rgb*256, alpha*255) == alpha fades by one step per tick
		oldDataBuffer = tearsData.clone()
		tearsData.fillRect(tearArea, 0)
		tearsData.merge(oldDataBuffer, tearArea, Vector2i(), rgbBlendMult, rgbBlendMult, rgbBlendMult, alphaBlendMult)
	var tn := tearList.size()
	var t := 0
	while t < tn:
		var tp: TearPoint = tearList[t]
		if tp.tick():
			var ang: float
			if tp.y < 20:
				ang = headRotation - maxf(0.0, 20.0 - tp.y) / 40.0
			else:
				ang = headRotation - (30.0 - tp.y) / 600.0
			var step := Vector2(-sin(ang) * speed, cos(ang) * speed)
			tp.x += step.x * tp.speedMult
			tp.y += step.y * tp.speedMult
			if tp.y > tearArea.size.y:
				tearList.remove_at(t)
				t -= 1
				tn -= 1
			else:
				var m := Transform2D(-headRotation, Vector2(tp.scaling, tp.scaling), 0.0, Vector2(tp.x, tp.y))
				tearsData.draw(tearGraphic, m, FlashColorTransform.new(1, 1, 1, tp.alphaMult))
				_tearsIdle = 0
				var age := tp.getAge()
				if g.mascara and tp.hasMascara:
					if randf() > maxf(0.7 - g.mascaraAmount * 0.01, age):
						m.origin += Vector2(randf() * 2.0 - 1.0, randf() * 2.0)
						var ct := FlashColorTransform.new(1, 1, 1, maxf(0.0, 1.0 - age) * mascaraRGB["a"],
							mascaraRGB["r"], mascaraRGB["g"], mascaraRGB["b"])
						mascaraData.draw(mascaraGraphic, m, ct)
						mascaraChanged = true
		else:
			tearList.remove_at(t)
			t -= 1
			tn -= 1
		t += 1
	tearsLayer.refresh()
	if mascaraChanged:
		mascaraLayer.refresh()


func _refresh() -> void:
	tearsLayer.refresh()
	mascaraLayer.refresh()
	if lowerEyelidLayer:
		lowerEyelidLayer.refresh()


func smudge(target: Vector2) -> void:
	target = mascaraLayer.globalToLocal(target)
	if lastSmudgeTarget == null:
		lastSmudgeTarget = target
	smudgeVec = Vector2(target.x - lastSmudgeTarget.x, target.y - lastSmudgeTarget.y)
	var dist := sqrt(smudgeVec.x * smudgeVec.x + smudgeVec.y * smudgeVec.y)
	smudgeSteps = int(minf(100.0, floor(dist)))
	smudgeVec /= dist
	currentSmudge = lastSmudgeTarget
	lastSmudge = Vector2(Maths.round(lastSmudgeTarget.x), Maths.round(lastSmudgeTarget.y))
	smudgeToggle = true
	var changed := false
	for s in smudgeSteps:
		currentSmudge = Vector2(Maths.round(lastSmudgeTarget.x + smudgeVec.x * s), Maths.round(lastSmudgeTarget.y + smudgeVec.y * s))
		if currentSmudge != lastSmudge:
			if smudgeToggle:
				for b in smudgeBrush:
					var c1 := mascaraData.getPixel32(int(lastSmudge.x) + b.x, int(lastSmudge.y) + b.y)
					var a1 := (c1 >> 24) & 0xFF
					var r1 := (c1 >> 16) & 0xFF
					var g1 := (c1 >> 8) & 0xFF
					var b1 := c1 & 0xFF
					var c2 := mascaraData.getPixel32(int(currentSmudge.x) + b.x, int(currentSmudge.y) + b.y)
					var a2 := (c2 >> 24) & 0xFF
					var r2 := (c2 >> 16) & 0xFF
					var g2 := (c2 >> 8) & 0xFF
					var b2 := c2 & 0xFF
					var w := float(a1) / (a1 + a2) if a1 + a2 > 0 else NAN
					var na := mini(250, (a2 + a1) >> 1)
					# NaN weights (both pixels empty) produce 0 colour in Flash's uint conversion
					var nr := 0 if is_nan(w) else int(Maths.round(w * r1 + (1.0 - w) * r2))
					var ng := 0 if is_nan(w) else int(Maths.round(w * g1 + (1.0 - w) * g2))
					var nb := 0 if is_nan(w) else int(Maths.round(w * b1 + (1.0 - w) * b2))
					mascaraData.setPixel32(int(currentSmudge.x) + b.x, int(currentSmudge.y) + b.y,
						(na << 24) | (nr << 16) | (ng << 8) | nb)
					changed = true
				lastSmudge = currentSmudge
			smudgeToggle = not smudgeToggle
	lastSmudgeTarget = target
	if changed:
		mascaraLayer.refresh()
