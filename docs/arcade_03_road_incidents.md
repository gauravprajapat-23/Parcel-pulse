# ARCADE-03 — Interactive City Incidents

**Source status:** Committed to `main`. The Godot native regression suite and Android visual/device acceptance are **not verified in this environment**.

## What changes in gameplay

In live Arcade mode, parcels face occasional temporary road disruptions. The player gets an active decision beyond changing switch directions: clear the jam now for a small bonus, or let traffic crawl until the jam expires.

| Mechanic | Behavior |
| --- | --- |
| First incident | Starts after nine running seconds |
| Incident duration | Nine running seconds; automatically clears without penalty |
| Maximum incidents | Two per shift |
| Second incident | After a twelve-second cooldown following the first resolution |
| Affected route | One real directed road ending at a junction |
| Traffic impact | Parcels on that incoming road move at 45% of normal speed |
| Player actions | Tap the amber warning symbol on the street or use the CLEAR button |
| Clear reward | +75 points, once per incident |
| Other systems | No forced mistakes, no blocked paths, no extra lives lost, no network dependency |

An incident never changes `BoardState.edges` or existing route selections. Classic `ShiftController` instances and earlier Arcade tests have incidents disabled unless the caller explicitly opts in. The real `GameScreen` enables them.

The incident timer uses running real-time `delta`. Rush Hour and Focus scale parcel motion/spawns as before, while jam movement applies only to the affected street segment. Pausing freezes the incident clock and disables rescue.

## Visible design

- The affected route glows amber, with a striped road-work marker over its center.
- The bottom-left **CLEAR 9s** button counts down and is enabled only during active gameplay. **FOCUS** stays at the bottom right.
- Tapping the street warning takes precedence over changing the nearby junction; a separate nearest-junction hitbox remains available.
- Both action buttons are at least 48 logical pixels tall, and the narrow-board layout adjusts their minimum width so the buttons don't overlap or block the depot's center.
- Clearing a jam shows a floating **ROAD CLEAR +75** reward, with a short success cue. The top hint text explains what happened.
- Turning off decorative motion does not disable warnings, clearing, or controller scoring.

## Code structure

| Source | Responsibility |
| --- | --- |
| `scripts/game/road_incidents.gd` | Deterministic target road, timers, cooldown and slowdown factor |
| `scripts/game/shift_controller.gd` | Authoritative rescue score and opt-in incident lifecycle |
| `scripts/ui/city_board_overlay.gd` | Amber affected-road highlight and road-work symbol |
| `scripts/ui/board_view.gd` | CLEAR button, marker hit detection, compact-board layout |
| `scripts/ui/game_juice.gd` | Floating rescue reward |
| `scripts/ui/game_screen.gd` | Enables incidents, hints and success sounds |
| `tests/test_arcade_incidents.gd` | Five-map safety, timer, scoring, Pause, Retry, Exit and touch tests |

## Run the complete Godot gate on Windows

```powershell
cd "C:\Users\RSP.tech Solution\Desktop\Parcel-pulse"
git switch main
git pull --ff-only origin main

$godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"

# Import, all older regression tests, and ARCADE-03:
.\tools\build_android_debug.ps1 -TestsOnly -GodotExe $godot

if ($LASTEXITCODE -ne 0 -or -not $?) {
    throw "Godot tests failed"
}

& $godot --path .
```

With Android export templates/SDK installed, omit `-TestsOnly` for the debug APK.

## Required actual playtest

1. Start Stage 1. Confirm the amber road disruption appears around nine running seconds, while the parcel cars remain visibly moving.
2. Tap the warning sign. It must clear the jam and award +75 without changing the underlying golden junction arrow.
3. Retry and trigger an incident again. Use the bottom-left CLEAR button rather than the marker. No duplicate reward.
4. Leave the first incident uncleared. The affected road returns to normal after nine seconds and no mistake is added.
5. Confirm the second incident targets another junction and that the shift never generates a third.
6. Pause the game during a jam: the warning remains visible, countdown freezes, and CLEAR is disabled.
7. On Beacon Docks, test all five junctions with a jam present. Verify the incident hitbox does not interfere with adjacent switches.
8. On a 360×780 phone and a larger phone, check that CLEAR and FOCUS stay visible and do not overlap or obstruct parcel destination icons.
9. Turn MOTION OFF and SFX OFF: rescue and scoring must remain functional.
10. Finish a shift; verify best scores, stars, level unlocks and the Dispatch challenges still work.

**Release gate:** Full Godot import, every regression suite, an actual screenshot review and physical Android touch QA remain pending. This milestone is not declared production-ready without these results.

## Next direction

If ARCADE-03 passes native and device testing, measure players' choices and difficulty before adding more incident types. Avoid creating unfair hard blocks or excessive HUD buttons.
