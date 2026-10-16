# Porting scripts

One-off helpers used while porting the original ActionScript to GDScript. They are kept for reference and for
redoing a step; the game does not need them. Most take the FFDec export of the original `SDT.swf` (`extracted/`,
not in the repository) as input.

- `as3_to_gd.py`: rough AS3 to GDScript draft converter (output was reviewed by hand).
- `port_chars.py`: converts the character presets (`chars/*.as`).
- `port_dialogue_lib.py`: regenerates the built-in dialogue lines in `DialogueLibrary.gd`.
- `gen_symbol_stubs.py`: stubs for symbol classes that only extend a ported class.
- `add_super_init.py`, `gd_fix_locals.py`, `rename_api.py`: mechanical fix-ups applied once across the port.
- `pbj_disasm.py`: Pixel Bender bytecode disassembler (used to port the highlight filter to a shader).
- `wincap.ps1`: captures (and clicks into) a window, for comparing the original game with the port.
