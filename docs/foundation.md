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
| `Her.swallow` | after (args: `[intensity, speak]`, result: whether the swallow started) | P048 | The before point is asked on every request, also those the game drops (she is already swallowing, speaking or passed out); the after point tells which started. For the swallow queue and the event log. | ours (P048) |
| `Her.gulp` | before (args: `[]`, can cancel) and after | P048 | The moment she swallows (squint, sound, the wave down her neck, what leaves her mouth) was inside the jaw update; it is now `Her.gulp()`, same order, so it has its own point. Vetoed: no gulp this swallow; the swallow's motion still plays. | ours (P048) |
| `Her.releaseTeeth` | before (args: `[]`, can cancel) and after | P054 | New port function: she unclenches her teeth now (the game ends a clench only by its time, her speaking or a mood change). Vetoed: they stay clenched. | ours (P054) |
| `Tongue.startMovingTongue` | before (args: `[dir]` "out" / "in", can cancel; args can be changed) | P055 | Her tongue asked to come out or go in (near his tip, licks, when he comes, hanging out, the Tongue option). Vetoed: it does not move; nothing else changes. | ours (P055) |

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
- Sections come from `DevSchema` (`game/src/menu/dev_schema.gd`): `dev_tools` (workbench; the Log since P050),
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
  P051: Mouth tab rows "Gulp" (`Her.gulp`, P048: its switch vetoes the gulp, so swallows play without it) and
  "Gulp, no squint" (one gulp with `Her.swallowWince` false, a FINAL modifier for the call's length).
  P054: Mouth tab row "Release teeth" (`Her.releaseTeeth`) and the tabs' hand settings (`DevTuning`,
  `game/src/menu/dev_tuning.gd`, under a tab's rows): modifiers owned `devtuning` on the game's value points while a
  setting is not the game's, for this session only (the game's again at the next start, Developer mode on or not).
  Mouth: "Clench time" (0 = the game's 2..6 s at random; else that many seconds, `Her.clenchTime`), "Taps when
  clenching" (off: `Her.clenchTaps` false). The event log writes her clenching and unclenching.
  P055: Mouth tab rows "Tongue out" (`Tongue.startMovingTongue`; its switch vetoes only "out": an entry's optional
  sixth element is `fn(call) -> bool`, which of the hook's calls the switch vetoes), "Hang tongue out" and "Tongue in"
  (no automation). The event log writes her tongue coming out and going in (held 15 ticks).
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
  at +0.005 / -0.05 as seen in the game; P036: Tie +0.04 / -0.085, Gem Choker +0.03 / -0.03). Each tick a ring gets pressure from his width past its top edge, more while he pushes in, and from the
  swallow wave inside it; under pressure it stretches and wears down (would snap at 0), at rest it recovers. It is
  ticked by the throatresiststretch extension while Developer mode is on and changes nothing in the game; later
  stages give its stretch and hold to the throat resistance and bulge through value points and take over that
  extension's counter and the collar mods (sby's chokercollarresistance and its addon). Shown in the Body tab
  (values, collar controls) and by the overlay's fifth layer, `zones` (a line across the neck at each edge, green
  to red by stretch, thicker under pressure; dots at his tip and the swallow wave).
- Tools › Log (P050, `game/src/menu/dev_journal.gd` class `Journal`, the card `dev_journal_tab.gd`): the event log.
  Read only, and only while Developer mode is on (`DevMenu.apply_mode` -> `Journal.sync`; its handlers have owner
  `journal` and go when the mode goes off). Sources: the behaviour tabs' observer (`DevBehaviour` passes each call to
  `Journal.observed`; at the end of the tick a veto is a line naming who, a run is a line for cough, open-mouth cough,
  clenching her teeth, passing out, waking up and his ejaculation); after points `Her.swallow` (priority -100000:
  started, or dropped and why), `Her.gulp` (how much it took, read after the extensions' tick), `Him.nextSpurt`
  (where), `Dialogue.startSpeakingPhrase` (the line); a last before handler on `Her.lastSpurt`; states compared once
  per tick after the game (`Flash.tick_after`): in her mouth, past her throat entrance (depth 150), mouth full, the
  collar holding / snapping (while the rings were worked out that tick), holding her breath, out of breath (past
  `outOfBreathPoint`), no air left, mood, hand mode, auto mode. A state's new value must hold 15 ticks before it is a
  line, so strokes that only touch her lips and her breath level shaking at a threshold make none (mood, hand,
  auto, swallow end, mouth full, collar snapped: at once). Extensions write with `Journal.log(group, text)` (a no-op
  while it is off or paused); throatcumbulge writes its queue (queued / full / from the queue / cleared and why).
  The same line again right away folds into "x N"; the last 500 lines are kept. Groups: Swallowing, Mouth, Breath,
  Him, Other (filter buttons). The card shows newest first; Copy (shown groups) and Save (`<save dir>/journal/`,
  everything) give oldest first. It has no listeners: extensions react through Hooks. Wince is left out (it fires
  every tick of a swallow).
- Tools › Her (P053, `DevSchema._her_tools`): "Air" (`g.breathLevelMax`, the game's 50; `outOfBreathPoint` kept at
  half of it), "Oxygen" (before passing out: `Her.passOutMax`, 40: about 27 s with no air), each with ↺ to the game's, and
  "Air now" / "Oxygen now" (the current levels in %, as DialogueActions' breath / oxygen). A test tool:
  it writes the game's numbers for this session only (back at the next start), not through value points.
- Menu cards fold and reset (P052, `game/src/menu/menu_fold.gd`, in upstream's `SDTMenu._build_view`): a section
  that has `"fold": {group title: folded at first}` (only Behaviour for now: Resistance and Reactions folded at
  first) gets ▸/▾ on each card's heading (a click on the heading too), the number of its settings while folded, and
  the state in `port.cfg` `menu_fold/<section>/<group>`. ↺ on the heading, pressed twice within 3 s, sets every
  setting of the card back: the game's sliders through their own default buttons (`reset`), extension settings to
  their declared default (`MenuSchema.setting_control` adds `restore`), the game's checkboxes to its starting values
  (`"default": true` on Breathing, Coughing, Gagging, Tongue: all on in `g.gd`), the collar's stiffness (0.6) and
  resistance (0.18). "Reset resistance for each character" has no default and is left alone. Search results never
  fold.
- Info tab: her state by the same groups (gaze, eye, tears, cum in mouth, swallowing, teeth, cough build-up,
  drooling, sweat, wetness build-up, mood, breath, passing out, pace) and his pleasure.

Found while wiring the panel: a veto on upstream's `Her.passOut`, `Her.wakeUp` or `Her.cough` was asked again every
tick, because their callers poll (`animateBreathing`: pass-out factor at the top, breathing again while passed out;
`checkPosition`: the next cough time stays at 0). Fixed in P030 (see the hook table).

Checks: `game/debug/derrdev_checks.gd`.

## Value points (upstream's `Hooks.value`; ours since P038, on his core since P047)

Numbers the game reads every tick that extensions change through modifiers instead of writing the game's variable
themselves: upstream's value points (`Hooks.value`, `modify()`, phases GENERATE -> MOOD -> OVERRIDE -> CLAMP ->
FINAL; see his `docs/extensions.md`, "Value points"). P038 started with a small copy of his design (`ValuePoints`);
P047 moved everything onto his core and removed the copy. Our points are marked `# HOOK value point (derrdev)` in
game code; the ring extensions add `op: "fn"` modifiers (MOOD, the collar's band CLAMP) and keep their ids to
remove them when a setting goes off (`_drop_mods()`); all of an extension's modifiers go when it is switched off.

| Point | Where | The game's number |
|---|---|---|
| `Neck.throatBulge` | `Neck.render` | her throat bulge setting (`throatBulgeAmount`) |
| `Neck.bulgeCap` | `Neck.render` | 35 (px the bulge pushes the neck out at most) |
| `Her.resistance` | `Her.move`, while he pushes in | `previousResistance` (checkPosition's zones) |
| `Her.pushBack` | `Her.move`, after the intro push | 0 (pos pushed back per tick) |
| `Her.limpResistance` | `Her.move`, while she is passed out and he pushes in (P046) | 0 (the game holds nothing then) |
| `Neck.depth` | `Neck.render` (P039) | his depth / 400 (where the throat bulge sits) |
| `Neck.pointBulge` | `Neck.render`, per front outline point (P041; `Neck.bulgePointDepth` = that point's depth) | how far the point pushes out (px) |
| `Her.swallowSpeed` | `Her.swallow`, when a swallow starts (P048) | 1 (the four phases' lengths are divided by it, at least 1 tick apart) |
| `Her.swallowWince` | `Her.gulp` and `tickSwallowing` (P048) | true (she squints around the swallow) |
| `Her.clenchTime` | `Her.startClenchingTeeth` (P054) | 60..179 ticks at random (how long she keeps them clenched) |
| `Her.clenchTaps` | `Her.startClenchingTeeth` (P054) | true (she taps him as she clenches) |
| `Her.teethClosing` | `Her.updateLips`, while she clenches (P054) | true (her teeth close 0.2 a tick; false holds them) |

The developer panel (Body > Throat rings) shows who modifies each point and the value used last (`Hooks.explain`).

## Loader mods ported here (local branch `rings`, not pushed until upstream agrees)

- `penisrange` (P035, `game/src/ext/penisrange/penisrange.gd`, sby's penisrangeV8): Him > Penis > "Extended size
  range", off by default. Widens `Him.MIN/MAX_PENIS_SIZE` and `MIN/MAX_BALL_SIZE` (made static vars for this; the
  game's values unchanged): largest size 3 (setting), smallest the game's / 2 (setting), balls likewise. While a size
  is outside the game's range: the mask follows how far his tip is past her lips, the in-mouth constraint smoothing
  eases off for big sizes, big balls move down and back. Off again: the game's limits, sizes clamped back. Not
  taken: the per-character size file, the tilt options, the strap-on colour field.
  Limits of the game's geometry (tested): past a length of about 2 his tip is past her lips even with her head all
  the way back, so she takes him as poking her face; auto mode gets stuck with a long penis; the neck's bulge stops
  at 35 px.
- The throat ring model (P033/P034, see the Developer mode section) inside upstream's `throatresiststretch`. P039: its
  "Throat loosens" is the throat entrance ring (the mod's counter and its second neck render are gone): the ring's
  stretch lowers the entrance's share of `Her.resistance` and keeps `Neck.depth` at least at the stretch; "Throat
  recovers" sets how fast it tightens back (0.25: about 90 s from fully loose). Her throat resistance setting is
  never changed.
- `chokercollarresistance` (P040, new built-in, after sby's chokercollarresistanceV4, on the collar ring): Behaviour >
  Resistance > "Collar holds her throat", off by default. While she wears a collar: `Her.pushBack` past the collar's
  top edge (0.0015 pos per px past it x what the ring holds, like the intro limit), `Her.resistance` + 0.15 x hold
  past it; P041: `Neck.pointBulge` clamped between the collar's edges to 2 px (+ up to 17.5 px as it stretches, if its
  picture widens), rising over a 0.04 step past each edge - her neck bulges above and below the collar, held in by
  the band (P040 clamped `Neck.depth` at the top edge instead).
  P042: "Collar stretches" - her throat pushes the collar's front out (measured from the drawn neck under the band)
  and the picture follows with a lag (0.15 of the way per tick), up to the ring's room (stretch x 17.5 px); her
  throat may press 3 px into it first; the back edge (her nape) stays put. Settles back when her throat does.
  P043 (simpler): the collar's front is a spring pushed by her throat (pull 0.2 per px per tick, 30 % of its speed
  lost per tick: it lags, overshoots a little, settles); one "Collar stiffness" (0 soft band .. 1 metal, `port.cfg`
  `throat_rings/stiffness`, quick buttons Band 0.2 / Leather 0.6 / Metal 1.0) for every collar instead of a material
  and tightness per collar: tightness 0.35 + 0.5 k, ring stiffness k, durability 60..300, unbreakable from 0.95.
  `ThroatRings.collar_tags[name]`: what the picture does not tell - `band` (edge fit; the game's three collars),
  `stiffness` (its own), `can_snap`; collars loaded from mods are to add theirs (no loader yet). Rule for collar
  pictures: the picture is the band. The hand edge fit stays in Developer mode.
  "Collar stretches": the collar's picture widens with the stretch (x1.25 at full, as the mod); "Wince when it
  holds". Collar material and tightness in the same group, kept for each collar (`port.cfg` `throat_rings`). Pressure
  from what he does, not the mouse button. Not yet: the "collarresistance" line, the intro breath option, reactions
  when a collar snaps.
  P044 (after playing it): the collar holds like her throat entrance - `Her.resistance` rises across its band from 0
  at the top edge to 0.3 x hold at the bottom edge (the game's throat: 0.2 at resistance 100), then only a 0.03 x hold
  squeeze; `Her.pushBack` only while he is in the band (no more than the band's height). Tightness = k (0 holds
  nothing). The front gives 6 x (1 - k) / k px at once (plus the stretch's 17.5 px), so a soft collar moves with the
  first push; k = 0 or snapped: the collar rides along with her neck, no limit on the neck, nothing held. Spring
  pull 1.0 per px per tick, 60 % of its speed lost per tick (there in about 3 ticks, ~12 % overshoot). "Collar can
  break" (off by default; then every collar is unbreakable): `ThroatRings.collar_breaks`; a snapped collar rides
  free until "Repair collar", another collar or another stiffness. Past each edge the held outline blends into the
  free bulge over 0.08 depth (smoothstep), not a fixed px step, so big bulges keep a round step.
  P046: the wall has its own setting, "Collar resistance" 0..0.3 (`ThroatRings.collar_wall`, `port.cfg`
  `throat_rings/wall`): setting the stiffness or a quick button sets it to 0.3 x stiffness, then it can be set apart.
  The wall is the setting less the ring's stretch, rising across the band, 10 % of it past the bottom edge. While she
  is passed out the game applies no resistance at all; the new value point `Her.limpResistance` (`Her.move`, passed
  out, 0 in the game) carries the collar's wall then, so the collar no longer lets go when she passes out.
- `tongueguard` (P055, new built-in, a fix of the game; Behaviour > Reactions > "Tongue in when she clenches her
  teeth", on by default). Measured in the game (30 fps, her tongue out, then she clenches her teeth): her teeth are
  closed over her tongue for 33 ticks (it comes in at 39), 55+ ticks with it hanging out (it never comes in:
  `Tongue.moveTongueIn` turns back out at once while `hangingOut`), 32 in a long lick (the move in waits for the action
  playing). With the fix: 0 in all three, her tongue in at 8-9 ticks after she clenches. While her teeth are clenched
  or still opening, a before handler on `Tongue.update` (priority -50) skips the tongue's own update and moves it in
  4 frames a tick (the game's fast in) to `InDone`, as the game's move in ends (no licks meanwhile); `Her.teethClosing`
  (CLAMP) holds her teeth until it is in, at most 12 ticks. Her teeth open again and she hangs it out: out again.
- `throatcumbulge` "Neck follows his size" (P040): `Neck.bulgeCap` = 35 x his width (the game: 35 for every width).
- Swallowing (P037, stage 2 of the throat ring plan) inside upstream's `throatcumbulge`, after sby's swallowguzzleV2
  but on the game's own `Her.swallow` (the veto and the developer panel's switch apply), all off by default: "Swallow
  until empty" (a swallow that ends with cum left and her mouth free starts another), "Swallow while he cums" (Off /
  When full: more than half / Always; on `Him.nextSpurt`, in her mouth, not held deep, not already swallowing), "Per
  swallow" (0 = the game's 5-9; set from the wave's first tick, when the game has just taken its share), and swallow
  bulge mode "By amount" (the wave follows how much she swallowed: 10 = the largest of "By swallow"). Extra swallows
  pass speak = false (no SWALLOW line each time).
  P049, on P048's swallow points, the game's way by default: "Swallow queue" 0..5 (Her.swallow's after point,
  registered only while it is above 0: a swallow asked for while she swallows - a spurt with "Swallow while he
  cums", `Her.ejaculating`, the dialogue, the key, another extension - waits, up to that many; each starts "Pause
  between swallows" ticks (8) after the last one ended; passing out or speaking clears the queue; "Dry swallows" on:
  the series goes on with her mouth empty, off: an empty mouth ends it), "Swallow speed" 0.5..2 (`Her.swallowSpeed`,
  MOOD, x the setting), "Squint when swallowing" (off: `Her.swallowWince` false, OVERRIDE). Live (30 fps, 4 swallows
  asked at once): queue 0 - one swallow; queue 3 - four, gulps at ticks 37 / 104 / 158 / 208; speed 2 - 19 / 55 / 86 /
  121; dry off - one (her mouth was empty after it).

## Requests to upstream

| Request | Why | Status |
|---|---|---|
| Before hook point on `Her.blink` | See above. | merged (main) |
| `Hooks.Call.cancelled_by` | The event log names who vetoed a call. | done upstream (e6dda3a) |
| `Extensions._disable()` tells shared tables that an extension went off (an event or a callback list) | (was for `channels`, dropped) | not needed: modifiers go with their extension |
| `Him` size limits as static vars, not constants | Extensions widen them (penisrange). | ours (P035), to send with it |
| An event when a character code is loaded | (was for `channels`, dropped) | not needed for now |

P047 (27 October): the rings moved onto upstream's value points - `ValuePoints` and `SDTExtension.value_point()`
removed, the game code's points ask `Hooks.has_value` / `Hooks.value(name, obj, v)`, the extensions `modify()` with
`op: "fn"` modifiers (handlers `fn(v, obj)`), the developer panel reads `Hooks.explain`. Nothing else changes.
