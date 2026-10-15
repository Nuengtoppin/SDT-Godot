#pragma once

#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>

using namespace godot;

// Static helpers for the hottest paths of the game simulation, callable from GDScript as SDTNative.xxx(...).
class SDTNative : public Object {
	GDCLASS(SDTNative, Object)

protected:
	static void _bind_methods();

public:
	// Strand.renderStrand (with generateInterpolationPoints): builds the strand's drawing as one vertex-coloured
	// triangle mesh. Returns [points: PackedVector2Array, colors: PackedColorArray, indices: PackedInt32Array].
	static Array build_strand(const PackedVector2Array &p_pos, const PackedFloat32Array &p_thickness,
			const PackedFloat32Array &p_density, const PackedByteArray &p_has_stored,
			const PackedVector2Array &p_stored, const Color &p_rgb, double p_alpha, double p_max_interp_dist);

	// FlashDisplayObject._hit_shape (shape-flag hit testing) over the GDScript display tree: p is in obj's local
	// space, hb_gen the current FlashDisplayObject.hb_gen. Mirrors FlashSprite / FlashShape; other object types
	// (Graphics, text fields, bitmaps) call back into their GDScript _hit_shape.
	static bool hit_shape(Object *p_obj, const Vector2 &p_point, int64_t p_hb_gen);
};
