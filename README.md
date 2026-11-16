# Wizard Destruction Sandbox

First-person magic destruction sandbox for **Godot 4.x (Forward+)**, Windows PC.
No enemies, no mana, no cooldowns: five spells and a village to flatten.

## Launch

1. Install Godot 4.3 or newer (standard build; 4.2 should also work).
2. In the Project Manager choose **Import**, select `project.godot` in this folder, then **Import & Edit**.
3. Press **F5**. The startup scene is `res://scenes/main.tscn`.

Startup takes a couple of seconds while the sound set is synthesized.

Headless check (optional): `godot --headless --path . --import` then `godot --headless --path . --quit-after 120`.

## Controls

| Action | Keyboard / mouse | Controller (Xbox layout) |
|---|---|---|
| Move | WASD | Left stick |
| Look | Mouse | Right stick |
| Sprint | Shift (hold) | B (hold) or L3 (toggle) |
| Jump | Space (tap) | A (tap) |
| Fly | Hold Space (ascend), release to hover, Ctrl descends, Shift faster | Hold A (ascend), release to hover, B descends, L3 faster |
| Select spell | 1-5, mouse wheel | LB / RB, D-pad left / right |
| Cast | Left click | RT (or X) |
| Reset world | R | Y |
| Pause | Esc | Start (B also resumes) |

Tap jump for a normal hop. Hold jump for a short moment after leaving the ground to levitate. In the air, release jump to hover at that height, hold jump to climb, and hold descend to drop. Touching walkable ground while descending lands and returns to walking. Flight does not spend mana or stamina, and it does not change spell damage, effects, audio or cooldowns. Casting works the same in the air. On a controller, B is sprint on the ground and descend in the air; left-stick click toggles sprint on the ground and flies faster while held in the air.

Hold cast for **Thunder God** (continuous strikes) and **Inferno** (the tornado grows and follows your aim).
Controller extras: vibration on casts and blasts, stick sensitivity, invert-Y and vibration toggle in the pause menu, which is fully navigable with D-pad / stick and A. HUD prompts switch automatically to the device you last touched.

## Spells

1. **Cataclysm** - fireball projectile, mini-nuke detonation.
2. **Thunder God** - branching sky bolts, ground impacts, chain arcs to nearby pieces.
3. **Gravity Well** - singularity that strips buildings piece by piece, swallows them, collapses to a point and detonates.
4. **Inferno** - fire tornado that grows while held, then lingers and burns out.
5. **Meteor** - 3.3 s visible descent with fragments, then a catastrophic impact.

## Project layout

- `scripts/core/input_setup.gd` - all input actions (registered in code at startup), device detection, rumble.
- `scripts/audio/audio_manager.gd` - buses (Master, SFX, Ambience) and synthesized sounds.
- `scripts/destruction/` - `piece.gd`, `structure.gd`, `destruction_manager.gd` (autoload `DM`).
- `scripts/world/village_builder.gd` - procedural pre-fractured village.
- `scripts/fx/` - `fx.gd` (autoload `FX`) and `lightning_bolt.gd`; `shaders/` holds the effect shaders.
- `scripts/spells/` - caster plus one script per spell.
- `scripts/player/player.gd`, `scripts/ui/hud.gd`, `scripts/main.gd`.

Collision layers: 1 world, 2 intact structure pieces, 3 player, 4 loose debris.
The player does not collide with loose debris (so rubble can never trap you); debris collides with everything else.

## Destruction model

- Every building is a set of frozen rigid-body sections with health and a support graph.
- Damage breaks sections loose; anything left without support falls shortly after (secondary collapse).
- Overkill damage shatters a section into up to eight smaller fragments.
- All spells use the same three calls on `DM`: `explode()`, `attract()`, `touch_area()`.
- A structure restores 180 s after it first loses a piece, but never while a spell touched it in the last 4 s or while the player is standing in it.

## Practical limits (by design, casting is never blocked)

- Loose debris budget: 650 bodies. Beyond that the oldest pieces shrink away. Sleeping debris older than 75 s is also removed.
- Fragment shattering stops near the debris budget (sections still break loose whole).
- Secondary particle layers (embers, lingering fire and smoke, smoke column) are skipped while more than 90 bursts are active.
- Scorch decals: 40 most recent. Positional one-shot sound voices: 28 (oldest is reused).
- Thunder auto-repeats about 9 strikes per second while held.

## Verification status

Written without access to a Godot executable: no headless import, parse check or graphical run has been performed. Expect to fix a few first-run script or shader errors, and treat all visual and audio tuning as unverified.

## Enchanted night overhaul (Phase A)

- Night sky with stars, cool moonlight from behind the village, purple mist, drifting magical motes.
- Restyled palette for every stone, plaster, timber, roof, cloth and foliage material; cobblestone plaza and road.
- `Decor` autoload (`scripts/world/decor.gd`): window, lantern, crystal, finial, curl, rune, sign. Decorations are visual-only children of one destructible piece (`structure.decorate()` picks the nearest), so they follow it, vanish with it and return on rebuild. Lights on a loosened piece fade out.
- Decorated so far: all six houses, the tower and the gate. Not yet: perimeter walls, colonnades, well, stalls, fences, crates, barrels, trees.
- Piece specs, health, support graph, collision, spells, audio and input are unchanged. Baseline is tagged `baseline-v1` in Git.
