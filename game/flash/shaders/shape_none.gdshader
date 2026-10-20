shader_type canvas_item;
render_mode blend_mul;

// ERASE / ALPHA with no LAYER group above: Flash shows nothing (it would punch holes into the stage).
void fragment() {
	COLOR = vec4(1.0);
}
