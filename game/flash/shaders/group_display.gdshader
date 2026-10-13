shader_type canvas_item;
render_mode blend_premul_alpha;
// Draws an offscreen group's render target (premultiplied) and applies Flash filters:
// Blur, DropShadow / Glow (outer, inner, knockout, hideObject). Offsets / sizes are in texture pixels.
uniform int mode = 0;               // 0 passthrough, 1 blur, 2 shadow / glow
uniform vec2 blur_px = vec2(0.0);
uniform float passes = 1.0;
uniform vec2 offset_px = vec2(0.0);
uniform vec4 shadow_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float strength = 1.0;
uniform bool inner = false;
uniform bool knockout = false;
uniform bool hide_object = false;

vec4 blurred(sampler2D tex, vec2 uv, vec2 px) {
	vec2 sigma = max(blur_px * sqrt(passes) / 3.4641, vec2(0.001));
	vec4 acc = vec4(0.0);
	float wsum = 0.0;
	for (int y = -4; y <= 4; y++) {
		for (int x = -4; x <= 4; x++) {
			vec2 o = vec2(float(x), float(y)) / 4.0;
			float w = exp(-dot(o, o) * 4.5);
			acc += texture(tex, uv + o * sigma * 3.0 * px) * w;
			wsum += w;
		}
	}
	return acc / wsum;
}

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec4 c = texture(TEXTURE, UV);
	vec4 r = c;
	if (mode == 1) {
		r = blurred(TEXTURE, UV, px);
	} else if (mode == 2) {
		float a = blurred(TEXTURE, UV - offset_px * px, px).a;
		if (inner) {
			float ia = clamp((1.0 - a) * strength, 0.0, 1.0) * c.a * shadow_color.a;
			vec4 sh = vec4(shadow_color.rgb * ia, ia);
			r = knockout ? sh : sh + c * (1.0 - ia);
		} else {
			float oa = clamp(a * strength, 0.0, 1.0) * shadow_color.a;
			vec4 sh = vec4(shadow_color.rgb * oa, oa);
			r = knockout ? sh * (1.0 - c.a) : (hide_object ? sh : c + sh * (1.0 - c.a));
		}
	}
	// premultiplied output, scaled by the group's modulate (Flash alpha / multipliers of the composite)
	COLOR = vec4(r.rgb * COLOR.rgb, r.a) * COLOR.a;
}
