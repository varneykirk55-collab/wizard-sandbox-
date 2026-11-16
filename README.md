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
| Jump | Space | A |
| Select spell | 1-5, mouse wheel | LB / RB, D-pad left / right |
| Cast | Left click | RT (or X) |
| Reset world | R | Y |
| Pause | Esc | Start (B also resumes) |

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

The original sandbox was first written without a Godot executable. The village expansion below was checked with Godot 4.3 stable: headless import, a headless load of `scenes/main.tscn`, and an opt-in budget script (`VILLAGE_AUDIT=1`). See that section for the counts. Frame rate on player hardware was not measured.

## Enchanted night overhaul (Phase A)

- Night sky with stars, cool moonlight from behind the village, purple mist, drifting magical motes.
- Restyled palette for every stone, plaster, timber, roof, cloth and foliage material; cobblestone plaza and road.
- `Decor` autoload (`scripts/world/decor.gd`): window, lantern, crystal, finial, curl, rune, sign. Decorations are visual-only children of one destructible piece (`structure.decorate()` picks the nearest), so they follow it, vanish with it and return on rebuild. Lights on a loosened piece fade out.
- Decorated so far: all six houses, the tower and the gate. Not yet: perimeter walls, colonnades, well, stalls, fences, crates, barrels, trees.
- Piece specs, health, support graph, collision, spells, audio and input are unchanged. Baseline is tagged `baseline-v1` in Git.

## Village expansion

New districts are added inside the existing tree line and north wall. The original plaza, houses, great tower, gate and road are unchanged.

- **Residential lanes** (east and west of the plaza): 4 timber-and-stone cottages with curved roofs, glowing windows, lanterns and rune marks, plus yard walls, lantern posts and crystal clusters.
- **Marketplace** (both sides of the south road): 2 enchanted shops, 6 market stalls, 2 stone arches, paving and crystal clusters.
- **Wizard tower court** (inside the north wall): 2 small spires, 2 workshops with furnaces, a processional arch, crenellated garden walls, lantern posts and crystal clusters.
- Paths, shrubs and 4 trees fill the gaps between those districts.

Every new building, stall, wall, arch, cluster, post, shrub and tree is a `Structure` registered with `DM`, so roofs, walls and supports break, collapse, and rebuild on the existing 180 s timer. Decorations are attached with `decorate()` and ride the piece they are parented to. Crystal shards use emissive materials and are not extra real-time lights. New omni lights are the lanterns only.

Opt-in check (prints counts, support gaps, overlaps, and a one-shot explode on one cottage and one cluster):

`VILLAGE_AUDIT=1 godot --headless --path . --quit-after 3`
