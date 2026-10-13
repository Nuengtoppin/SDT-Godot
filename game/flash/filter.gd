class_name FlashFilter
extends RefCounted
## flash.filters.* as plain data: DropShadow, Glow, Blur, ColorMatrix, Shader.
## Rendered by FlashGroupProxy (offscreen filters) or folded into shape materials (ColorMatrix).

var type: String
var blur_x: float = 4.0
var blur_y: float = 4.0
var color: int = 0
var alpha: float = 1.0
var angle: float = 45.0          # degrees
var distance: float = 4.0
var strength: float = 1.0
var quality: int = 1
var inner := false
var knockout := false
var hide_object := false
## ColorMatrixFilter: 20 values (4 rows x 5 columns, offsets in 0..255).
var matrix: Array = []
## ShaderFilter: Godot shader + parameters (ported Pixel Bender kernels).
var shader: Shader = null
var shader_params: Dictionary = {}


static func drop_shadow(p_distance := 4.0, p_angle := 45.0, p_color := 0, p_alpha := 1.0, p_blur_x := 4.0,
		p_blur_y := 4.0, p_strength := 1.0, p_quality := 1, p_inner := false, p_knockout := false,
		p_hide := false) -> FlashFilter:
	var f := FlashFilter.new()
	f.type = "DropShadow"
	f.distance = p_distance
	f.angle = p_angle
	f.color = p_color
	f.alpha = p_alpha
	f.blur_x = p_blur_x
	f.blur_y = p_blur_y
	f.strength = p_strength
	f.quality = p_quality
	f.inner = p_inner
	f.knockout = p_knockout
	f.hide_object = p_hide
	return f


static func glow(p_color := 0xFF0000, p_alpha := 1.0, p_blur_x := 6.0, p_blur_y := 6.0, p_strength := 2.0,
		p_quality := 1, p_inner := false, p_knockout := false) -> FlashFilter:
	var f := FlashFilter.new()
	f.type = "Glow"
	f.color = p_color
	f.alpha = p_alpha
	f.blur_x = p_blur_x
	f.blur_y = p_blur_y
	f.strength = p_strength
	f.quality = p_quality
	f.inner = p_inner
	f.knockout = p_knockout
	f.distance = 0.0
	return f


static func blur(p_blur_x := 4.0, p_blur_y := 4.0, p_quality := 1) -> FlashFilter:
	var f := FlashFilter.new()
	f.type = "Blur"
	f.blur_x = p_blur_x
	f.blur_y = p_blur_y
	f.quality = p_quality
	return f


static func color_matrix(m: Array) -> FlashFilter:
	var f := FlashFilter.new()
	f.type = "ColorMatrix"
	f.matrix = m.duplicate()
	return f


static func shader_filter(s: Shader, params: Dictionary = {}) -> FlashFilter:
	var f := FlashFilter.new()
	f.type = "Shader"
	f.shader = s
	f.shader_params = params.duplicate()
	return f


## Converts filter dictionaries from library.json (PlaceObject3 filter lists).
static func from_swf_list(list: Array) -> Array:
	var out: Array = []
	for d in list:
		var f := FlashFilter.new()
		f.type = d["type"]
		if d.has("color"):
			var c: Array = d["color"]
			f.color = (int(c[0]) << 16) | (int(c[1]) << 8) | int(c[2])
			f.alpha = c[3] / 255.0
		f.blur_x = d.get("blurX", 0.0)
		f.blur_y = d.get("blurY", 0.0)
		f.angle = rad_to_deg(d.get("angle", 0.0))
		f.distance = d.get("distance", 0.0)
		f.strength = d.get("strength", 1.0)
		f.quality = d.get("passes", 1)
		f.inner = d.get("inner", 0) != 0
		f.knockout = d.get("knockout", 0) != 0
		f.hide_object = d.get("compositeSource", 1) == 0
		if d.has("matrix"):
			f.matrix = d["matrix"]
		out.append(f)
	return out


func clone() -> FlashFilter:
	var f := FlashFilter.new()
	for p in ["type", "blur_x", "blur_y", "color", "alpha", "angle", "distance", "strength", "quality", "inner",
			"knockout", "hide_object", "shader"]:
		f.set(p, get(p))
	f.matrix = matrix.duplicate()
	f.shader_params = shader_params.duplicate()
	return f
