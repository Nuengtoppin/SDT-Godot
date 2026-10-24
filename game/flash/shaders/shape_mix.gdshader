shader_type canvas_item;
render_mode blend_mix;
#define CUSTOM_VERTEX
#include "shape_common.gdshaderinc"

// Opt-in from Tan for selected vanilla fills; ordinary shapes use strength 0.
uniform float skin_tan_strength = 0.0;
uniform bool skin_tan_masked = false;
uniform sampler2D skin_tan_mask : filter_linear, repeat_disable;
uniform sampler2D skin_tan_full : filter_linear, repeat_disable;
uniform vec4 skin_tan_mask_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 skin_tan_full_rect = vec4(0.0, 0.0, 1.0, 1.0);
varying vec2 skin_local_position;

void vertex() {
	flash_modulate = COLOR;
	skin_local_position = VERTEX;
}

float silhouette_alpha(sampler2D image, vec4 bounds, vec2 position) {
	vec2 uv = (position - bounds.xy) / bounds.zw;
	if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) return 0.0;
	return texture(image, uv).a;
}

void fragment() {
	vec4 c = flash_color(texture(TEXTURE, UV), flash_modulate);
	float amount = skin_tan_strength;
	if (skin_tan_masked && amount > 0.0) {
		float mask_alpha = silhouette_alpha(skin_tan_mask, skin_tan_mask_rect, skin_local_position);
		float full_alpha = silhouette_alpha(skin_tan_full, skin_tan_full_rect, skin_local_position);
		// Shared outer coverage belongs to the skin, not the colour change.
		// The ratio retains the style's internal cutouts and soft boundaries.
		amount *= full_alpha > 0.0001 ? clamp(mask_alpha / full_alpha, 0.0, 1.0) : 0.0;
	}
	c.rgb = mix(c.rgb, max(2.0 * c.rgb - vec3(1.0), vec3(0.0)), amount);
	COLOR = c; // c.a is unchanged for both uniform and cutout styles.
}
