shader_type canvas_item;
render_mode blend_mul;
#include "shape_common.gdshaderinc"

// Flash ALPHA blend: destination alpha (and premultiplied colour) scaled by source alpha, only where the shape
// draws. The empty padding of the shape's image (alpha 0) leaves the destination alone (the game's only ALPHA
// shape, her upper arm mask, is a fill of alpha 1/255; its padding used to cut her shoulder off). A fill drawn
// with alpha exactly 0 would erase in Flash but is skipped here: the image cannot tell it from padding.
void fragment() {
	vec4 src = texture(TEXTURE, UV);
	if (src.a <= 0.0) {
		discard;
	}
	vec4 c = flash_color(src, flash_modulate);
	COLOR = vec4(c.a);
}
