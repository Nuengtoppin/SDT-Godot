#pragma once

#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>

#include <map>
#include <memory>
#include <vector>

using namespace godot;

namespace swf {
struct Shape;
struct Morph;
struct Font;
struct Tag {
	int code;
	size_t pos;
	size_t len;
};
} // namespace swf

// Reads a SWF file for the runtime mod converter: character index, timelines, ActionScript blocks, and renders
// shapes / morph shapes / static texts to anti-aliased images (the same library format tools/swfconv produces).
class SWFFile : public RefCounted {
	GDCLASS(SWFFile, RefCounted)

	std::vector<uint8_t> data;
	std::vector<swf::Tag> tags;
	struct Char {
		String type;
		int code = 0;
		size_t pos = 0, len = 0;
		std::vector<swf::Tag> sprite_tags;
		int frame_count = 0;
	};
	std::map<int, Char> chars;
	Dictionary symbol_classes, exports, scaling_grids;
	Array scene_labels, frame_labels_scene;
	int version = 0;
	double width = 0, height = 0, fps = 0;
	int frame_count = 0;
	std::vector<uint8_t> jpeg_tables;
	std::map<int, Ref<Image>> bitmap_cache;
	std::map<int, std::shared_ptr<swf::Font>> font_cache;

	void index_tags();
	Ref<Image> decode_bitmap(int id);
	std::shared_ptr<swf::Font> font(int id);
	bool shape_for(int id, int ratio, swf::Shape &out);

protected:
	static void _bind_methods();

public:
	Error open(const PackedByteArray &p_bytes);
	Dictionary get_info() const;
	// id -> {type, ...}; types: shape, morph, sprite, bitmap, text, font, sound, binary, edittext, button
	Dictionary get_characters() const;
	Dictionary get_symbol_classes() const { return symbol_classes; }
	Dictionary get_exports() const { return exports; }
	Dictionary get_scaling_grids() const { return scaling_grids; }
	Array get_scenes() const { return scene_labels; }
	// [frames: Array of Array of op Dictionaries, labels: Dictionary name -> 0-based frame] (id -1 = main timeline)
	Array get_timeline(int p_id) const;
	// DoABC payloads (the ABC bytes, after the flags / name header)
	Array get_abc_blocks() const;
	// {image: Image, x, y, w, h (bounds in pixels), hit: PackedByteArray, hw, hh} or {} when empty
	Dictionary render(int p_id, int p_ratio, double p_scale);
	Ref<Image> get_bitmap(int p_id);
	Dictionary get_sound(int p_id) const;
	Dictionary get_edit_text(int p_id) const;
	PackedByteArray get_binary(int p_id) const;
};
