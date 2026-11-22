# Parcel Pulse — Arcade gameplay upgrade

## Why this was added

The original game asked players to repeatedly toggle junction arrows. This upgrade adds changing priorities and decisions without changing the original graph, existing five stages, one-tap delivery controls, or offline progression.

## What the player sees

| Event | Player-facing feedback | Consequence |
| --- | --- | --- |
| Normal delivery | Colored cart reaches matching house | +100 points |
| Third consecutive correct Arcade parcel | COMBO ×3 indicator | Bonus starts (+25, then +50, +75, capped +100) |
| Fourth spawned parcel | Gold halo + circular countdown | +100 extra if correctly delivered with time remaining |
| Fifth consecutive Arcade delivery | RUSH HOUR indicator | Traffic runs about 18% faster for 7 real seconds |
| FOCUS button | FOCUS ×2, then SLOW 4s | One charge slows simulation to 58% for 4 real seconds |
| Wrong delivery | MISROUTE feedback | One mistake, combo reset, no points |
| Express countdown expires | Gold timer ring empties | Still delivers +100 normal points if routed correctly |
| Retry/Exit | Effects, boosts and streak reset | No change to persistent unlocks |

Only parcels spawned by an Arcade shift can earn combo and Express bonuses. Directly constructed parcels used by older tests keep their +100 score and do not increment combos. Classic mode remains the default when instantiating ShiftController directly; GameScreen turns on Arcade explicitly.

Rush and Focus timers use real elapsed time while their effects scale simulation time (both parcel motion and spawn schedule). Focus has priority if activated during a Rush. Pausing freezes both timers and game simulation.

## Implementation boundaries

- `DeliveryParcel`: Arcade metadata for spawned parcels; defaults remain safe.
- `ShiftController`: deterministic bonus accounting, streak, rush/focus timers, focus limits and reset semantics.
- `BoardView`: status banner, FOCUS button and UI layout. Gameplay state remains controller-owned.
- `CityBoardOverlay`: visible Express timer ring and modest extra Rush glow. No graph changes.
- `GameJuice`: displays the points actually awarded, including Express rewards.
- `GameScreen`: enables Arcade and coordinates feedback; the existing star/unlock save format stays unchanged.
- `tests/test_arcade_upgrade.gd`: Classic compatibility, bonus determinism, combo reset, rush, Focus, pause, UI button and retry.

## Run locally in Windows PowerShell

```powershell
cd "C:\Users\RSP.tech Solution\Desktop\Parcel-pulse"
git switch main
git pull --ff-only origin main

$godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"
.\tools\build_android_debug.ps1 -TestsOnly -GodotExe $godot
if (-not $?) { throw "Godot tests failed" }

& $godot --path .
```

Build the Android debug APK with `tools/build_android_debug.ps1` without `-TestsOnly` after a green gate.

## Manual gameplay QA — still pending

1. Start Stage 1. Check the board fills the panel and the FOCUS button stays away from junctions at 360×780 and 540×960.
2. Complete three correct deliveries: the combo indicator changes and delivery rewards increase.
3. Find the fourth spawned delivery: the cart has a gold countdown ring. Route it correctly and verify its bonus and the floating point label.
4. Reach combo five: Rush Hour triggers, the banner shows its countdown, and traffic speeds up temporarily.
5. Trigger Focus during Rush: motion slows, the boost timer counts down, the Focus charge decreases, and the button is disabled until the effect finishes.
6. Pause mid-Focus and resume. The countdown should not drain while paused.
7. Misroute a parcel: only one mistake and the combo resets; Express bonus expiry alone never counts as a mistake.
8. Retry and confirm the next run starts with two Focus charges, combo zero and no remaining Rush.
9. Switch MOTION OFF and SFX OFF: gameplay stays functional, and effects remain readable and optional.
10. Complete a shift, unlock the next stage, close and reopen offline; scores, stars and unlocks persist without corrupting old saves.

**Status:** Source and regression suite committed; actual Godot import, graphics, audio, FPS and Android touch testing have not run here. Do not treat the game as release-ready until these pass.
