// Shared by all shape shader variants: Flash ColorTransform offsets and ColorMatrixFilter.
// Multipliers arrive through COLOR (Godot modulate, inherited like Flash's concatenated multipliers).
uniform vec4 offset = vec4(0.0);            // additive offsets, 0..1 units
uniform bool use_matrix = false;
uniform mat4 cm = mat4(1.0);                // colour matrix (rows applied to rgba)
uniform vec4 cm_offset = vec4(0.0);         // colour matrix offsets, 0..1 units

vec4 flash_color(vec4 tex, vec4 modulate) {
	vec4 c = tex * modulate;
	if (tex.a > 0.0001) {
		c.rgb += offset.rgb;
		c.a += offset.a;
	}
	c = clamp(c, 0.0, 1.0);
	if (use_matrix) {
		c = clamp(cm * c + cm_offset, 0.0, 1.0);
	}
	return c;
}

// In a canvas fragment shader COLOR starts as texture * modulate; shapes need the modulate alone (the Flash colour
// multipliers), so it is passed from the vertex stage.
varying vec4 flash_modulate;

#ifndef CUSTOM_VERTEX
void vertex() {
	flash_modulate = COLOR;
}
#endif
