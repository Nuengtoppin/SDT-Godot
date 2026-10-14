shader_type canvas_item;
render_mode blend_mix;
#include "shape_common.gdshaderinc"

void fragment() {
	COLOR = flash_color(texture(TEXTURE, UV), flash_modulate);
}
