shader_type canvas_item;
render_mode blend_mul;
#include "shape_common.gdshaderinc"

// Flash multiply with coverage: dst * mix(1, src, srcAlpha). Alpha channel is left unchanged.
void fragment() {
	vec4 c = flash_color(texture(TEXTURE, UV), COLOR);
	COLOR = vec4(mix(vec3(1.0), c.rgb, c.a), 1.0);
}
