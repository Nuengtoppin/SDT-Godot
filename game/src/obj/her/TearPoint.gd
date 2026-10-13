class_name TearPoint
extends RefCounted
## Port of obj.her.TearPoint (a flash.geom.Point subclass): one point of a running tear.

var x: float
var y: float
var speedMult: float = 1.0
var alphaMult: float = 1.0
var scaling: float = 1.0
var age: int = 0
var mascaraTime: float
var hasMascara: bool


func _init(px: float, py: float, mult: float) -> void:
	x = px
	y = py
	speedMult = mult
	alphaMult = mult
	hasMascara = randf() > maxf(0.2, 1.0 - g.mascaraAmount * 0.015)
	if randf() > 0.96 - g.mascaraAmount * 0.008:
		mascaraTime = randf() * 100.0 + 200.0
	else:
		mascaraTime = randf() * 50.0 + 50.0
	mascaraTime = 1.0 / mascaraTime


func tick() -> bool:
	age += 1
	speedMult -= 0.005
	alphaMult -= 0.005
	return not (speedMult <= 0 or alphaMult <= 0)


func getAge() -> float:
	return age * mascaraTime


func toVector() -> Vector2:
	return Vector2(x, y)
