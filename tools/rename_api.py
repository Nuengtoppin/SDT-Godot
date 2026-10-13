"""One-off: rename the runtime's public API from snake_case to Flash's camelCase names."""
import os
import re
import sys

ROOT = sys.argv[1]

COMMON = {
    # DisplayObject
    'color_transform': 'colorTransform', 'blend_mode': 'blendMode', 'local_to_global': 'localToGlobal',
    'global_to_local': 'globalToLocal', 'get_bounds': 'getBounds', 'hit_test_point': 'hitTestPoint',
    'mouse_x': 'mouseX', 'mouse_y': 'mouseY', 'mouse_enabled': 'mouseEnabled',
    'add_event_listener': 'addEventListener', 'remove_event_listener': 'removeEventListener',
    'has_event_listener': 'hasEventListener', 'dispatch_event': 'dispatchEvent',
    # DisplayObjectContainer / Sprite
    'add_child_flash': 'addChild', 'add_child_at': 'addChildAt', 'remove_child_flash': 'removeChild',
    'remove_child_at': 'removeChildAt', 'remove_children': 'removeChildren', 'get_child_at': 'getChildAt',
    'get_child_index': 'getChildIndex', 'set_child_index': 'setChildIndex', 'swap_children': 'swapChildren',
    'get_child_by_name': 'getChildByName', 'num_children': 'numChildren', 'mouse_children': 'mouseChildren',
    'button_mode': 'buttonMode', 'use_hand_cursor': 'useHandCursor', 'hit_area': 'hitArea',
    # MovieClip
    'current_frame_label': 'currentFrameLabel', 'current_frame': 'currentFrame', 'total_frames': 'totalFrames',
    'current_labels': 'currentLabels', 'current_label': 'currentLabel', 'goto_and_stop': 'gotoAndStop',
    'goto_and_play': 'gotoAndPlay', 'next_frame': 'nextFrame', 'prev_frame': 'prevFrame',
    'add_frame_script': 'addFrameScript', 'is_playing': 'isPlaying',
    # Graphics
    'begin_fill': 'beginFill', 'begin_gradient_fill': 'beginGradientFill', 'end_fill': 'endFill',
    'line_style': 'lineStyle', 'move_to': 'moveTo', 'line_to': 'lineTo', 'curve_to': 'curveTo',
    'copy_from': 'copyFrom',
    # TextField
    'html_text': 'htmlText', 'text_color': 'textColor', 'text_width': 'textWidth', 'text_height': 'textHeight',
    'num_lines': 'numLines', 'word_wrap': 'wordWrap', 'default_text_format': 'defaultTextFormat',
    'set_text_format': 'setTextFormat', 'set_selection': 'setSelection', 'max_chars': 'maxChars',
    'auto_size': 'autoSize', 'border_color': 'borderColor', 'background_color': 'backgroundColor',
    'embed_fonts': 'embedFonts', 'append_text': 'appendText',
    # Events
    'stage_x': 'stageX', 'stage_y': 'stageY', 'local_x': 'localX', 'local_y': 'localY', 'key_code': 'keyCode',
    'char_code': 'charCode', 'shift_key': 'shiftKey', 'ctrl_key': 'ctrlKey', 'alt_key': 'altKey',
    'current_target': 'currentTarget', 'related_object': 'relatedObject', 'button_down': 'buttonDown',
    'stop_propagation': 'stopPropagation', 'stop_immediate_propagation': 'stopImmediatePropagation',
    'prevent_default': 'preventDefault', 'event_phase': 'eventPhase', 'default_prevented': 'defaultPrevented',
    # ColorTransform
    'red_multiplier': 'redMultiplier', 'green_multiplier': 'greenMultiplier',
    'blue_multiplier': 'blueMultiplier', 'alpha_multiplier': 'alphaMultiplier', 'red_offset': 'redOffset',
    'green_offset': 'greenOffset', 'blue_offset': 'blueOffset', 'alpha_offset': 'alphaOffset',
    # Sound
    'sound_transform': 'soundTransform',
    # Bitmap
    'bitmap_data': 'bitmapData',
    # Filters
    'blur_x': 'blurX', 'blur_y': 'blurY', 'hide_object': 'hideObject', 'drop_shadow': 'dropShadow',
    'color_matrix': 'colorMatrix', 'shader_filter': 'shaderFilter', 'shader_params': 'shaderParams',
}

# Only in graphics.gd (elsewhere these are Godot's CanvasItem methods).
GRAPHICS_ONLY = {'draw_rect': 'drawRect', 'draw_circle': 'drawCircle'}

# BitmapData methods: only rename the definitions and calls not made on an Image ("image.").
BITMAP_METHODS = {'get_pixel32': 'getPixel32', 'set_pixel32': 'setPixel32', 'get_pixel': 'getPixel',
                  'set_pixel': 'setPixel', 'fill_rect': 'fillRect', 'copy_pixels': 'copyPixels'}


def sub_words(text, mapping):
    for old in sorted(mapping, key=len, reverse=True):
        text = re.sub(r'(?<![\w.$"])%s\b|(?<=\.)%s\b' % (old, old), mapping[old], text)
    return text


for dirpath, _, files in os.walk(ROOT):
    if '.godot' in dirpath:
        continue
    for f in files:
        if not f.endswith('.gd'):
            continue
        p = os.path.join(dirpath, f)
        s = open(p, encoding='utf-8').read()
        o = s
        s = sub_words(s, COMMON)
        if f == 'graphics.gd':
            s = sub_words(s, GRAPHICS_ONLY)
        for old, new in BITMAP_METHODS.items():
            s = re.sub(r'(?<!image\.)(?<![\w])%s\(' % old, new + '(', s)
            s = re.sub(r'(?<=[a-z_)\]]\.)%s\(' % old, lambda m: m.group(0), s)
        # flash_parent() -> parent ; get_stage() -> stage
        s = s.replace('flash_parent()', 'parent')
        s = s.replace('get_stage()', 'stage')
        if s != o:
            open(p, 'w', encoding='utf-8').write(s)
            print('updated', p)
