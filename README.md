# Parcel Pulse

A small, original, offline-first parcel-routing game built with **Godot 4.x / GDScript**.

## Phase 1 playable core

- Portrait-first layout with procedural roads, packages, junctions and destinations.
- **3 tap-to-toggle junctions** and **3 symbol-coded destinations**: red diamond, blue circle, green triangle.
- A deterministic 18-parcel delivery schedule. Complete 12 correct deliveries to win; 3 wrong deliveries end a shift.
- Fixed-physics-tick movement, score, mistakes and results.
- Working PLAY, PAUSE/RESUME, RETRY and EXIT-to-ready controls, a 2×2 mobile button grid, Back navigation and automatic background pause.
- Local state only: no backend, no accounts, no third-party assets, no ads, no subscriptions.
- An optional read-only routing guide highlights the next junction and shows TAP vs READY instructions.
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
```

Read [tests/README.md](tests/README.md) for Windows commands and a physical Android smoke-test checklist. The [first-session validation plan](docs/first_session_validation.md) covers the guided tutorial and player comprehension test. The Android debug APK script and preset are documented in [docs/android_verification.md](docs/android_verification.md).

## How to play

1. Press **PLAY**.
2. Watch the live guide (GUIDE ON by default); it highlights the next junction to check. Turn it off anytime.
3. Tap a **golden junction** when the guide says TAP to change its white routing arrow.
4. Guide red diamonds to red, blue circles to blue and green triangles to green.
5. Get 12 right before making 3 mistakes.

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

This is an early vertical slice. It has one fixed board, one verified schedule, no sound, no persistence and no revenue features. The game must pass headless Godot validation and a real Android touch test before it is called release-ready.

## Planned Phase 2

Tutorial clarity, difficulty and timing balance, more route layouts, visual/audio polish and a progression prototype — **after Phase 1 is validated**.
