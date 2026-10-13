extends Node2D
# Checks nested CanvasGroup depth: columns with 1..4 nested groups around a red square.
func _ready() -> void:
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_window().size = Vector2i(500, 150)
	RenderingServer.set_default_clear_color(Color(0.5, 0.5, 0.5))
	for depth in range(1, 5):
		var parent: Node2D = self
		for d in depth:
			var g := CanvasGroup.new()
			if d == 0:
				g.position = Vector2(20 + (depth - 1) * 120, 20)
			parent.add_child(g)
			parent = g
		var p := Polygon2D.new()
		p.polygon = PackedVector2Array([Vector2(0, 0), Vector2(80, 0), Vector2(80, 80), Vector2(0, 80)])
		p.color = Color(1, 0, 0, 0.8)
		parent.add_child(p)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	get_tree().quit()
