shader_type canvas_item;
render_mode blend_mix;
#include "shape_common.gdshaderinc"

// Blend modes that read the backdrop. A BackBufferCopy is placed in front of the blended object.
uniform sampler2D backdrop : hint_screen_texture, filter_linear;
uniform int mode = 0; // 0 overlay, 1 hardlight, 2 screen, 3 lighten, 4 darken, 5 difference, 6 invert

float overlay1(float b, float s) {
	return b < 0.5 ? 2.0 * b * s : 1.0 - 2.0 * (1.0 - b) * (1.0 - s);
}

void fragment() {
	vec4 c = flash_color(texture(TEXTURE, UV), flash_modulate);
	// A transparent viewport stores premultiplied RGB. Nonlinear blend functions
	// need straight backdrop colour and must account for uncovered backdrop area.
	vec4 backdrop_sample = texture(backdrop, SCREEN_UV);
	float backdrop_alpha = clamp(backdrop_sample.a, 0.0, 1.0);
	vec3 b = backdrop_alpha > 0.0 ? backdrop_sample.rgb / backdrop_alpha : vec3(0.0);
	vec3 r;
	if (mode == 0) {
		r = vec3(overlay1(b.r, c.r), overlay1(b.g, c.g), overlay1(b.b, c.b));
	} else if (mode == 1) {
		r = vec3(overlay1(c.r, b.r), overlay1(c.g, b.g), overlay1(c.b, b.b));
	} else if (mode == 2) {
		r = 1.0 - (1.0 - b) * (1.0 - c.rgb);
	} else if (mode == 3) {
		r = max(b, c.rgb);
	} else if (mode == 4) {
		r = min(b, c.rgb);
	} else if (mode == 5) {
		r = abs(b - c.rgb);
	} else {
		r = 1.0 - b;
	}
	// Source-over with blending: (1-Ab)*Cs + Ab*B(Cb,Cs). blend_mix
	// applies source alpha and adds the remaining premultiplied destination.
	COLOR = vec4(mix(c.rgb, r, backdrop_alpha), c.a);
}
