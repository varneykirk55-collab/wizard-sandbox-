# Magical flight — integration notes

Flight is a new controller (`scripts/player/flight.gd`) called from the wizard.
It does not replace walking, jumping, aiming, or spell casting. There is no
mana, stamina, duration, or cooldown.

Other work in progress owns the wizard's hands/staff and the village. This
change does not edit decoration meshes, shaders, village generation, or spell
scripts. Shared scripts that did change are listed below — please keep these
hooks if you touch the same lines.

## Controls

Ground (unchanged, plus the hold):

- Tap A / Space: jump.
- Hold A / Space past ~0.17s while airborne: the jump becomes flight.
- B / Shift: sprint. L3 toggles sprint. Look and cast are unchanged.

Flight:

- Hold A / Space: ascend. Release: hover (vertical speed is forced to 0).
- Hold B / Ctrl: descend. If ascend and descend are both held, ascend wins,
  so a sprint button still held from takeoff does not drop you.
- Left stick / WASD: horizontal move, camera-relative, with smooth accel.
- L3 or Shift held: faster flight. L3 does not toggle ground sprint while flying.
- RT / X / left click: cast, same path as on the ground.
- Landing happens only while descending onto a walkable surface (slide contact,
  or a very short downward probe). Hovering near terrain does not land.
- After landing, flight does not restart until the ascend button is released
  and held again. Walking accel eases back in over ~0.45s.

## Shared scripts

### `scripts/player/player.gd`

The hands/staff owner should expect these hooks and leave them in place:

- `_flight` is created at the end of `_ready`. `_build_hands`, `_make_hand`,
  and `_part` are unchanged.
- `_unhandled_input`: L3 sprint toggle is ignored while `_flight.active`.
- `_process`: the walk-bob vector is multiplied by 0.3 while flying so the
  viewmodel does not bob like a camera shake. Camera position and rotation
  are still only pitch + the existing trauma shake. Flight adds no camera offset.
- `_physics_process`: if `_flight.physics_step` returns true it has already
  written `velocity` and the original ground/jump block is skipped. Otherwise
  that block is the original one, plus `soften_ground_accel` (identity when
  not just landed) and a one-frame `suppress_gravity` after touchdown.
  `move_and_slide` then `_flight.after_slide`. The y < -30 rescue calls
  `_flight.force_ground` before the existing teleport.
- Cast block under that is unchanged. `is_flying()` is public for the HUD.

### `scripts/core/input_setup.gd`

New actions, registered next to jump and sprint:

- `descend`: Ctrl, and joypad B. B is still also `sprint` (ground) and the
  pause menu still reads the B button directly to resume.
- `fly_boost`: Shift, and left-stick click. Shift is still also `sprint`.
  Left-stick click is still also `sprint_toggle`.

Do not bind B to anything that must stay free during flight; flight treats
`descend` as "go down".

### `scripts/audio/audio_manager.gd`

Two new synthesized streams only. Existing generators, buses, and spell
one-shots are unchanged.

- `lift` — short rising whoosh, played once from the player on takeoff.
- `hover` — quiet looping hum, played with `make_loop` on the player and
  stopped on landing. `make_loop` itself was not changed.

### `scripts/ui/hud.gd`

Hint text now mentions flight and swaps while `player.is_flying()` is true.
Pause menu, volume, mouse sensitivity, stick sensitivity, invert-Y, and
rumble are untouched.

## Left alone

`scripts/spells/*`, `scripts/world/village_builder.gd`, `scripts/world/decor.gd`,
`scripts/fx/*`, `scripts/destruction/*`, `scripts/main.gd`, and `shaders/*`.

## Check

`godot --headless --audio-driver Dummy --path . res://scenes/flight_test.tscn`

The test drives actions (not a physical gamepad) and covers tap-vs-hold,
hover stability, near-ground hover, landing, the re-arm latch, ceiling and
wall collision, landing on a structure-layer platform, and casting all five
spells while flying.
