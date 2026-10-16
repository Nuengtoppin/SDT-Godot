# SDT native extension

C++ (GDExtension) implementations of the hottest paths of the Flash runtime / game simulation, loaded by the game
from `game/bin/sdt_native.gdextension`. The GDScript code checks `ClassDB.class_exists("SDTNative")` and falls back
to its own (identical, slower) implementation when the library is missing; `--nonative` on the game's command line
forces the GDScript paths (for A/B tests), `--checknative` cross-checks native hit tests against GDScript.

Currently native:
- `SDTNative.build_strand` - Strand.renderStrand / generateInterpolationPoints as one vertex-coloured mesh (gradient
  stops reproduced exactly by splitting triangles at the stop lines).
- `SDTNative.hit_shape` - shape-flag hit testing (FlashSprite / FlashShape `_hit_shape`) over the display tree.

## Building (Windows)

Requirements: MinGW-w64 g++ (e.g. the one in Strawberry Perl, `C:\Strawberry\c\bin`, on PATH) and SCons
(`tools/.venv`: `pip install scons`). godot-cpp is a git submodule (`git submodule update --init`).

```
cd native
../tools/.venv/Scripts/scons platform=windows use_mingw=yes target=template_debug -j8     # running from the editor binary
../tools/.venv/Scripts/scons platform=windows use_mingw=yes target=template_release -j8   # exported builds
```

The first build compiles godot-cpp (several minutes). `extension_api.json` is dumped from the engine binary the game
uses (`godot --headless --dump-extension-api`); regenerate it when updating Godot. After the first build, run the
editor or `godot --headless --path game --import` once so Godot registers the extension (.godot/extension_list.cfg).
