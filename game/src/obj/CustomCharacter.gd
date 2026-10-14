class_name CustomCharacter
extends RefCounted
## Port of obj.CustomCharacter: a saved character slot (name, data string, 70x60 thumbnail).

var ver: String = "1"
var charName: String
var charData: String
var charShot: FlashBitmapData
var haveCharShot := false
var ID: int = 0
var dialogue: String = ""
var menuPosition: int = 0


func _init(n: String = "", data: String = "") -> void:
	charName = n
	charData = data


func giveCharShot(b: FlashBitmapData) -> void:
	charShot = b
	haveCharShot = true


## Thumbnail pixels as ARGB bytes, zlib-compressed like ByteArray.compress().
var shotBytes: PackedByteArray:
	get:
		return charShot.getPixels(Rect2i(0, 0, 70, 60)).compress(FileAccess.COMPRESSION_DEFLATE)


func saveFileObject() -> Dictionary:
	return {"charName": charName, "charData": charData, "shotBytes": shotBytes}
