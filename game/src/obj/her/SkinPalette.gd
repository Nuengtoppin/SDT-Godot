class_name SkinPalette
extends RefCounted
## Port of obj.her.SkinPalette: the colours of one skin tone.

const LIGHT_SKIN := "Light"
const PALE_SKIN := "Pale"
const TAN_SKIN := "Tan"
const DARK_SKIN := "Dark"

var skinName: String
var light: ARGBObject
var shade1: ARGBObject
var shade2: ARGBObject
var shade3: ARGBObject
var nippleLight: ARGBObject
var nippleShade: ARGBObject
var lipAlpha: float


func _init(pLight: int, pShade1: int, pShade2: int, pShade3: int, pNippleLight: int, pNippleShade: int,
		pLipAlpha: float = 1.0) -> void:
	light = split(pLight)
	shade1 = split(pShade1)
	shade2 = split(pShade2)
	shade3 = split(pShade3)
	nippleLight = split(pNippleLight)
	nippleShade = split(pNippleShade)
	lipAlpha = pLipAlpha


func split(c: int) -> ARGBObject:
	var a := 255 if c < 16777215 else (c & 0xFF000000) >> 24
	return ARGBObject.new(a, (c & 0xFF0000) >> 16, (c & 0xFF00) >> 8, c & 0xFF)
