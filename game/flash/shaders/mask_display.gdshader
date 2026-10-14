shader_type canvas_item;
render_mode blend_premul_alpha;
// Draws a mask proxy's content viewport (premultiplied) multiplied by the coverage of its mask viewport.
uniform sampler2D mask_tex : filter_linear;

varying vec4 modulate;

void vertex() {
	modulate = COLOR;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float m = texture(mask_tex, UV).a;
	COLOR = c * m * modulate.a;
}
