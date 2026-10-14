class_name PaletteUtils
extends RefCounted
## Port of obj.graphics.PaletteUtils: random colour helpers for shuffling.


static func randomSwatch(swatches: Array, randomAlpha: bool = false) -> AlphaRGBObject:
	var c: AlphaRGBObject = swatches[int(floor(randf() * swatches.size()))]
	c.a = randf() * 0.8 + 0.2 if randomAlpha else 1.0
	return c


static func midRandom() -> float:
	return 0.5 + (randf() - 0.5) * (randf() - 0.5)


static func getHue(hue: float, saturation: float, lightness: float = -1.0) -> AlphaRGBObject:
	var r := int(floor(hueWave(hue, 0, 360) * 255))
	var gg := int(floor(hueWave(hue, 1, 360) * 255))
	var b := int(floor(hueWave(hue, 2, 360) * 255))
	var avg := (r + gg + b) / 3.0
	r = int(Maths.round(avg + (r - avg) * saturation))
	gg = int(Maths.round(avg + (gg - avg) * saturation))
	b = int(Maths.round(avg + (b - avg) * saturation))
	if lightness != -1:
		lightness *= 255 * 3
		var shift := int(floor((lightness - r - gg - b) / 3.0))
		r = maxi(0, mini(255, r + shift))
		gg = maxi(0, mini(255, gg + shift))
		b = maxi(0, mini(255, b + shift))
	return AlphaRGBObject.new(1, r, gg, b)


static func hueWave(h: float, channel: int, cycle: float = 100.0) -> float:
	cycle /= 3.0
	h /= cycle
	h += channel
	var v := 6.0 * (h / 3.0 - floorf(h / 3.0 + 0.5))
	return maxf(0.0, minf(1.0, absf(v) - 1.0))
