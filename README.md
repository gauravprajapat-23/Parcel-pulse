# Parcel Pulse

A small, original, offline-first parcel-routing game built with **Godot 4.x / GDScript**.

## Phase 2B — five maps and offline progression

Five original stages now have different branching graphs, destination placements,
schedules and quotas. Use the left/right arrows on the READY screen to preview
stages. Winning unlocks the next stage and saves best scores/stars offline.
A completed shift offers **NEXT** to select the newly unlocked map, and returning
players resume at their first uncleared stage.
Read [Phase 2 maps and progression](docs/phase2_maps_progression.md) and
[Phase 2B acceptance](docs/phase2b_difficulty_validation.md) for implementation
and verification.

## Gameplay and current features

- Portrait-first layout with procedural roads, packages, junctions and destinations.
- **3–5 tap-to-toggle junctions** across five bundled maps and **3 symbol-coded destinations**: red diamond, blue circle, green triangle.
- Five deterministic stage-specific delivery schedules. Complete 12–16 correct deliveries depending on the map; 3 wrong deliveries end a shift.
- Fixed-physics-tick movement, score, mistakes and results.
- Working PLAY, PAUSE/RESUME, RETRY and EXIT-to-ready controls, a 2×2 mobile button grid, Back navigation and automatic background pause.
- Offline save data for unlocks, best scores and stars; no backend, accounts, third-party assets, ads or subscriptions.
- An optional read-only routing guide highlights the next junction and shows TAP vs READY instructions.
- UI-01A reusable neon theme, three compact HUD cards, and a four-button action bar (PLAY/PAUSE/RESUME, RETRY, GUIDE, EXIT).
- UI-01B procedural night city with three destination houses, depot, curved neon roads, greenery, gold junctions, and animated-position parcel carts.
- UI-01C tap ripples, floating delivery feedback, gently animated route chevrons, original synthesized sound cues with an SFX toggle, and smoother results.
- UI-01D compact Android layouts, safe-area insets, reduced-motion toggle, and capped decorative redraws.
- Dependency-free GDScript regression tests.

## Run locally

Open `project.godot` with Godot 4.3+ and press **F6/F5** to run (F5 runs the main scene). From a terminal:

```bash
godot --path .
```

## Automated test commands

```bash
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/test_phase1.gd
godot --headless --path . --script res://tests/test_ui_smoke.gd
godot --headless --path . --script res://tests/test_guidance.gd
godot --headless --path . --script res://tests/test_ui_design.gd
godot --headless --path . --script res://tests/test_ui_city_board.gd
godot --headless --path . --script res://tests/test_ui_juice.gd
godot --headless --path . --script res://tests/test_ui_responsive.gd
godot --headless --path . --script res://tests/test_phase2_levels.gd
godot --headless --path . --script res://tests/test_phase2b_progression.gd
```

Read the [UI-01D Android release gate](docs/ui_01d_android_release_gate.md), [UI-01C game feel guide](docs/ui_01c_game_feel.md) and [UI-01B city board guide](docs/ui_01b_city_board.md) and [UI-01A design system](docs/ui_01a_design_system.md) for reusable components and its validation checklist. Read [tests/README.md](tests/README.md) for Windows commands and a physical Android smoke-test checklist. The [first-session validation plan](docs/first_session_validation.md) covers the guided tutorial and player comprehension test. The Android debug APK script and preset are documented in [docs/android_verification.md](docs/android_verification.md).

## How to play

1. Press **PLAY**.
2. Watch the live guide (GUIDE ON by default); it highlights the next junction to check. Turn it off anytime.
3. Tap a **golden junction** when the guide says TAP to change its white routing arrow.
4. Guide red diamonds to red, blue circles to blue and green triangles to green.
5. Reach your stage quota (12–16 deliveries) before making 3 mistakes. Winning unlocks the next map.

**RETRY** starts a clean shift, **PAUSE** freezes the scheduler, and **EXIT** abandons the current shift and returns to the ready screen (it does not close the app).

## Architecture

- `scripts/game/board_state.gd` — graph, outgoing routes and junction validity.
- `scripts/game/delivery_parcel.gd` — parcel model and state.
- `scripts/game/route_scheduler.gd` — deterministic spawn schedule.
- `scripts/game/shift_controller.gd` — authoritative simulation, scoring and lifecycle.
- `scripts/ui/board_view.gd` — rendering and input only.
- `scripts/ui/game_screen.gd` — portrait HUD and buttons.
- `scripts/ui/result_screen.gd` — result overlay and actions.

## Current limits

The current build contains five maps, local progression and generated sound effects, but no online services or revenue features. Native Godot import, automated regressions and physical Android touch/performance checks are still unverified here and must pass before a release candidate is declared.

## Recommended next milestone

**Phase 2C — Native Godot regression, Android smoke tests, and observed difficulty tuning.** Fix any real engine errors, collect playtest evidence, then decide whether to add more levels.
