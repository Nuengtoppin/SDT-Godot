# Foundation layer: journal

One place that lists what the SDT_Path patches add for extensions and plugins: hook points in the game code,
shared plugins and their API, and what we have asked upstream for. Every patch that adds or changes one of these
updates this file. Before adding a hook point, check that upstream has not added the same one meanwhile.

The approach follows upstream's model (`docs/extensions.md`): the ported classes stay 1:1 with the original, new
behaviour lives in extensions or plugins. The game code only gets hook points. With nothing using them, the game
is unchanged.

## Hook points added to the game code

| Hook point | Kind | Patch | Why | Upstream |
|---|---|---|---|---|
| `Her.blink` | before (args: `[lookAround]`, can cancel) | P026, P028 | Switch off or take over her automatic blinking without replacing `Her.updateBlink`. The after point already existed. Vetoed (P028): `blinkTime` gets a normal wait (90–149 ticks), so `updateBlink` does not retry every tick; the eyelids and tears are left alone. | PR |
| `Her.swallow` | before (args: `[intensity, speak]`, can cancel) | P028 | Switch off or replace her swallowing (automatic, dialogue `[SWALLOW]`, the key). Vetoed: `startSwallowTimer` restarts, so the cum-in-mouth wait does not call it every tick; nothing else changes. A veto at the end of a swallow leaves breathing to `checkBreathing`'s usual delay. | PR |
| `Her.startClenchingTeeth` | before (args: `[]`, can cancel) | P028 | Switch off or replace her clenching her teeth (Angry mood, moremoods). Vetoed: nothing changes; the callers restart their own timers. | PR |
| `Her.waggleEyebrows` | before (args: `[]`, can cancel) | P028 | Switch off or replace the eyebrow waggle (Happy mood, auto mode, moremoods). The after point already existed. Vetoed: nothing changes. | PR |

Veto rule (upstream's request): a vetoed one-off action resets its own timers and changes no other state. Callers
may already have changed state before the call (`shock()` sets the eyelid shock, then calls `blink(false)`); that
stays theirs and needs its own hook point if it should be stoppable.

Not a one-off, so no before point: `Her.suck` adds to `suckPower` on every tick she pulls back (Happy,
Ahegao, auto mode); it is left for a value point.

## Plugins

### `channels` (Mods/Plugins/channels, P026)

One shared table of who controls a part of her behaviour right now. Other extensions use it instead of cancelling
each other's hooks.

Channels: `gaze` (where she looks) and `blink` (her automatic blinking). More follow (eyelids, hands, movement,
mouth).

Levels: `MANUAL` 300 > `DIALOGUE` 200 > `MOD` 100. A claim takes a free channel, one already held by the same
owner, or one held at a lower level; at an equal level the first holder keeps it.

A holder loses its channel on `release()`, when its `ttl` (game ticks) runs out, when a higher level takes it,
when the extension whose id is the owner is switched off, when a full character code is loaded, or when the
plugin is switched off. `on_lost(channel, reason)` is called. Holders are never saved.

```gdscript
var ch = Extensions.get_extension("channels")
if ch != null and ch.enabled:
	ch.look_at(id, "his_face", ch.DIALOGUE, 90)   # Vector2 in the scene layer, or "his_face" / "down" / "unfocused"
	ch.claim(&"blink", id, ch.MOD)                 # she stops blinking by herself
	ch.blink_now(id)                               # one blink, refused for anyone but the holder
	ch.release(&"blink", id)
```

| Call | What it does |
|---|---|
| `claim(channel, owner, level, data = {}, ttl = -1, on_lost = Callable())` | Takes a channel; false if refused. |
| `release(channel, owner)` / `release_owner(owner)` / `release_all()` | Gives channels back. |
| `update(channel, owner, data)` | Changes the holder's data. |
| `owner_of(channel)` / `level_of(channel)` / `is_held(channel)` / `snapshot()` | Who holds what. |
| `add_listener(fn)` / `remove_listener(fn)` | `fn(channel, old_owner, new_owner, reason)` on every change. |
| `look_at(owner, target, level = MOD, ttl = -1, on_lost = Callable())` | Takes the gaze (or moves the target of a gaze it already holds). |
| `gaze_target()` | The held gaze point, or null. |
| `blink_now(owner = "")` | One blink now, without looking around. |

How it works: before-handlers at priority -1000 on `Her.lookAt` (a held gaze cancels the call and runs the game's
own `lookAt` with the holder's target, so it also wins over moremoods' replacement), `Her.changeLookTarget` and
`Her.blink`.

Settings: `auto_blink` ("Automatic blinking") and `auto_look` ("Automatic look changes"), both on by default.

Known limit: code that rewrites the iris after `Her.updateEyes` (alternativePassOut's freeze, extramod's eye
following) still applies on top of the gaze holder. Moving those onto the channel is a later step.

Checks: `game/debug/channels_checks.gd` (needs the plugin in the mods folder).

## Developer mode panel (derrdev workbench)

Settings › Menu › Developer mode (off by default, kept in `port.cfg` as `developer/enabled`; an old
`debug_lab/enabled` is read as its default). It replaces the earlier Debug Lab panel.

- `DevMenu` (`game/src/menu/dev_menu.gd`) extends `SDTMenu`: the same panel (search, sections, cards, help line),
  docked on the side opposite the menu, so Menu side moves both. A DEBUG tab on its edge opens it, like the MENU
  tab. It never pauses the game. It is made the first time Developer mode is on (`SDTMenu._sync_dev()`), never in
  Vanilla mode or with the classic menu.
- What a second panel changes is a small set of instance methods in `SDTMenu`: `_left()`, `_enabled()`,
  `_make_sections()`, `_search_pool()`, `_home()`, `_title()`, `_search_hint()`, `_tab_label()`, `_pauses()`,
  `_default_help()`. With only the menu, they return what the menu used before.
- Both panels can be open together: clicking one does not close the other; clicking the scene closes both.
  `Flash.mouse_blocker` still asks the menu, which also asks the developer panel.
- Sections come from `DevSchema` (`game/src/menu/dev_schema.gd`): `dev_tools` (workbench, empty for now),
  `dev_info` (live values), `dev_panel`. Extensions can add controls with `SDTMenu.add_control()` and one of these
  section ids. `DevSchema.value(label, tip, get_fn)` is a read-only value row.
- The FPS counter (`game/scenes/fps_counter.gd`) slides beside an open panel docked on the left
  (`SDTMenu.left_inset()`).

Checks: `game/debug/derrdev_checks.gd`.

## Requests to upstream

| Request | Why | Status |
|---|---|---|
| Before hook point on `Her.blink` | See above. | PR (with the veto handled) |
| `Hooks.Call.cancelled_by` | The event log names who vetoed a call. | done upstream (e6dda3a) |
| `Extensions._disable()` tells shared tables that an extension went off (an event or a callback list) | `channels` checks every tick whether an owner's extension is still on. | to send |
| An event when a character code is loaded | `channels` uses a never-written character code field to get its reset call. | to send |
