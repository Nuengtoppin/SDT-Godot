# SDT-Godot

A port of the Flash game *SDT* to the Godot engine (4.7). It aims to stay faithful to the original while being
easier to extend (mods, new features) and running much faster than the Flash version.

The game's art, sounds and fonts are included, already converted from the original `SDT.swf` into
`game/assets/sdt/`, so the original game is not needed to play.

## Layout

- `game/`: the Godot project.
  - `game/flash/`: a small Flash runtime (display list, timelines, filters, text, SharedObject; an ActionScript
    interpreter for mod scripts).
  - `game/src/`: the game, ported class by class from the original ActionScript (same class and method names).
  - `game/scenes/main.gd`: entry point, plus the scripted test harness options.
- `native/`: source of the C++ GDExtension for hot paths (see [native/README.md](native/README.md)).
- `game/assets/sdt/`: the converted game assets (shapes, sounds, fonts, timelines in `library.json`).
- `game/bin/`: the native extension, prebuilt for Windows (debug and release DLLs).
- `tools/swfconv/`: converts `SDT.swf` into the asset library (only needed to regenerate `game/assets/sdt/`).
- `docs/`: development notes.
- `Mods/`: created next to the game on first run, with `Clothing`, `Hair`, `Backgrounds`, `Characters`,
  `Dialogue` and `Plugins` folders. Vanilla SDT `.swf` mods placed there show up in the in-game pickers.

## Running

1. Install [Godot 4.7.2](https://godotengine.org/download/archive/4.7.2-stable/) (the standard version, not .NET).
2. Tell `run_debug.bat` where Godot is: put the Godot folder on PATH as `godot.exe`, set the `GODOT` environment
   variable, or create `run_debug.local.bat` next to it containing
   `set GODOT=C:\path\to\Godot_v4.7.2-stable_win64_console.exe`.
3. Run `run_debug.bat`. The first run imports the assets once (a few minutes), then the game starts.

You can also open `game/` in the Godot editor and press F5.

## Regenerating the assets (optional)

Only needed to rebuild `game/assets/sdt/` from an original `SDT.swf`. Requirements: Python 3 with `pillow` and
`numpy`, Java and [JPEXS FFDec](https://github.com/jindrapetrik/jpexs-decompiler).

```
python tools/swfconv/convert.py original/SDT.swf game/assets/sdt --scale 2 [--ffdec path/to/ffdec.jar]
python tools/swfconv/fix_hitmasks.py original/SDT.swf game/assets/sdt
python tools/swfconv/supersample.py original/SDT.swf game/assets/sdt
```

The native extension can be rebuilt from source too, see `native/README.md`. Without it the game falls back to
slower GDScript code.

## Testing

`game/scenes/main.gd` documents the command-line options for scripted runs (`--eval`, `--driver`, `--shot`,
`--frames`, `--deterministic`, ...). Always pass `--save-dir=<folder>` to test runs so they don't overwrite your
own save. Example:

```
godot --headless --path game -- --save-dir=/tmp/sdt-test --driver=res://debug/stress_costumes.gd
```

`tools/check_all.sh` parse-checks every script. It reports "Identifier not found: Flash / g" for autoloads, which
can be ignored.
