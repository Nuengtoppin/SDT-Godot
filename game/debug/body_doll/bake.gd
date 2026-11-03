extends SceneTree
## Builds the doll's weights from its marks and saves the scene (after tools/body_proto/doll.py made it):
## godot --headless --path game --script res://debug/body_doll/bake.gd

const PATH := "res://debug/body_doll/doll.tscn"


func _initialize() -> void:
	var doll := (load(PATH) as PackedScene).instantiate()
	doll.rebuild_weights()
	var ps := PackedScene.new()
	var err := ps.pack(doll)
	if err == OK:
		err = ResourceSaver.save(ps, PATH)
	print("doll weights baked: ", error_string(err))
	doll.free()
	quit(0 if err == OK else 1)
