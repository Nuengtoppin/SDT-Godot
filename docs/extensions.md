# Extensions and plugins

The game code in `game/src` is a 1:1 port of the original ActionScript. Features that are not in the original
(reimplemented Loader mods, fixes, new options) are **extensions**, kept out of the ported classes:

- **Built-in extensions**: `game/src/ext/<name>/`, shipped with the game, each switched on or off in the options.
- **Plugins**: `Mods/Plugins/<name>/`, installed by the player (plugin loading is not implemented yet).

Both use the same API (`SDTExtension`). One switch, **Vanilla mode** (`--vanilla` on the command line), turns every
extension off and gives the original game.

Status: the hook system, the extension base class, tick callbacks and settings exist. Still to come: character
code fields, dialogue extension points, menu widgets, the generated options screen and plugin loading.

## Writing an extension

```gdscript
extends SDTExtension

func _init() -> void:
	id = "example"            # unique, used for settings and file names
	title = "Example"
	default_enabled = false   # on or off until the player chooses

func _setup() -> void:        # declare settings; saved values are loaded afterwards
	setting("strength", 0.5, {"label": "Strength", "min": 0.0, "max": 1.0})

func _enable() -> void:       # register everything here
	on_tick(_tick)            # every game tick, before the game's own logic
	hook_after(&"Her.passOut", _passed_out)

func _disable() -> void:      # hooks and tick callbacks are removed automatically;
	pass                      # undo only what you changed in the game yourself

func _tick() -> void:
	pass

func _passed_out(call: Hooks.Call) -> void:
	print("she passed out, strength ", get_setting("strength"))
```

| Call | What it does |
|---|---|
| `on_tick(fn)` / `on_late_tick(fn)` | `fn()` every game tick (30 per second), before the game's tick / after the game's logic. Extensions run in load order. |
| `hook_before(name, fn, priority, target)` / `hook_after(...)` | `fn(call)` around a game method, see Hooks below. |
| `setting(key, default, info)` | Declares a setting. Type from the default (bool, int, float, String); `info`: `label`, `desc`, `min`, `max`, `step`, `options`. |
| `get_setting(key)` / `set_setting(key, value)` | Read / change (saved immediately, then `_setting_changed(key, value)` is called). |
| `data_dir()` | A folder for the extension's own files, next to the save files. |

Settings and on/off choices are stored in `extensions.cfg` next to the save files. Test runs with `--save-dir` use
their own copy.

Tick time is measured per extension: it appears in `--profile` output and in the log's `HITCH` lines as
`ext:<id>.tick`.

## Hooks

GDScript cannot replace a method at runtime (the Loader's `lProxy` did this for Loader mods), so each game method
that an extension needs gets a hook point: two guarded blocks named after the original `Class.method`, marked
`# HOOK`. `grep -rn "# HOOK" game/src` lists them all. Hook points are added when an extension needs them.

```gdscript
func lookAt(target: Vector2) -> void:
	if Hooks.has(&"Her.lookAt"):                       # HOOK
		var h := Hooks.before(&"Her.lookAt", self, [target])
		if h.cancelled:
			return
		target = h.args[0]
	...original code, unchanged...
	if Hooks.has(&"Her.lookAt"):                       # HOOK
		Hooks.after(&"Her.lookAt", self, [target])
```

Handlers get a `Hooks.Call` with `name`, `obj` (the object whose method runs), `args`, `result` and `cancel(value)`:

- **Before-handlers** run in `priority` order (lower first, then registration order). They may change `call.args`,
  or call `call.cancel(value)`: the original method is skipped and returns `value`, and the remaining handlers
  (before and after) are skipped too.
- **After-handlers** see the method's return value in `call.result` and may replace it.
- While a hook's handlers run, the hook is inactive, so a handler can call the hooked method itself to run the
  original code.
- A handler registered with a `target` runs only for that object. A hook name covers every instance of the class.
- An unused hook point costs one dictionary lookup, so hooks are fine even in methods that run every tick.

## Testing

`tools/regress.sh` runs the game scenarios in Vanilla mode (their reference dumps must not change because of an
extension), plus `game/debug/ext_checks.gd`, which tests the hook system, the extension lifecycle, tick order and
settings.
