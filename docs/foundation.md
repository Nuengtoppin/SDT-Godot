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
| `Her.blink` | before (args: `[lookAround]`, can cancel) | P026, P028 | Switch off or take over her automatic blinking without replacing `Her.updateBlink`. The after point already existed. Vetoed (P028): `blinkTime` gets a normal wait (90–149 ticks), so `updateBlink` does not retry every tick; the eyelids and tears are left alone. | merged (main) |
| `Her.swallow` | before (args: `[intensity, speak]`, can cancel) | P028 | Switch off or replace her swallowing (automatic, dialogue `[SWALLOW]`, the key). Vetoed: `startSwallowTimer` restarts, so the cum-in-mouth wait does not call it every tick; nothing else changes. A veto at the end of a swallow leaves breathing to `checkBreathing`'s usual delay. | merged (main) |
| `Her.startClenchingTeeth` | before (args: `[]`, can cancel) | P028 | Switch off or replace her clenching her teeth (Angry mood, moremoods). Vetoed: nothing changes; the callers restart their own timers. | merged (main) |
| `Her.waggleEyebrows` | before (args: `[]`, can cancel) | P028 | Switch off or replace the eyebrow waggle (Happy mood, auto mode, moremoods). The after point already existed. Vetoed: nothing changes. | merged (main) |
| `Her.openEye` | before (args: `[]`, can cancel) | P028 | Keep an eye closed. Vetoed: `eyelidMotion.closedTimer` restarts, so `updateElements` does not ask every tick after 1200 ticks; the caller still clears `cumInEye`. | merged (main) |
| `Tears.addTearSpot` | before (args: `[]`, can cancel) | P028 | Switch off or replace new tear spots. Vetoed: no spot; the callers' own effects (cough, hilt) stay. | merged (main) |
| `Tears.releaseTears` | before (args: `[]`, can cancel) | P028 | Keep tear spots from running (on blink and wince). Vetoed: the spots stay. | merged (main) |
| `Her.generateRandomStrand` | before (args: `[side, long]`, can cancel) | P028 | Switch off, move or replace spit strands to him. Args can be changed. Vetoed: no strand; callers do not retry. | merged (main) |
| `Her.randomSpitDrool` | before (args: `[]`, can cancel) | P028 | Switch off or replace spit drool (gag, Ahegao, moremoods). Vetoed: no drool; the gag timer restarts as usual. | merged (main) |
| `Her.startDroolingCum` | before (args: `[force]`, can cancel) | P028 | Switch off or replace cum drooling. Asked only when it would start (more than 5 in her mouth, or forced). `updateElements` polls it every tick, so a veto holds the drool off while the conditions last and is asked again each tick then; there is no timer to restart. Vetoed: no forced cum, no drool. | merged (main) |
| `Him.ejaculate` | before (args: `[]`, can cancel) | P028 | Switch off or replace his ejaculation. Vetoed: `maxPleasureTimer` restarts (the pre-climax pulse runs again). The automatic caller resets pleasure and flashes only if `ejaculating` is set after the call (always so in the original), so a veto keeps his pleasure. | merged (main) |
| `Sweat.spawn` | before (args: `[container, p, spread, others]`, can cancel) | P028 | Switch off, move or replace sweat droplets. Static: `obj` is null. Args can be changed. Vetoed: no droplet. | merged (main) |
| `Her.passOut` (upstream's) | before, can cancel | P030 | Veto clean-up only. Vetoed, not replaced (still awake, factor at the top): `passOutFactor` drops 7.5 below the top, so `animateBreathing` tries again in 150 ticks; she stays on the edge. A handler that passes her out itself (alternativePassOut) is left alone. | merged (main) |
| `Her.wakeUp` (upstream's) | before, can cancel | P030 | Veto clean-up only. Vetoed, not replaced (still out, factor at 0): `passOutFactor` goes back to the top, so the next try is in 80 ticks. | merged (main) |
| `Her.cough` (upstream's) | before, can cancel | P030 | Veto clean-up only. Vetoed and no wait of its own set by the handler (moremoods sets one): `nextCoughTime` gets a normal wait (30–239 ticks) instead of 0. | merged (main) |
| `Her.shock` | before (args: `[amount]`, can cancel) | P031 | Switch off, weaken or replace her being startled (eyes wide, sometimes a blink): he comes, she wakes up, cum from her nose, dialogue. Vetoed: nothing changes (no shock, no blink). | merged (main) |
| `Her.lastSpurt` | before (args: `[]`, can cancel) | P031 | Switch off or replace cum from her nose at his last spurt (her mouth over-full, Nostril spray on). Vetoed: nothing changes. | merged (main) |

Not one-offs, so no before point: `Him.closeHand` (`Her.move` calls it every tick while he holds her; it is the hand's
state, a flag for a value point) and the spit flow while she moves (`generateSpit`, every tick).

Veto rule (upstream's request): a vetoed one-off action resets its own timers and changes no other state. Callers
may already have changed state before the call (`shock()` sets the eyelid shock, then calls `blink(false)`); that
stays theirs and needs its own hook point if it should be stoppable.

Not a one-off, so no before point: `Her.suck` adds to `suckPower` on every tick she pulls back (Happy,
Ahegao, auto mode); it is left for a value point.

## Plugins

The `channels` plugin (P026: shared owners for her gaze and blinking) was dropped when derrdev was rebuilt on
upstream's main (27 October): upstream's value points (`Hooks.value`, `modify()`; her gaze on `Her.lookTarget` and
`Her.gazeAngle`) do the same job in the core. Its old checks went with it.

## Developer mode panel (derrdev workbench)

Settings › Menu › Developer mode (off by default, kept in `port.cfg` as `developer/enabled`). It replaced the earlier
Debug Lab panel and is in upstream's main since the devmode PR; derrdev adds the behaviour tabs (P029) and the Body
tab (P032) on top.

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
- Behaviour tabs (P029, `game/src/menu/dev_behaviour.gd`): Eyes, Mouth, Fluids, State, Him. One row per behaviour
  from `DevBehaviour.entries()` (group, label, hook point, call, tip): a call button, an "auto" switch and a status
  line. Auto off = a veto at priority -99999 on that before point (owner `devmode`); the row's call passes it
  (`call_now`), other extensions' vetoes still apply. An observer at -100000 on every listed point keeps the last
  `Hooks.Call`, so the status shows "ran / called from here / vetoed by <owner>" with `cancelled_by`. Vetoes and
  observers exist only while Developer mode is on (not in Vanilla mode or with the classic menu).
- Panel tab › Automation: Freeze all / Restore all, how many are off, and "Remember after restart"
  (`port.cfg` `dev_behaviour/remember`, the list in `dev_behaviour/off`). Off: every start is the normal game; the
  session keeps its switches.
- Body tab (P032, `game/src/menu/dev_body_overlay.gd`): debug layers drawn over body parts, the same layers for every
  part - source shape (cyan), what is drawn this tick (pink, a second outline in blue), control points, axes and
  bones (yellow) - plus line width and point size. A part is a provider returning its node and point arrays in the
  node's space; `DevBodyOverlay` draws them in screen space on its own CanvasLayer (45: over the game, under the
  menus), outside the Flash display list, so nothing in the game changes and nothing is hit-tested. First part: the
  neck (`Neck.renderedPoints` / `lastDepth`, kept by `Neck.render` for this). Next: legs and breasts.
- Throat rings (P033, `game/src/ext/throatresiststretch/throat_rings.gd`, stage 1, read only): her throat as a path
  by depth (the neck's own: penisInMouthDist / 400) with rings on it - the throat entrance (the game's resistance zone
  75..150, tightness = her throat resistance) and, while she wears one, her collar (edges from the collar's bounds on
  the neck, kept to a 70 px band, adjustable by hand; material Band / Leather / Metal sets tightness, stiffness and
  durability; P034: the adjustments and material are kept for each collar in `port.cfg` `throat_rings`, Leather starts
  at +0.005 / -0.05 as seen in the game). Each tick a ring gets pressure from his width past its top edge, more while he pushes in, and from the
  swallow wave inside it; under pressure it stretches and wears down (would snap at 0), at rest it recovers. It is
  ticked by the throatresiststretch extension while Developer mode is on and changes nothing in the game; later
  stages give its stretch and hold to the throat resistance and bulge through value points and take over that
  extension's counter and the collar mods (sby's chokercollarresistance and its addon). Shown in the Body tab
  (values, collar controls) and by the overlay's fifth layer, `zones` (a line across the neck at each edge, green
  to red by stretch, thicker under pressure; dots at his tip and the swallow wave).
- Info tab: her state by the same groups (gaze, eye, tears, cum in mouth, swallowing, teeth, cough build-up,
  drooling, sweat, wetness build-up, mood, breath, passing out, pace) and his pleasure.

Found while wiring the panel: a veto on upstream's `Her.passOut`, `Her.wakeUp` or `Her.cough` was asked again every
tick, because their callers poll (`animateBreathing`: pass-out factor at the top, breathing again while passed out;
`checkPosition`: the next cough time stays at 0). Fixed in P030 (see the hook table).

Checks: `game/debug/derrdev_checks.gd`.

## Requests to upstream

| Request | Why | Status |
|---|---|---|
| Before hook point on `Her.blink` | See above. | merged (main) |
| `Hooks.Call.cancelled_by` | The event log names who vetoed a call. | done upstream (e6dda3a) |
| `Extensions._disable()` tells shared tables that an extension went off (an event or a callback list) | (was for `channels`, dropped) | not needed: modifiers go with their extension |
| An event when a character code is loaded | (was for `channels`, dropped) | not needed for now |
