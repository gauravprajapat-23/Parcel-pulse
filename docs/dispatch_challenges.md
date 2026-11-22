# ARCADE-02 — Live Dispatch Contracts

**Status:** Source code and headless regression suite committed. Godot 4.7.2 native parsing and device verification are pending.

## Design intent

Delivery routing remains the core mechanic, but players now have *changing optional goals* during a shift. Each job displays progress next to the existing routing guide, without adding another button over an already crowded city board.

| Order | Job | Requirement | Additional reward |
| --- | --- | --- | ---: |
| 1 | Color Delivery | Correctly deliver two parcels to a particular colored home (rotates by stage) | +150 |
| 2 | Clean Streak | Make three consecutive correct Arcade deliveries *after the color job* | +200 |
| 3 | Gold Express | Make an on-time correct delivery of one golden Express parcel | +250 |

When all three are complete, the panel celebrates the full set. A completed job advances to the next automatically. The jobs are **optional**: they do not prevent completing a stage, are never required for stars or unlocks, and do not change the three-mistake limit.

### Fairness and consistency

- Only *real Arcade-spawned* parcels can advance contracts. Existing synthetic test deliveries, Classic mode, and programmatic Arcade controllers that did not explicitly opt into Dispatch preserve their original scoring.
- Rewards are part of the authoritative `ShiftController.score` and `bonus_score`; they also contribute to `last_delivery_points`, making the floating score accurate.
- A delivered parcel's `active=false` guard prevents the same parcel from receiving a reward twice.
- On a mistake, the Clean Streak challenge resets its progress to zero. The Color Delivery job retains already completed matching parcels.
- Express jobs award their bonus only when `is_express`, the actual timer is positive, and delivery matched its destination. An expired Express bonus never causes an extra mistake.
- Retry, Exit, or a new level reset mission progress and one-shift reward tallies. Persistent stage unlocks and best scores are unaffected.
- The dispatch bar is visible while RUNNING or PAUSED and hidden on the READY screen, avoiding unnecessary menu clutter.
- The game uses a predefined sequence with no ads, accounts, network data, real-money rewards, or unbounded random generation.

### Files

- `scripts/game/dispatch_challenges.gd`: immutable challenge descriptions and stage-color selection
- `scripts/game/shift_controller.gd`: challenge state, progress updates and one-time scoring
- `scripts/ui/game_screen.gd`: compact mission label and gold progress bar inside the guide panel
- `scripts/ui/board_view.gd`, `scripts/ui/game_juice.gd`: floating contract reward near depot
- `tests/test_dispatch_challenges.gd`: eligible-parcel checks, wrong-color filtering, clean streak resets, Express timing, reward idempotency, Retry/Exit, Classic compatibility and UI updates

## Run regression gate

```powershell
cd "C:\Users\RSP.tech Solution\Desktop\Parcel-pulse"
git switch main
git pull --ff-only origin main

$godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"

# Full source import and all existing + new regressions
.\tools\build_android_debug.ps1 -TestsOnly -GodotExe $godot
if (-not $?) { throw "Godot regression gate failed" }

# Open the game for visual acceptance
& $godot --path .
```

## Native and Android acceptance — still required

1. Open Stage 1. The dispatch panel is hidden on READY and shows **RED DELIVERY 0/2** on PLAY.
2. Deliver one red parcel, then another. Confirm the bar increments and the mission pays **+150** once, with a visible reward.
3. Deliver three correct parcels in a row after that job: watch CLEAN STREAK 0/3→3/3 and verify +200.
4. Route the next available golden Express parcel to its correct house before the ring expires. The third job awards +250 once.
5. Misroute while CLEAN STREAK is active: its job progress should reset but the already completed color bonus must not disappear.
6. Pause and resume. Dispatch progress must not advance while paused.
7. Retry a shift. The color job restarts at 0/2, mission bonus score clears and the Focus charges are restored.
8. On a 360×780 phone and on a large phone, check that the guide, dispatch bar, full game board, and buttons remain visible and do not overlap.
9. Run all local headless suites with zero failures. Export a debug APK only after the tests pass.
10. Replay Old Town and Beacon Docks to check that dispatch challenge color targets match the chosen stage.

**Known verification limit:** This workspace has no Godot executable or Android device, so it cannot attest actual GDScript parser, renderer, screenshot, audio, or device results. The new native suite is authored but not executed here.

**Next iteration:** Increase environmental interactions (temporary traffic interruptions or player-earned rescue tools) only after real Arcade + Dispatch playtesting confirms the pacing is fun rather than frustrating.
