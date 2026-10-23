shader_type canvas_item;
render_mode blend_premul_alpha;
// Port of DT_HighlightFilter (Pixel Bender kernel "NewFilter" by Konashion, decompiled from the SWF's bytecode):
// adds a highlight along the top edge of opaque areas and scales the colour by `trans`. Used on the spit / cum
// strand layers. Optionally followed by Flash's inner DropShadowFilter (g.shadow), since a group draws through a
// single material.
// Rendering refined by @Nuengtoppin (issue #1), closer to Flash than a plain port of the kernel: subpixel
// footprint (no flicker on thin distant strands, no dark transparent edges), highlight and inner shadow kept within
// the strand's own coverage.
// Offscreen group textures contain premultiplied RGB, as in group_display.gdshader.
uniform float totMult = 0.25;
uniform float trans = 0.3;
// Render-target pixels per Flash stage pixel, scene zoom included (the kernel's offsets are in stage pixels).
uniform float px_scale = 1.0;
// Opacity of the whole layer (saliva is drawn at 85%, see FlashGroupProxy).
uniform float opacity = 1.0;

uniform bool has_shadow = false;
uniform vec2 shadow_offset_px = vec2(0.0, -1.0);
uniform vec2 shadow_blur_px = vec2(5.0, 5.0);
uniform vec4 shadow_color : source_color = vec4(0.79, 0.76, 0.64, 1.0);
uniform float shadow_strength = 1.5;

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	float scale = max(px_scale, 0.01);
	// A subpixel footprint softens raster corners without a broad shape blur.
	vec2 d = px * 0.4;
	vec4 c = texture(TEXTURE, UV) * 0.5;
	c += texture(TEXTURE, UV + vec2(d.x, 0.0)) * 0.125;
	c += texture(TEXTURE, UV - vec2(d.x, 0.0)) * 0.125;
	c += texture(TEXTURE, UV + vec2(0.0, d.y)) * 0.125;
	c += texture(TEXTURE, UV - vec2(0.0, d.y)) * 0.125;
	float coverage = clamp(c.a, 0.0, 1.0);
	vec3 rgb = coverage > 0.00001 ? clamp(c.rgb / coverage, vec3(0.0), vec3(1.0)) : vec3(0.0);
	// Filter the two highlight samples across a subpixel horizontal footprint.
	vec2 uv_near = UV + vec2(0.0, -3.0) * px * scale;
	vec2 uv_far = UV + vec2(1.0, -7.0) * px * scale;
	float a_near = texture(TEXTURE, uv_near).a * 0.5;
	a_near += (texture(TEXTURE, uv_near + vec2(d.x, 0.0)).a + texture(TEXTURE, uv_near - vec2(d.x, 0.0)).a) * 0.25;
	float a_far = texture(TEXTURE, uv_far).a * 0.5;
	a_far += (texture(TEXTURE, uv_far + vec2(d.x, 0.0)).a + texture(TEXTURE, uv_far - vec2(d.x, 0.0)).a) * 0.25;
	float highlight = max(0.0, 0.8 * a_near - a_far) * max(totMult, 0.0);
	// Do not create a new opaque rim beyond the source's antialiased coverage.
	float alpha = clamp(coverage * clamp(trans, 0.0, 1.0) + highlight, 0.0, coverage);
	float shine = alpha > 0.00001 ? clamp(highlight / alpha, 0.0, 1.0) : 0.0;
	rgb = mix(rgb, vec3(1.0), shine);
	if (has_shadow && coverage > 0.00001) {
		float sum = 0.0;
		vec2 radius = shadow_blur_px * scale * 0.5;
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				float weight = (x == 0 ? 2.0 : 1.0) * (y == 0 ? 2.0 : 1.0);
				vec2 offset = vec2(float(x), float(y)) * radius;
				sum += texture(TEXTURE, UV - (shadow_offset_px * scale + offset) * px).a * weight;
			}
		}
		// Normalize by local coverage so thin transparent strands are not all shadow.
		float missing = clamp(1.0 - (sum / 16.0) / coverage, 0.0, 1.0);
		float shadow = clamp(missing * max(shadow_strength, 0.0) * shadow_color.a * 0.45, 0.0, 0.35);
		rgb = mix(rgb, shadow_color.rgb, shadow);
	}
	// Scale premultiplied RGB and alpha together; never darken the straight colour.
	COLOR = vec4(rgb * alpha, alpha) * clamp(opacity, 0.0, 1.0);
}
