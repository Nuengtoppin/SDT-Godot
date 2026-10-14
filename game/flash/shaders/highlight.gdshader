shader_type canvas_item;
// Port of DT_HighlightFilter (Pixel Bender kernel "NewFilter" by Konashion, decompiled from the SWF's bytecode):
// adds a highlight along the top edge of opaque areas and scales the colour by `trans`. Used on the spit / cum
// strand layers. Optionally followed by Flash's inner DropShadowFilter (g.shadow), since a group draws through a
// single material.

uniform float totMult = 0.25;
uniform float trans = 0.3;
// Render-target pixels per Flash stage pixel (the kernel's offsets are in stage pixels).
uniform float px_scale = 1.0;

uniform bool has_shadow = false;
uniform vec2 shadow_offset_px = vec2(0.0, -1.0);
uniform vec2 shadow_blur_px = vec2(5.0, 5.0);
uniform vec4 shadow_color : source_color = vec4(0.79, 0.76, 0.64, 1.0);
uniform float shadow_strength = 1.5;

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec4 c = texture(TEXTURE, UV);
	vec4 o;
	if (c.a > 0.0) {
		float h = 0.8 * texture(TEXTURE, UV + vec2(0.0, -3.0) * px * px_scale).a;
		h -= texture(TEXTURE, UV + vec2(1.0, -7.0) * px * px_scale).a;
		o = clamp(vec4(h * totMult) + c * trans, 0.0, 1.0);
	} else {
		o = c * trans;
	}
	if (has_shadow && o.a > 0.0) {
		// Inner shadow: how much of the shape is missing at the (blurred) offset position.
		float sum = 0.0;
		float n = 0.0;
		vec2 r = shadow_blur_px * px_scale * 0.5;
		for (int i = -2; i <= 2; i++) {
			for (int j = -2; j <= 2; j++) {
				vec2 d = vec2(float(i), float(j)) * 0.5 * r;
				sum += texture(TEXTURE, UV - (shadow_offset_px * px_scale + d) * px).a;
				n += 1.0;
			}
		}
		float s = clamp((1.0 - sum / n) * shadow_strength, 0.0, 1.0) * shadow_color.a;
		o.rgb = mix(o.rgb, shadow_color.rgb * o.a, s);
	}
	COLOR = o;
}
