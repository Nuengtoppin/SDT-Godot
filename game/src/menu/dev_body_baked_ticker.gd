extends Node
## Baked legs: feeds the shaders the angles between the last two ticks, every frame (DevBodyBaked._frame).


func _process(_delta: float) -> void:
	DevBodyBaked._frame()
