shader_type canvas_item;
render_mode blend_mul;
#include "shape_common.gdshaderinc"

// Flash ALPHA blend: destination alpha (and premultiplied colour) scaled by source alpha.
void fragment() {
	vec4 c = flash_color(texture(TEXTURE, UV), COLOR);
	COLOR = vec4(c.a);
}
