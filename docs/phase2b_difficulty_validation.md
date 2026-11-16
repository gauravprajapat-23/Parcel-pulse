# Phase 2B — Difficulty, New Maps & Level Selection

**Status:** Source committed and statically reviewed. Godot headless execution and Android device QA are still required.

## What has shipped in source

Five original, offline graph-based maps with independent routing, destination positions, spawn schedules and quotas. Stages 4 and 5 extend the three-map Phase 2 foundation with additional junction choices.

| Stage | Name | Level difficulty | Junctions | Quota | Spawn interval |
| ---: | --- | --- | ---: | ---: | ---: |
| 1 | Old Town | Intro | 3 | 12 | 2.45 sec |
| 2 | Mirror Market | Easy | 3 | 13 | 2.30 sec |
| 3 | Canal Crossing | Moderate | 4 | 14 | 2.15 sec |
| 4 | Riverside Switch | Tricky | 4 | 15 | 2.10 sec (Phase 2C) |
| 5 | Beacon Docks | Expert | 5 | 16 | 2.05 sec (Phase 2C) |

The routing graph remains deterministic. The mistake limit remains three; monetization, multiplayer and accounts remain absent.

## Level selection improvements

- One compact READY-screen strip shows **Stage n/5**, stage name and a second row for difficulty/quota, or the player's best stars and score.
- Locked stages can be previewed but cannot be started, including when calling the controller through the existing UI.
- On first app start the initial stage is selected. Returning players are directed to the first unlocked, uncleared stage.
- Success results show **NEXT** when the following stage is unlocked. This returns to READY with the new stage preview loaded, rather than auto-playing unexpectedly.
- **PLAY AGAIN** and **LEVELS** remain functional; on the final map, NEXT is hidden.
- The save version remains v1: previous three-stage unlocks and best records survive the update; no destructive migration needed.
- New stage palettes use original dark blue-slate and indigo nighttime colors and retain shape identifiers.

## Balance verification approach

A separate source-data simulation (not Godot) checked that each of the five stage schedules can reach its actual quota with zero mistakes when an ideal routing player chooses legal routes. This confirms logical feasibility under one test strategy, **not** measured human difficulty or native-engine correctness.

The headless suite `tests/test_phase2b_progression.gd` attempts a full, real-controller run for all five stages at a physics-sized time step, with no synthetic score changes. It also checks difficulty increments, stored records, locked-stage guards, result NEXT navigation and a saved returning-player session.

## Run on Windows

```powershell
cd "C:\Users\gauravp\Projects\Parcel-pulse"
git switch main
git pull --ff-only origin main

$godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"

# Import + all core, UI and Phase 2A/2B suites, without Android SDK:
.\tools\build_android_debug.ps1 -TestsOnly -GodotExe $godot

# Launch game and inspect each map:
& $godot --path .

# After configuring Android export templates and SDK:
.\tools\build_android_debug.ps1 -GodotExe $godot
```

The build script exits on failure and does not invoke GitHub Actions.

## Manual device gate — pending

1. On a new installation, ensure Stage 1 is ready and Stages 2–5 display LOCKED; preview all map topologies and palettes.
2. Win Stage 1 and use NEXT directly from the result card. Confirm Stage 2 selection without unrequested autoplay.
3. Win through Stage 5, checking each 12–16 parcel quota, current-stage score, stars, and exact unlock rules.
4. Close and restart the game offline; verify the first uncleared stage resumes automatically and old high scores remain unchanged.
5. Test a poor replay after a three-star clear: best stars/score must not regress.
6. On a 360×780 Android phone, confirm all 5 switches on Beacon Docks remain independently tappable and never overlap the bottom action grid.
7. Check Level 4/5 roofs, roads, chevrons and carts for clipping; compare screen captures against the approved UI design.
8. Observe actual player comprehension and mistake rates. Suggested playtest sample: 5–10 new users. Do not treat simulated zero-mistake runs as user retention.
9. Complete the full headless suite, APK export, and a physical-device smoke pass before calling the release gate green.

**Next after native verification:** Phase 2C — Tune real-user difficulty and add only the maps supported by playtest results.
