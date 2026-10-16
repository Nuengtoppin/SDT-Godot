# SDT-Godot

A port of the Flash game *SDT* to the Godot engine (4.7). It aims to stay faithful to the original while being
easier to extend (mods, new features) and running much faster than the Flash version.

**No game files are included.** You need your own copy of the original `SDT.swf`; the game's art, sounds and fonts
are converted from it locally (see below). The repository contains only the port's code and tools.

## Layout

- `game/`: the Godot project.
  - `game/flash/`: a small Flash runtime (display list, timelines, filters, text, SharedObject; an ActionScript
    interpreter for mod scripts).
  - `game/src/`: the game, ported class by class from the original ActionScript (same class and method names).
  - `game/scenes/main.gd`: entry point, plus the scripted test harness options.
- `native/`: optional C++ GDExtension for hot paths (see [native/README.md](native/README.md)).
- `tools/swfconv/`: converts `SDT.swf` into the asset library the game loads (`game/assets/sdt/`).
- `docs/`: development notes.
- `Mods/`: created next to the game on first run, with `Clothing`, `Hair`, `Backgrounds`, `Characters`,
  `Dialogue` and `Plugins` folders. Vanilla SDT `.swf` mods placed there show up in the in-game pickers.

## Setup

Requirements: [Godot 4.7.2](https://godotengine.org/), Python 3 with `pillow` and `numpy`, Java and
[JPEXS FFDec](https://github.com/jindrapetrik/jpexs-decompiler) (used to rasterise shapes).

1. Put your `SDT.swf` somewhere outside the repository, e.g. `original/SDT.swf` (ignored by git).
2. Convert it into the game's asset library:
   ```
   python tools/swfconv/convert.py original/SDT.swf game/assets/sdt --scale 2 [--ffdec path/to/ffdec.jar]
   python tools/swfconv/fix_hitmasks.py original/SDT.swf game/assets/sdt
   python tools/swfconv/supersample.py original/SDT.swf game/assets/sdt
   ```
3. Optional: build the native extension (`native/README.md`). Without it the game uses slower GDScript fallbacks.
4. Run the game: open `game/` in the Godot editor and press F5, or use `run_debug.bat` (Windows). The script uses
   the `GODOT` environment variable, or a `run_debug.local.bat` next to it (`set GODOT=C:\path\to\godot.exe`),
   or `godot.exe` on PATH.

## Testing

`game/scenes/main.gd` documents the command-line options for scripted runs (`--eval`, `--driver`, `--shot`,
`--frames`, `--deterministic`, ...). Always pass `--save-dir=<folder>` to test runs so they don't overwrite your
own save. Example:

```
godot --headless --path game -- --save-dir=/tmp/sdt-test --driver=res://debug/stress_costumes.gd
```

`tools/check_all.sh` parse-checks every script. It reports "Identifier not found: Flash / g" for autoloads, which
can be ignored.
