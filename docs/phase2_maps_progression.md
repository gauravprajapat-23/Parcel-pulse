# Phase 2 — Additional maps, stages and offline progression

**Implementation:** three local maps, per-map schedules/quotas, a READY-screen stage preview, sequential unlocks, best score/three-star records and a persistent offline save. **Native Godot and Android verification still required.**

## Current stages

| Stage | Map | Graph difference | Quota | Spawn interval |
| --- | --- | --- | ---: | ---: |
| 1 | Old Town | Original three-junction board, with Red left / Blue middle / Green right | 12 | 2.45 s |
| 2 | Mirror Market | Red and Green exchange sides; switch destination order changes | 13 | 2.30 s |
| 3 | Canal Crossing | Adds a fourth switch (`upper`), extra junction path for Blue/Green | 14 | 2.15 s |

All stages use the original offline one-touch mechanic, color+symbol destination identity, three-mistake limit and 100 points per correct delivery. Each stage has its own deterministic schedule with enough extra parcels to allow two mistakes before the completion quota becomes impossible. No ads, accounts, payments or backend.

### Unlocking and records

- On a fresh install: only Stage 1 is playable. Use the arrows above the board to preview other stages; a locked stage displays **LOCKED** and its PLAY control cannot start it.
- Completing a stage unlocks the next. Failure does not unlock a stage.
- Each stage records **best score** and **best stars** (3 minus mistakes, minimum 1 for a win). Replays never reduce an existing record.
- Records persist in a versioned JSON file at `user://parcel_pulse_progress.json`. Writes are flushed to a temporary file and renamed over the previous file. On an invalid or incompatible file, the game falls back safely to Stage 1.
- Restarting or leaving a running shift does not clear unlocked stages. Loading an old Phase 1 installation with no save creates a fresh Stage 1 profile.
- Manual exports, cloud saves, login and inventory/currency progression are deliberately out of scope.

### Architecture

| File | Ownership |
| --- | --- |
| `scripts/game/level_catalog.gd` | Immutable bundled stage definitions, validation and graph reachability |
| `scripts/game/board_state.gd` | Current graph and switch states, `map_changed` signal |
| `scripts/game/route_scheduler.gd` | Per-stage deterministic parcel timing |
| `scripts/game/shift_controller.gd` | Game rules, stage selection and quotas |
| `scripts/game/progress_store.gd` | Save schema, validation, unlock rules, best records and disk I/O |
| `scripts/ui/routing_coach.gd` | Generalized read-only route advice on the current graph |
| `scripts/ui/city_board_*.gd` | Houses, roads, carts and glows use the selected map |
| `scripts/ui/game_screen.gd` | Stage preview UI and gate enforcement; saves progress after actual wins |
| `tests/test_phase2_levels.gd` | Graph/route/progression/save/UI regressions |

The original `BoardState.NODES`, `BoardState.EDGES`, `RouteScheduler.SCHEDULE` and `ShiftController.REQUIRED_DELIVERIES` are maintained as Level 1 defaults for Phase 1 regression compatibility. UI displays read the controller's active quota.

## Local verification

Run in Windows PowerShell from your local repository root:

```powershell
git switch main
git pull --ff-only origin main

$godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"
& $godot --headless --path . --editor --import --quit
if ($LASTEXITCODE -ne 0) { throw "Godot import failed" }

& $godot --headless --path . --script res://tests/test_phase2_levels.gd
if ($LASTEXITCODE -ne 0) { throw "Phase 2 regressions failed" }

# All existing tests + Phase 2, without Android SDK/export:
.\tools\build_android_debug.ps1 -TestsOnly -GodotExe $godot

# Open game:
& $godot --path .
```

All test-created saves are isolated from the player's normal `user://parcel_pulse_progress.json`.

For a debug APK, configure Godot Android export templates and Android SDK then run `tools/build_android_debug.ps1` without `-TestsOnly`.

## Required manual Android acceptance

1. Start offline with a new save: Stage 1 playable, Stages 2 and 3 locked.
2. Preview each map before starting it. Verify the destination house positions, junction count and highlighted selected roads differ; the fourth switch on Stage 3 is tappable.
3. Route parcels for correct deliveries; verify quota 12/13/14 displays on the HUD and game results.
4. Lose three times on Stage 1. Check Stage 2 remains locked.
5. Win Stage 1; return to selection; start Stage 2. Check the best score and stars appear for Stage 1.
6. Win Stage 2 and unlock Stage 3. Exit app, launch offline again and verify unlocks and records survive.
7. Replay Stage 1 with a lower score, confirm the prior high score is not lost.
8. Test Pause, Resume, Retry, background and Android Back while playing alternate maps.
9. Confirm no missing streets, clipping, wrong-house markings or mislabeled routing hints.
10. Keep performance acceptable on a low-end device, with a full Stage 3 shift and screenshots.

**Do not declare Phase 2 release-ready until local Godot import and all test suites pass, debug APK exports, and manual phone QA completes.**

## Follow-on iteration

Phase 2B: playtest difficulty, tutorial transitions, themed environmental art, 5–10 additional validated boards, and level-select polish based on measured feedback. Avoid complexity before verifying three playable maps.
