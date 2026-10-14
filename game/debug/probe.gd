extends Node

var spr: Sprite2D
var n := 0

func _ready() -> void:
	spr = Sprite2D.new()
	spr.texture = load("res://icon.svg") if ResourceLoader.exists("res://icon.svg") else PlaceholderTexture2D.new()
	var img := Image.create(200, 200, false, Image.FORMAT_RGBA8)
	img.fill(Color.RED)
	spr.texture = ImageTexture.create_from_image(img)
	spr.position = Vector2(300, 300)
	add_child(spr)

func _process(_d: float) -> void:
	n += 1
	if n == 30:
		spr.visible = false
	if n == 60:
		await RenderingServer.frame_post_draw
		var im := get_viewport().get_texture().get_image()
		print("pixel ", im.get_pixel(int(300 * im.get_width() / 700.0), int(300 * im.get_height() / 600.0)))
		get_tree().quit()
