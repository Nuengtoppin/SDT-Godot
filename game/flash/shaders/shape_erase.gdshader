shader_type canvas_item;
render_mode blend_mul;
#include "shape_common.gdshaderinc"

// Flash ERASE: destination alpha (and premultiplied colour) scaled by (1 - srcAlpha). Applying this per shape
// equals erasing with the composited group, since (1-a1)(1-a2) = 1 - (a1 + a2(1-a1)).
void fragment() {
	vec4 c = flash_color(texture(TEXTURE, UV), flash_modulate);
	COLOR = vec4(1.0 - c.a);
}
